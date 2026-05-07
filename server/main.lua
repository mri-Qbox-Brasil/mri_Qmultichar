local function dprint(...)
    if Config and Config.Debug then
        lib.print.info(...)
    end
end

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

CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `properties` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `property_name` VARCHAR(255) NOT NULL,
            `coords` TEXT NOT NULL,
            `owner` VARCHAR(255) DEFAULT NULL,
            PRIMARY KEY (`id`),
            KEY `owner` (`owner`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
end)

CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `player_settings` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `license` VARCHAR(255) NOT NULL,
            `license2` VARCHAR(255) DEFAULT NULL,
            `theme` VARCHAR(50) DEFAULT 'dark',
            `camera_effects` TINYINT(1) DEFAULT 1,
            `camera_effect_type` VARCHAR(50) DEFAULT 'cinema',
            `streamer_mode` TINYINT(1) DEFAULT 0,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `license` (`license`),
            KEY `license2` (`license2`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
    dprint('[mri_Qmultichar] Tabela player_settings criada/verificada')
end)

local function getPlayerSlots(license, license2)
    local result = MySQL.single.await('SELECT slots FROM character_slots WHERE license = ? OR license2 = ? LIMIT 1', { license, license2 })
    if result then
        return result.slots
    end
    return Config.CharacterSlots.defaultSlots
end

local function setPlayerSlots(license, license2, slots)
    if slots > Config.CharacterSlots.maxSlots then
        slots = Config.CharacterSlots.maxSlots
    end
    if slots < 1 then
        slots = 1
    end

    local existing = MySQL.single.await('SELECT id, license, license2 FROM character_slots WHERE license = ? OR license2 = ? OR license = ? OR license2 = ? LIMIT 1', {
        license, license, license2, license2
    })

    if existing then
        MySQL.update.await('UPDATE character_slots SET slots = ?, license = ?, license2 = ? WHERE id = ?', {
            slots, license, license2, existing.id
        })
    else
        MySQL.insert.await('INSERT INTO character_slots (license, license2, slots) VALUES (?, ?, ?)', {
            license, license2, slots
        })
    end
    return slots
end

local function getPlayerSettingsFromDB(license, license2)
    local result = MySQL.single.await('SELECT * FROM player_settings WHERE license = ? OR license2 = ? LIMIT 1', { license, license2 or license })

    if result then
        local streamerModeValue = false
        if result.streamer_mode then
            streamerModeValue = result.streamer_mode ~= 0
        end

        return {
            theme = result.theme or Config.Theme or 'dark',
            cameraEffects = result.camera_effects ~= 0,
            cameraEffectType = result.camera_effect_type or 'cinema',
            streamerMode = streamerModeValue,
        }
    end

    return {
        theme = Config.Theme or 'dark',
        cameraEffects = Config.CameraEffects ~= false,
        cameraEffectType = 'cinema',
        streamerMode = Config.StreamerMode or false,
    }
end

local function savePlayerSettingsToDB(license, license2, settings)
    local existing = MySQL.single.await('SELECT id FROM player_settings WHERE license = ? OR license2 = ? LIMIT 1', { license, license2 or license })

    local streamerModeValue = (settings.streamerMode == true) and 1 or 0

    if existing then
        MySQL.update.await('UPDATE player_settings SET theme = ?, camera_effects = ?, camera_effect_type = ?, streamer_mode = ?, license = ?, license2 = ? WHERE id = ?', {
            settings.theme or Config.Theme or 'dark',
            settings.cameraEffects and 1 or 0,
            settings.cameraEffectType or 'cinema',
            streamerModeValue,
            license,
            license2 or license,
            existing.id
        })
    else
        MySQL.insert.await('INSERT INTO player_settings (license, license2, theme, camera_effects, camera_effect_type, streamer_mode) VALUES (?, ?, ?, ?, ?, ?)', {
            license,
            license2 or license,
            settings.theme or Config.Theme or 'dark',
            settings.cameraEffects and 1 or 0,
            settings.cameraEffectType or 'cinema',
            streamerModeValue,
        })
    end
end

local function getPlayerLicenses(source)
    return GetPlayerIdentifierByType(source, 'license'), GetPlayerIdentifierByType(source, 'license2')
end

local function isCharacterOwnedBySource(source, citizenId)
    if not citizenId then
        return false
    end

    local license, license2 = getPlayerLicenses(source)
    local result = MySQL.single.await('SELECT citizenid FROM players WHERE citizenid = ? AND (license = ? OR license = ?) LIMIT 1', {
        citizenId,
        license,
        license2,
    })

    return result ~= nil
end

lib.callback.register('mri_Qmultichar:server:getCharacters', function(source)
    local license, license2 = getPlayerLicenses(source)

    local slots = getPlayerSlots(license, license2)

    local result = MySQL.query.await('SELECT citizenid, charinfo, money, job, gang, position, metadata, cid FROM players WHERE license = ? OR license = ? ORDER BY cid', {license, license2})

    local characters = {}
    local seenCitizenIds = {}

    if result then
        for i = 1, #result do
            local citizenid = result[i].citizenid
            if not seenCitizenIds[citizenid] then
                seenCitizenIds[citizenid] = true

                local charinfo = json.decode(result[i].charinfo)
                local job = result[i].job and json.decode(result[i].job) or {label = 'Unemployed', grade = {name = '0'}}
                local gang = result[i].gang and json.decode(result[i].gang) or {label = 'None', grade = {name = '0'}}
                local metadata = result[i].metadata and json.decode(result[i].metadata) or {}

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
                    metadata = metadata,
                    cid = result[i].cid,
                    photo = metadata.photo or nil,
                }
            end
        end
    end

    local settingsLicense = license2 or license
    local playerSettings = getPlayerSettingsFromDB(settingsLicense, license2)
    local themeName = playerSettings.theme or Config.Theme or 'dark'
    local themeData = Config.Themes[themeName] or Config.Themes.dark

    local musicConfig = Config.Music or {
        enabled = false,
        url = '',
        volume = 0.3,
        loop = true,
        autoplay = true,
    }

    local localeFile = LoadResourceFile(GetCurrentResourceName(), string.format('locales/%s.json', Config.Locale or 'pt-br'))
    local locales = {}
    if localeFile then
        local success, decoded = pcall(json.decode, localeFile)
        if success and decoded then
            locales = decoded
        end
    end

    return characters, slots, themeData, musicConfig, Config.AllowThemeChange or true, Config.Themes or {}, locales
end)

lib.callback.register('mri_Qmultichar:server:getCharacterPhoto', function(_source, citizenId)
    if not citizenId then
        return nil
    end

    local result = MySQL.scalar.await('SELECT JSON_UNQUOTE(JSON_EXTRACT(metadata, "$.photo")) FROM players WHERE citizenid = ? LIMIT 1', { citizenId })
    if result == nil or result == '' or result == 'null' then
        return nil
    end

    return result
end)

lib.callback.register('mri_Qmultichar:server:saveCharacterPhoto', function(source, citizenId, photoBase64)
    if not citizenId or type(photoBase64) ~= 'string' or photoBase64 == '' then
        return false
    end

    local license, license2 = getPlayerLicenses(source)
    local owned = MySQL.scalar.await('SELECT 1 FROM players WHERE citizenid = ? AND (license = ? OR license = ?) LIMIT 1', {
        citizenId, license, license2,
    })
    if not owned then
        lib.print.warn(string.format('[mri_Qmultichar] saveCharacterPhoto: source %s tentou salvar foto de citizenid %s que nao lhe pertence', source, citizenId))
        return false
    end

    local affected = MySQL.update.await('UPDATE players SET metadata = JSON_SET(COALESCE(metadata, JSON_OBJECT()), "$.photo", ?) WHERE citizenid = ?', {
        photoBase64, citizenId,
    })

    if affected and affected > 0 then
        dprint(string.format('[mri_Qmultichar] Foto salva em metadata.photo para citizenid %s (%d bytes)', citizenId, #photoBase64))
        return true
    end

    return false
end)

RegisterNetEvent('mri_Qmultichar:server:setBucket', function(bucket)
    local source = source
    dprint(string.format('[mri_Qmultichar] [SERVER] Definindo bucket %d para source %d', bucket, source))

    if exports.qbx_core and exports.qbx_core.SetPlayerBucket then
        exports.qbx_core:SetPlayerBucket(source, bucket)
    else
        SetPlayerRoutingBucket(source, bucket)
    end

    dprint(string.format('[mri_Qmultichar] [SERVER] Bucket %d definido para source %d', bucket, source))
end)

local function doesTableExist(tableName)
    local result = MySQL.single.await('SELECT COUNT(*) as count FROM information_schema.TABLES WHERE TABLE_NAME = ? AND TABLE_SCHEMA in (SELECT DATABASE())', {tableName})
    return result and result.count > 0
end

local function DeleteCharacterData(citizenId)
    if not citizenId then return false end

    if Config.DeleteTables and #Config.DeleteTables > 0 then
        local deleteQueries = {}

        for i = 1, #Config.DeleteTables do
            local tableConfig = Config.DeleteTables[i]
            if type(tableConfig) == 'table' and #tableConfig >= 2 then
                local tableName = tableConfig[1]
                local columnName = tableConfig[2]

                if doesTableExist(tableName) then
                    deleteQueries[#deleteQueries + 1] = {
                        query = string.format('DELETE FROM `%s` WHERE `%s` = ?', tableName, columnName),
                        values = {citizenId}
                    }
                end
            end
        end

        if #deleteQueries > 0 then
            local deleteSuccess = MySQL.transaction.await(deleteQueries)
            return deleteSuccess
        end
    end
    return true
end

lib.callback.register('mri_Qmultichar:server:deleteCharacter', function(source, citizenId)
    if not citizenId then
        return false
    end

    local license = GetPlayerIdentifierByType(source, 'license')
    local license2 = GetPlayerIdentifierByType(source, 'license2')

    local result = MySQL.single.await('SELECT license FROM players WHERE citizenid = ?', {citizenId})
    if not result then
        lib.print.warn(string.format('[mri_Qmultichar] Personagem não encontrado. CitizenID: %s', citizenId))
        return false
    end

    if result.license ~= license and result.license ~= license2 then
        lib.print.warn(string.format('[mri_Qmultichar] Tentativa de deletar personagem de outro jogador. Source: %s, CitizenID: %s, License do personagem: %s, License do jogador: %s/%s',
            source, citizenId, result.license, license, license2))
        return false
    end

    local storage = require('@qbx_core/server/storage/main')
    local pcallSuccess, deleteResult = pcall(function()
        return storage.deletePlayer(citizenId)
    end)

    if not pcallSuccess then
        lib.print.warn(string.format('[mri_Qmultichar] Erro interno do qbx_core ao deletar (pode ser ignorado). CitizenID: %s, Erro: %s', citizenId, tostring(deleteResult)))
    elseif not deleteResult then
        lib.print.error(string.format('[mri_Qmultichar] Falha ao deletar personagem. CitizenID: %s', citizenId))
        return false
    end

    local additionalDeleteSuccess = DeleteCharacterData(citizenId)
    if not additionalDeleteSuccess then
        lib.print.error(string.format('[mri_Qmultichar] Falha ao deletar dados adicionais do personagem via export. CitizenID: %s', citizenId))
    end

    Wait(200)

    local verifyResult = MySQL.single.await('SELECT citizenid FROM players WHERE citizenid = ?', {citizenId})
    if verifyResult then
        lib.print.error(string.format('[mri_Qmultichar] Personagem ainda existe após deleção! CitizenID: %s', citizenId))
        return false
    end

    dprint(string.format('[mri_Qmultichar] Personagem deletado com sucesso. Source: %s, CitizenID: %s', source, citizenId))

    return true
end)

lib.callback.register('mri_Qmultichar:server:checkSlotAvailable', function(source, slot)
    if not slot then
        return { available = false }
    end

    local license = GetPlayerIdentifierByType(source, 'license')
    local license2 = GetPlayerIdentifierByType(source, 'license2')

    local result = MySQL.single.await('SELECT citizenid FROM players WHERE (license = ? OR license = ?) AND cid = ?', {license, license2, slot})

    if result then
        lib.print.warn(string.format('[mri_Qmultichar] Slot %d ocupado por CitizenID: %s', slot, result.citizenid))
        return { available = false, citizenid = result.citizenid }
    else
        return { available = true }
    end
end)

lib.callback.register('mri_Qmultichar:server:updateSettings', function(source, data)
    local license = GetPlayerIdentifierByType(source, 'license2') or GetPlayerIdentifierByType(source, 'license')
    local license2 = GetPlayerIdentifierByType(source, 'license2')
    if not license then
        return false
    end

    local currentSettings = getPlayerSettingsFromDB(license, license2)

    if data.theme then
        if Config.AllowThemeChange then
            currentSettings.theme = data.theme
            dprint(string.format('[mri_Qmultichar] Tema alterado por %s: %s', GetPlayerName(source), data.theme))
        end
    end

    if data.cameraEffects ~= nil then
        currentSettings.cameraEffects = data.cameraEffects
        dprint(string.format('[mri_Qmultichar] Efeitos de câmera alterados por %s: %s', GetPlayerName(source), tostring(data.cameraEffects)))
    end

    if data.cameraEffectType then
        currentSettings.cameraEffectType = data.cameraEffectType
        dprint(string.format('[mri_Qmultichar] Tipo de efeito de câmera alterado por %s: %s', GetPlayerName(source), data.cameraEffectType))
    end

    if data.streamerMode ~= nil then
        currentSettings.streamerMode = data.streamerMode
        dprint(string.format('[mri_Qmultichar] Modo streamer alterado por %s: %s', GetPlayerName(source), tostring(data.streamerMode)))
    end

    savePlayerSettingsToDB(license, license2, currentSettings)

    return true
end)

lib.callback.register('mri_Qmultichar:server:getPlayerSettings', function(source)
    local license = GetPlayerIdentifierByType(source, 'license2') or GetPlayerIdentifierByType(source, 'license')
    local license2 = GetPlayerIdentifierByType(source, 'license2')

    if not license then
        return {
            theme = Config.Theme or 'dark',
            cameraEffects = Config.CameraEffects ~= false,
            cameraEffectType = 'cinema',
            streamerMode = Config.StreamerMode or false,
        }
    end

    return getPlayerSettingsFromDB(license, license2)
end)

lib.callback.register('mri_Qmultichar:server:validateCharacterSelection', function(source, citizenId)
    if not citizenId then
        return {
            allowed = false,
            message = 'Personagem inválido.',
        }
    end

    if not isCharacterOwnedBySource(source, citizenId) then
        lib.print.warn(string.format(
            '[mri_Qmultichar] Tentativa de seleção inválida. Source: %s, CitizenID: %s',
            source,
            citizenId
        ))

        return {
            allowed = false,
            message = 'Você não pode selecionar este personagem.',
        }
    end

    return {
        allowed = true,
    }
end)

lib.callback.register('mri_Qmultichar:server:getCharacterPhotoData', function(source, citizenId)
    if not citizenId then
        return { success = false, data = nil }
    end

    local result = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', { citizenId })
    if not result then
        lib.print.error(string.format('[mri_Qmultichar] Personagem não encontrado: %s', citizenId))
        return { success = false, data = nil }
    end

    local charinfo = json.decode(result.charinfo)
    if not charinfo then
        lib.print.error(string.format('[mri_Qmultichar] Falha ao decodificar charinfo: %s', citizenId))
        return { success = false, data = nil }
    end

    local clothing = charinfo.skin or charinfo
    local gender = charinfo.gender or 0
    local model = charinfo.model

    if not model then
        if gender == 1 then
            model = `mp_f_freemode_01`
        else
            model = `mp_m_freemode_01`
        end
    end

    return {
        success = true,
        data = {
            clothing = clothing,
            model = model,
            gender = gender
        }
    }
end)

local function AddDeleteTable(tableName, columnName)
    if not tableName or not columnName then
        return false
    end

    if not Config.DeleteTables then
        Config.DeleteTables = {}
    end

    for i = 1, #Config.DeleteTables do
        if Config.DeleteTables[i][1] == tableName then
            Config.DeleteTables[i][2] = columnName
            dprint(string.format('[mri_Qmultichar] Tabela de deleção atualizada: %s (%s)', tableName, columnName))
            return true
        end
    end

    table.insert(Config.DeleteTables, {tableName, columnName})
    dprint(string.format('[mri_Qmultichar] Nova tabela de deleção adicionada: %s (%s)', tableName, columnName))
    return true
end

exports('getPlayerSlots', getPlayerSlots)
exports('setPlayerSlots', setPlayerSlots)
exports('SetCharacterSlots', setPlayerSlots)
exports('AddDeleteTable', AddDeleteTable)
exports('DeleteCharacterData', DeleteCharacterData)
