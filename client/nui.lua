-- Bridge entre Lua e NUI: callbacks vindos do CEF e mensagens enviadas pra ele.
-- Tudo que é RegisterNUICallback / SendNUIMessage mora aqui. Lifecycle real
-- (load/create/finish) fica em main.lua via Multichar.*.

Multichar = Multichar or {}

local isNuiOpen = false
local isNuiReady = false

local function fetchInitialPayload()
    local payload = lib.callback.await('mri_Qmultichar:server:getCharacters', false)
    if type(payload) ~= 'table' then
        return nil
    end
    return payload
end

function Multichar.openMultichar()
    if isNuiOpen then return end

    DebugPrint('[mri_Qmultichar] Preparando dados para abrir NUI...')

    local payload = fetchInitialPayload()
    if not payload then
        lib.print.error('[mri_Qmultichar] Falha ao obter payload inicial do servidor')
        return
    end

    isNuiOpen = true
    SetNuiFocus(true, true)

    DebugPrint('[mri_Qmultichar] Abrindo NUI com dados carregados')
    SendNUIMessage({
        action = 'open',
        characters = payload.characters or {},
        amount = payload.slots or 3,
        accentColor = payload.accentColor,
        allowAccentOverride = payload.allowAccentOverride ~= false,
        defaults = payload.defaults or {},
        music = payload.music,
        locales = payload.locales or {},
    })
end

function Multichar.closeMultichar()
    if not isNuiOpen then return end

    isNuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })

    Headshots.cleanup()
end

function Multichar.isNuiOpen()
    return isNuiOpen
end

function Multichar.isNuiReady()
    return isNuiReady
end

RegisterNUICallback('getCharacters', function(_, cb)
    DebugPrint('[mri_Qmultichar] Callback getCharacters chamado')
    local payload = fetchInitialPayload()

    if payload then
        local characters = payload.characters or {}
        DebugPrint(string.format('[mri_Qmultichar] Personagens carregados: %d, Slots: %d', #characters, payload.slots or 3))
        cb({
            success = true,
            characters = characters,
            amount = payload.slots or 3,
            accentColor = payload.accentColor,
            allowAccentOverride = payload.allowAccentOverride ~= false,
            defaults = payload.defaults or {},
            music = payload.music,
            locales = payload.locales or {},
        })
    else
        lib.print.error('[mri_Qmultichar] Erro ao carregar personagens')
        local musicConfig = Config.Music or { enabled = false, url = '', volume = 0.3, loop = true, autoplay = true }
        local localeFile = LoadResourceFile(GetCurrentResourceName(), string.format('locales/%s.json', Config.Locale or 'pt-br'))
        local locales = {}
        if localeFile then
            local success, decoded = pcall(json.decode, localeFile)
            if success and decoded then
                locales = decoded
            end
        end
        cb({
            success = false,
            characters = {},
            amount = 3,
            accentColor = Config.AccentColor or '#00E699',
            allowAccentOverride = Config.AllowAccentOverride ~= false,
            defaults = {
                cameraEffects = Config.CameraEffects ~= false,
                cameraEffectType = Config.CameraEffectType or 'cinema',
                streamerMode = Config.StreamerMode == true,
            },
            music = musicConfig,
            locales = locales,
        })
    end
end)

-- Aplicação dos efeitos de câmera (timecycle modifier do preview cam).
-- NUI armazena a preferência em localStorage e dispara este callback ao mudar.
RegisterNUICallback('setCameraEffects', function(data, cb)
    if exports.mri_Qmultichar and exports.mri_Qmultichar.setCameraEffects then
        exports.mri_Qmultichar:setCameraEffects(data.enabled ~= false, data.effectType or 'cinema')
    end
    cb({ success = true })
end)

RegisterNUICallback('getCharacterPhoto', function(data, cb)
    local citizenId = data.citizenid
    if not citizenId then
        cb({ success = false, photo = nil })
        return
    end

    local success, photo = pcall(function()
        return lib.callback.await('mri_Qmultichar:server:getCharacterPhoto', false, citizenId)
    end)

    cb({ success = success and photo ~= nil, photo = success and photo or nil })
end)

RegisterNUICallback('savePhotoBase64', function(data, cb)
    local citizenId = data.citizenid
    local photo = data.photo

    if not citizenId or type(photo) ~= 'string' or photo == '' then
        cb({ success = false })
        return
    end

    Headshots.consumePending(citizenId)

    local ok = lib.callback.await('mri_Qmultichar:server:saveCharacterPhoto', false, citizenId, photo)
    if ok then
        DebugPrint(string.format('[mri_Qmultichar] Foto salva no metadata para %s', citizenId))
    else
        lib.print.warn(string.format('[mri_Qmultichar] Falha ao salvar foto no metadata para %s', citizenId))
    end

    cb({ success = ok == true })
end)

RegisterNUICallback('loadCharacter', function(data, cb)
    local success, message = Multichar.beginCharacterLoad(data.citizenid)
    cb({ success = success, message = message })
end)

RegisterNUICallback('createCharacter', function(data, cb)
    local charData = data.characterData
    if not charData then
        cb({ success = false, message = 'Dados do personagem não fornecidos' })
        return
    end

    if not charData.firstname or not charData.lastname or not charData.nationality or not charData.birthdate then
        cb({ success = false, message = 'Dados incompletos' })
        return
    end

    local success, message = Multichar.beginCharacterCreation(charData)
    cb({ success = success, message = message })
end)

RegisterNUICallback('deleteCharacter', function(data, cb)
    local citizenId = data.citizenid
    if not citizenId then
        cb({ success = false, message = 'CitizenID não fornecido' })
        return
    end

    Citizen.Wait(100)

    local success = lib.callback.await('mri_Qmultichar:server:deleteCharacter', false, citizenId)

    if success then
        Multichar.markDeleteTimestamp()

        Citizen.Wait(500)

        lib.notify({
            title = locale('messages.success'),
            description = locale('characters.character_deleted'),
            type = 'success',
        })

        SendNUIMessage({ action = 'refreshCharacters' })

        cb({ success = true })
    else
        lib.notify({
            title = locale('messages.error'),
            description = locale('characters.error_deleting'),
            type = 'error',
        })
        cb({ success = false, message = locale('characters.error_deleting') })
    end
end)

RegisterNUICallback('getPreviewData', function(data, cb)
    if Multichar.isCharacterCreationFlowActive() then
        DebugPrint('[mri_Qmultichar] [PREVIEW] getPreviewData chamado durante fluxo de criação, ignorando...')
        cb({ success = false })
        return
    end

    local citizenId = data.citizenid
    local jobName = data.job or 'unemployed'
    if not citizenId then
        cb({ success = false })
        return
    end

    DebugPrint(string.format('[mri_Qmultichar] [PREVIEW] Atualizando preview para CitizenID: %s, Job: %s', citizenId, jobName))

    cb({ success = true })

    CreateThread(function()
        exports.mri_Qmultichar:previewPed(citizenId, jobName)
    end)
end)

RegisterNUICallback('close', function(_, cb)
    Multichar.closeMultichar()
    cb({ success = true })
end)

RegisterNUICallback('nuiStarted', function(_, cb)
    local wasNotReady = not isNuiReady
    isNuiReady = true
    DebugPrint('[mri_Qmultichar] NUI sinalizou que está pronta (Handshake OK)')

    if wasNotReady and isNuiOpen then
        DebugPrint('[mri_Qmultichar] NUI pronta após fallback, reenviando dados de abertura...')
        isNuiOpen = false
        Multichar.openMultichar()
    end

    cb({ success = true })
end)

RegisterNetEvent('mri_Qmultichar:client:accentColorChanged', function(newColor)
    if not isNuiOpen then return end
    SendNUIMessage({ action = 'updateAccentColor', accentColor = newColor })
end)

exports('openMultichar', Multichar.openMultichar)
exports('closeMultichar', Multichar.closeMultichar)
