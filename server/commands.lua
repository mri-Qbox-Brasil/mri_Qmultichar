local VALID_ACTIONS = { get = true, set = true, add = true, remove = true }

local localLocales = {}

local function loadLocales()
    local localeName = Config.Locale or 'pt-br'
    local localeFile = LoadResourceFile(GetCurrentResourceName(), string.format('locales/%s.json', localeName))
    if localeFile then
        local success, decoded = pcall(json.decode, localeFile)
        if success and decoded then
            localLocales = decoded
        end
    end
end

loadLocales()

local function getTranslation(key)
    local keys = {}
    for k in string.gmatch(key, "[^.]+") do
        table.insert(keys, k)
    end

    local current = localLocales
    for i = 1, #keys do
        if type(current) ~= 'table' then
            return nil
        end
        current = current[keys[i]]
    end

    return type(current) == 'string' and current or nil
end

local function formatLocale(key, vars)
    local str = getTranslation(key) or locale(key)
    if not str then return key end
    if not vars then return str end

    for k, v in pairs(vars) do
        str = string.gsub(str, '%%{' .. k .. '}', tostring(v))
    end
    return str
end

local function notify(target, key, vars, type)
    exports.qbx_core:Notify(target, formatLocale(key, vars), type)
end

local function getTargetLicenses(targetId)
    return GetPlayerIdentifierByType(targetId, 'license'),
           GetPlayerIdentifierByType(targetId, 'license2')
end

lib.addCommand('slots', {
    help = locale('commands.slots.help'),
    restricted = 'group.admin',
    params = {
        { name = 'action', help = locale('commands.slots.params.action'), type = 'string' },
        { name = 'id', help = locale('commands.slots.params.id'), type = 'number' },
        { name = 'amount', help = locale('commands.slots.params.amount'), type = 'number', optional = true },
    },
}, function(source, args)
    local action = args.action and args.action:lower()
    local targetId = args.id
    local amount = args.amount

    if not action or not VALID_ACTIONS[action] then
        notify(source, 'commands.slots.invalid_action', nil, 'error')
        return
    end

    if action ~= 'get' and (not amount or amount < 1) then
        notify(source, 'commands.slots.invalid_amount', nil, 'error')
        return
    end

    local targetPlayer = exports.qbx_core:GetPlayer(targetId)
    if not targetPlayer then
        notify(source, 'commands.player_not_found', nil, 'error')
        return
    end

    local license, license2 = getTargetLicenses(targetId)
    local targetName = GetPlayerName(targetId)

    if action == 'get' then
        local slots = exports.mri_Qmultichar:getPlayerSlots(license, license2)
        notify(source, 'commands.slots.get_result', { name = targetName, slots = slots }, 'info')
        return
    end

    local newValue
    if action == 'set' then
        if amount > Config.CharacterSlots.maxSlots then
            notify(source, 'commands.slots.invalid_range', { max = Config.CharacterSlots.maxSlots }, 'error')
            return
        end
        newValue = amount
    elseif action == 'add' then
        newValue = exports.mri_Qmultichar:getPlayerSlots(license, license2) + amount
    elseif action == 'remove' then
        newValue = math.max(1, exports.mri_Qmultichar:getPlayerSlots(license, license2) - amount)
    end

    local finalSlots = exports.mri_Qmultichar:setPlayerSlots(license, license2, newValue)

    notify(source, 'commands.slots.success_admin_' .. action, {
        name = targetName, slots = finalSlots, amount = amount,
    }, 'success')
    notify(targetId, 'commands.slots.success_target_' .. action, {
        slots = finalSlots, amount = amount,
    }, 'info')
end)

lib.addCommand('setslots', {
    help = locale('commands.slots.help'),
    restricted = 'group.admin',
    params = {
        { name = 'id', help = locale('commands.slots.params.id'), type = 'number' },
        { name = 'amount', help = locale('commands.slots.params.amount'), type = 'number' },
    },
}, function(source, args)
    local targetId = args.id
    local amount = args.amount

    if not amount or amount < 1 then
        notify(source, 'commands.slots.invalid_amount', nil, 'error')
        return
    end

    local targetPlayer = exports.qbx_core:GetPlayer(targetId)
    if not targetPlayer then
        notify(source, 'commands.player_not_found', nil, 'error')
        return
    end

    local license, license2 = getTargetLicenses(targetId)
    local targetName = GetPlayerName(targetId)

    if amount > Config.CharacterSlots.maxSlots then
        notify(source, 'commands.slots.invalid_range', { max = Config.CharacterSlots.maxSlots }, 'error')
        return
    end

    local finalSlots = exports.mri_Qmultichar:setPlayerSlots(license, license2, amount)

    notify(source, 'commands.slots.success_admin_set', {
        name = targetName, slots = finalSlots, amount = amount,
    }, 'success')
    notify(targetId, 'commands.slots.success_target_set', {
        slots = finalSlots, amount = amount,
    }, 'info')
end)

lib.addCommand('getslots', {
    help = locale('commands.slots.help'),
    restricted = 'group.admin',
    params = {
        { name = 'id', help = locale('commands.slots.params.id'), type = 'number' },
    },
}, function(source, args)
    local targetId = args.id

    local targetPlayer = exports.qbx_core:GetPlayer(targetId)
    if not targetPlayer then
        notify(source, 'commands.player_not_found', nil, 'error')
        return
    end

    local license, license2 = getTargetLicenses(targetId)
    local targetName = GetPlayerName(targetId)

    local slots = exports.mri_Qmultichar:getPlayerSlots(license, license2)
    notify(source, 'commands.slots.get_result', { name = targetName, slots = slots }, 'info')
end)

lib.addCommand('myslots', {
    help = locale('commands.myslots.help'),
}, function(source)
    local license, license2 = getTargetLicenses(source)
    local slots = exports.mri_Qmultichar:getPlayerSlots(license, license2)
    notify(source, 'commands.myslots.result', { slots = slots }, 'info')
end)