-- Orquestrador do multichar: estado, lifecycle (load/create/finish),
-- spawn flow, listeners de eventos do framework e thread de inicialização.
-- NUI bridge mora em nui.lua, headshots em headshots.lua.

Multichar = Multichar or {}

local isSpawning = false
local isCreatingCharacter = false
local isInCharacterCreation = false
local isIlleniumCustomizationActive = false
local isLoadingCharacter = false
-- chegada escolhida no capítulo Chegada: { id, config, credit }, toca quando o editor fecha
local pendingArrival = nil

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
    return require('@qbx_core/config/client')
end

local function isResourceStarted(resourceName)
    local resourceState = GetResourceState(resourceName)
    return resourceState == 'started' or resourceState == 'starting'
end

function Multichar.isCharacterCreationFlowActive()
    return isCreatingCharacter or isInCharacterCreation
end

local function finishCharacterCreation(reason, waitTime)
    local shouldReset = Multichar.isCharacterCreationFlowActive() or isIlleniumCustomizationActive

    isIlleniumCustomizationActive = false

    if not shouldReset then
        return
    end

    -- the editor just released its camera: take it in this same frame, no cut
    local arrival = pendingArrival
    pendingArrival = nil
    if arrival then
        Prelude.takeCamera()
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

    FreezeEntityPosition(PlayerPedId(), false)
    Showroom.studioEnd()
    Intro.ambienceStop()
    isInCharacterCreation = false
    isCreatingCharacter = false
    DebugPrint('[mri_Qmultichar] [CRIAÇÃO] Criação finalizada, flags resetadas')

    -- a cena roda na instância da criação (os outros não veem o veículo local); o
    -- mundo normal só depois dela
    -- a trilha da criação acaba aqui, ou depois da chegada
    if arrival then
        CreateThread(function()
            Arrival.play(arrival.id, arrival.config, arrival.credit)
            SendNUIMessage({ action = 'musicEnd' })
            TriggerServerEvent('mri_Qmultichar:server:setBucket', 0)
        end)
    else
        SendNUIMessage({ action = 'musicEnd' })
        TriggerServerEvent('mri_Qmultichar:server:setBucket', 0)
    end
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
---@param coords vector4 ponto do ped de preview no palco (Showroom.creationStagePose)
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

    -- mesma chamada que pôs o preview no palco, pra os dois ficarem no mesmo ponto
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped, coords.w)
    FreezeEntityPosition(ped, true)

    -- invisível até trocar de lugar com o preview (Showroom.creationFinale)
    SetEntityVisible(ped, false, false)
    ClearPedTasksImmediately(ped)
    ClearPedDecorations(ped)

    -- mesmo visual do preview, pro editor abrir a partir dele
    Showroom.dressCreationPed(ped, tonumber(gender) == 1 and 1 or 0)
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

    -- a câmera do editor já está ativa: desmonta o showroom sem soltar a câmera
    Showroom.creationHandoff(true)

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

    -- dados do personagem que o qbx_core acabou de carregar
    local data = awaitPlayerData(5000)
    if not data then
        lib.print.error('[mri_Qmultichar] personagem carregado sem dados no client; spawn cancelado')
        isSpawning = false
        DoScreenFadeIn(500)
        return
    end

    local pos = data.position
    local ok, err = pcall(function()
        exports.spawnmanager:spawnPlayer({ x = pos.x, y = pos.y, z = pos.z, heading = pos.w })
    end)
    if not ok then
        lib.print.error(('[mri_Qmultichar] spawnmanager falhou ao spawnar na última posição: %s'):format(tostring(err)))
    end

    Citizen.Wait(1000)

    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')

    -- Depois do OnPlayerLoaded: e nele que o ps-housing monta os imoveis no client.
    local insideMeta = data.metadata and data.metadata.inside
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

    -- Lock before the await: a second click during validation would log in twice and qbx_core kicks for it.
    isLoadingCharacter = true

    if not options.skipValidation then
        local validation = lib.callback.await('mri_Qmultichar:server:validateCharacterSelection', false, citizenId)
        if not validation or not validation.allowed then
            isLoadingCharacter = false
            return false, validation and validation.message or 'Você não pode selecionar este personagem.'
        end
    end

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

-- A NUI já considerou a criação aceita (o callback respondeu antes do qbx_core
-- criar): avisa a falha pra ela voltar pro último capítulo com o erro.
local function creationFailed()
    Showroom.creationRecover()
    SendNUIMessage({ action = 'creationFailed', message = locale('character_creation.generic_error') })
end

function Multichar.beginCharacterCreation(charData)
    if isCreatingCharacter then
        return false, 'Criação de personagem já em andamento'
    end

    local slotCheck = lib.callback.await('mri_Qmultichar:server:checkSlotAvailable', false, charData.cid)
    if not slotCheck or not slotCheck.available then
        lib.print.warn(string.format('[mri_Qmultichar] Slot %d não está disponível. Personagem ainda existe?', charData.cid))
        return false, 'Este slot ainda está ocupado. Aguarde alguns segundos e tente novamente.'
    end

    pendingArrival = nil
    if type(charData.arrival) == 'string' then
        local panel = lib.callback.await('mri_Qmultichar:server:getConfig', false)
        local a = panel and panel.arrivals and panel.arrivals[charData.arrival]
        if a and a.enabled then
            pendingArrival = {
                id = charData.arrival,
                config = a,
                credit = {
                    name = ('%s %s'):format(charData.firstname, charData.lastname),
                    nationality = charData.nationality,
                    birthdate = charData.birthdate,
                },
            }
        else
            lib.print.warn(('[mri_Qmultichar] [CRIAÇÃO] chegada %s desligada ou inexistente no painel'):format(charData.arrival))
        end
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
                creationFailed()
                return
            end

            isSpawning = true
            DebugPrint('[mri_Qmultichar] [CRIAÇÃO] Flag isSpawning = true')

            -- O palco do showroom é o estúdio: o ped do jogador vai pro ponto do
            -- preview (invisível), o final leva a câmera ao plano inicial do editor e
            -- os dois peds trocam de lugar. O editor abre ali, sem fade nem teleporte.
            local stage = Showroom.creationStagePose()
            if not stage then
                lib.print.error('[mri_Qmultichar] [CRIAÇÃO] Showroom sem ped de preview; não há palco pra criação')
                isSpawning = false
                isCreatingCharacter = false
                creationFailed()
                return
            end
            TriggerServerEvent('mri_Qmultichar:server:setBucket', 2)
            prepareFreemodePedForCreation(charData.gender, stage)
            Showroom.creationFinale()

            Multichar.closeMultichar(true) -- a HUD segue escondida: o editor vem em seguida

            DebugPrint('[mri_Qmultichar] [CRIAÇÃO] Disparando eventos do qbx_core...')
            TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
            TriggerEvent('QBCore:Client:OnPlayerLoaded')
            Intro.ambienceResume()

            isInCharacterCreation = true
            DebugPrint('[mri_Qmultichar] [CRIAÇÃO] Flag isInCharacterCreation = true')

            -- Finaliza se o editor fechar sem o appearance chamar o callback.
            -- Não toca na posição do ped: durante a edição quem manda é o appearance.
            CreateThread(function()
                DebugPrint('[mri_Qmultichar] [CRIAÇÃO] Vigia do editor iniciada')

                while isInCharacterCreation do
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

                DebugPrint('[mri_Qmultichar] [CRIAÇÃO] Vigia do editor finalizada')
            end)

            DebugPrint(string.format('[mri_Qmultichar] [CRIAÇÃO] Abrindo appearance (%s)...', Appearance.getResourceName() or '?'))

            -- Ultimo recurso, so se o editor nao abrir mesmo apos o timeout. Este
            -- caminho refaz bucket e roupas por conta propria (o mri_Qappearance
            -- atende o evento e chama InitializeCharacter), entao pode conflitar
            -- com o bucket 2 e o ped ja preparados aqui.
            if not openIlleniumCharacterCreator() then
                -- editor não abriu: solta a câmera do showroom (se ainda for dele)
                Showroom.creationHandoff(false)
                lib.print.warn('[mri_Qmultichar] [CRIAÇÃO] Fallback para qb-clothes:client:CreateFirstCharacter')
                isIlleniumCustomizationActive = true
                TriggerEvent('qb-clothes:client:CreateFirstCharacter')
            end

            isSpawning = false
        else
            lib.print.warn(('[mri_Qmultichar] [CRIAÇÃO] qbx_core não criou o personagem: %s'):format(tostring(newData)))
            creationFailed()
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

            -- hora e clima do menu já valem na abertura e no showroom
            local panel = lib.callback.await('mri_Qmultichar:server:getConfig', false)
            Intro.ambienceStart(panel and panel.ambience)

            -- Polling de 16ms (1 frame) em vez de 100ms: este handshake e a
            -- ULTIMA etapa antes da tela aparecer, entao a granularidade grossa
            -- entrava inteira no tempo percebido. Teto de 25s pelo mesmo motivo
            -- dos loops acima — nao mascarar o tempo real da NUI na medicao.
            local function awaitNui()
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
            end

            local withIntro = Intro.enabled(panel)
            if withIntro then
                -- tela de título sobre os planos da cidade; no Enter a câmera desce até
                -- o palco e só então entra o menu
                awaitNui()
                DebugPrint('[mri_Qmultichar] Abrindo NUI na abertura...')
                Multichar.openMultichar(true)
                Intro.play(panel)

                DebugPrint('[mri_Qmultichar] Montando showroom (voo da abertura)...')
                Showroom.build(characters, lastPlayed, true)
                Wait(math.floor(Config.Intro.approach.time * 1000))
                SendNUIMessage({ action = 'introDone' })
            else
                DebugPrint('[mri_Qmultichar] Montando showroom...')
                Citizen.Wait(100)
                Showroom.build(characters, lastPlayed)

                Wait(100)
                awaitNui()
                DebugPrint('[mri_Qmultichar] Abrindo NUI...')
                Multichar.openMultichar()
            end

            CreateThread(function()
                Wait(2000)
                if not Multichar.isNuiOpen() then
                    lib.print.warn('[mri_Qmultichar] NUI não abriu, tentando abrir novamente...')
                    Multichar.openMultichar(Intro.isPlaying())
                end
            end)

            break
        end
    end
end)

exports('isInCharacterCreation', function()
    return Multichar.isCharacterCreationFlowActive()
end)
