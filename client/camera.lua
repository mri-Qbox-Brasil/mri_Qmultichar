local previewCam = nil
local previewVehicle = nil
local previewPedEntity = nil -- Para paciente na cena de ambulance
local cameraEffectsEnabled = true -- Efeitos de câmera ativados por padrão
local cameraEffectType = 'cinema' -- Tipo de efeito de câmera

local randomPeds = {
    {
        model = `mp_m_freemode_01`,
        headOverlays = {
            beard = {color = 0, style = 0, secondColor = 0, opacity = 1},
            complexion = {color = 0, style = 0, secondColor = 0, opacity = 0},
            bodyBlemishes = {color = 0, style = 0, secondColor = 0, opacity = 0},
            blush = {color = 0, style = 0, secondColor = 0, opacity = 0},
            lipstick = {color = 0, style = 0, secondColor = 0, opacity = 0},
            blemishes = {color = 0, style = 0, secondColor = 0, opacity = 0},
            eyebrows = {color = 0, style = 0, secondColor = 0, opacity = 1},
            makeUp = {color = 0, style = 0, secondColor = 0, opacity = 0},
            sunDamage = {color = 0, style = 0, secondColor = 0, opacity = 0},
            moleAndFreckles = {color = 0, style = 0, secondColor = 0, opacity = 0},
            chestHair = {color = 0, style = 0, secondColor = 0, opacity = 1},
            ageing = {color = 0, style = 0, secondColor = 0, opacity = 1},
        },
        components = {
            {texture = 0, drawable = 0, component_id = 0},
            {texture = 0, drawable = 0, component_id = 1},
            {texture = 0, drawable = 0, component_id = 2},
            {texture = 0, drawable = 0, component_id = 5},
            {texture = 0, drawable = 0, component_id = 7},
            {texture = 0, drawable = 0, component_id = 9},
            {texture = 0, drawable = 0, component_id = 10},
            {texture = 0, drawable = 15, component_id = 11},
            {texture = 0, drawable = 15, component_id = 8},
            {texture = 0, drawable = 15, component_id = 3},
            {texture = 0, drawable = 34, component_id = 6},
            {texture = 0, drawable = 61, component_id = 4},
        },
        props = {
            {prop_id = 0, drawable = -1, texture = -1},
            {prop_id = 1, drawable = -1, texture = -1},
            {prop_id = 2, drawable = -1, texture = -1},
            {prop_id = 6, drawable = -1, texture = -1},
            {prop_id = 7, drawable = -1, texture = -1},
        }
    },
    {
        model = `mp_f_freemode_01`,
        headBlend = {
            shapeMix = 0.3,
            skinFirst = 0,
            shapeFirst = 31,
            skinSecond = 0,
            shapeSecond = 0,
            skinMix = 0,
            thirdMix = 0,
            shapeThird = 0,
            skinThird = 0,
        },
        hair = {
            color = 0,
            style = 15,
            texture = 0,
            highlight = 0
        },
        headOverlays = {
            chestHair = {secondColor = 0, opacity = 0, color = 0, style = 0},
            bodyBlemishes = {secondColor = 0, opacity = 0, color = 0, style = 0},
            beard = {secondColor = 0, opacity = 0, color = 0, style = 0},
            lipstick = {secondColor = 0, opacity = 0, color = 0, style = 0},
            complexion = {secondColor = 0, opacity = 0, color = 0, style = 0},
            blemishes = {secondColor = 0, opacity = 0, color = 0, style = 0},
            moleAndFreckles = {secondColor = 0, opacity = 0, color = 0, style = 0},
            makeUp = {secondColor = 0, opacity = 0, color = 0, style = 0},
            ageing = {secondColor = 0, opacity = 1, color = 0, style = 0},
            eyebrows = {secondColor = 0, opacity = 1, color = 0, style = 0},
            blush = {secondColor = 0, opacity = 0, color = 0, style = 0},
            sunDamage = {secondColor = 0, opacity = 0, color = 0, style = 0},
        },
        components = {
            {drawable = 0, component_id = 0, texture = 0},
            {drawable = 0, component_id = 1, texture = 0},
            {drawable = 0, component_id = 2, texture = 0},
            {drawable = 0, component_id = 5, texture = 0},
            {drawable = 0, component_id = 7, texture = 0},
            {drawable = 0, component_id = 9, texture = 0},
            {drawable = 0, component_id = 10, texture = 0},
            {drawable = 15, component_id = 3, texture = 0},
            {drawable = 15, component_id = 11, texture = 3},
            {drawable = 14, component_id = 8, texture = 0},
            {drawable = 15, component_id = 4, texture = 3},
            {drawable = 35, component_id = 6, texture = 0},
        },
        props = {
            {prop_id = 0, drawable = -1, texture = -1},
            {prop_id = 1, drawable = -1, texture = -1},
            {prop_id = 2, drawable = -1, texture = -1},
            {prop_id = 6, drawable = -1, texture = -1},
            {prop_id = 7, drawable = -1, texture = -1},
        }
    }
}

NetworkStartSoloTutorialSession()

-- Limpar veículos e peds criados
local function cleanupPreviewEntities()
    if previewVehicle and DoesEntityExist(previewVehicle) then
        DeleteEntity(previewVehicle)
        previewVehicle = nil
    end
    if previewPedEntity and DoesEntityExist(previewPedEntity) then
        DeleteEntity(previewPedEntity)
        previewPedEntity = nil
    end
end

-- Posição padrão do personagem
local defaultPedCoords = Config.Preview.default.pedCoords

-- Função para obter altura do chão
local function getGroundZ(x, y, z)
    local found, groundZ = GetGroundZFor_3dCoord(x, y, z + 10.0, false)
    if found then
        return groundZ
    end
    return z
end

-- Função para fixar veículo no chão (melhorada)
local function fixVehicleOnGround(vehicle)
    if not DoesEntityExist(vehicle) then return end
    
    local attempts = 0
    local maxAttempts = 10
    
    while attempts < maxAttempts do
        local vehCoords = GetEntityCoords(vehicle)
        local found, groundZ = GetGroundZFor_3dCoord(vehCoords.x, vehCoords.y, vehCoords.z + 5.0, false)
        
        if found then
            local heightDiff = math.abs(vehCoords.z - groundZ)
            if heightDiff > 0.1 then
                SetEntityCoords(vehicle, vehCoords.x, vehCoords.y, groundZ + 0.1, false, false, false, true)
                SetVehicleOnGroundProperly(vehicle)
                Citizen.Wait(50)
            else
                break
            end
        end
        
        attempts = attempts + 1
        Citizen.Wait(50)
    end
    
    -- Garantir que está no chão uma última vez
    SetVehicleOnGroundProperly(vehicle)
end

-- Configurar câmera com coordenadas customizadas
local function setupPreviewCam(scenario, pedCoords, camConfig)
    -- Verificar se está criando personagem (via export para verificar flag)
    local isCreating = false
    pcall(function()
        if exports.mri_Qmultichar and exports.mri_Qmultichar.isInCharacterCreation then
            isCreating = exports.mri_Qmultichar:isInCharacterCreation()
        end
    end)
    
    if isCreating then
        lib.print.warn('[mri_Qmultichar] [CAMERA] setupPreviewCam chamado durante criação de personagem, ignorando...')
        return
    end
    
    lib.print.info('[mri_Qmultichar] [CAMERA] Configurando câmera de preview...')
    
    camConfig = camConfig or {}
    local zoomOut = camConfig.zoomOut or false
    local camDistance = camConfig.camDistance or 1.6
    local camHeight = camConfig.camHeight or 0.65
    local camFov = camConfig.camFov or 38.0
    local isNight = camConfig.isNight or false
    local skipBucket = camConfig.skipBucket or false
    
    -- Usar bucket isolado para preview (bucket 1) - via server (se não foi definido antes)
    if not skipBucket then
        TriggerServerEvent('mri_Qmultichar:server:setBucket', 1)
        Citizen.Wait(100) -- Aguardar bucket ser aplicado
    end
    
    -- Definir hora do dia se for noite (ANTES de posicionar o player)
    if isNight then
        NetworkOverrideClockTime(22, 0, 0) -- 22:00 (noite)
        Citizen.Wait(50) -- Aguardar um pouco para garantir que o horário foi aplicado
    end
    
    -- Usar coordenadas customizadas ou padrão
    local coords = pedCoords or defaultPedCoords
    
    -- Obter altura do chão para garantir que o personagem não fique voando
    local groundZ = getGroundZ(coords.x, coords.y, coords.z)
    local finalZ = groundZ + 0.1 -- Pequeno offset para garantir que está no chão
    
    -- Posicionar personagem no chão
    SetEntityCoords(cache.ped, coords.x, coords.y, finalZ, false, false, false, true)
    SetEntityHeading(cache.ped, coords.w or 0.0)
    
    -- Aguardar um pouco para garantir que o personagem está no chão
    Citizen.Wait(100)
    
    -- Verificar novamente e ajustar se necessário
    local currentZ = GetEntityCoords(cache.ped).z
    local newGroundZ = getGroundZ(coords.x, coords.y, currentZ)
    if math.abs(currentZ - newGroundZ) > 0.5 then
        SetEntityCoords(cache.ped, coords.x, coords.y, newGroundZ + 0.1, false, false, false, true)
    end
    
    FreezeEntityPosition(cache.ped, false)
    ClearPedTasks(PlayerPedId())
    
    -- Executar animação/scenario
    if scenario and IsEntityVisible(cache.ped) then
        if string.find(scenario, 'WORLD_HUMAN') then
            TaskStartScenarioInPlace(cache.ped, scenario, 0, true)
        else
            -- Para animações customizadas (amb@medic@standing@kneel@base)
            lib.requestAnimDict(scenario)
            TaskPlayAnim(cache.ped, scenario, 'base', 8.0, -8.0, -1, 1, 0, false, false, false)
        end
    elseif IsEntityVisible(cache.ped) then
        -- Animações padrão aleatórias
        local scenarios = Config.Preview.default.scenarios
        local randomScenario = scenarios[math.random(1, #scenarios)]
        TaskStartScenarioInPlace(cache.ped, randomScenario, 0, true)
    end
    
    -- Posicionar câmera (ajustar distância se zoom out)
    local camOffset = zoomOut and 3.0 or camDistance
    local camCoords = GetOffsetFromEntityInWorldCoords(cache.ped, 0, camOffset, 0)
    
    previewCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamActive(previewCam, true)
    RenderScriptCams(true, true, 1250, 1, 0)
    
    SetCamCoord(previewCam, camCoords.x, camCoords.y, camCoords.z + camHeight)
    SetCamFov(previewCam, zoomOut and 50.0 or camFov) -- FOV maior para zoom out
    
    local pedHeading = GetEntityHeading(cache.ped)
    SetCamRot(previewCam, 0.0, 0.0, pedHeading + 180)
    PointCamAtPedBone(previewCam, cache.ped, 31086, 0.0, 0.0, 0.0, 1)
    
    local camPos = GetCamCoord(previewCam)
    TaskLookAtCoord(cache.ped, camPos.x, camPos.y, camPos.z, 5000, 1, 1)
    
    local camHeading = GetCamRot(previewCam, 2).z
    SetEntityHeading(cache.ped, camHeading - 180)
    
    -- Configurar Depth of Field
    SetCamUseShallowDofMode(previewCam, true)
    SetCamNearDof(previewCam, 0.8)
    SetCamFarDof(previewCam, zoomOut and 8.0 or 3.5) -- DoF maior para zoom out
    SetCamDofStrength(previewCam, 3.0)
    SetCamDofMaxNearInFocusDistance(previewCam, 1.5)
    
    Citizen.Wait(500)
    
    -- Aplicar efeitos de câmera se habilitado
    if cameraEffectsEnabled then
        -- Timecycle modifiers para efeitos visuais
        SetTimecycleModifier(cameraEffectType)
        SetTimecycleModifierStrength(0.5)
    else
        SetTimecycleModifier('default')
        SetTimecycleModifierStrength(0.0)
    end
    
    DoScreenFadeIn(1000)
    CreateThread(function()
        while DoesCamExist(previewCam) do
            SetUseHiDof()
            SetCamDofStrength(previewCam, 3.0)
            -- Manter horário noturno se configurado
            if isNight then
                NetworkOverrideClockTime(22, 0, 0) -- 22:00 (noite)
            end
            -- Manter timecycle modifier se efeitos estiverem ativos
            if cameraEffectsEnabled then
                SetTimecycleModifier(cameraEffectType)
                SetTimecycleModifierStrength(0.5)
            else
                SetTimecycleModifier('default')
                SetTimecycleModifierStrength(0.0)
            end
            Wait(0)
        end
    end)
end

local function destroyPreviewCam()
    if not previewCam then 
        lib.print.info('[mri_Qmultichar] [CAMERA] destroyPreviewCam chamado mas não há câmera ativa')
        return 
    end

    lib.print.info('[mri_Qmultichar] [CAMERA] Destruindo câmera de preview...')
    -- Não resetar timecycle modifier aqui, deixar o export controlar
    SetCamActive(previewCam, false)
    DestroyCam(previewCam, true)
    previewCam = nil
    ClearPedTasks(PlayerPedId())
    RenderScriptCams(false, false, 1, true, true)
    FreezeEntityPosition(cache.ped, false)
    cleanupPreviewEntities()
    
    -- Resetar hora do dia (sempre resetar, mesmo que não tenha sido alterado)
    NetworkClearClockTimeOverride()
    Citizen.Wait(100) -- Aguardar um pouco para garantir que o reset foi aplicado
    
    -- Remover bucket (voltar ao bucket padrão) - via server
    -- MAS apenas se NÃO estiver criando personagem (para não interferir)
    local isCreating = false
    pcall(function()
        if exports.mri_Qmultichar and exports.mri_Qmultichar.isInCharacterCreation then
            isCreating = exports.mri_Qmultichar:isInCharacterCreation()
        end
    end)
    
    if not isCreating then
        TriggerServerEvent('mri_Qmultichar:server:setBucket', 0)
    else
        lib.print.info('[mri_Qmultichar] [CAMERA] Não removendo bucket pois está criando personagem')
    end
    
    lib.print.info('[mri_Qmultichar] [CAMERA] Câmera de preview destruída')
end

-- Preview para Police
local function setupPolicePreview()
    local config = Config.Preview.police
    cleanupPreviewEntities()
    
    Citizen.Wait(100)
    
    -- Obter altura do chão para o veículo
    local vehGroundZ = getGroundZ(config.vehicleCoords.x, config.vehicleCoords.y, config.vehicleCoords.z)
    local vehFinalZ = vehGroundZ + 0.1
    
    -- Criar viatura usando coordenadas do config
    lib.requestModel(config.vehicleModel, 60000)
    previewVehicle = CreateVehicle(config.vehicleModel, config.vehicleCoords.x, config.vehicleCoords.y, vehFinalZ, config.vehicleCoords.w, false, false)
    SetEntityAsMissionEntity(previewVehicle, true, true)
    SetVehicleOnGroundProperly(previewVehicle)
    SetEntityCollision(previewVehicle, false, false)
    FreezeEntityPosition(previewVehicle, true)
    SetEntityVisible(previewVehicle, true, 0)
    SetEntityAlpha(previewVehicle, 255, false)
    
    -- Fixar veículo no chão (função melhorada)
    Citizen.Wait(200)
    fixVehicleOnGround(previewVehicle)
    
    -- Ligar giroflex
    if config.enableSiren then
        SetVehicleSiren(previewVehicle, true)
        SetVehicleHasMutedSirens(previewVehicle, true) -- Silenciar o som mas manter a luz
    end
    
    SetModelAsNoLongerNeeded(config.vehicleModel)
    
    -- Configurar preview com coordenadas do player e noite
    setupPreviewCam(config.scenario, config.pedCoords, { isNight = true })
end

-- Preview para Ambulance
local function setupAmbulancePreview()
    local config = Config.Preview.ambulance
    cleanupPreviewEntities()
    
    Citizen.Wait(100)
    
    -- Obter altura do chão para a ambulância
    local vehGroundZ = getGroundZ(config.vehicleCoords.x, config.vehicleCoords.y, config.vehicleCoords.z)
    local vehFinalZ = vehGroundZ + 0.1
    
    -- Criar ambulância usando coordenadas do config
    lib.requestModel(config.vehicleModel, 60000)
    previewVehicle = CreateVehicle(config.vehicleModel, config.vehicleCoords.x, config.vehicleCoords.y, vehFinalZ, config.vehicleCoords.w, false, false)
    SetEntityAsMissionEntity(previewVehicle, true, true)
    SetVehicleOnGroundProperly(previewVehicle)
    SetEntityCollision(previewVehicle, false, false)
    FreezeEntityPosition(previewVehicle, true)
    SetEntityVisible(previewVehicle, true, 0)
    SetEntityAlpha(previewVehicle, 255, false)
    
    -- Fixar veículo no chão (função melhorada)
    Citizen.Wait(200)
    fixVehicleOnGround(previewVehicle)
    
    -- Ligar giroflex se configurado
    if config.enableSiren then
        SetVehicleSiren(previewVehicle, true)
        SetVehicleHasMutedSirens(previewVehicle, true) -- Silenciar o som mas manter a luz
    end
    
    SetModelAsNoLongerNeeded(config.vehicleModel)
    
    -- Configurar preview (define bucket, posiciona player, aplica noite e zoom out)
    setupPreviewCam(config.scenario, config.pedCoords, { 
        zoomOut = config.zoomOut or false,
        isNight = config.isNight 
    })
    
    -- Aplicar bucket ao veículo explicitamente após o preview
    Citizen.Wait(100)
    SetEntityRoutingBucket(previewVehicle, 1)
end

-- Preview para Mechanic
local function setupMechanicPreview()
    local config = Config.Preview.mechanic
    cleanupPreviewEntities()
    
    Citizen.Wait(100)
    
    -- Obter altura do chão para o carro
    local vehGroundZ = getGroundZ(config.vehicleCoords.x, config.vehicleCoords.y, config.vehicleCoords.z)
    local vehFinalZ = vehGroundZ + 0.1
    
    -- Criar carro usando coordenadas do config
    lib.requestModel(config.vehicleModel, 60000)
    previewVehicle = CreateVehicle(config.vehicleModel, config.vehicleCoords.x, config.vehicleCoords.y, vehFinalZ, config.vehicleCoords.w, false, false)
    SetEntityAsMissionEntity(previewVehicle, true, true)
    SetVehicleOnGroundProperly(previewVehicle)
    SetEntityCollision(previewVehicle, false, false)
    FreezeEntityPosition(previewVehicle, true)
    SetEntityVisible(previewVehicle, true, 0)
    SetEntityAlpha(previewVehicle, 255, false)
    
    -- Fixar veículo no chão (função melhorada)
    Citizen.Wait(200)
    fixVehicleOnGround(previewVehicle)
    
    -- Abrir capô se configurado
    if config.hoodOpen then
        SetVehicleDoorOpen(previewVehicle, 4, false, false) -- Abrir capô
    end
    
    SetModelAsNoLongerNeeded(config.vehicleModel)
    
    -- Se configurado para apoiar no capô com chave, posicionar primeiro
    if config.leanOnHood then
        Citizen.Wait(200)
        -- Posicionar player ao lado do carro (não na frente, para não bloquear com o capô)
        local vehCoords = GetEntityCoords(previewVehicle)
        local vehHeading = GetEntityHeading(previewVehicle)
        -- Offset para ficar ao lado esquerdo do carro, próximo ao capô
        local offset = GetOffsetFromEntityInWorldCoords(previewVehicle, -1.0, 0.5, 0.0)
        -- Obter altura do chão para o player
        local pedGroundZ = getGroundZ(offset.x, offset.y, offset.z)
        local pedFinalZ = pedGroundZ + 0.1
        SetEntityCoords(cache.ped, offset.x, offset.y, pedFinalZ, false, false, false, true)
        -- Fazer player olhar para o lado direito (em direção ao carro), não para a frente
        SetEntityHeading(cache.ped, vehHeading + 90)
        
        -- Verificar novamente e ajustar se necessário
        Citizen.Wait(100)
        local currentPedZ = GetEntityCoords(cache.ped).z
        local newPedGroundZ = getGroundZ(offset.x, offset.y, currentPedZ)
        if math.abs(currentPedZ - newPedGroundZ) > 0.5 then
            SetEntityCoords(cache.ped, offset.x, offset.y, newPedGroundZ + 0.1, false, false, false, true)
        end
        
        -- Animação de apoiar (leaning) - sem mexer no carro
        TaskStartScenarioInPlace(cache.ped, 'WORLD_HUMAN_LEANING', 0, true)
        
        -- Dar chave/chave de fenda na mão
        Citizen.Wait(200)
        local propHash = `prop_tool_screwdvr02` -- Chave de fenda
        lib.requestModel(propHash, 60000)
        local prop = CreateObject(propHash, 0.0, 0.0, 0.0, true, true, true)
        AttachEntityToEntity(prop, cache.ped, GetPedBoneIndex(cache.ped, 18905), 0.12, 0.028, 0.001, 10.0, 175.0, 0.0, true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(propHash)
        
        -- Configurar preview após posicionar e animar com zoom out
        Citizen.Wait(300)
        setupPreviewCam(nil, vector4(offset.x, offset.y, pedFinalZ, vehHeading + 90), { zoomOut = config.zoomOut })
    else
        -- Configurar preview normalmente se não for para apoiar no capô
        setupPreviewCam(config.scenario, config.pedCoords)
    end
end

-- Preview para Taxi
local function setupTaxiPreview()
    local config = Config.Preview.taxi
    cleanupPreviewEntities()
    
    Citizen.Wait(100)
    
    -- Obter altura do chão para o taxi
    local vehGroundZ = getGroundZ(config.vehicleCoords.x, config.vehicleCoords.y, config.vehicleCoords.z)
    local vehFinalZ = vehGroundZ + 0.1
    
    -- Criar taxi usando coordenadas do config
    lib.requestModel(config.vehicleModel, 60000)
    previewVehicle = CreateVehicle(config.vehicleModel, config.vehicleCoords.x, config.vehicleCoords.y, vehFinalZ, config.vehicleCoords.w, false, false)
    SetEntityAsMissionEntity(previewVehicle, true, true)
    SetVehicleOnGroundProperly(previewVehicle)
    SetEntityCollision(previewVehicle, false, false)
    FreezeEntityPosition(previewVehicle, true)
    SetEntityVisible(previewVehicle, true, 0)
    SetEntityAlpha(previewVehicle, 255, false)
    
    -- Fixar veículo no chão (função melhorada)
    Citizen.Wait(200)
    fixVehicleOnGround(previewVehicle)
    
    SetModelAsNoLongerNeeded(config.vehicleModel)
    
    -- Configurar preview com coordenadas do player
    setupPreviewCam(config.scenario, config.pedCoords)
end

-- Preview para Cardealer
local function setupCardealerPreview()
    local config = Config.Preview.cardealer
    cleanupPreviewEntities()
    
    Citizen.Wait(100)
    
    -- Obter altura do chão para o carro de luxo
    local vehGroundZ = getGroundZ(config.vehicleCoords.x, config.vehicleCoords.y, config.vehicleCoords.z)
    local vehFinalZ = vehGroundZ + 0.1
    
    -- Criar carro de luxo usando coordenadas do config
    lib.requestModel(config.vehicleModel, 60000)
    previewVehicle = CreateVehicle(config.vehicleModel, config.vehicleCoords.x, config.vehicleCoords.y, vehFinalZ, config.vehicleCoords.w, false, false)
    SetEntityAsMissionEntity(previewVehicle, true, true)
    SetVehicleOnGroundProperly(previewVehicle)
    SetEntityCollision(previewVehicle, false, false)
    FreezeEntityPosition(previewVehicle, true)
    SetEntityVisible(previewVehicle, true, 0)
    SetEntityAlpha(previewVehicle, 255, false)
    
    -- Fixar veículo no chão (função melhorada)
    Citizen.Wait(200)
    fixVehicleOnGround(previewVehicle)
    
    SetModelAsNoLongerNeeded(config.vehicleModel)
    
    -- Configurar preview com coordenadas do player
    setupPreviewCam(config.scenario, config.pedCoords)
end

-- Preview padrão
local function setupDefaultPreview()
    cleanupPreviewEntities()
    setupPreviewCam(nil) -- Usará animação aleatória
end

local function randomPed()
    local ped = randomPeds[math.random(1, #randomPeds)]
    lib.requestModel(ped.model, 60000)
    SetPlayerModel(cache.playerId, ped.model)
    pcall(function() exports['illenium-appearance']:setPedAppearance(PlayerPedId(), ped) end)
    SetModelAsNoLongerNeeded(ped.model)
    SetEntityVisible(PlayerPedId(), true, 0)

    destroyPreviewCam()
    Citizen.Wait(100)
    setupDefaultPreview()
end

local function previewPed(citizenId, jobName)
    -- Verificar se está criando personagem (via export para verificar flag)
    local isCreating = false
    pcall(function()
        if exports.mri_Qmultichar and exports.mri_Qmultichar.isInCharacterCreation then
            isCreating = exports.mri_Qmultichar:isInCharacterCreation()
        end
    end)
    
    if isCreating then
        lib.print.warn('[mri_Qmultichar] [PREVIEW] previewPed chamado durante criação de personagem, ignorando...')
        return
    end
    
    lib.print.info(string.format('[mri_Qmultichar] [PREVIEW] previewPed chamado - CitizenID: %s, Job: %s', citizenId or 'nil', jobName or 'nil'))
    
    DoScreenFadeOut(500)
    Citizen.Wait(500)
    
    if not citizenId then 
        randomPed() 
        return 
    end

    local clothing, model = lib.callback.await('qbx_core:server:getPreviewPedData', false, citizenId)
    if model and clothing then
        lib.requestModel(model, 60000)
        SetPlayerModel(cache.playerId, model)
        SetEntityVisible(PlayerPedId(), true)
        pcall(function() exports['illenium-appearance']:setPedAppearance(PlayerPedId(), json.decode(clothing)) end)
        SetModelAsNoLongerNeeded(model)
    else
        randomPed()
        return
    end

    destroyPreviewCam()
    Citizen.Wait(100)
    
    -- Selecionar preview baseado no job
    jobName = jobName and jobName:lower() or 'unemployed'
    
    lib.print.info(string.format('[mri_Qmultichar] [PREVIEW] Configurando preview para job: %s', jobName))
    
    if jobName == 'police' or jobName == 'bcso' or jobName == 'sasp' then
        setupPolicePreview()
    elseif jobName == 'ambulance' or jobName == 'ems' then
        setupAmbulancePreview()
    elseif jobName == 'mechanic' then
        setupMechanicPreview()
    elseif jobName == 'taxi' then
        setupTaxiPreview()
    elseif jobName == 'cardealer' then
        setupCardealerPreview()
    elseif jobName == 'realestate' then
        cleanupPreviewEntities()
        setupPreviewCam(Config.Preview.realestate.scenario, Config.Preview.realestate.pedCoords)
    else
        setupDefaultPreview()
    end
end

-- Exportar funções
exports('setupPreviewCam', setupPreviewCam)
exports('destroyPreviewCam', destroyPreviewCam)
exports('previewPed', previewPed)

-- Export para controlar efeitos de câmera
exports('setCameraEffects', function(enabled, effectType)
    cameraEffectsEnabled = enabled
    if effectType then
        cameraEffectType = effectType
    end
    
    -- Aplicar globalmente (funciona mesmo sem câmera ativa)
    if enabled then
        SetTimecycleModifier(cameraEffectType)
        SetTimecycleModifierStrength(0.5)
        lib.print.info(string.format('[mri_Qmultichar] [CAMERA] Efeitos ativados: %s', cameraEffectType))
    else
        SetTimecycleModifier('default')
        SetTimecycleModifierStrength(0.0)
        lib.print.info('[mri_Qmultichar] [CAMERA] Efeitos desativados')
    end
    
    -- Também aplicar se a câmera existir
    if previewCam and DoesCamExist(previewCam) then
        if enabled then
            SetTimecycleModifier(cameraEffectType)
            SetTimecycleModifierStrength(0.5)
        else
            SetTimecycleModifier('default')
            SetTimecycleModifierStrength(0.0)
        end
    end
end)

-- Eventos para atualizar preview
RegisterNetEvent('mri_Qmultichar:client:previewPed', function(citizenId, jobName)
    previewPed(citizenId, jobName)
end)
