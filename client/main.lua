local isNuiOpen = false

-- Flag global para prevenir múltiplos spawns simultâneos
local isSpawning = false

-- Configurações do player
local playerSettings = {
    cameraEffects = true,
    streamerMode = false,
    theme = 'dark'
}

-- Variável para prevenir múltiplas criações simultâneas
local isCreatingCharacter = false

-- Variável para rastrear se está criando personagem (para voltar ao bucket padrão após illenium)
local isInCharacterCreation = false
local isIlleniumCustomizationActive = false

-- Variável para rastrear quando um personagem foi deletado (prevenir criação imediata)
local lastDeleteTime = 0
local DELETE_COOLDOWN = 3000 -- 3 segundos de cooldown após deletar (aumentado para garantir sincronização)

-- Flag para saber se a NUI está carregada e pronta (recebida via post message)
local isNuiReady = false

-- Sistema de Mugshot Nativo - Armazenar headshots ativos para limpeza posterior
local activeHeadshots = {}

-- Obter config do qbx_core via callback ou usar valores padrão
local function getQbxConfig()
    -- Tentar obter via require do qbx_core
    local success, qbxConfig = pcall(function()
        return require('@qbx_core/config/client')
    end)
    
    if success and qbxConfig and qbxConfig.characters then
        return qbxConfig
    end
    
    -- Fallback: valores padrão
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

    lib.print.info(string.format('[mri_Qmultichar] [CRIAÇÃO] Finalizando criação (%s)...', reason or 'sem motivo'))
    TriggerServerEvent('mri_Qmultichar:server:setBucket', 0)
    isInCharacterCreation = false
    isCreatingCharacter = false
    lib.print.info('[mri_Qmultichar] [CRIAÇÃO] Criação finalizada, flags resetadas')
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

-- Função para obter localização de criação de personagem (illenium)
-- Usa a config do mri_Qmultichar primeiro, depois tenta do qbx_core como fallback
local function getIlleniumLocation()
    -- Primeiro, tentar usar a config do mri_Qmultichar
    if Config and Config.CharacterCreation and Config.CharacterCreation.createLocation then
        return Config.CharacterCreation.createLocation
    end
    
    -- Se não tiver na config do mri_Qmultichar, tentar do qbx_core
    local qbxConfig = getQbxConfig()
    if qbxConfig and qbxConfig.characters and qbxConfig.characters.locations and #qbxConfig.characters.locations > 0 then
        return qbxConfig.characters.locations[1].pedCoords
    end
    
    -- Fallback final se não conseguir obter de nenhum lugar
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
                lib.print.info('[mri_Qmultichar] [CRIAÇÃO] Aparência salva pelo illenium-appearance')
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

-- Carregar configurações do player ao abrir NUI
local function loadPlayerSettings()
    local success, settings = pcall(function()
        return lib.callback.await('mri_Qmultichar:server:getPlayerSettings', false)
    end)
    
    if success and settings then
        playerSettings.cameraEffects = settings.cameraEffects ~= false
        -- Garantir que streamerMode seja boolean explícito (false ou true, nunca nil)
        playerSettings.streamerMode = settings.streamerMode == true
        playerSettings.theme = settings.theme or 'dark'
        playerSettings.cameraEffectType = settings.cameraEffectType or 'cinema'
        
        -- Aplicar configurações
        SendNUIMessage({ action = 'setStreamerMode', enabled = playerSettings.streamerMode })
        
        if playerSettings.theme then
            SendNUIMessage({ action = 'updateTheme', theme = playerSettings.theme })
        end
        
        -- Aplicar efeitos de câmera
        if exports.mri_Qmultichar and exports.mri_Qmultichar.setCameraEffects then
            exports.mri_Qmultichar:setCameraEffects(playerSettings.cameraEffects, playerSettings.cameraEffectType)
        end
    end
end

-- Função para abrir a NUI
local function openMultichar()
    if isNuiOpen then return end
    
    lib.print.info('[mri_Qmultichar] Preparando dados para abrir NUI...')
    
    -- Obter todos os dados necessários antes de abrir para evitar flicker
    local characters, amount, theme, music, allowThemeChange, availableThemes, locales = lib.callback.await('mri_Qmultichar:server:getCharacters', false)
    
    -- Obter e aplicar configurações de efeitos
    local settings = lib.callback.await('mri_Qmultichar:server:getPlayerSettings', false)
    if settings then
        playerSettings.cameraEffects = settings.cameraEffects ~= false
        playerSettings.streamerMode = settings.streamerMode == true
        playerSettings.theme = settings.theme or 'dark'
        playerSettings.cameraEffectType = settings.cameraEffectType or 'cinema'
        
        -- Aplicar efeitos de câmera
        if exports.mri_Qmultichar and exports.mri_Qmultichar.setCameraEffects then
            exports.mri_Qmultichar:setCameraEffects(playerSettings.cameraEffects, playerSettings.cameraEffectType)
        end
    end

    isNuiOpen = true
    SetNuiFocus(true, true)
    
    lib.print.info('[mri_Qmultichar] Abrindo NUI com dados carregados')
    SendNUIMessage({
        action = 'open',
        characters = characters,
        amount = amount or 3,
        theme = theme,
        music = music,
        allowThemeChange = allowThemeChange,
        availableThemes = availableThemes or {},
        locales = locales or {},
        streamerMode = playerSettings.streamerMode
    })
end

-- Função para limpar todos os headshots ativos
local function CleanupHeadshots()
    -- Garantir que activeHeadshots seja sempre uma tabela válida
    if type(activeHeadshots) ~= 'table' then
        activeHeadshots = {}
        return
    end
    
    -- Limpar headshots de forma segura
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
    
    -- Resetar tabela
    activeHeadshots = {}
end

-- Função para fechar a NUI
local function closeMultichar()
    if not isNuiOpen then return end
    
    isNuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'close',
    })
    
    -- Limpar headshots ao fechar NUI (gerenciamento de memória)
    CleanupHeadshots()
end

local function spawnLastLocation()
    -- Prevenir múltiplos spawns simultâneos
    if isSpawning then
        return
    end
    
    isSpawning = true
    
    DoScreenFadeOut(500)

    while not IsScreenFadedOut() do
        Wait(0)
    end

    exports.mri_Qmultichar:destroyPreviewCam()
    
    -- Aguardar um pouco antes de spawnar
    Citizen.Wait(200)

    pcall(function() 
        exports.spawnmanager:spawnPlayer({
            x = QBX.PlayerData.position.x,
            y = QBX.PlayerData.position.y,
            z = QBX.PlayerData.position.z,
            heading = QBX.PlayerData.position.w
        })
    end)
    
    -- Aguardar spawn completar
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
    -- Prevenir múltiplos spawns simultâneos
    if isSpawning then
        return
    end
    
    isSpawning = true
    
    -- Obter localização do illenium
    local illeniumLocation = getIlleniumLocation()
    
    -- Garantir que o personagem está visível
    SetEntityVisible(cache.ped, true, false)
    
    -- Carregar colisão na localização do illenium
    RequestCollisionAtCoord(illeniumLocation.x, illeniumLocation.y, illeniumLocation.z)
    while not HasCollisionLoadedAroundEntity(cache.ped) do 
        Wait(0) 
    end
    
    -- Reposicionar personagem na localização do illenium
    SetEntityCoords(cache.ped, illeniumLocation.x, illeniumLocation.y, illeniumLocation.z, false, false, false, true)
    SetEntityHeading(cache.ped, illeniumLocation.w)
    
    -- Aguardar um pouco para garantir que está na posição
    Citizen.Wait(500)
    
    -- Fazer fade in
    DoScreenFadeIn(250)
    
    -- Aguardar fade in completar
    while not IsScreenFadedIn() do
        Wait(0)
    end
    
    -- Trigger eventos do qbx_core
    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
    TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
    TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)
    
    -- Marcar que está criando personagem
    if not isInCharacterCreation then
        isInCharacterCreation = true
    end
    
    -- Aguardar um pouco antes de abrir o illenium-appearance
    Wait(500)
    
    -- Abrir illenium-appearance para criação de personagem
    TriggerEvent('qb-clothes:client:CreateFirstCharacter')
    
    isSpawning = false
end

-- Callback para obter personagens
RegisterNUICallback('getCharacters', function(_, cb)
    lib.print.info('[mri_Qmultichar] Callback getCharacters chamado')
    local characters, amount, theme, music, allowThemeChange, availableThemes, locales = lib.callback.await('mri_Qmultichar:server:getCharacters', false)
    
    if characters then
        lib.print.info(string.format('[mri_Qmultichar] Personagens carregados: %d, Slots: %d', #characters, amount or 3))
        cb({ 
            success = true, 
            characters = characters, 
            amount = amount or 3, 
            theme = theme, 
            music = music, 
            allowThemeChange = allowThemeChange,
            availableThemes = availableThemes or {},
            locales = locales or {}
        })
    else
        lib.print.error('[mri_Qmultichar] Erro ao carregar personagens')
        local themeName = Config.Theme or 'dark'
        local themeData = Config.Themes[themeName] or Config.Themes.dark
        local musicConfig = Config.Music or { enabled = false, url = '', volume = 0.3, loop = true, autoplay = true }
        -- Carregar locales mesmo em caso de erro
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
            theme = themeData, 
            music = musicConfig, 
            allowThemeChange = Config.AllowThemeChange or true,
            availableThemes = Config.Themes or {},
            locales = locales
        })
    end
end)

-- Callback para atualizar configurações
RegisterNUICallback('updateSettings', function(data, cb)
    local success = lib.callback.await('mri_Qmultichar:server:updateSettings', false, data)
    
    if success then
        -- Atualizar configurações locais
        if data.streamerMode ~= nil then
            playerSettings.streamerMode = data.streamerMode
            -- Desativar música se modo streamer
            SendNUIMessage({ action = 'setStreamerMode', enabled = data.streamerMode })
        end
        
        if data.theme then
            playerSettings.theme = data.theme
            -- Atualizar tema
            SendNUIMessage({ action = 'updateTheme', theme = data.theme })
        end
        
        if data.cameraEffects ~= nil then
            playerSettings.cameraEffects = data.cameraEffects
            -- Aplicar efeitos de câmera
            if exports.mri_Qmultichar and exports.mri_Qmultichar.setCameraEffects then
                exports.mri_Qmultichar:setCameraEffects(data.cameraEffects, data.cameraEffectType or 'cinema')
            end
        end
        
        if data.cameraEffectType then
            playerSettings.cameraEffectType = data.cameraEffectType
            -- Aplicar tipo de efeito
            if exports.mri_Qmultichar and exports.mri_Qmultichar.setCameraEffects then
                exports.mri_Qmultichar:setCameraEffects(playerSettings.cameraEffects or true, data.cameraEffectType)
            end
        end
    end
    
    cb({ success = success })
end)

-- Função principal para obter mugshot (usa MugShotBase64 para retornar base64)
local function GetMugshot(ped)
    if not DoesEntityExist(ped) or ped == 0 then
        lib.print.error('[mri_Qmultichar] Ped inválido para GetMugshot')
        return nil, nil
    end

    -- Verificar se ped está visível (necessário para headshot)
    if not IsEntityVisible(ped) then
        lib.print.warn('[mri_Qmultichar] Ped não está visível, tornando visível...')
        SetEntityVisible(ped, true, false)
        Wait(100)
    end

    -- Tentar usar MugShotBase64 para gerar imagem real (se o resource estiver ativo)
    if GetResourceState('MugShotBase64') == 'started' then
        -- Verificar se o ped existe e está visível antes de pedir o mugshot
        if DoesEntityExist(ped) and IsEntityVisible(ped) then
            -- Pequeno delay para garantir que o ped está totalmente "assentado" no mundo
            Wait(100)
            
            local base64 = exports['MugShotBase64']:GetMugShotBase64(ped, false)
            if base64 and base64 ~= "" then
                -- Garantir que a string base64 tenha o prefixo correto
                if not string.find(base64, "^data:image") then
                    base64 = "data:image/png;base64," .. base64
                end
                lib.print.info('[mri_Qmultichar] Headshot gerado com sucesso usando MugShotBase64')
                return base64, nil
            else
                lib.print.warn('[mri_Qmultichar] MugShotBase64 falhou ou não retornou dados')
            end
        end
    else
        lib.print.warn('[mri_Qmultichar] MugShotBase64 não está disponível, usando método nativo')
    end

    -- Fallback: usar método nativo (mas converter para base64 não é possível aqui)
    -- Então vamos usar o método nativo apenas se MugShotBase64 não estiver disponível
    local headshot = RegisterPedheadshot(ped)
    if not headshot or headshot == 0 then
        lib.print.error('[mri_Qmultichar] Falha ao registrar headshot')
        return nil, nil
    end
    
    local timeout = 100 -- ~1000ms (100 * 10ms)
    
    while not IsPedheadshotReady(headshot) and timeout > 0 do
        Wait(10)
        timeout = timeout - 1
    end

    if IsPedheadshotReady(headshot) and IsPedheadshotValid(headshot) then
        local txd = GetPedheadshotTxdString(headshot)
        if txd and txd ~= "" then
            -- Usar protocolo nui-img:// (pode não funcionar no navegador, mas é o fallback)
            local url = "nui-img://" .. txd .. "/" .. txd
            -- Armazenar handle para limpeza posterior
            table.insert(activeHeadshots, headshot)
            lib.print.warn(string.format('[mri_Qmultichar] Headshot gerado com método nativo (pode não funcionar): %s', url))
            return url, headshot
        else
            lib.print.error('[mri_Qmultichar] TXD string vazia')
            UnregisterPedheadshot(headshot)
            return nil, nil
        end
    else
        lib.print.error('[mri_Qmultichar] Headshot não está pronto ou inválido')
        UnregisterPedheadshot(headshot)
        return nil, nil
    end
end

-- Função para limpar todos os headshots ativos
local function CleanupHeadshots()
    for _, headshot in ipairs(activeHeadshots) do
        if headshot and headshot ~= 0 then
            pcall(function()
                UnregisterPedheadshot(headshot)
            end)
        end
    end
    activeHeadshots = {}
end

-- Função para criar ped temporário e obter headshot (sincronizado com preview ped)
local function getCharacterHeadshot(citizenId)
    -- Obter dados do personagem via qbx_core (mesma fonte do preview 3D)
    local clothing, model = lib.callback.await('qbx_core:server:getPreviewPedData', false, citizenId)
    if not model or not clothing then
        lib.print.error(string.format('[mri_Qmultichar] Falha ao obter dados de preview do qbx_core para: %s', citizenId))
        return nil
    end
    
    local tempPed = nil
    
    -- Carregar modelo
    lib.requestModel(model, 10000)
    if not HasModelLoaded(model) then
        lib.print.error(string.format('[mri_Qmultichar] Falha ao carregar modelo: %s', model))
        return nil
    end
    
    -- Criar ped temporário em localização remota (mas visível para o headshot)
    local coords = vector3(0.0, 0.0, -200.0) -- Localização remota
    tempPed = CreatePed(4, model, coords.x, coords.y, coords.z, 0.0, false, true)
    
    if not tempPed or tempPed == 0 then
        SetModelAsNoLongerNeeded(model)
        lib.print.error('[mri_Qmultichar] Falha ao criar ped temporário')
        return nil
    end
    
    -- Configurar ped (sem colisão, mas VISÍVEL para o headshot funcionar)
    SetEntityCollision(tempPed, false, false)
    FreezeEntityPosition(tempPed, true)
    SetEntityInvincible(tempPed, true)
    SetEntityVisible(tempPed, true, false) -- IMPORTANTE: ped precisa estar visível para headshot
    SetBlockingOfNonTemporaryEvents(tempPed, true)
    
    -- Aplicar aparência do personagem
    local appearanceData = type(clothing) == 'string' and json.decode(clothing) or clothing
    
    -- Aguardar um pouco antes de aplicar aparência
    Wait(200)
    
    local appearanceApplied = false
    if exports['illenium-appearance'] then
        local success = pcall(function()
            exports['illenium-appearance']:setPedAppearance(tempPed, appearanceData)
            appearanceApplied = true
        end)
        if not success then
            lib.print.error('[mri_Qmultichar] Falha ao aplicar aparência com illenium-appearance')
        end
    elseif exports['fivem-appearance'] then
        local success = pcall(function()
            exports['fivem-appearance']:setPedAppearance(tempPed, appearanceData)
            appearanceApplied = true
        end)
        if not success then
            lib.print.error('[mri_Qmultichar] Falha ao aplicar aparência com fivem-appearance')
        end
    end
    
    if appearanceApplied then
        lib.print.info('[mri_Qmultichar] Aparência aplicada com sucesso para headshot')
    end
    
    -- Aguardar aparência ser aplicada e ped ser renderizado
    Wait(1000) 
    
    -- Forçar renderização do ped
    SetEntityAlpha(tempPed, 255, false)
    
    -- Verificar se ped ainda existe e está válido
    if not DoesEntityExist(tempPed) or tempPed == 0 then
        lib.print.error('[mri_Qmultichar] Ped foi deletado antes de gerar headshot')
        SetModelAsNoLongerNeeded(model)
        return nil
    end
    
    -- Usar função GetMugshot para obter headshot
    local imgUrl, headshotHandle = GetMugshot(tempPed)
    
    -- Limpar ped temporário
    if DoesEntityExist(tempPed) then
        DeleteEntity(tempPed)
    end
    SetModelAsNoLongerNeeded(model)
    
    return imgUrl
end

-- Callback para obter configurações
RegisterNUICallback('getSettings', function(data, cb)
    local settings = lib.callback.await('mri_Qmultichar:server:getPlayerSettings', false)
    cb({ success = true, settings = settings })
end)

-- Callback para obter foto do personagem (tenta metadata do idcard primeiro, depois cria ped temporário)
RegisterNUICallback('getCharacterPhoto', function(data, cb)
    local citizenId = data.citizenid
    if not citizenId then
        lib.print.error('[mri_Qmultichar] getCharacterPhoto: citizenId não fornecido')
        cb({ success = false, photo = nil })
        return
    end
    
    lib.print.info(string.format('[mri_Qmultichar] getCharacterPhoto: Buscando foto para %s', citizenId))
    
    -- Primeiro tentar buscar foto do servidor (metadata do idcard ou player online)
    local success, photoUrl = pcall(function()
        return lib.callback.await('mri_Qmultichar:server:getCharacterPhoto', false, citizenId)
    end)
    
    if success and photoUrl then
        lib.print.info(string.format('[mri_Qmultichar] Foto encontrada no servidor: %s', photoUrl))
        cb({ success = true, photo = photoUrl })
        return
    end
    
    -- Se não encontrou no servidor (player offline ou sem mugshot), criar ped temporário
    lib.print.info(string.format('[mri_Qmultichar] Player offline ou sem mugshot, criando ped temporário para %s...', citizenId))
    CreateThread(function()
        local imgUrl = getCharacterHeadshot(citizenId)
        if imgUrl then
            lib.print.info(string.format('[mri_Qmultichar] Headshot gerado com sucesso (offline): %s', imgUrl))
            SendNUIMessage({
                action = 'characterPhotoReady',
                citizenid = citizenId,
                photo = imgUrl
            })
        else
            lib.print.error(string.format('[mri_Qmultichar] Falha ao gerar headshot (offline) para %s', citizenId))
            SendNUIMessage({
                action = 'characterPhotoReady',
                citizenid = citizenId,
                photo = nil
            })
        end
    end)
    
    -- Retornar imediatamente (a foto será enviada via SendNUIMessage)
    cb({ success = true, photo = nil, loading = true })
end)

-- Variável para prevenir múltiplos carregamentos simultâneos
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

-- Callback para carregar personagem
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

    -- Prevenir múltiplos carregamentos simultâneos
    if isLoadingCharacter then
        cb({ success = false, message = 'Carregamento de personagem já em andamento' })
        return
    end

    isLoadingCharacter = true

    -- Responder callback e fazer carregamento em thread separada
    cb({ success = true })
    
    CreateThread(function()
        -- Prevenir múltiplos spawns simultâneos
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
            
            -- Aguardar um pouco antes de fazer spawn
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

-- Callback para criar personagem
RegisterNUICallback('createCharacter', function(data, cb)
    local charData = data.characterData
    if not charData then
        cb({ success = false, message = 'Dados do personagem não fornecidos' })
        return
    end

    -- Validar dados básicos
    if not charData.firstname or not charData.lastname or not charData.nationality or not charData.birthdate then
        cb({ success = false, message = 'Dados incompletos' })
        return
    end

    -- Prevenir múltiplas criações simultâneas
    if isCreatingCharacter then
        cb({ success = false, message = 'Criação de personagem já em andamento' })
        return
    end
    
    -- Verificar cooldown após deleção de personagem (aumentado para garantir sincronização)
    local timeSinceDelete = GetGameTimer() - lastDeleteTime
    local cooldownTime = DELETE_COOLDOWN * 2 -- Dobrar o cooldown para garantir sincronização
    if timeSinceDelete < cooldownTime then
        local remainingTime = math.ceil((cooldownTime - timeSinceDelete) / 1000)
        cb({ success = false, message = string.format('Aguarde %d segundo(s) após deletar um personagem', remainingTime) })
        return
    end

    -- Verificar se o slot está realmente livre no servidor antes de criar
    local slotCheck = lib.callback.await('mri_Qmultichar:server:checkSlotAvailable', false, charData.cid)
    if not slotCheck or not slotCheck.available then
        lib.print.warn(string.format('[mri_Qmultichar] Slot %d não está disponível. Personagem ainda existe?', charData.cid))
        cb({ success = false, message = 'Este slot ainda está ocupado. Aguarde alguns segundos e tente novamente.' })
        return
    end

    isCreatingCharacter = true

    -- Responder callback imediatamente para evitar timeout
    cb({ success = true })

    -- Fazer a criação do personagem em thread separada
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
            lib.print.info('[mri_Qmultichar] [CRIAÇÃO] Iniciando criação de personagem...')
            
            -- Prevenir múltiplos spawns simultâneos
            if isSpawning then
                lib.print.warn('[mri_Qmultichar] [CRIAÇÃO] Spawn já em andamento, cancelando...')
                isCreatingCharacter = false
                return
            end
            
            isSpawning = true
            lib.print.info('[mri_Qmultichar] [CRIAÇÃO] Flag isSpawning = true')
            
            -- Fechar NUI e destruir câmera de preview
            lib.print.info('[mri_Qmultichar] [CRIAÇÃO] Fechando NUI e destruindo câmera de preview...')
            exports.mri_Qmultichar:destroyPreviewCam()
            closeMultichar()
            
            -- Aguardar para garantir que o NUI fechou completamente
            Citizen.Wait(500)
            lib.print.info('[mri_Qmultichar] [CRIAÇÃO] NUI fechada, aguardando...')
            
            -- Definir bucket separado para criação (bucket 2)
            lib.print.info('[mri_Qmultichar] [CRIAÇÃO] Definindo bucket 2 para criação...')
            TriggerServerEvent('mri_Qmultichar:server:setBucket', 2)
            Citizen.Wait(200)
            
            -- Obter localização de criação de personagem (do config do mri_Qmultichar)
            local illeniumLocation = getIlleniumLocation()
            lib.print.info(string.format('[mri_Qmultichar] [CRIAÇÃO] Localização do illenium: %.2f, %.2f, %.2f, %.2f', 
                illeniumLocation.x, illeniumLocation.y, illeniumLocation.z, illeniumLocation.w))
            
            -- Obter posição atual antes de mover
            local currentPos = GetEntityCoords(cache.ped)
            lib.print.info(string.format('[mri_Qmultichar] [CRIAÇÃO] Posição atual: %.2f, %.2f, %.2f', 
                currentPos.x, currentPos.y, currentPos.z))
            
            -- Fade out
            lib.print.info('[mri_Qmultichar] [CRIAÇÃO] Iniciando fade out...')
            DoScreenFadeOut(500)
            while not IsScreenFadedOut() do
                Wait(0)
            end
            
            -- Limpar qualquer preview de job (veículos, peds, etc.)
            lib.print.info('[mri_Qmultichar] [CRIAÇÃO] Limpando preview de jobs...')
            FreezeEntityPosition(PlayerPedId(), false)
            ClearPedTasks(PlayerPedId())
            
            -- Carregar colisão na localização do illenium
            lib.print.info('[mri_Qmultichar] [CRIAÇÃO] Carregando colisão na localização do illenium...')
            RequestCollisionAtCoord(illeniumLocation.x, illeniumLocation.y, illeniumLocation.z)
            while not HasCollisionLoadedAroundEntity(cache.ped) do 
                Wait(0) 
            end
            
            -- Reposicionar personagem na localização do illenium
            lib.print.info('[mri_Qmultichar] [CRIAÇÃO] Reposicionando personagem para localização do illenium...')
            SetEntityCoords(cache.ped, illeniumLocation.x, illeniumLocation.y, illeniumLocation.z, false, false, false, true)
            SetEntityHeading(cache.ped, illeniumLocation.w)
            SetEntityVisible(cache.ped, true, false)
            
            -- Verificar se foi reposicionado corretamente
            Citizen.Wait(200)
            local newPos = GetEntityCoords(cache.ped)
            lib.print.info(string.format('[mri_Qmultichar] [CRIAÇÃO] Nova posição após reposicionar: %.2f, %.2f, %.2f', 
                newPos.x, newPos.y, newPos.z))
            
            -- Aguardar para garantir que está na posição
            Citizen.Wait(300)
            
            -- Fade in
            lib.print.info('[mri_Qmultichar] [CRIAÇÃO] Iniciando fade in...')
            DoScreenFadeIn(250)
            while not IsScreenFadedIn() do
                Wait(0)
            end
            
            -- Obter config do qbx_core
            local qbxConfig = getQbxConfig()
            
            -- Trigger eventos do qbx_core
            lib.print.info('[mri_Qmultichar] [CRIAÇÃO] Disparando eventos do qbx_core...')
            TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
            TriggerEvent('QBCore:Client:OnPlayerLoaded')
            TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
            TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)
            
            -- Aguardar antes de abrir o illenium
            Wait(500)
            
            -- Verificar posição novamente antes de abrir illenium
            local posBeforeIllenium = GetEntityCoords(cache.ped)
            lib.print.info(string.format('[mri_Qmultichar] [CRIAÇÃO] Posição antes de abrir illenium: %.2f, %.2f, %.2f', 
                posBeforeIllenium.x, posBeforeIllenium.y, posBeforeIllenium.z))
            
            -- Marcar que está criando personagem
            isInCharacterCreation = true
            lib.print.info('[mri_Qmultichar] [CRIAÇÃO] Flag isInCharacterCreation = true')
            
            -- Criar thread para manter jogador na localização correta durante criação
            -- IMPORTANTE: Esta thread só deve rodar enquanto o illenium está aberto
            CreateThread(function()
                local illeniumLocation = getIlleniumLocation()
                local maxWaitTime = 300000 -- 5 minutos máximo (timeout de segurança)
                local startTime = GetGameTimer()
                lib.print.info('[mri_Qmultichar] [CRIAÇÃO] Thread de monitoramento iniciada')
                
                while isInCharacterCreation do
                    -- Timeout de segurança: se passou muito tempo, desativar
                    if GetGameTimer() - startTime > maxWaitTime then
                        lib.print.warn('[mri_Qmultichar] [CRIAÇÃO] Timeout na thread de monitoramento, desativando...')
                        finishCharacterCreation('monitor_timeout')
                        break
                    end
                    
                    if not isIlleniumCustomizationActive then
                        Wait(2000)

                        if not isIlleniumCustomizationActive then
                            lib.print.info('[mri_Qmultichar] [CRIAÇÃO] Illenium não está mais ativo, desativando monitoramento...')
                            finishCharacterCreation('monitor_detected_closed')
                            break
                        end
                    end
                    
                    -- Verificar se o personagem foi realmente carregado (se sim, desativar monitoramento)
                    if LocalPlayer.state.isLoggedIn and not isIlleniumCustomizationActive then
                        lib.print.info('[mri_Qmultichar] [CRIAÇÃO] Personagem carregado (isLoggedIn = true), desativando monitoramento...')
                        finishCharacterCreation('monitor_player_loaded')
                        break
                    end
                    
                    local currentCoords = GetEntityCoords(cache.ped)
                    local distance = #(vector3(currentCoords.x, currentCoords.y, currentCoords.z) - vector3(illeniumLocation.x, illeniumLocation.y, illeniumLocation.z))
                    
                    -- Se o jogador se afastou da localização do illenium, reposicionar
                    -- Mas apenas se o illenium ainda estiver aberto
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
                            lib.print.info(string.format('[mri_Qmultichar] [CRIAÇÃO] Reposicionado para: %.2f, %.2f, %.2f', 
                                afterPos.x, afterPos.y, afterPos.z))
                        else
                            -- Illenium fechado, aguardar um pouco e verificar se o personagem foi carregado
                            Wait(3000) -- Aguardar 3 segundos para dar tempo do personagem ser carregado
                            if LocalPlayer.state.isLoggedIn then
                                lib.print.info('[mri_Qmultichar] [CRIAÇÃO] Personagem carregado após fechar illenium, desativando...')
                                finishCharacterCreation('monitor_closed_after_loaded')
                                break
                            else
                                -- Se ainda não foi carregado, desativar mesmo assim (illenium fechado)
                                lib.print.info('[mri_Qmultichar] [CRIAÇÃO] Illenium fechado durante monitoramento, desativando...')
                                finishCharacterCreation('monitor_closed_without_load')
                                break
                            end
                        end
                    end
                    
                    Wait(500) -- Verificar a cada meio segundo
                end
                
                lib.print.info('[mri_Qmultichar] [CRIAÇÃO] Thread de monitoramento finalizada')
            end)
            
            -- Abrir illenium (personagem já está na localização correta)
            lib.print.info('[mri_Qmultichar] [CRIAÇÃO] Abrindo illenium-appearance...')
            
            -- Aguardar um pouco mais para garantir que tudo está pronto
            Citizen.Wait(500)
            
            -- Abrir illenium diretamente pelo export nativo para evitar depender
            -- do fluxo indireto do qbx_core/qb-clothes no momento da criação.
            if not openIlleniumCharacterCreator(charData.gender) then
                lib.print.warn('[mri_Qmultichar] [CRIAÇÃO] Fallback para qb-clothes:client:CreateFirstCharacter')
                isIlleniumCustomizationActive = true
                TriggerEvent('qb-clothes:client:CreateFirstCharacter')
            end
            
            lib.print.info('[mri_Qmultichar] [CRIAÇÃO] Illenium aberto, aguardando...')
            
            -- Verificar posição após abrir illenium
            CreateThread(function()
                Wait(2000) -- Aguardar 2 segundos após abrir illenium
                if isInCharacterCreation then
                    local posAfterIllenium = GetEntityCoords(cache.ped)
                    lib.print.info(string.format('[mri_Qmultichar] [CRIAÇÃO] Posição após 2s do illenium: %.2f, %.2f, %.2f', 
                        posAfterIllenium.x, posAfterIllenium.y, posAfterIllenium.z))
                end
            end)
            
            isSpawning = false
        end
        
        isCreatingCharacter = false
    end)
end)

-- Escutar quando o illenium-appearance for fechado/salvo
RegisterNetEvent('illenium-appearance:client:characterSaved', function()
    lib.print.info('[mri_Qmultichar] [ILLENIUM] Evento characterSaved recebido')
    if isInCharacterCreation then
        lib.print.info('[mri_Qmultichar] [ILLENIUM] isInCharacterCreation = true, finalizando criação...')
        isIlleniumCustomizationActive = false
        finishCharacterCreation('event_character_saved', 2000)
    else
        lib.print.info('[mri_Qmultichar] [ILLENIUM] isInCharacterCreation = false, ignorando evento')
    end
end)

-- Fallback: escutar evento alternativo do illenium
RegisterNetEvent('qb-clothes:client:characterSaved', function()
    lib.print.info('[mri_Qmultichar] [ILLENIUM] Evento qb-clothes characterSaved recebido')
    if isInCharacterCreation then
        lib.print.info('[mri_Qmultichar] [ILLENIUM] isInCharacterCreation = true, finalizando criação...')
        isIlleniumCustomizationActive = false
        finishCharacterCreation('event_qb_character_saved', 2000)
    else
        lib.print.info('[mri_Qmultichar] [ILLENIUM] isInCharacterCreation = false, ignorando evento')
    end
end)

-- Eventos adicionais do illenium para garantir que a flag seja resetada
RegisterNetEvent('illenium-appearance:client:close', function()
    lib.print.info('[mri_Qmultichar] [ILLENIUM] Evento close recebido')
    if isInCharacterCreation then
        lib.print.info('[mri_Qmultichar] [ILLENIUM] isInCharacterCreation = true, finalizando criação (close)...')
        isIlleniumCustomizationActive = false
        finishCharacterCreation('event_illenium_close', 2000)
    end
end)

RegisterNetEvent('qb-clothes:client:close', function()
    lib.print.info('[mri_Qmultichar] [ILLENIUM] Evento qb-clothes close recebido')
    if isInCharacterCreation then
        lib.print.info('[mri_Qmultichar] [ILLENIUM] isInCharacterCreation = true, finalizando criação (close)...')
        isIlleniumCustomizationActive = false
        finishCharacterCreation('event_qb_close', 2000)
    end
end)

-- Evento quando o personagem é carregado (indica que a criação foi concluída)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    if isInCharacterCreation then
        lib.print.info('[mri_Qmultichar] [LOADED] Personagem carregado, finalizando criação...')
        isIlleniumCustomizationActive = false
        finishCharacterCreation('event_player_loaded', 1000)
    end
end)

-- Callback para deletar personagem
RegisterNUICallback('deleteCharacter', function(data, cb)
    local citizenId = data.citizenid
    if not citizenId then
        cb({ success = false, message = 'CitizenID não fornecido' })
        return
    end

    -- Aguardar um pouco antes de deletar para evitar condições de corrida
    Citizen.Wait(100)
    
    -- Usar callback customizado do mri_Qmultichar que inclui deleção de tabelas adicionais
    local success = lib.callback.await('mri_Qmultichar:server:deleteCharacter', false, citizenId)
    
    if success then
        -- Registrar tempo da deleção para cooldown
        lastDeleteTime = GetGameTimer()
        
        -- Aguardar um pouco para garantir que a deleção foi processada completamente
        Citizen.Wait(500)
        
        lib.notify({
            title = locale('messages.success'),
            description = locale('characters.character_deleted'),
            type = 'success'
        })
        
        -- Recarregar lista de personagens após deleção
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

-- Callback para obter preview do personagem
RegisterNUICallback('getPreviewData', function(data, cb)
    -- NÃO fazer preview em nenhuma etapa da criação de personagem.
    -- O front-end recebe sucesso do createCharacter antes do fluxo terminar, então
    -- precisamos bloquear previews já no início para não reposicionar o ped.
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

    lib.print.info(string.format('[mri_Qmultichar] [PREVIEW] Atualizando preview para CitizenID: %s, Job: %s', citizenId, jobName))
    
    -- Responder callback imediatamente para evitar timeout
    cb({ success = true })
    
    -- Atualizar preview do personagem em thread separada
    CreateThread(function()
        pcall(function()
            exports.mri_Qmultichar:previewPed(citizenId, jobName)
        end)
    end)
end)

-- Callback para fechar NUI
RegisterNUICallback('close', function(_, cb)
    closeMultichar()
    cb({ success = true })
end)

-- Callback para sinalizar que a NUI carregou e está pronta para receber dados
RegisterNUICallback('nuiStarted', function(_, cb)
    local wasNotReady = not isNuiReady
    isNuiReady = true
    lib.print.info('[mri_Qmultichar] NUI sinalizou que está pronta (Handshake OK)')
    
    -- Se a NUI ficou pronta DEPOIS que tentamos abrir (fallback), mandar os dados novamente
    if wasNotReady and isNuiOpen then
        lib.print.info('[mri_Qmultichar] NUI pronta após fallback, reenviando dados de abertura...')
        isNuiOpen = false -- Resetar temporariamente para permitir o novo openMultichar
        openMultichar()
    end
    
    cb({ success = true })
end)

-- Evento quando jogador faz logout
RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    if GetInvokingResource() then return end
    -- Resetar flag de criação ao fazer logout
    if isInCharacterCreation then
        lib.print.info('[mri_Qmultichar] [LOGOUT] Resetando flag isInCharacterCreation ao fazer logout')
        isIlleniumCustomizationActive = false
        isInCharacterCreation = false
        TriggerServerEvent('mri_Qmultichar:server:setBucket', 0)
    end

    openMultichar()
    pcall(function()
        exports.mri_Qmultichar:setupPreviewCam()
    end)
end)

-- Evento quando jogador é descarregado (fallback)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    -- Resetar flag de criação ao descarregar personagem
    if isInCharacterCreation then
        lib.print.info('[mri_Qmultichar] [UNLOAD] Resetando flag isInCharacterCreation ao descarregar personagem')
        isIlleniumCustomizationActive = false
        isInCharacterCreation = false
        TriggerServerEvent('mri_Qmultichar:server:setBucket', 0)
    end
end)

-- Thread principal para abrir multichar no início
CreateThread(function()
    lib.print.info('[mri_Qmultichar] Thread de inicialização iniciada')
    while true do
        Wait(0)
        if NetworkIsSessionStarted() then
            lib.print.info('[mri_Qmultichar] Sessão iniciada, configurando multichar...')
            pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
            Wait(250)
            
            -- Obter personagens primeiro
            local characters, amount = lib.callback.await('mri_Qmultichar:server:getCharacters', false)
            local firstCharacterCitizenId = characters[1] and characters[1].citizenid
            
            -- Preview do primeiro personagem ou random
            local jobName = characters[1] and characters[1].job and (characters[1].job.name or (characters[1].job.label and string.lower(string.gsub(characters[1].job.label, '%s+', '')))) or 'unemployed'
            -- Aguardar um pouco para garantir que o export está disponível
            Citizen.Wait(100)
            pcall(function()
                exports.mri_Qmultichar:previewPed(firstCharacterCitizenId, jobName)
            end)
            
            -- Escolher localização aleatória do qbx_core
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
            
            Wait(250) -- Reduzido de 1500
            ShutdownLoadingScreen()
            ShutdownLoadingScreenNui()
            
            lib.print.info('[mri_Qmultichar] Configurando preview cam...')
            -- Aguardar um pouco para garantir que o export está disponível
            Citizen.Wait(100)
            pcall(function()
                exports.mri_Qmultichar:setupPreviewCam()
            end)
            
            Wait(100) -- Reduzido de 1000
            lib.print.info('[mri_Qmultichar] Abrindo NUI...')
            
            -- AGUARDAR NUI ESTAR PRONTA (Handshake) antes de abrir de fato
            -- Isso evita que ela tente abrir antes do React estar montado
            -- Aumentado para 30 segundos para conexões/PCs lentos na primeira carga
            local timeout = 50 -- Reduzido para 5 segundos
            while not isNuiReady and timeout > 0 do
                Wait(100)
                timeout = timeout - 1
                if timeout % 10 == 0 then
                    lib.print.info('[mri_Qmultichar] Aguardando NUI ficar pronta (Handshake)...')
                end
            end
            
            if not isNuiReady then
                lib.print.warn('[mri_Qmultichar] NUI demorou demais para sinalizar pronta, tentando abrir mesmo assim...')
            end
            
            openMultichar()
            
            -- Garantir que a NUI abra mesmo se houver delay
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
    
    -- Tornar jogador invencível durante seleção de personagem
    while isNuiOpen do
        SetEntityInvincible(PlayerPedId(), true)
        Wait(250)
    end
    SetEntityInvincible(PlayerPedId(), false)
end)

-- Carregar configurações ao iniciar o resource
CreateThread(function()
    Wait(2000) -- Aguardar resource estar totalmente carregado
    loadPlayerSettings()
end)

-- Exportar funções
exports('openMultichar', openMultichar)
exports('closeMultichar', closeMultichar)
exports('isInCharacterCreation', function()
    return isCharacterCreationFlowActive()
end)
