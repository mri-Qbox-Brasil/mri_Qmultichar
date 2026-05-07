local function dprint(...)
    if Config and Config.Debug then
        lib.print.info(...)
    end
end

local isNuiOpen = false

local isSpawning = false

local isCreatingCharacter = false

local isInCharacterCreation = false
local isIlleniumCustomizationActive = false

local lastDeleteTime = 0
local DELETE_COOLDOWN = 3000

local isNuiReady = false

local activeHeadshots = {}

local captureHeadshotForCharacter

local function awaitPlayerData(maxWaitMs)
    local elapsed = 0
    local step = 100
    local timeout = maxWaitMs or 5000

    while elapsed <= timeout do
        local ok, data = pcall(function()
            return exports.qbx_core:GetPlayerData()
        end)

        if ok and data and data.citizenid then
            return data
        end

        Wait(step)
        elapsed = elapsed + step
    end

    return nil
end

local function getQbxConfig()
    local success, qbxConfig = pcall(function()
        return require('@qbx_core/config/client')
    end)

    if success and qbxConfig and qbxConfig.characters then
        return qbxConfig
    end

    return {
        characters = {
            locations = {
                {
                    pedCoords = vector4(-66.28, -822.13, 285.61 - 1, 70.82),
                },
            },
            startingApartment = false,
        }
    }
end

local function isResourceStarted(resourceName)
    local resourceState = GetResourceState(resourceName)
    return resourceState == 'started' or resourceState == 'starting'
end

local function isCharacterCreationFlowActive()
    return isCreatingCharacter or isInCharacterCreation
end

local function finishCharacterCreation(reason, waitTime)
    local shouldReset = isCharacterCreationFlowActive() or isIlleniumCustomizationActive

    isIlleniumCustomizationActive = false

    if not shouldReset then
        return
    end

    if waitTime and waitTime > 0 then
        Wait(waitTime)
    end

    dprint(string.format('[mri_Qmultichar] [CRIAÇÃO] Finalizando criação (%s)...', reason or 'sem motivo'))

    CreateThread(function()
        local data = awaitPlayerData(5000)
        local citizenId = data and data.citizenid
        if not citizenId then
            lib.print.warn('[mri_Qmultichar] finishCharacterCreation sem citizenid disponível após espera; pulando captura de headshot')
            return
        end

        local ok, err = pcall(captureHeadshotForCharacter, citizenId, PlayerPedId())
        if not ok then
            lib.print.warn(string.format('[mri_Qmultichar] Falha (pcall) ao capturar headshot após criação: %s', tostring(err)))
        end
    end)

    TriggerServerEvent('mri_Qmultichar:server:setBucket', 0)
    isInCharacterCreation = false
    isCreatingCharacter = false
    dprint('[mri_Qmultichar] [CRIAÇÃO] Criação finalizada, flags resetadas')
end

local function useStartingApartment()
    local qbxConfig = getQbxConfig()
    return qbxConfig and qbxConfig.characters and qbxConfig.characters.startingApartment == true
end

local function hasQbxApartmentSelector()
    return isResourceStarted('qbx_properties') or isResourceStarted('qbx_apartments')
end

local function chooseConfiguredSpawn(citizenId)
    if isResourceStarted('mri_Qspawn') then
        exports['mri_Qspawn']:chooseSpawn()
        return true
    end

    if hasQbxApartmentSelector() and useStartingApartment() then
        TriggerEvent('apartments:client:setupSpawnUI', citizenId)
        return true
    end

    if isResourceStarted('qbx_spawn') then
        TriggerEvent('qb-spawn:client:setupSpawns', citizenId)
        TriggerEvent('qb-spawn:client:openUI', true)
        return true
    end

    return false
end

local function getIlleniumLocation()
    if Config and Config.CharacterCreation and Config.CharacterCreation.createLocation then
        return Config.CharacterCreation.createLocation
    end

    local qbxConfig = getQbxConfig()
    if qbxConfig and qbxConfig.characters and qbxConfig.characters.locations and #qbxConfig.characters.locations > 0 then
        return qbxConfig.characters.locations[1].pedCoords
    end

    return vector4(-66.28, -822.13, 285.61 - 1, 70.82)
end

local function getIlleniumCharacterConfig()
    return {
        ped = false,
        headBlend = true,
        faceFeatures = true,
        headOverlays = true,
        components = true,
        componentConfig = {
            masks = true,
            upperBody = true,
            lowerBody = true,
            bags = true,
            shoes = true,
            scarfAndChains = true,
            bodyArmor = true,
            shirts = true,
            decals = true,
            jackets = true,
        },
        props = true,
        propConfig = {
            hats = true,
            glasses = true,
            ear = true,
            watches = true,
            bracelets = true,
        },
        tattoos = true,
        enableExit = false,
        hasTracker = false,
        automaticFade = true,
    }
end

local function isNuiFocusedSafe()
    local ok, focused = pcall(function()
        return IsNuiFocused()
    end)

    return ok and focused == true
end

local function prepareFreemodePedForCreation(gender)
    local model = tonumber(gender) == 1 and `mp_f_freemode_01` or `mp_m_freemode_01`

    lib.requestModel(model, 60000)
    SetPlayerModel(cache.playerId, model)
    SetModelAsNoLongerNeeded(model)

    Wait(150)

    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    ClearPedTasksImmediately(ped)
    ClearPedDecorations(ped)
    SetPedDefaultComponentVariation(ped)

    if model == `mp_m_freemode_01` then
        SetPedHeadBlendData(ped, 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, false)
    else
        SetPedHeadBlendData(ped, 45, 21, 0, 20, 15, 0, 0.3, 0.1, 0.0, false)
    end

    for componentId = 0, 11 do
        SetPedComponentVariation(ped, componentId, 0, 0, 2)
    end

    for _, propId in ipairs({ 0, 1, 2, 6, 7 }) do
        ClearPedProp(ped, propId)
    end

    SetPedComponentVariation(ped, 2, 0, 0, 2)
    SetPedHairColor(ped, 0, 0)
    return ped
end

local function openIlleniumCharacterCreator(gender)
    if not isResourceStarted('illenium-appearance') then
        lib.print.error('[mri_Qmultichar] [CRIAÇÃO] illenium-appearance não está iniciado')
        return false
    end

    local illeniumLocation = getIlleniumLocation()
    local ped = prepareFreemodePedForCreation(gender)

    RequestCollisionAtCoord(illeniumLocation.x, illeniumLocation.y, illeniumLocation.z)
    SetEntityCoords(ped, illeniumLocation.x, illeniumLocation.y, illeniumLocation.z, false, false, false, true)
    SetEntityHeading(ped, illeniumLocation.w)
    SetEntityVisible(ped, true, false)

    isIlleniumCustomizationActive = true

    local ok, err = pcall(function()
        exports['illenium-appearance']:startPlayerCustomization(function(appearance)
            isIlleniumCustomizationActive = false

            if appearance then
                dprint('[mri_Qmultichar] [CRIAÇÃO] Aparência salva pelo illenium-appearance')
                TriggerServerEvent('illenium-appearance:server:saveAppearance', appearance)
                finishCharacterCreation('appearance_saved', 500)
            else
                lib.print.warn('[mri_Qmultichar] [CRIAÇÃO] Customização do illenium foi fechada sem salvar')
                finishCharacterCreation('appearance_closed', 500)
            end
        end, getIlleniumCharacterConfig())
    end)

    if not ok then
        isIlleniumCustomizationActive = false
        lib.print.error(string.format('[mri_Qmultichar] [CRIAÇÃO] Falha ao abrir startPlayerCustomization: %s', err))
        return false
    end

    Wait(200)

    if not isNuiFocusedSafe() then
        isIlleniumCustomizationActive = false
        lib.print.warn('[mri_Qmultichar] [CRIACAO] Illenium nao assumiu o foco da NUI, usando fallback...')
        return false
    end

    return true
end

local function fetchInitialPayload()
    local payload = lib.callback.await('mri_Qmultichar:server:getCharacters', false)
    if type(payload) ~= 'table' then
        return nil
    end
    return payload
end

local function openMultichar()
    if isNuiOpen then return end

    dprint('[mri_Qmultichar] Preparando dados para abrir NUI...')

    local payload = fetchInitialPayload()
    if not payload then
        lib.print.error('[mri_Qmultichar] Falha ao obter payload inicial do servidor')
        return
    end

    isNuiOpen = true
    SetNuiFocus(true, true)

    dprint('[mri_Qmultichar] Abrindo NUI com dados carregados')
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

local function CleanupHeadshots()
    if type(activeHeadshots) ~= 'table' then
        activeHeadshots = {}
        return
    end

    local count = #activeHeadshots
    if count > 0 then
        for i = 1, count do
            local headshot = activeHeadshots[i]
            if headshot and headshot ~= 0 then
                pcall(function()
                    UnregisterPedheadshot(headshot)
                end)
            end
        end
    end

    activeHeadshots = {}
end

local function closeMultichar()
    if not isNuiOpen then return end

    isNuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'close',
    })

    CleanupHeadshots()
end

local function spawnLastLocation()
    if isSpawning then
        return
    end

    isSpawning = true

    DoScreenFadeOut(500)

    while not IsScreenFadedOut() do
        Wait(0)
    end

    exports.mri_Qmultichar:destroyPreviewCam()

    Citizen.Wait(200)

    pcall(function()
        exports.spawnmanager:spawnPlayer({
            x = QBX.PlayerData.position.x,
            y = QBX.PlayerData.position.y,
            z = QBX.PlayerData.position.z,
            heading = QBX.PlayerData.position.w
        })
    end)

    Citizen.Wait(1000)

    local insideMeta = QBX.PlayerData.metadata.inside
    if GetResourceState('ps-housing') == 'started' and insideMeta.propertyId then
        TriggerServerEvent('ps-housing:server:enterProperty', tostring(insideMeta.propertyId))
    end

    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
    TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
    TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)

    while not IsScreenFadedIn() do
        Wait(0)
    end

    isSpawning = false
end

local function spawnDefault()
    if isSpawning then
        return
    end

    isSpawning = true

    local illeniumLocation = getIlleniumLocation()

    SetEntityVisible(cache.ped, true, false)

    RequestCollisionAtCoord(illeniumLocation.x, illeniumLocation.y, illeniumLocation.z)
    while not HasCollisionLoadedAroundEntity(cache.ped) do
        Wait(0)
    end

    SetEntityCoords(cache.ped, illeniumLocation.x, illeniumLocation.y, illeniumLocation.z, false, false, false, true)
    SetEntityHeading(cache.ped, illeniumLocation.w)

    Citizen.Wait(500)

    DoScreenFadeIn(250)

    while not IsScreenFadedIn() do
        Wait(0)
    end

    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
    TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
    TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)

    if not isInCharacterCreation then
        isInCharacterCreation = true
    end

    Wait(500)

    TriggerEvent('qb-clothes:client:CreateFirstCharacter')

    isSpawning = false
end

RegisterNUICallback('getCharacters', function(_, cb)
    dprint('[mri_Qmultichar] Callback getCharacters chamado')
    local payload = fetchInitialPayload()

    if payload then
        local characters = payload.characters or {}
        dprint(string.format('[mri_Qmultichar] Personagens carregados: %d, Slots: %d', #characters, payload.slots or 3))
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

local pendingHeadshots = {}

captureHeadshotForCharacter = function(citizenId, ped)
    if not citizenId then
        lib.print.error('[mri_Qmultichar] captureHeadshotForCharacter: citizenId nao fornecido')
        return false
    end

    ped = ped or PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        lib.print.error('[mri_Qmultichar] captureHeadshotForCharacter: ped invalido')
        return false
    end

    if not IsEntityVisible(ped) then
        SetEntityVisible(ped, true, false)
        Wait(100)
    end

    local handle = RegisterPedheadshotTransparent(ped)
    if not handle or handle == 0 then
        lib.print.error('[mri_Qmultichar] Falha ao registrar pedheadshot transparent')
        return false
    end

    local timeout = 200
    while not IsPedheadshotReady(handle) and timeout > 0 do
        Wait(10)
        timeout = timeout - 1
    end

    if not IsPedheadshotReady(handle) or not IsPedheadshotValid(handle) then
        lib.print.error('[mri_Qmultichar] Pedheadshot nao ficou pronto/valido')
        UnregisterPedheadshot(handle)
        return false
    end

    local txd = GetPedheadshotTxdString(handle)
    if not txd or txd == '' then
        lib.print.error('[mri_Qmultichar] TXD string vazia')
        UnregisterPedheadshot(handle)
        return false
    end

    local previous = pendingHeadshots[citizenId]
    if previous and previous ~= handle then
        pcall(UnregisterPedheadshot, previous)
    end
    pendingHeadshots[citizenId] = handle
    activeHeadshots[#activeHeadshots + 1] = handle

    SendNUIMessage({
        action = 'captureBase64',
        citizenid = citizenId,
        txd = txd,
    })

    dprint(string.format('[mri_Qmultichar] captureBase64 enviado para NUI: citizenid=%s, txd=%s', citizenId, txd))
    return true
end

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

    local handle = pendingHeadshots[citizenId]
    pendingHeadshots[citizenId] = nil
    if handle then
        pcall(UnregisterPedheadshot, handle)
    end

    local ok = lib.callback.await('mri_Qmultichar:server:saveCharacterPhoto', false, citizenId, photo)
    if ok then
        dprint(string.format('[mri_Qmultichar] Foto salva no metadata para %s', citizenId))
    else
        lib.print.warn(string.format('[mri_Qmultichar] Falha ao salvar foto no metadata para %s', citizenId))
    end

    cb({ success = ok == true })
end)

exports('captureHeadshotForCharacter', captureHeadshotForCharacter)

local isLoadingCharacter = false

local function beginCharacterLoad(citizenId, options)
    options = options or {}

    if not citizenId then
        return false, 'CitizenID nÃ£o fornecido'
    end

    if isLoadingCharacter then
        return false, 'Carregamento de personagem jÃ¡ em andamento'
    end

    if isSpawning then
        return false, 'Spawn jÃ¡ em andamento'
    end

    if not options.skipValidation then
        local validation = lib.callback.await('mri_Qmultichar:server:validateCharacterSelection', false, citizenId)
        if not validation or not validation.allowed then
            return false, validation and validation.message or 'VocÃª nÃ£o pode selecionar este personagem.'
        end
    end

    isLoadingCharacter = true

    CreateThread(function()
        if isSpawning then
            isLoadingCharacter = false
            return
        end

        if not isResourceStarted('mri_Qspawn') then
            DoScreenFadeOut(10)
        end

        local success = pcall(function()
            lib.callback.await('qbx_core:server:loadCharacter', false, citizenId)
        end)

        if success then
            isSpawning = true

            exports.mri_Qmultichar:destroyPreviewCam()
            closeMultichar()

            Citizen.Wait(200)

            if chooseConfiguredSpawn(citizenId) then
                isSpawning = false
            else
                spawnLastLocation()
            end
        end

        isLoadingCharacter = false
    end)

    return true
end

RegisterNUICallback('loadCharacter', function(data, cb)
    local success, message = beginCharacterLoad(data.citizenid)
    cb({
        success = success,
        message = message,
    })

    if true then
        return
    end

    local citizenId = data.citizenid
    if not citizenId then
        cb({ success = false, message = 'CitizenID não fornecido' })
        return
    end

    if isLoadingCharacter then
        cb({ success = false, message = 'Carregamento de personagem já em andamento' })
        return
    end

    isLoadingCharacter = true

    cb({ success = true })

    CreateThread(function()
        if isSpawning then
            isLoadingCharacter = false
            return
        end

        if not isResourceStarted('mri_Qspawn') then
            DoScreenFadeOut(10)
        end

        local success = pcall(function()
            lib.callback.await('qbx_core:server:loadCharacter', false, citizenId)
        end)

        if success then
            isSpawning = true

            exports.mri_Qmultichar:destroyPreviewCam()
            closeMultichar()

            Citizen.Wait(200)

            if chooseConfiguredSpawn(citizenId) then
                isSpawning = false
            else
                spawnLastLocation()
            end
        end

        isLoadingCharacter = false
    end)
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

    if isCreatingCharacter then
        cb({ success = false, message = 'Criação de personagem já em andamento' })
        return
    end

    local timeSinceDelete = GetGameTimer() - lastDeleteTime
    local cooldownTime = DELETE_COOLDOWN * 2
    if timeSinceDelete < cooldownTime then
        local remainingTime = math.ceil((cooldownTime - timeSinceDelete) / 1000)
        cb({ success = false, message = string.format('Aguarde %d segundo(s) após deletar um personagem', remainingTime) })
        return
    end

    local slotCheck = lib.callback.await('mri_Qmultichar:server:checkSlotAvailable', false, charData.cid)
    if not slotCheck or not slotCheck.available then
        lib.print.warn(string.format('[mri_Qmultichar] Slot %d não está disponível. Personagem ainda existe?', charData.cid))
        cb({ success = false, message = 'Este slot ainda está ocupado. Aguarde alguns segundos e tente novamente.' })
        return
    end

    isCreatingCharacter = true

    cb({ success = true })

    CreateThread(function()
        local success, newData = pcall(function()
            return lib.callback.await('qbx_core:server:createCharacter', false, {
                firstname = charData.firstname,
                lastname = charData.lastname,
                nationality = charData.nationality,
                gender = charData.gender,
                birthdate = charData.birthdate,
                cid = charData.cid,
            })
        end)

        if success and newData then
            dprint('[mri_Qmultichar] [CRIAÇÃO] Iniciando criação de personagem...')

            if isSpawning then
                lib.print.warn('[mri_Qmultichar] [CRIAÇÃO] Spawn já em andamento, cancelando...')
                isCreatingCharacter = false
                return
            end

            isSpawning = true
            dprint('[mri_Qmultichar] [CRIAÇÃO] Flag isSpawning = true')

            dprint('[mri_Qmultichar] [CRIAÇÃO] Fechando NUI e destruindo câmera de preview...')
            exports.mri_Qmultichar:destroyPreviewCam()
            closeMultichar()

            Citizen.Wait(500)
            dprint('[mri_Qmultichar] [CRIAÇÃO] NUI fechada, aguardando...')

            dprint('[mri_Qmultichar] [CRIAÇÃO] Definindo bucket 2 para criação...')
            TriggerServerEvent('mri_Qmultichar:server:setBucket', 2)
            Citizen.Wait(200)

            local illeniumLocation = getIlleniumLocation()
            dprint(string.format('[mri_Qmultichar] [CRIAÇÃO] Localização do illenium: %.2f, %.2f, %.2f, %.2f',
                illeniumLocation.x, illeniumLocation.y, illeniumLocation.z, illeniumLocation.w))

            local currentPos = GetEntityCoords(cache.ped)
            dprint(string.format('[mri_Qmultichar] [CRIAÇÃO] Posição atual: %.2f, %.2f, %.2f',
                currentPos.x, currentPos.y, currentPos.z))

            dprint('[mri_Qmultichar] [CRIAÇÃO] Iniciando fade out...')
            DoScreenFadeOut(500)
            while not IsScreenFadedOut() do
                Wait(0)
            end

            dprint('[mri_Qmultichar] [CRIAÇÃO] Limpando preview de jobs...')
            FreezeEntityPosition(PlayerPedId(), false)
            ClearPedTasks(PlayerPedId())

            dprint('[mri_Qmultichar] [CRIAÇÃO] Carregando colisão na localização do illenium...')
            RequestCollisionAtCoord(illeniumLocation.x, illeniumLocation.y, illeniumLocation.z)
            while not HasCollisionLoadedAroundEntity(cache.ped) do
                Wait(0)
            end

            dprint('[mri_Qmultichar] [CRIAÇÃO] Reposicionando personagem para localização do illenium...')
            SetEntityCoords(cache.ped, illeniumLocation.x, illeniumLocation.y, illeniumLocation.z, false, false, false, true)
            SetEntityHeading(cache.ped, illeniumLocation.w)
            SetEntityVisible(cache.ped, true, false)

            Citizen.Wait(200)
            local newPos = GetEntityCoords(cache.ped)
            dprint(string.format('[mri_Qmultichar] [CRIAÇÃO] Nova posição após reposicionar: %.2f, %.2f, %.2f',
                newPos.x, newPos.y, newPos.z))

            Citizen.Wait(300)

            dprint('[mri_Qmultichar] [CRIAÇÃO] Iniciando fade in...')
            DoScreenFadeIn(250)
            while not IsScreenFadedIn() do
                Wait(0)
            end

            local qbxConfig = getQbxConfig()

            dprint('[mri_Qmultichar] [CRIAÇÃO] Disparando eventos do qbx_core...')
            TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
            TriggerEvent('QBCore:Client:OnPlayerLoaded')
            TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
            TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)

            Wait(500)

            local posBeforeIllenium = GetEntityCoords(cache.ped)
            dprint(string.format('[mri_Qmultichar] [CRIAÇÃO] Posição antes de abrir illenium: %.2f, %.2f, %.2f',
                posBeforeIllenium.x, posBeforeIllenium.y, posBeforeIllenium.z))

            isInCharacterCreation = true
            dprint('[mri_Qmultichar] [CRIAÇÃO] Flag isInCharacterCreation = true')

            CreateThread(function()
                local illeniumLocation = getIlleniumLocation()
                local maxWaitTime = 300000
                local startTime = GetGameTimer()
                dprint('[mri_Qmultichar] [CRIAÇÃO] Thread de monitoramento iniciada')

                while isInCharacterCreation do
                    if GetGameTimer() - startTime > maxWaitTime then
                        lib.print.warn('[mri_Qmultichar] [CRIAÇÃO] Timeout na thread de monitoramento, desativando...')
                        finishCharacterCreation('monitor_timeout')
                        break
                    end

                    if not isIlleniumCustomizationActive then
                        Wait(2000)

                        if not isIlleniumCustomizationActive then
                            dprint('[mri_Qmultichar] [CRIAÇÃO] Illenium não está mais ativo, desativando monitoramento...')
                            finishCharacterCreation('monitor_detected_closed')
                            break
                        end
                    end

                    if LocalPlayer.state.isLoggedIn and not isIlleniumCustomizationActive then
                        dprint('[mri_Qmultichar] [CRIAÇÃO] Personagem carregado (isLoggedIn = true), desativando monitoramento...')
                        finishCharacterCreation('monitor_player_loaded')
                        break
                    end

                    local currentCoords = GetEntityCoords(cache.ped)
                    local distance = #(vector3(currentCoords.x, currentCoords.y, currentCoords.z) - vector3(illeniumLocation.x, illeniumLocation.y, illeniumLocation.z))

                    if distance > 5.0 then
                        if isIlleniumCustomizationActive then
                            lib.print.warn(string.format('[mri_Qmultichar] [CRIAÇÃO] Jogador se afastou (distância: %.2f), reposicionando...', distance))
                            RequestCollisionAtCoord(illeniumLocation.x, illeniumLocation.y, illeniumLocation.z)
                            while not HasCollisionLoadedAroundEntity(cache.ped) do
                                Wait(0)
                            end
                            SetEntityCoords(cache.ped, illeniumLocation.x, illeniumLocation.y, illeniumLocation.z, false, false, false, true)
                            SetEntityHeading(cache.ped, illeniumLocation.w)

                            local afterPos = GetEntityCoords(cache.ped)
                            dprint(string.format('[mri_Qmultichar] [CRIAÇÃO] Reposicionado para: %.2f, %.2f, %.2f',
                                afterPos.x, afterPos.y, afterPos.z))
                        else
                            Wait(3000)
                            if LocalPlayer.state.isLoggedIn then
                                dprint('[mri_Qmultichar] [CRIAÇÃO] Personagem carregado após fechar illenium, desativando...')
                                finishCharacterCreation('monitor_closed_after_loaded')
                                break
                            else
                                dprint('[mri_Qmultichar] [CRIAÇÃO] Illenium fechado durante monitoramento, desativando...')
                                finishCharacterCreation('monitor_closed_without_load')
                                break
                            end
                        end
                    end

                    Wait(500)
                end

                dprint('[mri_Qmultichar] [CRIAÇÃO] Thread de monitoramento finalizada')
            end)

            dprint('[mri_Qmultichar] [CRIAÇÃO] Abrindo illenium-appearance...')

            Citizen.Wait(500)

            if not openIlleniumCharacterCreator(charData.gender) then
                lib.print.warn('[mri_Qmultichar] [CRIAÇÃO] Fallback para qb-clothes:client:CreateFirstCharacter')
                isIlleniumCustomizationActive = true
                TriggerEvent('qb-clothes:client:CreateFirstCharacter')
            end

            dprint('[mri_Qmultichar] [CRIAÇÃO] Illenium aberto, aguardando...')

            CreateThread(function()
                Wait(2000)
                if isInCharacterCreation then
                    local posAfterIllenium = GetEntityCoords(cache.ped)
                    dprint(string.format('[mri_Qmultichar] [CRIAÇÃO] Posição após 2s do illenium: %.2f, %.2f, %.2f',
                        posAfterIllenium.x, posAfterIllenium.y, posAfterIllenium.z))
                end
            end)

            isSpawning = false
        end

        isCreatingCharacter = false
    end)
end)

RegisterNetEvent('illenium-appearance:client:characterSaved', function()
    dprint('[mri_Qmultichar] [ILLENIUM] Evento characterSaved recebido')
    if isInCharacterCreation then
        dprint('[mri_Qmultichar] [ILLENIUM] isInCharacterCreation = true, finalizando criação...')
        isIlleniumCustomizationActive = false
        finishCharacterCreation('event_character_saved', 2000)
    else
        dprint('[mri_Qmultichar] [ILLENIUM] isInCharacterCreation = false, ignorando evento')
    end
end)

RegisterNetEvent('qb-clothes:client:characterSaved', function()
    dprint('[mri_Qmultichar] [ILLENIUM] Evento qb-clothes characterSaved recebido')
    if isInCharacterCreation then
        dprint('[mri_Qmultichar] [ILLENIUM] isInCharacterCreation = true, finalizando criação...')
        isIlleniumCustomizationActive = false
        finishCharacterCreation('event_qb_character_saved', 2000)
    else
        dprint('[mri_Qmultichar] [ILLENIUM] isInCharacterCreation = false, ignorando evento')
    end
end)

RegisterNetEvent('illenium-appearance:client:close', function()
    dprint('[mri_Qmultichar] [ILLENIUM] Evento close recebido')
    if isInCharacterCreation then
        dprint('[mri_Qmultichar] [ILLENIUM] isInCharacterCreation = true, finalizando criação (close)...')
        isIlleniumCustomizationActive = false
        finishCharacterCreation('event_illenium_close', 2000)
    end
end)

RegisterNetEvent('qb-clothes:client:close', function()
    dprint('[mri_Qmultichar] [ILLENIUM] Evento qb-clothes close recebido')
    if isInCharacterCreation then
        dprint('[mri_Qmultichar] [ILLENIUM] isInCharacterCreation = true, finalizando criação (close)...')
        isIlleniumCustomizationActive = false
        finishCharacterCreation('event_qb_close', 2000)
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    if isInCharacterCreation then
        dprint('[mri_Qmultichar] [LOADED] Personagem carregado, finalizando criação...')
        isIlleniumCustomizationActive = false
        finishCharacterCreation('event_player_loaded', 1000)
        return
    end

    CreateThread(function()
        Wait(4000)

        local data = awaitPlayerData(5000)
        local citizenId = data and data.citizenid
        if not citizenId then
            lib.print.warn('[mri_Qmultichar] OnPlayerLoaded sem citizenid disponível; pulando verificação de foto')
            return
        end

        local existing = data.metadata and data.metadata.photo
        if existing and existing ~= '' then
            return
        end

        local ok, dbPhoto = pcall(function()
            return lib.callback.await('mri_Qmultichar:server:getCharacterPhoto', false, citizenId)
        end)
        if ok and dbPhoto and dbPhoto ~= '' then
            return
        end

        dprint(string.format('[mri_Qmultichar] Char %s sem foto salva, capturando...', citizenId))
        pcall(captureHeadshotForCharacter, citizenId, PlayerPedId())
    end)
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
        lastDeleteTime = GetGameTimer()

        Citizen.Wait(500)

        lib.notify({
            title = locale('messages.success'),
            description = locale('characters.character_deleted'),
            type = 'success'
        })

        SendNUIMessage({
            action = 'refreshCharacters',
        })

        cb({ success = true })
    else
        lib.notify({
            title = locale('messages.error'),
            description = locale('characters.error_deleting'),
            type = 'error'
        })
        cb({ success = false, message = locale('characters.error_deleting') })
    end
end)

RegisterNUICallback('getPreviewData', function(data, cb)
    if isCharacterCreationFlowActive() then
        lib.print.warn('[mri_Qmultichar] [PREVIEW] getPreviewData chamado durante fluxo de criação, ignorando...')
        cb({ success = false })
        return
    end

    local citizenId = data.citizenid
    local jobName = data.job or 'unemployed'
    if not citizenId then
        cb({ success = false })
        return
    end

    dprint(string.format('[mri_Qmultichar] [PREVIEW] Atualizando preview para CitizenID: %s, Job: %s', citizenId, jobName))

    cb({ success = true })

    CreateThread(function()
        pcall(function()
            exports.mri_Qmultichar:previewPed(citizenId, jobName)
        end)
    end)
end)

RegisterNUICallback('close', function(_, cb)
    closeMultichar()
    cb({ success = true })
end)

RegisterNUICallback('nuiStarted', function(_, cb)
    local wasNotReady = not isNuiReady
    isNuiReady = true
    dprint('[mri_Qmultichar] NUI sinalizou que está pronta (Handshake OK)')

    if wasNotReady and isNuiOpen then
        dprint('[mri_Qmultichar] NUI pronta após fallback, reenviando dados de abertura...')
        isNuiOpen = false
        openMultichar()
    end

    cb({ success = true })
end)

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    if GetInvokingResource() then return end
    if isInCharacterCreation then
        dprint('[mri_Qmultichar] [LOGOUT] Resetando flag isInCharacterCreation ao fazer logout')
        isIlleniumCustomizationActive = false
        isInCharacterCreation = false
        TriggerServerEvent('mri_Qmultichar:server:setBucket', 0)
    end

    openMultichar()
    pcall(function()
        exports.mri_Qmultichar:setupPreviewCam()
    end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    if isInCharacterCreation then
        dprint('[mri_Qmultichar] [UNLOAD] Resetando flag isInCharacterCreation ao descarregar personagem')
        isIlleniumCustomizationActive = false
        isInCharacterCreation = false
        TriggerServerEvent('mri_Qmultichar:server:setBucket', 0)
    end
end)

CreateThread(function()
    dprint('[mri_Qmultichar] Thread de inicialização iniciada')
    while true do
        Wait(0)
        if NetworkIsSessionStarted() then
            if LocalPlayer.state.isLoggedIn then
                dprint('[mri_Qmultichar] Player já logado em personagem; solicitando logout server-side')
                TriggerServerEvent('mri_Qmultichar:server:requestLogout')
                break
            end

            dprint('[mri_Qmultichar] Sessão iniciada, configurando multichar...')
            pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
            Wait(250)

            local payload = fetchInitialPayload()
            local characters = payload and payload.characters or {}
            local firstCharacterCitizenId = characters[1] and characters[1].citizenid

            local jobName = characters[1] and characters[1].job and (characters[1].job.name or (characters[1].job.label and string.lower(string.gsub(characters[1].job.label, '%s+', '')))) or 'unemployed'
            Citizen.Wait(100)
            pcall(function()
                exports.mri_Qmultichar:previewPed(firstCharacterCitizenId, jobName)
            end)

            local qbxConfig = getQbxConfig()
            if not qbxConfig or not qbxConfig.characters or not qbxConfig.characters.locations or #qbxConfig.characters.locations == 0 then
                lib.print.error('[mri_Qmultichar] Nenhuma localização configurada no qbx_core!')
                break
            end
            local randomLocation = qbxConfig.characters.locations[math.random(1, #qbxConfig.characters.locations)]

            DoScreenFadeOut(500)

            while not IsScreenFadedOut() and cache.ped ~= PlayerPedId() do
                Wait(0)
            end

            FreezeEntityPosition(cache.ped, true)
            Wait(1000)

            RequestCollisionAtCoord(randomLocation.pedCoords.x, randomLocation.pedCoords.y, randomLocation.pedCoords.z)
            while not HasCollisionLoadedAroundEntity(cache.ped) do Wait(0) end

            SetEntityCoords(cache.ped, randomLocation.pedCoords.x, randomLocation.pedCoords.y, randomLocation.pedCoords.z, false, false, false, false)
            SetEntityHeading(cache.ped, randomLocation.pedCoords.w)

            NetworkStartSoloTutorialSession()

            while not NetworkIsInTutorialSession() do
                Wait(0)
            end

            Wait(250)
            ShutdownLoadingScreen()
            ShutdownLoadingScreenNui()

            dprint('[mri_Qmultichar] Configurando preview cam...')
            Citizen.Wait(100)
            pcall(function()
                exports.mri_Qmultichar:setupPreviewCam()
            end)

            Wait(100)
            dprint('[mri_Qmultichar] Abrindo NUI...')

            local timeout = 50
            while not isNuiReady and timeout > 0 do
                Wait(100)
                timeout = timeout - 1
                if timeout % 10 == 0 then
                    dprint('[mri_Qmultichar] Aguardando NUI ficar pronta (Handshake)...')
                end
            end

            if not isNuiReady then
                lib.print.warn('[mri_Qmultichar] NUI demorou demais para sinalizar pronta, tentando abrir mesmo assim...')
            end

            openMultichar()

            CreateThread(function()
                Wait(2000)
                if not isNuiOpen then
                    lib.print.warn('[mri_Qmultichar] NUI não abriu, tentando abrir novamente...')
                    openMultichar()
                end
            end)

            break
        end
    end

    while isNuiOpen do
        SetEntityInvincible(PlayerPedId(), true)
        Wait(250)
    end
    SetEntityInvincible(PlayerPedId(), false)
end)

RegisterNetEvent('mri_Qmultichar:client:accentColorChanged', function(newColor)
    if not isNuiOpen then return end
    SendNUIMessage({ action = 'updateAccentColor', accentColor = newColor })
end)

exports('openMultichar', openMultichar)
exports('closeMultichar', closeMultichar)
exports('isInCharacterCreation', function()
    return isCharacterCreationFlowActive()
end)
