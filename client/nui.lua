-- Bridge entre Lua e NUI: callbacks vindos do CEF e mensagens enviadas pra ele.
-- Tudo que é RegisterNUICallback / SendNUIMessage mora aqui. Lifecycle real
-- (load/create/finish) fica em main.lua via Multichar.*.

Multichar = Multichar or {}

local isNuiOpen = false
local isNuiReady = false

-- ===== trilha sonora do mri_Qbox (opcional) ==========================
-- Com o módulo soundtrack do mri_Qbox ligado, a música das fases (menu, criação,
-- editor, chegada) vira um pedido no statebag do jogador (music:mri_Qmultichar,
-- prioridade de cena) e o player próprio da NUI fica parado. Sem export: sem o
-- mri_Qbox, o estado não tem quem leia e o player próprio toca como antes.

local MUSIC_KEY = 'music:mri_Qmultichar'
local DUCK_KEY = 'musicDuck:mri_Qmultichar'

-- a config de módulos que o mri_Qbox publica no GlobalState diz se a trilha está ligada
function Multichar.soundtrackAvailable()
    if GetResourceState('mri_Qbox') ~= 'started' then return false end
    local modules = GlobalState['mri_Qbox:config']
    return type(modules) == 'table' and type(modules.soundtrack) == 'table' and modules.soundtrack.enabled == true
end

local function releaseMusic()
    LocalPlayer.state:set(MUSIC_KEY, nil, false)
    LocalPlayer.state:set(DUCK_KEY, nil, false)
end

RegisterNUICallback('musicPush', function(data, cb)
    cb({ success = true })
    if type(data) ~= 'table' or type(data.url) ~= 'string' then return end
    -- nothing on the mri_Qbox screen: its NUI sits under ours and could not take clicks anyway
    LocalPlayer.state:set(MUSIC_KEY, { url = data.url, loop = data.loop ~= false, priority = 'scene', display = 'none' }, false)
end)

RegisterNUICallback('musicPop', function(_, cb)
    cb({ success = true })
    releaseMusic()
end)

-- a criação abaixa a música pros efeitos e sobe no final (setMusicLevel na NUI)
RegisterNUICallback('musicDuck', function(data, cb)
    cb({ success = true })
    if type(data) ~= 'table' then return end
    local level = tonumber(data.level) or 1
    LocalPlayer.state:set(DUCK_KEY, level < 0.999 and { level = level, fade = tonumber(data.fadeMs) } or nil, false)
end)

-- o pedido é deste resource: parou, solta (senão a música seguiria tocando)
AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then releaseMusic() end
end)

local function fetchInitialPayload()
    local payload = lib.callback.await('mri_Qmultichar:server:getCharacters', false)
    if type(payload) ~= 'table' then
        return nil
    end
    return payload
end

---@param intro boolean|nil true = abre na tela de título da abertura (Intro)
function Multichar.openMultichar(intro)
    if isNuiOpen then return end

    DebugPrint('[mri_Qmultichar] Preparando dados para abrir NUI...')

    local payload = fetchInitialPayload()
    if not payload then
        lib.print.error('[mri_Qmultichar] Falha ao obter payload inicial do servidor')
        return
    end

    isNuiOpen = true
    SetNuiFocus(true, true)
    SetEntityInvincible(PlayerPedId(), true)

    -- esconde a HUD (mri_Qhud escuta o statebag hideHud do player)
    LocalPlayer.state:set('hideHud', true, false)
    Intro.ambienceStart(payload.ambience)

    DebugPrint('[mri_Qmultichar] Abrindo NUI com dados carregados')
    SendNUIMessage({
        action = 'open',
        intro = intro == true,
        characters = payload.characters or {},
        amount = payload.slots or 3,
        lastPlayed = payload.lastPlayed,
        accentColor = payload.accentColor,
        backgroundColor = payload.backgroundColor or '',
        allowAccentOverride = payload.allowAccentOverride ~= false,
        branding = payload.branding,
        landing = payload.landing,
        music = payload.music,
        externalMusic = Multichar.soundtrackAvailable(),
        arrivals = payload.arrivals,
        locales = payload.locales or {},
    })
end

---@param keepHud boolean|nil true = deixa a HUD escondida (a criação segue direto pro editor)
function Multichar.closeMultichar(keepHud)
    if not isNuiOpen then return end

    isNuiOpen = false
    SetNuiFocus(false, false)
    SetEntityInvincible(PlayerPedId(), false)
    -- indo pro editor, a trilha segue (passa pra faixa do editor); entrando no jogo, some
    SendNUIMessage({ action = 'close', keepMusic = keepHud == true })

    -- restaura a HUD, a hora e o clima ao sair do multichar (a criação segue com eles
    -- no estúdio e devolve no fim)
    if not keepHud then
        LocalPlayer.state:set('hideHud', false, false)
        Intro.ambienceStop()
    end

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
            lastPlayed = payload.lastPlayed,
            accentColor = payload.accentColor,
            backgroundColor = payload.backgroundColor or '',
            allowAccentOverride = payload.allowAccentOverride ~= false,
            branding = payload.branding,
            landing = payload.landing,
            music = payload.music,
            arrivals = payload.arrivals,
            locales = payload.locales or {},
        })
    else
        lib.print.error('[mri_Qmultichar] Erro ao carregar personagens')
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
            accentColor = GetConvar('mri:color', '#00E699'),
            backgroundColor = GetConvar('mri:backgroundColor', ''),
            allowAccentOverride = Config.AllowAccentOverride ~= false,
            locales = locales,
        })
    end
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

-- Preview 3D da criação (ped no palco que acompanha o gênero escolhido na NUI).
RegisterNUICallback('creationPreviewStart', function(_, cb)
    cb({ success = Showroom.creationStart() })
end)

RegisterNUICallback('creationPreview', function(data, cb)
    cb({ success = true })
    if type(data) ~= 'table' then return end
    Showroom.creationPreview(data.gender)
end)

RegisterNUICallback('creationShot', function(data, cb)
    cb({ success = true })
    if type(data) ~= 'table' then return end
    Showroom.creationShot(data.shot)
end)

RegisterNUICallback('creationReact', function(data, cb)
    cb({ success = true })
    if type(data) ~= 'table' then return end
    Showroom.creationReact(data.kind)
end)

RegisterNUICallback('creationPreviewStop', function(_, cb)
    cb({ success = true })
    Showroom.creationStop()
end)

-- uma deleção por vez: a NUI já trava o botão, isto barra chamada repetida que chegue mesmo assim
local deleteInFlight = false

RegisterNUICallback('deleteCharacter', function(data, cb)
    local citizenId = data.citizenid
    if not citizenId then
        cb({ success = false, message = 'CitizenID não fornecido' })
        return
    end

    if deleteInFlight then
        cb({ success = false, busy = true })
        return
    end

    deleteInFlight = true
    local ok, success = pcall(lib.callback.await, 'mri_Qmultichar:server:deleteCharacter', false, citizenId)
    deleteInFlight = false
    success = ok and success

    if success then
        cb({ success = true })

        lib.notify({
            title = locale('messages.success'),
            description = locale('characters.character_deleted'),
            type = 'success',
        })

        -- o ped some da cena e os seguintes andam uma posição; só depois a NUI
        -- recarrega a lista e foca a próxima seleção
        Showroom.removeCharacter(citizenId)
        SendNUIMessage({ action = 'refreshCharacters' })
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

    DebugPrint(string.format('[mri_Qmultichar] [PREVIEW] Focando showroom no CitizenID: %s', citizenId))

    cb({ success = true })

    Showroom.focus(citizenId)
end)

RegisterNUICallback('focusEmptySlot', function(_, cb)
    cb({ success = true })
    if Multichar.isCharacterCreationFlowActive() then return end
    Showroom.focusEmpty()
end)

-- SFX da interação (juice): usa os sons de frontend nativos do GTA — zero assets.
-- A NUI dispara playSound com uma chave; mapeamos pra (soundName, soundSet).
local SFX = {
    hover  = { 'NAV_UP_DOWN',    'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    switch = { 'NAV_LEFT_RIGHT', 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    select = { 'SELECT',         'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    back   = { 'BACK',           'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    cancel = { 'CANCEL',         'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    error  = { 'ERROR',          'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    delete = { 'DELETE',         'HUD_DEACTIVATE_SOUNDSET' },
    enter  = { 'Mission_Pass_Notify', 'DLC_HEISTS_GENERAL_FRONTEND_SOUNDS' },
}

RegisterNUICallback('playSound', function(data, cb)
    local key = type(data) == 'table' and data.name
    local s = key and SFX[key]
    if s then
        PlaySoundFrontend(-1, s[1], s[2], true)
    end
    cb({ success = s ~= nil })
end)

RegisterNUICallback('close', function(_, cb)
    Multichar.closeMultichar()
    cb({ success = true })
end)

-- Estilo visual do painel /uiconfig do ox_lib (radius, cores de status, etc).
-- Em thread própria: se o ox_lib não tiver o callback (sem a mri/), só isso
-- fica esperando e a abertura do multichar não trava.
local function pushUiConfig()
    CreateThread(function()
        local uiConfig = lib.callback.await('ox_lib:getUiConfig', false)
        if type(uiConfig) ~= 'table' then return end
        SendNUIMessage({ action = 'applyUiConfig', uiConfig = uiConfig })
    end)
end

RegisterNUICallback('nuiStarted', function(_, cb)
    local wasNotReady = not isNuiReady
    isNuiReady = true
    DebugPrint('[mri_Qmultichar] NUI sinalizou que está pronta (Handshake OK)')

    if wasNotReady then
        pushUiConfig()
    end

    if wasNotReady and isNuiOpen then
        DebugPrint('[mri_Qmultichar] NUI pronta após fallback, reenviando dados de abertura...')
        isNuiOpen = false
        Multichar.openMultichar(Intro.isPlaying())
    end

    cb({ success = true })
end)

RegisterNetEvent('mri_Qmultichar:client:accentColorChanged', function(newColor)
    if not isNuiOpen then return end
    SendNUIMessage({ action = 'updateAccentColor', accentColor = newColor })
end)

-- Sem checar isNuiOpen: a NUI guarda a cor e o /adminchar também usa esta página.
RegisterNetEvent('mri_Qmultichar:client:backgroundColorChanged', function(newColor)
    SendNUIMessage({ action = 'updateBackgroundColor', backgroundColor = newColor or '' })
end)

-- Broadcast do ox_lib quando o admin salva o /uiconfig — reaplica sem restart.
RegisterNetEvent('ox_lib:uiConfigChanged', function(newConfig)
    if type(newConfig) ~= 'table' then return end
    SendNUIMessage({ action = 'applyUiConfig', uiConfig = newConfig })
end)

-- Broadcast do painel /adminchar (branding/landing/música): atualiza a NUI ao vivo.
RegisterNetEvent('mri_Qmultichar:client:configChanged', function(newConfig, arrivals)
    if type(newConfig) ~= 'table' then return end
    if not isNuiOpen then return end
    SendNUIMessage({
        action = 'updateConfig',
        branding = newConfig.branding,
        landing = newConfig.landing,
        music = newConfig.music,
        arrivals = arrivals,
    })
end)

exports('openMultichar', Multichar.openMultichar)
exports('closeMultichar', Multichar.closeMultichar)
