-- Orquestrador do multichar: estado, lifecycle (load/create/finish),
-- spawn flow, listeners de eventos do framework e thread de inicialização.
-- NUI bridge mora em nui.lua, headshots em headshots.lua.

Multichar = Multichar or {}

local isSpawning = false
local isCreatingCharacter = false
local isInCharacterCreation = false
local isIlleniumCustomizationActive = false
local isLoadingCharacter = false

local lastDeleteTime = 0
local DELETE_COOLDOWN = 3000

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

function Multichar.isCharacterCreationFlowActive()
    return isCreatingCharacter or isInCharacterCreation
end

function Multichar.markDeleteTimestamp()
    lastDeleteTime = GetGameTimer()
end

local function finishCharacterCreation(reason, waitTime)
    local shouldReset = Multichar.isCharacterCreationFlowActive() or isIlleniumCustomizationActive

    isIlleniumCustomizationActive = false

    if not shouldReset then
        return
    end

    if waitTime and waitTime > 0 then
        Wait(waitTime)
    end

    DebugPrint(string.format('[mri_Qmultichar] [CRIAÇÃO] Finalizando criação (%s)...', reason or 'sem motivo'))

    CreateThread(function()
        local data = awaitPlayerData(5000)
        local citizenId = data and data.citizenid
        if not citizenId then
            lib.print.warn('[mri_Qmultichar] finishCharacterCreation sem citizenid disponível após espera; pulando captura de headshot')
            return
        end

        local ok, err = pcall(Headshots.capture, citizenId, PlayerPedId())
        if not ok then
            lib.print.warn(string.format('[mri_Qmultichar] Falha (pcall) ao capturar headshot após criação: %s', tostring(err)))
        end
    end)

    TriggerServerEvent('mri_Qmultichar:server:setBucket', 0)
    isInCharacterCreation = false
    isCreatingCharacter = false
    DebugPrint('[mri_Qmultichar] [CRIAÇÃO] Criação finalizada, flags resetadas')
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
    return IsNuiFocused() == true
end

-- Troca o modelo (delegada ao appearance) e posiciona o ped. O posicionamento vem
-- logo depois da troca: SetPlayerModel recria o ped e o novo nasce na posição
-- default da engine (aeroporto) até alguém colocá-lo no lugar.
---@param gender number|string 1 = feminino
---@param coords vector4 posição + heading da criação
local function prepareFreemodePedForCreation(gender, coords)
    local model = tonumber(gender) == 1 and `mp_f_freemode_01` or `mp_m_freemode_01`

    RequestCollisionAtCoord(coords.x, coords.y, coords.z)

    if not Appearance.setPlayerModel(model) then
        -- último recurso: mesma receita do illenium, na mão
        lib.print.warn('[mri_Qmultichar] [CRIAÇÃO] appearance sem setPlayerModel; trocando o modelo na mão')
        lib.requestModel(model, 60000)
        SetPlayerModel(cache.playerId, model)
        SetModelAsNoLongerNeeded(model)
        Wait(150)
        SetPedDefaultComponentVariation(PlayerPedId())
        if model == `mp_m_freemode_01` then
            SetPedHeadBlendData(PlayerPedId(), 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, false)
        else
            SetPedHeadBlendData(PlayerPedId(), 45, 21, 0, 20, 15, 0, 0.3, 0.1, 0.0, false)
        end
    end

    local ped = PlayerPedId()

    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, true)
    SetEntityHeading(ped, coords.w)

    SetEntityVisible(ped, true, false)
    ClearPedTasksImmediately(ped)
    ClearPedDecorations(ped)

    -- estado "cru" pro editor abrir
    for componentId = 0, 11 do
        SetPedComponentVariation(ped, componentId, 0, 0, 2)
    end

    for _, propId in ipairs({ 0, 1, 2, 6, 7 }) do
        ClearPedProp(ped, propId)
    end

    SetPedHairColor(ped, 0, 0)
    return ped
end

local function openIlleniumCharacterCreator()
    if not Appearance.isReady() then
        lib.print.error('[mri_Qmultichar] [CRIAÇÃO] nenhum resource de appearance compatível está iniciado')
        return false
    end

    -- ped já trocado e posicionado em prepareFreemodePedForCreation
    isIlleniumCustomizationActive = true

    local ok = Appearance.startCustomization(function(appearance)
        isIlleniumCustomizationActive = false

        if appearance then
            DebugPrint(string.format('[mri_Qmultichar] [CRIAÇÃO] Aparência salva pelo %s', Appearance.getResourceName()))
            Appearance.saveAppearance(appearance)
            finishCharacterCreation('appearance_saved', 500)
        else
            lib.print.warn('[mri_Qmultichar] [CRIAÇÃO] Customização foi fechada sem salvar')
            finishCharacterCreation('appearance_closed', 500)
        end
    end, getIlleniumCharacterConfig())

    if not ok then
        isIlleniumCustomizationActive = false
        lib.print.error('[mri_Qmultichar] [CRIAÇÃO] Falha ao abrir startCustomization')
        return false
    end

    -- Espera o editor assumir o foco da NUI. Era um Wait(200) fixo: na criacao
    -- do primeiro personagem o appearance ainda esta inicializando e passa
    -- disso, entao caia no fallback e os dois fluxos disputavam bucket e ped.
    local deadline = GetGameTimer() + 5000
    while not isNuiFocusedSafe() and GetGameTimer() < deadline do
        Wait(50)
    end

    if not isNuiFocusedSafe() then
        isIlleniumCustomizationActive = false
        lib.print.warn('[mri_Qmultichar] [CRIACAO] Illenium nao assumiu o foco da NUI, usando fallback...')
        return false
    end

    return true
end

-- O ps-housing so monta os imoveis no client no OnPlayerLoaded e avisa com
-- initialisedProperties; entrar antes disso quebra o EnterShell dele. Se o
-- player ja esta logado (relog ou restart deste resource), ja foram montados.
local housingReady = LocalPlayer.state.isLoggedIn == true
AddEventHandler('ps-housing:client:initialisedProperties', function()
    housingReady = true
end)

local function spawnLastLocation()
    if isSpawning then
        return
    end

    isSpawning = true

    DoScreenFadeOut(500)

    while not IsScreenFadedOut() do
        Wait(0)
    end

    Showroom.destroy(true)

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

    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')

    -- Depois do OnPlayerLoaded: e nele que o ps-housing monta os imoveis no client.
    local insideMeta = QBX.PlayerData.metadata.inside
    if GetResourceState('ps-housing') == 'started' and insideMeta and insideMeta.property_id then
        local deadline = GetGameTimer() + 10000
        while not housingReady and GetGameTimer() < deadline do Wait(50) end
        if housingReady then
            TriggerServerEvent('ps-housing:server:enterProperty', tostring(insideMeta.property_id))
        else
            lib.print.warn('[mri_Qmultichar] ps-housing nao carregou os imoveis; entrada no imovel cancelada.')
        end
    end

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

    if not isInCharacterCreation then
        isInCharacterCreation = true
    end

    Wait(500)

    TriggerEvent('qb-clothes:client:CreateFirstCharacter')

    isSpawning = false
end

function Multichar.beginCharacterLoad(citizenId, options)
    options = options or {}

    if not citizenId then
        return false, 'CitizenID não fornecido'
    end

    if isLoadingCharacter then
        return false, 'Carregamento de personagem já em andamento'
    end

    if isSpawning then
        return false, 'Spawn já em andamento'
    end

    if not options.skipValidation then
        local validation = lib.callback.await('mri_Qmultichar:server:validateCharacterSelection', false, citizenId)
        if not validation or not validation.allowed then
            return false, validation and validation.message or 'Você não pode selecionar este personagem.'
        end
    end

    isLoadingCharacter = true

    CreateThread(function()
        if isSpawning then
            isLoadingCharacter = false
            return
        end

        DoScreenFadeOut(250)
        while not IsScreenFadedOut() do Wait(0) end

        local success = pcall(function()
            lib.callback.await('qbx_core:server:loadCharacter', false, citizenId)
        end)

        if success then
            isSpawning = true

            TriggerServerEvent('mri_Qmultichar:server:recordLastPlayed', citizenId)

            Showroom.destroy(true)
            Multichar.closeMultichar()

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

function Multichar.beginCharacterCreation(charData)
    if isCreatingCharacter then
        return false, 'Criação de personagem já em andamento'
    end

    local timeSinceDelete = GetGameTimer() - lastDeleteTime
    local cooldownTime = DELETE_COOLDOWN * 2
    if timeSinceDelete < cooldownTime then
        local remainingTime = math.ceil((cooldownTime - timeSinceDelete) / 1000)
        return false, string.format('Aguarde %d segundo(s) após deletar um personagem', remainingTime)
    end

    local slotCheck = lib.callback.await('mri_Qmultichar:server:checkSlotAvailable', false, charData.cid)
    if not slotCheck or not slotCheck.available then
        lib.print.warn(string.format('[mri_Qmultichar] Slot %d não está disponível. Personagem ainda existe?', charData.cid))
        return false, 'Este slot ainda está ocupado. Aguarde alguns segundos e tente novamente.'
    end

    isCreatingCharacter = true

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
            DebugPrint('[mri_Qmultichar] [CRIAÇÃO] Iniciando criação de personagem...')

            if isSpawning then
                DebugPrint('[mri_Qmultichar] [CRIAÇÃO] Spawn já em andamento, cancelando...')
                isCreatingCharacter = false
                return
            end

            isSpawning = true
            DebugPrint('[mri_Qmultichar] [CRIAÇÃO] Flag isSpawning = true')

            -- Escurece ANTES de desmontar o showroom: o destroy devolve o ped do
            -- player visivel e solta a camera, entao com a tela aberta da pra ver
            -- o ped na cena e a viagem ate o aeroporto que o SetPlayerModel causa.
            DebugPrint('[mri_Qmultichar] [CRIAÇÃO] Iniciando fade out...')
            DoScreenFadeOut(500)
            while not IsScreenFadedOut() do
                Wait(0)
            end

            DebugPrint('[mri_Qmultichar] [CRIAÇÃO] Fechando NUI e destruindo showroom...')
            Showroom.destroy(true)
            Multichar.closeMultichar()

            Citizen.Wait(500)
            DebugPrint('[mri_Qmultichar] [CRIAÇÃO] NUI fechada, aguardando...')

            DebugPrint('[mri_Qmultichar] [CRIAÇÃO] Definindo bucket 2 para criação...')
            TriggerServerEvent('mri_Qmultichar:server:setBucket', 2)
            Citizen.Wait(200)

            local illeniumLocation = getIlleniumLocation()
            DebugPrint(string.format('[mri_Qmultichar] [CRIAÇÃO] Localização do illenium: %.2f, %.2f, %.2f, %.2f',
                illeniumLocation.x, illeniumLocation.y, illeniumLocation.z, illeniumLocation.w))

            local currentPos = GetEntityCoords(cache.ped)
            DebugPrint(string.format('[mri_Qmultichar] [CRIAÇÃO] Posição atual: %.2f, %.2f, %.2f',
                currentPos.x, currentPos.y, currentPos.z))

            DebugPrint('[mri_Qmultichar] [CRIAÇÃO] Limpando preview de jobs...')
            FreezeEntityPosition(PlayerPedId(), false)
            ClearPedTasks(PlayerPedId())

            DebugPrint('[mri_Qmultichar] [CRIAÇÃO] Carregando colisão na localização do illenium...')
            RequestCollisionAtCoord(illeniumLocation.x, illeniumLocation.y, illeniumLocation.z)
            while not HasCollisionLoadedAroundEntity(PlayerPedId()) do
                Wait(0)
            end

            -- troca de modelo + posicionamento com a tela ainda preta
            DebugPrint('[mri_Qmultichar] [CRIAÇÃO] Preparando ped na localização do illenium...')
            prepareFreemodePedForCreation(charData.gender, illeniumLocation)

            Citizen.Wait(200)
            local newPos = GetEntityCoords(PlayerPedId())
            DebugPrint(string.format('[mri_Qmultichar] [CRIAÇÃO] Nova posição após reposicionar: %.2f, %.2f, %.2f',
                newPos.x, newPos.y, newPos.z))

            Citizen.Wait(300)

            DebugPrint('[mri_Qmultichar] [CRIAÇÃO] Iniciando fade in...')
            DoScreenFadeIn(250)
            while not IsScreenFadedIn() do
                Wait(0)
            end

            DebugPrint('[mri_Qmultichar] [CRIAÇÃO] Disparando eventos do qbx_core...')
            TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
            TriggerEvent('QBCore:Client:OnPlayerLoaded')

            Wait(500)

            local posBeforeIllenium = GetEntityCoords(cache.ped)
            DebugPrint(string.format('[mri_Qmultichar] [CRIAÇÃO] Posição antes de abrir illenium: %.2f, %.2f, %.2f',
                posBeforeIllenium.x, posBeforeIllenium.y, posBeforeIllenium.z))

            isInCharacterCreation = true
            DebugPrint('[mri_Qmultichar] [CRIAÇÃO] Flag isInCharacterCreation = true')

            -- Rede de segurança pro caso do callback do appearance nunca chegar.
            -- Não toca na posição do ped: durante a edição quem manda é o appearance.
            CreateThread(function()
                local maxWaitTime = 300000
                local startTime = GetGameTimer()
                DebugPrint('[mri_Qmultichar] [CRIAÇÃO] Thread de segurança iniciada')

                while isInCharacterCreation do
                    if GetGameTimer() - startTime > maxWaitTime then
                        lib.print.warn('[mri_Qmultichar] [CRIAÇÃO] Timeout na thread de segurança, finalizando...')
                        finishCharacterCreation('monitor_timeout')
                        break
                    end

                    -- confirma depois de um respiro (o editor ainda pode estar abrindo)
                    if not isIlleniumCustomizationActive then
                        Wait(2000)

                        if not isIlleniumCustomizationActive and isInCharacterCreation then
                            DebugPrint('[mri_Qmultichar] [CRIAÇÃO] Editor fechado sem callback, finalizando...')
                            finishCharacterCreation('monitor_detected_closed')
                            break
                        end
                    end

                    Wait(500)
                end

                DebugPrint('[mri_Qmultichar] [CRIAÇÃO] Thread de segurança finalizada')
            end)

            DebugPrint(string.format('[mri_Qmultichar] [CRIAÇÃO] Abrindo appearance (%s)...', Appearance.getResourceName() or '?'))

            Citizen.Wait(500)

            -- Ultimo recurso, so se o editor nao abrir mesmo apos o timeout. Este
            -- caminho refaz bucket e roupas por conta propria (o mri_Qappearance
            -- atende o evento e chama InitializeCharacter), entao pode conflitar
            -- com o bucket 2 e o ped ja preparados aqui.
            if not openIlleniumCharacterCreator() then
                lib.print.warn('[mri_Qmultichar] [CRIAÇÃO] Fallback para qb-clothes:client:CreateFirstCharacter')
                isIlleniumCustomizationActive = true
                TriggerEvent('qb-clothes:client:CreateFirstCharacter')
            end

            DebugPrint('[mri_Qmultichar] [CRIAÇÃO] Illenium aberto, aguardando...')

            CreateThread(function()
                Wait(2000)
                if isInCharacterCreation then
                    local posAfterIllenium = GetEntityCoords(cache.ped)
                    DebugPrint(string.format('[mri_Qmultichar] [CRIAÇÃO] Posição após 2s do illenium: %.2f, %.2f, %.2f',
                        posAfterIllenium.x, posAfterIllenium.y, posAfterIllenium.z))
                end
            end)

            isSpawning = false
        end

        isCreatingCharacter = false
    end)

    return true
end

RegisterNetEvent('illenium-appearance:client:characterSaved', function()
    DebugPrint('[mri_Qmultichar] [ILLENIUM] Evento characterSaved recebido')
    if isInCharacterCreation then
        DebugPrint('[mri_Qmultichar] [ILLENIUM] isInCharacterCreation = true, finalizando criação...')
        isIlleniumCustomizationActive = false
        finishCharacterCreation('event_character_saved', 2000)
    else
        DebugPrint('[mri_Qmultichar] [ILLENIUM] isInCharacterCreation = false, ignorando evento')
    end
end)

RegisterNetEvent('qb-clothes:client:characterSaved', function()
    DebugPrint('[mri_Qmultichar] [ILLENIUM] Evento qb-clothes characterSaved recebido')
    if isInCharacterCreation then
        DebugPrint('[mri_Qmultichar] [ILLENIUM] isInCharacterCreation = true, finalizando criação...')
        isIlleniumCustomizationActive = false
        finishCharacterCreation('event_qb_character_saved', 2000)
    else
        DebugPrint('[mri_Qmultichar] [ILLENIUM] isInCharacterCreation = false, ignorando evento')
    end
end)

RegisterNetEvent('illenium-appearance:client:close', function()
    DebugPrint('[mri_Qmultichar] [ILLENIUM] Evento close recebido')
    if isInCharacterCreation then
        DebugPrint('[mri_Qmultichar] [ILLENIUM] isInCharacterCreation = true, finalizando criação (close)...')
        isIlleniumCustomizationActive = false
        finishCharacterCreation('event_illenium_close', 2000)
    end
end)

RegisterNetEvent('qb-clothes:client:close', function()
    DebugPrint('[mri_Qmultichar] [ILLENIUM] Evento qb-clothes close recebido')
    if isInCharacterCreation then
        DebugPrint('[mri_Qmultichar] [ILLENIUM] isInCharacterCreation = true, finalizando criação (close)...')
        isIlleniumCustomizationActive = false
        finishCharacterCreation('event_qb_close', 2000)
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    if isInCharacterCreation then
        DebugPrint('[mri_Qmultichar] [LOADED] Personagem carregado, finalizando criação...')
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

        DebugPrint(string.format('[mri_Qmultichar] Char %s sem foto salva, capturando...', citizenId))
        pcall(Headshots.capture, citizenId, PlayerPedId())
    end)
end)

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    if GetInvokingResource() then return end
    if isInCharacterCreation then
        DebugPrint('[mri_Qmultichar] [LOGOUT] Resetando flag isInCharacterCreation ao fazer logout')
        isIlleniumCustomizationActive = false
        isInCharacterCreation = false
        TriggerServerEvent('mri_Qmultichar:server:setBucket', 0)
    end

    Multichar.openMultichar()
    Showroom.open()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    if isInCharacterCreation then
        DebugPrint('[mri_Qmultichar] [UNLOAD] Resetando flag isInCharacterCreation ao descarregar personagem')
        isIlleniumCustomizationActive = false
        isInCharacterCreation = false
        TriggerServerEvent('mri_Qmultichar:server:setBucket', 0)
    end
end)

CreateThread(function()
    DebugPrint('[mri_Qmultichar] Thread de inicialização iniciada')
    while true do
        Wait(0)
        if NetworkIsSessionStarted() then
            if LocalPlayer.state.isLoggedIn then
                -- Restart do resource com o player já em jogo (ex.: ensure a quente):
                -- NÃO desloga. O multichar só manda no fluxo de seleção na ENTRADA;
                -- quem já escolheu personagem e está jogando não deve ser tocado.
                DebugPrint('[mri_Qmultichar] Player já logado; pulando fluxo de seleção (sem logout)')
                break
            end

            DebugPrint('[mri_Qmultichar] Sessão iniciada, configurando multichar...')
            pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
            Wait(250)

            local payload = lib.callback.await('mri_Qmultichar:server:getCharacters', false)
            local characters = payload and payload.characters or {}
            local lastPlayed = payload and payload.lastPlayed

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

            -- Sem espera fixa aqui: o Wait(1000) que existia nao aguardava nada
            -- verificavel — o gate real e o loop de colisao logo abaixo, que ja
            -- espera o mundo estar solido sob o ped.
            RequestCollisionAtCoord(randomLocation.pedCoords.x, randomLocation.pedCoords.y, randomLocation.pedCoords.z)
            -- Teto de 25s: rede de seguranca pra o login nunca travar pra sempre
            -- se a colisao nao vier. Alto de proposito pra nao mascarar medicao.
            local collisionDeadline = GetGameTimer() + 25000
            while not HasCollisionLoadedAroundEntity(cache.ped) and GetGameTimer() < collisionDeadline do
                Wait(0)
            end
            if not HasCollisionLoadedAroundEntity(cache.ped) then
                lib.print.warn('[mri_Qmultichar] Colisao nao carregou em 25s; seguindo mesmo assim.')
            end

            SetEntityCoords(cache.ped, randomLocation.pedCoords.x, randomLocation.pedCoords.y, randomLocation.pedCoords.z, false, false, false, false)
            SetEntityHeading(cache.ped, randomLocation.pedCoords.w)

            NetworkStartSoloTutorialSession()

            -- Mesma rede de seguranca de 25s do loop de colisao acima.
            local tutorialDeadline = GetGameTimer() + 25000
            while not NetworkIsInTutorialSession() and GetGameTimer() < tutorialDeadline do
                Wait(0)
            end
            if not NetworkIsInTutorialSession() then
                lib.print.warn('[mri_Qmultichar] Sessao de tutorial nao iniciou em 25s; seguindo mesmo assim.')
            end

            Wait(250)
            ShutdownLoadingScreen()
            ShutdownLoadingScreenNui()

            DebugPrint('[mri_Qmultichar] Montando showroom...')
            Citizen.Wait(100)
            Showroom.build(characters, lastPlayed)

            Wait(100)
            DebugPrint('[mri_Qmultichar] Abrindo NUI...')

            -- Polling de 16ms (1 frame) em vez de 100ms: este handshake e a
            -- ULTIMA etapa antes da tela aparecer, entao a granularidade grossa
            -- entrava inteira no tempo percebido. Teto de 25s pelo mesmo motivo
            -- dos loops acima — nao mascarar o tempo real da NUI na medicao.
            local nuiDeadline = GetGameTimer() + 25000
            local nextLog = GetGameTimer() + 1000
            while not Multichar.isNuiReady() and GetGameTimer() < nuiDeadline do
                Wait(16)
                if GetGameTimer() >= nextLog then
                    nextLog = GetGameTimer() + 1000
                    DebugPrint('[mri_Qmultichar] Aguardando NUI ficar pronta (Handshake)...')
                end
            end

            if not Multichar.isNuiReady() then
                lib.print.warn('[mri_Qmultichar] NUI demorou demais para sinalizar pronta, tentando abrir mesmo assim...')
            end

            Multichar.openMultichar()

            CreateThread(function()
                Wait(2000)
                if not Multichar.isNuiOpen() then
                    lib.print.warn('[mri_Qmultichar] NUI não abriu, tentando abrir novamente...')
                    Multichar.openMultichar()
                end
            end)

            break
        end
    end

    while Multichar.isNuiOpen() do
        SetEntityInvincible(PlayerPedId(), true)
        Wait(250)
    end
    SetEntityInvincible(PlayerPedId(), false)
end)

exports('isInCharacterCreation', function()
    return Multichar.isCharacterCreationFlowActive()
end)
