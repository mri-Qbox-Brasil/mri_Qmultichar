-- Fix para o qbx_spawn sem precisar modificar os arquivos dele diretamente
-- Este script intercepta o callback de propriedades para garantir que ele nunca retorne nil,
-- evitando o erro "attempt to get length of a nil value" no cliente do qbx_spawn.

local function registerSafeSpawnCallback()
    lib.callback.register('qbx_spawn:server:getProperties', function(source)
        local player = exports.qbx_core:GetPlayer(source)
        if not player then return {} end

        local houseData = {}

        -- Tenta buscar as propriedades se o qbx_properties estiver rodando
        if GetResourceState('qbx_properties'):find('start') then
            -- Usamos pcall para evitar que o mri_Qmultichar pare se a tabela 'properties' não existir no banco
            local success, properties = pcall(function()
                return MySQL.query.await('SELECT id, property_name, coords FROM properties WHERE owner = ?', { player.PlayerData.citizenid })
            end)

            if success and properties then
                for i = 1, #properties do
                    local property = properties[i]
                    houseData[#houseData + 1] = {
                        label = property.property_name,
                        coords = json.decode(property.coords),
                        propertyId = property.id,
                    }
                end
            end
        end

        -- Se falhou ou não tem propriedades, retorna uma tabela vazia em vez de nil
        return houseData
    end)
end

-- Registra no início e se o qbx_spawn for reiniciado
AddEventHandler('onResourceStart', function(resource)
    if resource == 'qbx_spawn' or resource == GetCurrentResourceName() then
        Wait(500) -- Pequeno delay para garantir que o qbx_spawn já registrou o dele
        registerSafeSpawnCallback()
    end
end)

-- Registro inicial
CreateThread(function()
    Wait(500)
    registerSafeSpawnCallback()
end)
