--[[
    vAvA_inventory - Server Main
    Gestion principale de l'inventaire côté serveur
]]

local playerInventories = {}
local playerHotbars = {}
local itemCallbacks = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- INITIALISATION
-- ═══════════════════════════════════════════════════════════════════════════

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    -- Créer la table inventaire si elle n'existe pas
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS `player_inventories` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `owner` VARCHAR(60) NOT NULL,
            `items` LONGTEXT NULL,
            `hotbar` LONGTEXT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            UNIQUE KEY `owner` (`owner`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]], {})
    
    -- Table pour les items au sol
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS `dropped_items` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `item` VARCHAR(100) NOT NULL,
            `amount` INT NOT NULL DEFAULT 1,
            `metadata` LONGTEXT NULL,
            `coords` VARCHAR(255) NOT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]], {})
    
    print('^2[vAvA_inventory] ^7Système d\'inventaire démarré')
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- CALLBACKS
-- ═══════════════════════════════════════════════════════════════════════════

-- Event simple pour demander l'inventaire
RegisterNetEvent('vAvA_inventory:requestInventory')
AddEventHandler('vAvA_inventory:requestInventory', function()
    local source = source
    local identifier = GetPlayerIdentifier(source)
    
    print('[vAvA_inventory] Demande inventaire de ' .. (identifier or 'unknown'))
    
    if not identifier then
        print('[vAvA_inventory] ^1Erreur: pas d\'identifier pour source ' .. source)
        TriggerClientEvent('vAvA_inventory:receiveInventory', source, {}, {})
        return
    end
    
    LoadPlayerInventory(source, identifier, function(inventory, hotbar)
        print('[vAvA_inventory] Envoi inventaire à ' .. source .. ' (' .. #inventory .. ' items)')
        TriggerClientEvent('vAvA_inventory:receiveInventory', source, inventory, hotbar)
    end)
end)

-- Ancien système de callback (garde pour compatibilité)
RegisterNetEvent('vAvA_inventory:triggerCallback')
AddEventHandler('vAvA_inventory:triggerCallback', function(name, requestId, ...)
    local source = source
    
    if name == 'vAvA_inventory:getInventory' then
        local identifier = GetPlayerIdentifier(source)
        LoadPlayerInventory(source, identifier, function(inventory, hotbar)
            TriggerClientEvent('vAvA_inventory:callback:' .. requestId, source, inventory, hotbar)
        end)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- CHARGEMENT / SAUVEGARDE INVENTAIRE
-- ═══════════════════════════════════════════════════════════════════════════

function LoadPlayerInventory(source, identifier, callback)
    if playerInventories[identifier] then
        callback(playerInventories[identifier], playerHotbars[identifier])
        return
    end
    
    exports.oxmysql:execute('SELECT items, hotbar FROM player_inventories WHERE owner = ?', {identifier}, function(result)
        if result and result[1] then
            playerInventories[identifier] = json.decode(result[1].items) or {}
            playerHotbars[identifier] = json.decode(result[1].hotbar) or {}
        else
            playerInventories[identifier] = {}
            playerHotbars[identifier] = {}
            -- Créer l'entrée en base
            exports.oxmysql:insert('INSERT INTO player_inventories (owner, items, hotbar) VALUES (?, ?, ?)', {
                identifier, '[]', '{}'
            })
        end
        
        callback(playerInventories[identifier], playerHotbars[identifier])
    end)
end

function SavePlayerInventory(identifier)
    if not playerInventories[identifier] then return end
    
    exports.oxmysql:execute('UPDATE player_inventories SET items = ?, hotbar = ? WHERE owner = ?', {
        json.encode(playerInventories[identifier]),
        json.encode(playerHotbars[identifier] or {}),
        identifier
    })
end

function GetPlayerIdentifier(source)
    local identifiers = GetPlayerIdentifiers(source)
    for _, id in pairs(identifiers) do
        if string.find(id, 'license:') then
            return id
        end
    end
    return nil
end

-- ═══════════════════════════════════════════════════════════════════════════
-- GESTION ITEMS
-- ═══════════════════════════════════════════════════════════════════════════

function AddItem(source, itemName, amount, metadata)
    local identifier = GetPlayerIdentifier(source)
    if not identifier or not playerInventories[identifier] then return false end
    
    local inventory = playerInventories[identifier]
    local itemData = GetItemData(itemName)
    
    if not itemData then
        print('^1[vAvA_inventory] ^7Item inconnu: ' .. itemName)
        return false
    end
    
    amount = amount or 1
    
    -- Vérifier le poids
    local totalWeight = Inventory.CalculateWeight(inventory)
    local addWeight = (itemData.weight or 0.1) * amount
    
    if totalWeight + addWeight > InventoryConfig.MaxWeight then
        TriggerClientEvent('vAvA:notify', source, 'Inventaire trop lourd !', 'error')
        return false
    end
    
    -- Chercher un slot existant pour stacker
    if itemData.stackable ~= false then
        for i, item in ipairs(inventory) do
            if item.name == itemName and (item.amount + amount) <= (itemData.maxStack or 999) then
                -- Vérifier les metadata
                if CompareMetadata(item.metadata, metadata) then
                    inventory[i].amount = item.amount + amount
                    SavePlayerInventory(identifier)
                    TriggerClientEvent('vAvA_inventory:updateInventory', source, inventory)
                    return true
                end
            end
        end
    end
    
    -- Trouver un slot libre
    local freeSlot = GetFreeSlot(inventory)
    if not freeSlot then
        TriggerClientEvent('vAvA:notify', source, 'Inventaire plein !', 'error')
        return false
    end
    
    -- Ajouter le nouvel item
    table.insert(inventory, {
        slot = freeSlot,
        name = itemName,
        label = itemData.label or itemName,
        amount = amount,
        weight = itemData.weight or 0.1,
        metadata = metadata or {},
        stackable = itemData.stackable ~= false
    })
    
    SavePlayerInventory(identifier)
    TriggerClientEvent('vAvA_inventory:updateInventory', source, inventory)
    
    return true
end

function RemoveItem(source, itemName, amount, metadata)
    local identifier = GetPlayerIdentifier(source)
    if not identifier or not playerInventories[identifier] then return false end
    
    local inventory = playerInventories[identifier]
    amount = amount or 1
    
    for i, item in ipairs(inventory) do
        if item.name == itemName then
            if metadata and not CompareMetadata(item.metadata, metadata) then
                goto continue
            end
            
            if item.amount >= amount then
                inventory[i].amount = item.amount - amount
                
                if inventory[i].amount <= 0 then
                    table.remove(inventory, i)
                end
                
                SavePlayerInventory(identifier)
                TriggerClientEvent('vAvA_inventory:updateInventory', source, inventory)
                return true
            end
        end
        ::continue::
    end
    
    return false
end

function HasItem(source, itemName, amount)
    local identifier = GetPlayerIdentifier(source)
    if not identifier or not playerInventories[identifier] then return false end
    
    amount = amount or 1
    local count = GetItemCount(source, itemName)
    return count >= amount
end

function GetItemCount(source, itemName)
    local identifier = GetPlayerIdentifier(source)
    if not identifier or not playerInventories[identifier] then return 0 end
    
    local count = 0
    for _, item in ipairs(playerInventories[identifier]) do
        if item.name == itemName then
            count = count + item.amount
        end
    end
    
    return count
end

function GetFreeSlot(inventory)
    local usedSlots = {}
    for _, item in ipairs(inventory) do
        usedSlots[item.slot] = true
    end
    
    for i = 1, InventoryConfig.MaxSlots do
        if not usedSlots[i] then
            return i
        end
    end
    
    return nil
end

function GetItemData(itemName)
    -- Vérifier si c'est une arme
    local weaponData = InventoryConfig.Weapons.list[string.lower(itemName)]
    if weaponData then
        return {
            name = itemName,
            label = weaponData.label,
            weight = weaponData.weight,
            stackable = false
        }
    end
    
    -- Vérifier si c'est des munitions
    local ammoData = InventoryConfig.AmmoItems[string.lower(itemName)]
    if ammoData then
        return {
            name = itemName,
            label = ammoData.label,
            weight = ammoData.weight,
            stackable = true,
            maxStack = 500
        }
    end
    
    -- Item générique
    return {
        name = itemName,
        label = itemName,
        weight = 0.1,
        stackable = true
    }
end

function CompareMetadata(meta1, meta2)
    if not meta1 and not meta2 then return true end
    if not meta1 or not meta2 then return false end
    return json.encode(meta1) == json.encode(meta2)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EVENTS
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_inventory:useItem')
AddEventHandler('vAvA_inventory:useItem', function(slot, itemName)
    local source = source
    local identifier = GetPlayerIdentifier(source)
    
    if not identifier or not playerInventories[identifier] then return end
    
    -- Trouver l'item
    local item = nil
    for _, invItem in ipairs(playerInventories[identifier]) do
        if invItem.slot == slot and invItem.name == itemName then
            item = invItem
            break
        end
    end
    
    if not item then return end
    
    -- Trigger callback si défini
    if itemCallbacks[itemName] then
        itemCallbacks[itemName](source, item)
    else
        -- Comportement par défaut
        TriggerClientEvent('vAvA:notify', source, 'Item utilisé: ' .. item.label, 'info')
    end
end)

RegisterNetEvent('vAvA_inventory:dropItem')
AddEventHandler('vAvA_inventory:dropItem', function(slot, amount)
    local source = source
    local identifier = GetPlayerIdentifier(source)
    
    if not identifier or not playerInventories[identifier] then return end
    
    local inventory = playerInventories[identifier]
    
    for i, item in ipairs(inventory) do
        if item.slot == slot then
            local dropAmount = math.min(amount, item.amount)
            
            -- Retirer de l'inventaire
            inventory[i].amount = item.amount - dropAmount
            if inventory[i].amount <= 0 then
                table.remove(inventory, i)
            end
            
            -- Créer l'objet au sol
            local ped = GetPlayerPed(source)
            local coords = GetEntityCoords(ped)
            
            CreateDroppedItem(item.name, dropAmount, item.metadata, coords)
            
            SavePlayerInventory(identifier)
            TriggerClientEvent('vAvA_inventory:updateInventory', source, inventory)
            TriggerClientEvent('vAvA:notify', source, 'Item jeté: ' .. item.label .. ' x' .. dropAmount, 'info')
            
            break
        end
    end
end)

RegisterNetEvent('vAvA_inventory:giveItem')
AddEventHandler('vAvA_inventory:giveItem', function(targetId, slot, amount)
    local source = source
    local identifier = GetPlayerIdentifier(source)
    
    if not identifier or not playerInventories[identifier] then return end
    
    local targetIdentifier = GetPlayerIdentifier(targetId)
    if not targetIdentifier then
        TriggerClientEvent('vAvA:notify', source, 'Joueur introuvable', 'error')
        return
    end
    
    local inventory = playerInventories[identifier]
    
    for i, item in ipairs(inventory) do
        if item.slot == slot then
            local giveAmount = math.min(amount, item.amount)
            
            -- Tenter d'ajouter au joueur cible
            if AddItem(targetId, item.name, giveAmount, item.metadata) then
                -- Retirer de notre inventaire
                inventory[i].amount = item.amount - giveAmount
                if inventory[i].amount <= 0 then
                    table.remove(inventory, i)
                end
                
                SavePlayerInventory(identifier)
                TriggerClientEvent('vAvA_inventory:updateInventory', source, inventory)
                
                TriggerClientEvent('vAvA:notify', source, 'Vous avez donné ' .. giveAmount .. 'x ' .. item.label, 'success')
                TriggerClientEvent('vAvA:notify', targetId, 'Vous avez reçu ' .. giveAmount .. 'x ' .. item.label, 'success')
            else
                TriggerClientEvent('vAvA:notify', source, 'Le joueur ne peut pas recevoir cet item', 'error')
            end
            
            break
        end
    end
end)

RegisterNetEvent('vAvA_inventory:moveItem')
AddEventHandler('vAvA_inventory:moveItem', function(fromSlot, toSlot, amount)
    local source = source
    local identifier = GetPlayerIdentifier(source)
    
    if not identifier or not playerInventories[identifier] then return end
    
    local inventory = playerInventories[identifier]
    local fromItem = nil
    local toItem = nil
    local fromIndex = nil
    local toIndex = nil
    
    for i, item in ipairs(inventory) do
        if item.slot == fromSlot then
            fromItem = item
            fromIndex = i
        elseif item.slot == toSlot then
            toItem = item
            toIndex = i
        end
    end
    
    if not fromItem then return end
    
    amount = math.min(amount, fromItem.amount)
    
    if toItem then
        -- Stack si même item
        if fromItem.name == toItem.name and fromItem.stackable then
            local maxStack = GetItemData(fromItem.name).maxStack or 999
            local canAdd = maxStack - toItem.amount
            local addAmount = math.min(amount, canAdd)
            
            inventory[toIndex].amount = toItem.amount + addAmount
            inventory[fromIndex].amount = fromItem.amount - addAmount
            
            if inventory[fromIndex].amount <= 0 then
                table.remove(inventory, fromIndex)
            end
        else
            -- Swap
            inventory[fromIndex].slot = toSlot
            inventory[toIndex].slot = fromSlot
        end
    else
        -- Déplacer vers slot vide
        if amount >= fromItem.amount then
            inventory[fromIndex].slot = toSlot
        else
            -- Split
            inventory[fromIndex].amount = fromItem.amount - amount
            table.insert(inventory, {
                slot = toSlot,
                name = fromItem.name,
                label = fromItem.label,
                amount = amount,
                weight = fromItem.weight,
                metadata = fromItem.metadata,
                stackable = fromItem.stackable
            })
        end
    end
    
    SavePlayerInventory(identifier)
    TriggerClientEvent('vAvA_inventory:updateInventory', source, inventory)
end)

RegisterNetEvent('vAvA_inventory:setHotbar')
AddEventHandler('vAvA_inventory:setHotbar', function(slot, item)
    local source = source
    local identifier = GetPlayerIdentifier(source)
    
    if not identifier then return end
    
    if not playerHotbars[identifier] then
        playerHotbars[identifier] = {}
    end
    
    playerHotbars[identifier][slot] = item
    SavePlayerInventory(identifier)
end)

RegisterNetEvent('vAvA_inventory:splitStack')
AddEventHandler('vAvA_inventory:splitStack', function(slot, amount)
    local source = source
    local identifier = GetPlayerIdentifier(source)
    
    if not identifier or not playerInventories[identifier] then return end
    
    local inventory = playerInventories[identifier]
    
    for i, item in ipairs(inventory) do
        if item.slot == slot and item.amount > amount then
            local freeSlot = GetFreeSlot(inventory)
            if not freeSlot then
                TriggerClientEvent('vAvA:notify', source, 'Pas de slot disponible', 'error')
                return
            end
            
            inventory[i].amount = item.amount - amount
            table.insert(inventory, {
                slot = freeSlot,
                name = item.name,
                label = item.label,
                amount = amount,
                weight = item.weight,
                metadata = item.metadata,
                stackable = item.stackable
            })
            
            SavePlayerInventory(identifier)
            TriggerClientEvent('vAvA_inventory:updateInventory', source, inventory)
            break
        end
    end
end)

RegisterNetEvent('vAvA_inventory:syncAmmo')
AddEventHandler('vAvA_inventory:syncAmmo', function(ammoType, count)
    -- Sync munitions - à implémenter selon les besoins
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- DROPPED ITEMS
-- ═══════════════════════════════════════════════════════════════════════════

local droppedItems = {}

function CreateDroppedItem(itemName, amount, metadata, coords)
    local id = #droppedItems + 1
    
    droppedItems[id] = {
        id = id,
        item = itemName,
        amount = amount,
        metadata = metadata,
        coords = coords
    }
    
    -- Notifier tous les clients
    TriggerClientEvent('vAvA_inventory:createDroppedItem', -1, id, itemName, amount, coords)
    
    -- Auto-suppression après un délai
    if InventoryConfig.Drops.despawnTime > 0 then
        SetTimeout(InventoryConfig.Drops.despawnTime, function()
            if droppedItems[id] then
                droppedItems[id] = nil
                TriggerClientEvent('vAvA_inventory:removeDroppedItem', -1, id)
            end
        end)
    end
    
    return id
end

RegisterNetEvent('vAvA_inventory:pickupItem')
AddEventHandler('vAvA_inventory:pickupItem', function(dropId)
    local source = source
    local drop = droppedItems[dropId]
    
    if not drop then return end
    
    if AddItem(source, drop.item, drop.amount, drop.metadata) then
        droppedItems[dropId] = nil
        TriggerClientEvent('vAvA_inventory:removeDroppedItem', -1, dropId)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- NETTOYAGE
-- ═══════════════════════════════════════════════════════════════════════════

AddEventHandler('playerDropped', function()
    local source = source
    local identifier = GetPlayerIdentifier(source)
    
    if identifier then
        SavePlayerInventory(identifier)
        playerInventories[identifier] = nil
        playerHotbars[identifier] = nil
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('AddItem', AddItem)
exports('RemoveItem', RemoveItem)
exports('HasItem', HasItem)
exports('GetItemCount', GetItemCount)

exports('RegisterItemCallback', function(itemName, callback)
    itemCallbacks[itemName] = callback
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMANDES ADMIN
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('giveitem', function(source, args, rawCommand)
    if source == 0 or IsPlayerAceAllowed(source, 'command.giveitem') then
        local targetId = tonumber(args[1])
        local itemName = args[2]
        local amount = tonumber(args[3]) or 1
        
        if targetId and itemName then
            if AddItem(targetId, itemName, amount) then
                print('^2[vAvA_inventory] ^7Donné ' .. amount .. 'x ' .. itemName .. ' au joueur ' .. targetId)
            else
                print('^1[vAvA_inventory] ^7Impossible de donner l\'item')
            end
        else
            print('^1[vAvA_inventory] ^7Usage: /giveitem [id] [item] [amount]')
        end
    end
end, true)

RegisterCommand('clearinventory', function(source, args, rawCommand)
    if source == 0 or IsPlayerAceAllowed(source, 'command.clearinventory') then
        local targetId = tonumber(args[1]) or source
        local identifier = GetPlayerIdentifier(targetId)
        
        if identifier then
            playerInventories[identifier] = {}
            playerHotbars[identifier] = {}
            SavePlayerInventory(identifier)
            TriggerClientEvent('vAvA_inventory:updateInventory', targetId, {})
            print('^2[vAvA_inventory] ^7Inventaire vidé pour le joueur ' .. targetId)
        end
    end
end, true)
