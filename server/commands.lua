-- Comando para definir slots de um jogador
lib.addCommand('setslots', {
    help = 'Define o número de slots de personagem de um jogador',
    restricted = 'group.admin',
    params = {
        { name = 'id', help = 'ID do jogador', type = 'number' },
        { name = 'slots', help = 'Número de slots (1-10)', type = 'number' },
    }
}, function(source, args)
    local targetId = args.id
    local slots = args.slots
    
    if not targetId or not slots then
        exports.qbx_core:Notify(source, 'Uso: /setslots [id] [slots]', 'error')
        return
    end
    
    if slots < 1 or slots > Config.CharacterSlots.maxSlots then
        exports.qbx_core:Notify(source, string.format('Número de slots deve estar entre 1 e %d', Config.CharacterSlots.maxSlots), 'error')
        return
    end
    
    local targetPlayer = exports.qbx_core:GetPlayer(targetId)
    if not targetPlayer then
        exports.qbx_core:Notify(source, 'Jogador não encontrado', 'error')
        return
    end
    
    local license = GetPlayerIdentifierByType(targetId, 'license')
    local license2 = GetPlayerIdentifierByType(targetId, 'license2')
    
    local newSlots = exports.mri_Qmultichar:setPlayerSlots(license, license2, slots)
    
    exports.qbx_core:Notify(source, string.format('Slots do jogador %s definidos para %d', GetPlayerName(targetId), newSlots), 'success')
    exports.qbx_core:Notify(targetId, string.format('Seus slots de personagem foram alterados para %d', newSlots), 'info')
end)

-- Comando para ver slots de um jogador
lib.addCommand('getslots', {
    help = 'Ver o número de slots de personagem de um jogador',
    restricted = 'group.admin',
    params = {
        { name = 'id', help = 'ID do jogador', type = 'number' },
    }
}, function(source, args)
    local targetId = args.id
    
    if not targetId then
        exports.qbx_core:Notify(source, 'Uso: /getslots [id]', 'error')
        return
    end
    
    local targetPlayer = exports.qbx_core:GetPlayer(targetId)
    if not targetPlayer then
        exports.qbx_core:Notify(source, 'Jogador não encontrado', 'error')
        return
    end
    
    local license = GetPlayerIdentifierByType(targetId, 'license')
    local license2 = GetPlayerIdentifierByType(targetId, 'license2')
    
    local slots = exports.mri_Qmultichar:getPlayerSlots(license, license2)
    
    exports.qbx_core:Notify(source, string.format('Jogador %s tem %d slots de personagem', GetPlayerName(targetId), slots), 'info')
end)

-- Comando para adicionar slots a um jogador (adiciona ao valor atual)
lib.addCommand('addslots', {
    help = 'Adiciona slots de personagem a um jogador',
    restricted = 'group.admin',
    params = {
        { name = 'id', help = 'ID do jogador', type = 'number' },
        { name = 'slots', help = 'Número de slots para adicionar', type = 'number' },
    }
}, function(source, args)
    local targetId = args.id
    local slotsToAdd = args.slots
    
    if not targetId or not slotsToAdd then
        exports.qbx_core:Notify(source, 'Uso: /addslots [id] [slots]', 'error')
        return
    end
    
    if slotsToAdd < 1 then
        exports.qbx_core:Notify(source, 'Número de slots deve ser maior que 0', 'error')
        return
    end
    
    local targetPlayer = exports.qbx_core:GetPlayer(targetId)
    if not targetPlayer then
        exports.qbx_core:Notify(source, 'Jogador não encontrado', 'error')
        return
    end
    
    local license = GetPlayerIdentifierByType(targetId, 'license')
    local license2 = GetPlayerIdentifierByType(targetId, 'license2')
    
    -- Obter slots atuais
    local currentSlots = exports.mri_Qmultichar:getPlayerSlots(license, license2)
    local newSlots = currentSlots + slotsToAdd
    
    -- Definir novos slots (a função já valida o máximo)
    local finalSlots = exports.mri_Qmultichar:setPlayerSlots(license, license2, newSlots)
    
    exports.qbx_core:Notify(source, string.format('Adicionados %d slots ao jogador %s. Total: %d', slotsToAdd, GetPlayerName(targetId), finalSlots), 'success')
    exports.qbx_core:Notify(targetId, string.format('Você recebeu %d slots adicionais! Total: %d', slotsToAdd, finalSlots), 'success')
end)

-- Comando para remover slots de um jogador
lib.addCommand('removeslots', {
    help = 'Remove slots de personagem de um jogador',
    restricted = 'group.admin',
    params = {
        { name = 'id', help = 'ID do jogador', type = 'number' },
        { name = 'slots', help = 'Número de slots para remover', type = 'number' },
    }
}, function(source, args)
    local targetId = args.id
    local slotsToRemove = args.slots
    
    if not targetId or not slotsToRemove then
        exports.qbx_core:Notify(source, 'Uso: /removeslots [id] [slots]', 'error')
        return
    end
    
    if slotsToRemove < 1 then
        exports.qbx_core:Notify(source, 'Número de slots deve ser maior que 0', 'error')
        return
    end
    
    local targetPlayer = exports.qbx_core:GetPlayer(targetId)
    if not targetPlayer then
        exports.qbx_core:Notify(source, 'Jogador não encontrado', 'error')
        return
    end
    
    local license = GetPlayerIdentifierByType(targetId, 'license')
    local license2 = GetPlayerIdentifierByType(targetId, 'license2')
    
    -- Obter slots atuais
    local currentSlots = exports.mri_Qmultichar:getPlayerSlots(license, license2)
    local newSlots = math.max(1, currentSlots - slotsToRemove) -- Mínimo de 1 slot
    
    -- Definir novos slots
    local finalSlots = exports.mri_Qmultichar:setPlayerSlots(license, license2, newSlots)
    
    exports.qbx_core:Notify(source, string.format('Removidos %d slots do jogador %s. Total: %d', slotsToRemove, GetPlayerName(targetId), finalSlots), 'success')
    exports.qbx_core:Notify(targetId, string.format('Você perdeu %d slots. Total: %d', slotsToRemove, finalSlots), 'info')
end)

-- Comando para ver seus próprios slots
lib.addCommand('myslots', {
    help = 'Ver seu número de slots de personagem',
}, function(source, args)
    local license = GetPlayerIdentifierByType(source, 'license')
    local license2 = GetPlayerIdentifierByType(source, 'license2')
    
    local slots = exports.mri_Qmultichar:getPlayerSlots(license, license2)
    
    exports.qbx_core:Notify(source, string.format('Você tem %d slots de personagem disponíveis', slots), 'info')
end)

