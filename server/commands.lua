local VALID_ACTIONS = { get = true, set = true, add = true, remove = true }

local function notify(target, key, vars, type)
    exports.qbx_core:Notify(target, locale(key, vars), type)
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