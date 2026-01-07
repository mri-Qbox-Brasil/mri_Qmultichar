-- Criar tabela de slots se não existir
CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `character_slots` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `license` VARCHAR(255) NOT NULL,
            `license2` VARCHAR(255) DEFAULT NULL,
            `slots` INT(11) NOT NULL DEFAULT 3,
            PRIMARY KEY (`id`),
            UNIQUE KEY `license` (`license`),
            KEY `license2` (`license2`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
end)

-- Função para obter número de slots do jogador
local function getPlayerSlots(license, license2)
    local result = MySQL.single.await('SELECT slots FROM character_slots WHERE license = ? OR license2 = ? LIMIT 1', { license, license2 })
    if result then
        return result.slots
    end
    return Config.CharacterSlots.defaultSlots
end

-- Função para definir número de slots do jogador
local function setPlayerSlots(license, license2, slots)
    if slots > Config.CharacterSlots.maxSlots then
        slots = Config.CharacterSlots.maxSlots
    end
    if slots < 1 then
        slots = 1
    end
    
    -- Buscar por license OU license2 (pode estar em qualquer um dos campos)
    local existing = MySQL.single.await('SELECT id, license, license2 FROM character_slots WHERE license = ? OR license2 = ? OR license = ? OR license2 = ? LIMIT 1', { 
        license, license, license2, license2 
    })
    
    if existing then
        -- Atualizar registro existente, garantindo que ambos os licenses estejam salvos
        MySQL.update.await('UPDATE character_slots SET slots = ?, license = ?, license2 = ? WHERE id = ?', { 
            slots, license, license2, existing.id 
        })
    else
        -- Criar novo registro
        MySQL.insert.await('INSERT INTO character_slots (license, license2, slots) VALUES (?, ?, ?)', { 
            license, license2, slots 
        })
    end
    return slots
end

-- Callback para obter personagens
lib.callback.register('mri_Qmultichar:server:getCharacters', function(source)
    local license2 = GetPlayerIdentifierByType(source, 'license2')
    local license = GetPlayerIdentifierByType(source, 'license')
    
    -- Obter slots do jogador
    local slots = getPlayerSlots(license, license2)
    
    -- Obter personagens usando query direta (igual ao qbx_core)
    -- Buscar pelo license OU license2 (a coluna license pode conter qualquer um dos dois)
    local result = MySQL.query.await('SELECT citizenid, charinfo, money, job, gang, position, metadata, cid FROM players WHERE license = ? OR license = ? ORDER BY cid', {license, license2})
    
    local characters = {}
    local seenCitizenIds = {}
    
    if result then
        for i = 1, #result do
            local citizenid = result[i].citizenid
            -- Evitar duplicados
            if not seenCitizenIds[citizenid] then
                seenCitizenIds[citizenid] = true
                
                local charinfo = json.decode(result[i].charinfo)
                local job = result[i].job and json.decode(result[i].job) or {label = 'Unemployed', grade = {name = '0'}}
                local gang = result[i].gang and json.decode(result[i].gang) or {label = 'None', grade = {name = '0'}}
                
                -- Garantir que o job tenha 'name' (usar label em lowercase como fallback)
                if not job.name then
                    job.name = job.label and string.lower(string.gsub(job.label, '%s+', '')) or 'unemployed'
                end
                
                characters[#characters + 1] = {
                    citizenid = citizenid,
                    charinfo = charinfo,
                    money = json.decode(result[i].money),
                    job = job,
                    gang = gang,
                    position = json.decode(result[i].position),
                    metadata = json.decode(result[i].metadata),
                    cid = result[i].cid
                }
            end
        end
    end
    
    -- Obter tema atual
    local themeName = Config.Theme or 'dark'
    local themeData = Config.Themes[themeName] or Config.Themes.dark
    
    -- Retornar personagens, slots e tema
    return characters, slots, themeData
end)

-- Evento para definir bucket do player (client chama isso)
RegisterNetEvent('mri_Qmultichar:server:setBucket', function(bucket)
    local source = source
    if exports.qbx_core and exports.qbx_core.SetPlayerBucket then
        exports.qbx_core:SetPlayerBucket(source, bucket)
    else
        -- Fallback: usar função nativa diretamente
        SetPlayerRoutingBucket(source, bucket)
    end
end)

-- Exportar funções
exports('getPlayerSlots', getPlayerSlots)
exports('setPlayerSlots', setPlayerSlots)

