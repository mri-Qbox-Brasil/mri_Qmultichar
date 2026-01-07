local isNuiOpen = false

-- Flag global para prevenir múltiplos spawns simultâneos
local isSpawning = false

-- Variável para prevenir múltiplas criações simultâneas
local isCreatingCharacter = false

-- Variável para rastrear se está criando personagem (para voltar ao bucket padrão após illenium)
local isInCharacterCreation = false

-- Default spawn (mesmo valor do qbx_core)
local defaultSpawn = vector4(-66.24, -822.09, 285.61 - 1, 78.8)

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

-- Função para abrir a NUI
local function openMultichar()
    if isNuiOpen then return end
    
    lib.print.info('[mri_Qmultichar] Abrindo NUI...')
    isNuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
    })
    lib.print.info('[mri_Qmultichar] NUI aberta')
end

-- Função para fechar a NUI
local function closeMultichar()
    if not isNuiOpen then return end
    
    isNuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'close',
    })
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
    
    DoScreenFadeOut(500)

    while not IsScreenFadedOut() do
        Wait(0)
    end

    exports.mri_Qmultichar:destroyPreviewCam()
    
    -- Aguardar um pouco antes de spawnar
    Citizen.Wait(200)

    pcall(function() 
        exports.spawnmanager:spawnPlayer({
            x = defaultSpawn.x,
            y = defaultSpawn.y,
            z = defaultSpawn.z,
            heading = defaultSpawn.w
        })
    end)
    
    -- Aguardar spawn completar
    Citizen.Wait(1000)

    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
    TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
    TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)

    while not IsScreenFadedIn() do
        Wait(0)
    end
    
    -- Marcar que está criando personagem (se ainda não foi marcado)
    if not isInCharacterCreation then
        isInCharacterCreation = true
    end
    
    -- Aguardar um pouco antes de abrir o illenium-appearance
    Wait(500)
    TriggerEvent('qb-clothes:client:CreateFirstCharacter')
    
    isSpawning = false
end

-- Callback para obter personagens
RegisterNUICallback('getCharacters', function(_, cb)
    lib.print.info('[mri_Qmultichar] Callback getCharacters chamado')
    local characters, amount, theme = lib.callback.await('mri_Qmultichar:server:getCharacters', false)
    
    if characters then
        lib.print.info(string.format('[mri_Qmultichar] Personagens carregados: %d, Slots: %d', #characters, amount or 3))
        cb({ success = true, characters = characters, amount = amount or 3, theme = theme })
    else
        lib.print.error('[mri_Qmultichar] Erro ao carregar personagens')
        local themeName = Config.Theme or 'dark'
        local themeData = Config.Themes[themeName] or Config.Themes.dark
        cb({ success = false, characters = {}, amount = 3, theme = themeData })
    end
end)

-- Variável para prevenir múltiplos carregamentos simultâneos
local isLoadingCharacter = false

-- Callback para carregar personagem
RegisterNUICallback('loadCharacter', function(data, cb)
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
        
        if not GetResourceState('mri_Qspawn'):find('start') then 
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
            
            if GetResourceState('mri_Qspawn'):find('start') then
                exports['mri_Qspawn']:chooseSpawn()
                isSpawning = false
            elseif GetResourceState('qbx_apartments'):find('start') and getQbxConfig().characters.startingApartment then
                TriggerEvent('apartments:client:setupSpawnUI', citizenId)
                isSpawning = false
            elseif GetResourceState('qbx_spawn'):find('start') then
                TriggerEvent('qb-spawn:client:setupSpawns', citizenId)
                TriggerEvent('qb-spawn:client:openUI', true)
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
            -- Prevenir múltiplos spawns simultâneos
            if isSpawning then
                isCreatingCharacter = false
                return
            end
            
            isSpawning = true
            
            -- Fechar NUI e destruir câmera primeiro
            exports.mri_Qmultichar:destroyPreviewCam()
            closeMultichar()
            
            -- Aguardar para garantir que o NUI fechou completamente
            Citizen.Wait(500)
            
            -- Definir bucket separado para criação (bucket 2)
            TriggerServerEvent('mri_Qmultichar:server:setBucket', 2)
            Citizen.Wait(200) -- Aguardar bucket ser aplicado
            
            -- Descongelar player e limpar qualquer posição fixa do preview
            FreezeEntityPosition(PlayerPedId(), false)
            ClearPedTasks(PlayerPedId())
            
            -- Seguir a mesma lógica do qbx_core para criação de personagem
            if GetResourceState('qbx_spawn') == 'missing' then
                -- Se não tiver qbx_spawn, usar spawn padrão
                spawnDefault()
            else
                -- Verificar se tem startingApartment configurado
                local qbxConfig = getQbxConfig()
                if qbxConfig.characters.startingApartment then
                    -- Criar apartamento e abrir illenium lá (igual qbx_core)
                    TriggerEvent('apartments:client:setupSpawnUI', newData)
                else
                    -- Sem apartamento, usar spawn sem apartamentos
                    TriggerEvent('qbx_core:client:spawnNoApartments')
                end
            end
            
            -- Marcar que está criando personagem
            isInCharacterCreation = true
            
            isSpawning = false
        end
        
        isCreatingCharacter = false
    end)
end)

-- Escutar quando o illenium-appearance for fechado/salvo para voltar ao bucket padrão
RegisterNetEvent('illenium-appearance:client:characterSaved', function()
    if isInCharacterCreation then
        Citizen.Wait(500) -- Aguardar um pouco para garantir que tudo foi salvo
        -- Voltar ao bucket padrão (0) onde todos os jogadores estão
        TriggerServerEvent('mri_Qmultichar:server:setBucket', 0)
        isInCharacterCreation = false
    end
end)

-- Fallback: escutar evento alternativo do illenium
RegisterNetEvent('qb-clothes:client:characterSaved', function()
    if isInCharacterCreation then
        Citizen.Wait(500)
        TriggerServerEvent('mri_Qmultichar:server:setBucket', 0)
        isInCharacterCreation = false
    end
end)

-- Fallback adicional: escutar quando o player é carregado após criação
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    if isInCharacterCreation then
        CreateThread(function()
            Citizen.Wait(2000) -- Aguardar um pouco mais para garantir que o illenium foi fechado
            if isInCharacterCreation then
                TriggerServerEvent('mri_Qmultichar:server:setBucket', 0)
                isInCharacterCreation = false
            end
        end)
    end
end)

-- Callback para deletar personagem
RegisterNUICallback('deleteCharacter', function(data, cb)
    local citizenId = data.citizenid
    if not citizenId then
        cb({ success = false, message = 'CitizenID não fornecido' })
        return
    end

    local success = lib.callback.await('qbx_core:server:deleteCharacter', false, citizenId)
    
    if success then
        lib.notify({
            title = 'Sucesso',
            description = 'Personagem deletado com sucesso',
            type = 'success'
        })
        cb({ success = true })
    else
        lib.notify({
            title = 'Erro',
            description = 'Falha ao deletar personagem',
            type = 'error'
        })
        cb({ success = false, message = 'Falha ao deletar personagem' })
    end
end)

-- Callback para obter preview do personagem
RegisterNUICallback('getPreviewData', function(data, cb)
    local citizenId = data.citizenid
    local jobName = data.job or 'unemployed'
    if not citizenId then
        cb({ success = false })
        return
    end

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

-- Evento quando jogador faz logout
RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    if GetInvokingResource() then return end
    openMultichar()
    exports.mri_Qmultichar:setupPreviewCam()
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
            exports.mri_Qmultichar:previewPed(firstCharacterCitizenId, jobName)
            
            -- Escolher localização aleatória do qbx_core
            local qbxConfig = getQbxConfig()
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
            
            Wait(1500)
            ShutdownLoadingScreen()
            ShutdownLoadingScreenNui()
            
            lib.print.info('[mri_Qmultichar] Configurando preview cam...')
            exports.mri_Qmultichar:setupPreviewCam()
            
            Wait(1000)
            lib.print.info('[mri_Qmultichar] Abrindo NUI...')
            openMultichar()
            
            -- Garantir que a NUI abra mesmo se houver delay
            CreateThread(function()
                Wait(2000)
                if not isNuiOpen then
                    lib.print.warn('[mri_Qmultichar] NUI não abriu, tentando novamente...')
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

-- Exportar funções
exports('openMultichar', openMultichar)
exports('closeMultichar', closeMultichar)
