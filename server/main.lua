local HEX_PATTERN = '^#%x%x%x%x%x%x$'

local function isValidHex(value)
    return type(value) == 'string' and value:match(HEX_PATTERN) ~= nil
end

local function resolveAccentColor()
    local convar = GetConvar('mri:color', '')
    if isValidHex(convar) then
        return convar
    end

    if isValidHex(Config.AccentColor) then
        return Config.AccentColor
    end

    return '#00E699'
end

CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `mri_qmultichar_slots` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `license` VARCHAR(255) NOT NULL,
            `license2` VARCHAR(255) DEFAULT NULL,
            `slots` INT(11) NOT NULL DEFAULT 3,
            PRIMARY KEY (`id`),
            UNIQUE KEY `license` (`license`),
            KEY `license2` (`license2`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `mri_qmultichar_photos` (
            `citizenid` VARCHAR(50) NOT NULL,
            `photo` MEDIUMTEXT NOT NULL,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    -- coluna do último personagem jogado (para o botão "Continuar" da landing)
    MySQL.query([[
        ALTER TABLE `mri_qmultichar_slots`
        ADD COLUMN IF NOT EXISTS `last_citizenid` VARCHAR(50) DEFAULT NULL
    ]])

    -- registra pro cleanup automático em DeleteCharacterData
    Config.DeleteTables = Config.DeleteTables or {}
    Config.DeleteTables[#Config.DeleteTables + 1] = { 'mri_qmultichar_photos', 'citizenid' }
end)

-- default/teto de slots geridos pelo painel (/adminchar), com fallback no config.lua.
local function panelSlots()
    local cfg = GetPanelConfig and GetPanelConfig() or nil
    local s = cfg and cfg.slots or nil
    local default = (s and tonumber(s.default)) or Config.CharacterSlots.defaultSlots
    local max = (s and tonumber(s.max)) or Config.CharacterSlots.maxSlots
    return default, max
end

local function getPlayerSlots(license, license2)
    local result = MySQL.single.await('SELECT slots FROM mri_qmultichar_slots WHERE license = ? OR license2 = ? LIMIT 1', { license, license2 })
    if result then
        return result.slots
    end
    local default = panelSlots()
    return default
end

local function setPlayerSlots(license, license2, slots)
    local _, maxSlots = panelSlots()
    if slots > maxSlots then
        slots = maxSlots
    end
    if slots < 1 then
        slots = 1
    end

    local existing = MySQL.single.await('SELECT id, license, license2 FROM mri_qmultichar_slots WHERE license = ? OR license2 = ? OR license = ? OR license2 = ? LIMIT 1', {
        license, license, license2, license2
    })

    if existing then
        MySQL.update.await('UPDATE mri_qmultichar_slots SET slots = ?, license = ?, license2 = ? WHERE id = ?', {
            slots, license, license2, existing.id
        })
    else
        MySQL.insert.await('INSERT INTO mri_qmultichar_slots (license, license2, slots) VALUES (?, ?, ?)', {
            license, license2, slots
        })
    end
    return slots
end

local function getPlayerLicenses(source)
    return GetPlayerIdentifierByType(source, 'license'), GetPlayerIdentifierByType(source, 'license2')
end

---Lê o último citizenid jogado por este license (para o botão "Continuar").
---@param license string
---@param license2 string|nil
---@return string|nil
local function getLastPlayed(license, license2)
    local result = MySQL.single.await('SELECT last_citizenid FROM mri_qmultichar_slots WHERE license = ? OR license2 = ? LIMIT 1', { license, license2 })
    if result and result.last_citizenid and result.last_citizenid ~= '' then
        return result.last_citizenid
    end
    return nil
end

---Grava o último citizenid jogado, criando a linha do license se necessário.
---@param license string
---@param license2 string|nil
---@param citizenId string
local function setLastPlayed(license, license2, citizenId)
    local existing = MySQL.single.await('SELECT id FROM mri_qmultichar_slots WHERE license = ? OR license2 = ? LIMIT 1', { license, license2 })
    if existing then
        MySQL.update.await('UPDATE mri_qmultichar_slots SET last_citizenid = ? WHERE id = ?', { citizenId, existing.id })
    else
        MySQL.insert.await('INSERT INTO mri_qmultichar_slots (license, license2, slots, last_citizenid) VALUES (?, ?, ?, ?)', {
            license, license2, Config.CharacterSlots.defaultSlots, citizenId
        })
    end
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

    local result = MySQL.query.await([[
        SELECT p.citizenid, p.charinfo, p.money, p.job, p.gang, p.position, p.metadata, p.cid, ph.photo
        FROM players p
        LEFT JOIN mri_qmultichar_photos ph ON ph.citizenid = p.citizenid
        WHERE p.license = ? OR p.license = ?
        ORDER BY p.cid
    ]], {license, license2})

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
                    photo = result[i].photo,
                }
            end
        end
    end

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

    -- só devolve lastPlayed se o personagem ainda existir na lista atual
    local lastPlayed = getLastPlayed(license, license2)
    if lastPlayed and not seenCitizenIds[lastPlayed] then
        lastPlayed = nil
    end

    local panelConfig = GetPanelConfig and GetPanelConfig() or {}

    return {
        characters = characters,
        slots = slots,
        lastPlayed = lastPlayed,
        accentColor = resolveAccentColor(),
        allowAccentOverride = Config.AllowAccentOverride ~= false,
        branding = panelConfig.branding,
        landing = panelConfig.landing,
        defaults = {
            cameraEffects = Config.CameraEffects ~= false,
            cameraEffectType = Config.CameraEffectType or 'cinema',
            streamerMode = Config.StreamerMode == true,
        },
        music = musicConfig,
        locales = locales,
    }
end)

---Grava o último personagem jogado. Disparado pelo cliente após um load bem-sucedido.
RegisterNetEvent('mri_Qmultichar:server:recordLastPlayed', function(citizenId)
    local source = source
    if not source or source == 0 or type(citizenId) ~= 'string' or citizenId == '' then
        return
    end
    if not isCharacterOwnedBySource(source, citizenId) then
        lib.print.warn(string.format('[mri_Qmultichar] recordLastPlayed: source %s tentou marcar citizenid %s que nao lhe pertence', source, citizenId))
        return
    end
    local license, license2 = getPlayerLicenses(source)
    setLastPlayed(license, license2, citizenId)
end)

lib.callback.register('mri_Qmultichar:server:getCharacterPhoto', function(_source, citizenId)
    if not citizenId then
        return nil
    end

    local photo = MySQL.scalar.await('SELECT photo FROM mri_qmultichar_photos WHERE citizenid = ?', { citizenId })
    if photo == nil or photo == '' then
        return nil
    end

    return photo
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

    local affected = MySQL.insert.await([[
        INSERT INTO mri_qmultichar_photos (citizenid, photo) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE photo = VALUES(photo)
    ]], { citizenId, photoBase64 })

    if affected then
        DebugPrint(string.format('[mri_Qmultichar] Foto salva em mri_qmultichar_photos para citizenid %s (%d bytes)', citizenId, #photoBase64))
        return true
    end

    return false
end)

RegisterNetEvent('mri_Qmultichar:server:setBucket', function(bucket)
    local source = source
    DebugPrint(string.format('[mri_Qmultichar] [SERVER] Definindo bucket %d para source %d', bucket, source))

    if exports.qbx_core and exports.qbx_core.SetPlayerBucket then
        exports.qbx_core:SetPlayerBucket(source, bucket)
    else
        SetPlayerRoutingBucket(source, bucket)
    end

    DebugPrint(string.format('[mri_Qmultichar] [SERVER] Bucket %d definido para source %d', bucket, source))
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

    DebugPrint(string.format('[mri_Qmultichar] Personagem deletado com sucesso. Source: %s, CitizenID: %s', source, citizenId))

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

-- Broadcast da mudança da convar `mri:color` para NUIs já abertas.
AddConvarChangeListener('mri:color', function(name)
    if name ~= 'mri:color' then return end
    local newColor = resolveAccentColor()
    DebugPrint(string.format('[mri_Qmultichar] convar mri:color alterada para %s, propagando aos clientes', newColor))
    TriggerClientEvent('mri_Qmultichar:client:accentColorChanged', -1, newColor)
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
            DebugPrint(string.format('[mri_Qmultichar] Tabela de deleção atualizada: %s (%s)', tableName, columnName))
            return true
        end
    end

    table.insert(Config.DeleteTables, {tableName, columnName})
    DebugPrint(string.format('[mri_Qmultichar] Nova tabela de deleção adicionada: %s (%s)', tableName, columnName))
    return true
end

-- Gestão de slots pelo painel /adminchar (substitui os comandos) --------------

lib.callback.register('mri_Qmultichar:server:adminListPlayers', function(source)
    if not MultiCharIsAdmin(source) then return { ok = false } end

    local list = {}
    for _, pid in ipairs(GetPlayers()) do
        pid = tonumber(pid)
        local license = GetPlayerIdentifierByType(pid, 'license')
        local license2 = GetPlayerIdentifierByType(pid, 'license2')
        list[#list + 1] = {
            id = pid,
            name = GetPlayerName(pid),
            slots = getPlayerSlots(license, license2),
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)

    local default, max = panelSlots()
    return { ok = true, players = list, default = default, max = max }
end)

lib.callback.register('mri_Qmultichar:server:adminSetSlots', function(source, targetId, slots)
    if not MultiCharIsAdmin(source) then return { ok = false } end
    targetId = tonumber(targetId)
    slots = tonumber(slots)
    if not targetId or not slots then return { ok = false } end

    local license = GetPlayerIdentifierByType(targetId, 'license')
    local license2 = GetPlayerIdentifierByType(targetId, 'license2')
    if not license then return { ok = false } end

    local final = setPlayerSlots(license, license2, slots)
    return { ok = true, slots = final }
end)

exports('getPlayerSlots', getPlayerSlots)
exports('setPlayerSlots', setPlayerSlots)
exports('SetCharacterSlots', setPlayerSlots)
exports('AddDeleteTable', AddDeleteTable)
exports('DeleteCharacterData', DeleteCharacterData)
