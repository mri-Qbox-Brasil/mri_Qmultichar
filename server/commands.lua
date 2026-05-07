lib.addCommand('setslots', {
    help = locale('commands.setslots.help'),
    restricted = 'group.admin',
    params = {
        { name = 'id', help = locale('commands.setslots.params.id'), type = 'number' },
        { name = 'slots', help = locale('commands.setslots.params.slots') .. string.format(' (1-%d)', Config.CharacterSlots.maxSlots), type = 'number' },
    }
}, function(source, args)
    local targetId = args.id
    local slots = args.slots

    if not targetId or not slots then
        exports.qbx_core:Notify(source, locale('commands.setslots.usage'), 'error')
        return
    end

    if slots < 1 or slots > Config.CharacterSlots.maxSlots then
        exports.qbx_core:Notify(source, locale('commands.setslots.invalid_range', { max = Config.CharacterSlots.maxSlots }), 'error')
        return
    end

    local targetPlayer = exports.qbx_core:GetPlayer(targetId)
    if not targetPlayer then
        exports.qbx_core:Notify(source, locale('commands.player_not_found'), 'error')
        return
    end

    local license = GetPlayerIdentifierByType(targetId, 'license')
    local license2 = GetPlayerIdentifierByType(targetId, 'license2')

    local newSlots = exports.mri_Qmultichar:setPlayerSlots(license, license2, slots)

    exports.qbx_core:Notify(source, locale('commands.setslots.success_source', { name = GetPlayerName(targetId), slots = newSlots }), 'success')
    exports.qbx_core:Notify(targetId, locale('commands.setslots.success_target', { slots = newSlots }), 'info')
end)

lib.addCommand('getslots', {
    help = locale('commands.getslots.help'),
    restricted = 'group.admin',
    params = {
        { name = 'id', help = locale('commands.setslots.params.id'), type = 'number' },
    }
}, function(source, args)
    local targetId = args.id

    if not targetId then
        exports.qbx_core:Notify(source, locale('commands.getslots.usage'), 'error')
        return
    end

    local targetPlayer = exports.qbx_core:GetPlayer(targetId)
    if not targetPlayer then
        exports.qbx_core:Notify(source, locale('commands.player_not_found'), 'error')
        return
    end

    local license = GetPlayerIdentifierByType(targetId, 'license')
    local license2 = GetPlayerIdentifierByType(targetId, 'license2')

    local slots = exports.mri_Qmultichar:getPlayerSlots(license, license2)

    exports.qbx_core:Notify(source, locale('commands.getslots.result', { name = GetPlayerName(targetId), slots = slots }), 'info')
end)

lib.addCommand('addslots', {
    help = locale('commands.addslots.help'),
    restricted = 'group.admin',
    params = {
        { name = 'id', help = locale('commands.setslots.params.id'), type = 'number' },
        { name = 'slots', help = locale('commands.addslots.params.slots'), type = 'number' },
    }
}, function(source, args)
    local targetId = args.id
    local slotsToAdd = args.slots

    if not targetId or not slotsToAdd then
        exports.qbx_core:Notify(source, locale('commands.addslots.usage'), 'error')
        return
    end

    if slotsToAdd < 1 then
        exports.qbx_core:Notify(source, locale('commands.addslots.invalid_amount'), 'error')
        return
    end

    local targetPlayer = exports.qbx_core:GetPlayer(targetId)
    if not targetPlayer then
        exports.qbx_core:Notify(source, locale('commands.player_not_found'), 'error')
        return
    end

    local license = GetPlayerIdentifierByType(targetId, 'license')
    local license2 = GetPlayerIdentifierByType(targetId, 'license2')

    local currentSlots = exports.mri_Qmultichar:getPlayerSlots(license, license2)
    local newSlots = currentSlots + slotsToAdd

    local finalSlots = exports.mri_Qmultichar:setPlayerSlots(license, license2, newSlots)

    exports.qbx_core:Notify(source, locale('commands.addslots.success_source', { amount = slotsToAdd, name = GetPlayerName(targetId), total = finalSlots }), 'success')
    exports.qbx_core:Notify(targetId, locale('commands.addslots.success_target', { amount = slotsToAdd, total = finalSlots }), 'success')
end)

lib.addCommand('removeslots', {
    help = locale('commands.removeslots.help'),
    restricted = 'group.admin',
    params = {
        { name = 'id', help = locale('commands.setslots.params.id'), type = 'number' },
        { name = 'slots', help = locale('commands.removeslots.params.slots'), type = 'number' },
    }
}, function(source, args)
    local targetId = args.id
    local slotsToRemove = args.slots

    if not targetId or not slotsToRemove then
        exports.qbx_core:Notify(source, locale('commands.removeslots.usage'), 'error')
        return
    end

    if slotsToRemove < 1 then
        exports.qbx_core:Notify(source, locale('commands.removeslots.invalid_amount'), 'error')
        return
    end

    local targetPlayer = exports.qbx_core:GetPlayer(targetId)
    if not targetPlayer then
        exports.qbx_core:Notify(source, locale('commands.player_not_found'), 'error')
        return
    end

    local license = GetPlayerIdentifierByType(targetId, 'license')
    local license2 = GetPlayerIdentifierByType(targetId, 'license2')

    local currentSlots = exports.mri_Qmultichar:getPlayerSlots(license, license2)
    local newSlots = math.max(1, currentSlots - slotsToRemove)

    local finalSlots = exports.mri_Qmultichar:setPlayerSlots(license, license2, newSlots)

    exports.qbx_core:Notify(source, locale('commands.removeslots.success_source', { amount = slotsToRemove, name = GetPlayerName(targetId), total = finalSlots }), 'success')
    exports.qbx_core:Notify(targetId, locale('commands.removeslots.success_target', { amount = slotsToRemove, total = finalSlots }), 'info')
end)

lib.addCommand('myslots', {
    help = locale('commands.myslots.help'),
}, function(source, args)
    local license = GetPlayerIdentifierByType(source, 'license')
    local license2 = GetPlayerIdentifierByType(source, 'license2')

    local slots = exports.mri_Qmultichar:getPlayerSlots(license, license2)

    exports.qbx_core:Notify(source, locale('commands.myslots.result', { slots = slots }), 'info')
end)

lib.addCommand('logout', {
    help = 'Desconecta do personagem atual apenas se voce tiver 2 ou mais personagens.',
}, function(source)
    local license = GetPlayerIdentifierByType(source, 'license')
    local license2 = GetPlayerIdentifierByType(source, 'license2')
    local characterCount = tonumber(MySQL.scalar.await(
        'SELECT COUNT(DISTINCT citizenid) FROM players WHERE license = ? OR license = ?',
        { license, license2 }
    )) or 0

    if characterCount < 2 then
        exports.qbx_core:Notify(source, string.format('Você precisa ter pelo menos 2 personagens para usar logout. Atualmente: %d.', characterCount), 'error')
        return
    end

    exports.qbx_core:Logout(source)
end)
