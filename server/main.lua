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
    lib.print.info(string.format('[mri_Qmultichar] [SERVER] Definindo bucket %d para source %d', bucket, source))
    
    if exports.qbx_core and exports.qbx_core.SetPlayerBucket then
        exports.qbx_core:SetPlayerBucket(source, bucket)
    else
        -- Fallback: usar função nativa diretamente
        SetPlayerRoutingBucket(source, bucket)
    end
    
    lib.print.info(string.format('[mri_Qmultichar] [SERVER] Bucket %d definido para source %d', bucket, source))
end)

-- Função para verificar se uma tabela existe
local function doesTableExist(tableName)
    local result = MySQL.single.await('SELECT COUNT(*) as count FROM information_schema.TABLES WHERE TABLE_NAME = ? AND TABLE_SCHEMA in (SELECT DATABASE())', {tableName})
    return result and result.count > 0
end

-- Callback customizado para deletar personagem com tabelas adicionais
lib.callback.register('mri_Qmultichar:server:deleteCharacter', function(source, citizenId)
    if not citizenId then
        return false
    end
    
    local license = GetPlayerIdentifierByType(source, 'license')
    local license2 = GetPlayerIdentifierByType(source, 'license2')
    
    -- Buscar license do personagem no banco de dados
    local result = MySQL.single.await('SELECT license FROM players WHERE citizenid = ?', {citizenId})
    if not result then
        lib.print.warn(string.format('[mri_Qmultichar] Personagem não encontrado. CitizenID: %s', citizenId))
        return false -- Personagem não existe
    end
    
    -- Verificar se o license corresponde (igual ao qbx_core)
    if result.license ~= license and result.license ~= license2 then
        -- License não corresponde - possível exploração
        lib.print.warn(string.format('[mri_Qmultichar] Tentativa de deletar personagem de outro jogador. Source: %s, CitizenID: %s, License do personagem: %s, License do jogador: %s/%s', 
            source, citizenId, result.license, license, license2))
        return false
    end
    
    -- Deletar usando o storage do qbx_core diretamente (mesma lógica que o qbx_core usa)
    -- Usar pcall para capturar erros internos do qbx_core (como GroupType nil)
    local storage = require('@qbx_core/server/storage/main')
    local pcallSuccess, deleteResult = pcall(function()
        return storage.deletePlayer(citizenId)
    end)
    
    -- Se pcall retornou false, significa que houve um erro durante a execução
    if not pcallSuccess then
        lib.print.warn(string.format('[mri_Qmultichar] Erro interno do qbx_core ao deletar (pode ser ignorado). CitizenID: %s, Erro: %s', citizenId, tostring(deleteResult)))
        -- Mesmo com erro, tentar continuar (o personagem pode ter sido deletado parcialmente)
        -- Vamos assumir sucesso se não conseguirmos verificar
    elseif not deleteResult then
        -- Se deletePlayer retornou false, significa que a deleção falhou
        lib.print.error(string.format('[mri_Qmultichar] Falha ao deletar personagem. CitizenID: %s', citizenId))
        return false
    end
    
    -- Log de sucesso (similar ao qbx_core)
    lib.print.info(string.format('[mri_Qmultichar] Personagem deletado com sucesso. Source: %s, CitizenID: %s', source, citizenId))
    
    -- Deletar tabelas adicionais configuradas
    if Config.DeleteTables and #Config.DeleteTables > 0 then
        local deleteQueries = {}
        
        for i = 1, #Config.DeleteTables do
            local tableConfig = Config.DeleteTables[i]
            if type(tableConfig) == 'table' and #tableConfig >= 2 then
                local tableName = tableConfig[1]
                local columnName = tableConfig[2]
                
                -- Verificar se a tabela existe
                if doesTableExist(tableName) then
                    deleteQueries[#deleteQueries + 1] = {
                        query = string.format('DELETE FROM `%s` WHERE `%s` = ?', tableName, columnName),
                        values = {citizenId}
                    }
                else
                    lib.print.warn(string.format('[mri_Qmultichar] Tabela %s não existe no banco de dados. Pulando...', tableName))
                end
            end
        end
        
        -- Executar queries de deleção adicionais
        if #deleteQueries > 0 then
            local deleteSuccess = MySQL.transaction.await(deleteQueries)
            if not deleteSuccess then
                lib.print.error(string.format('[mri_Qmultichar] Falha ao deletar dados adicionais do personagem. CitizenID: %s', citizenId))
                -- Não retornar false aqui, pois o personagem principal já foi deletado
            else
                lib.print.info(string.format('[mri_Qmultichar] Dados adicionais deletados com sucesso. CitizenID: %s, Tabelas: %d', citizenId, #deleteQueries))
            end
        end
    end
    
    return true
end)

-- Exportar funções
exports('getPlayerSlots', getPlayerSlots)
exports('setPlayerSlots', setPlayerSlots)

