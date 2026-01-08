--[[
    vAvA_inventory - Server Main
    Version 100% ASYNC - zero blocage
]]

local playerInventories = {}
local playerHotbars = {}
local registeredItems = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- INITIALISATION
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    Wait(2000) -- Attendre que oxmysql soit pret
    
    -- Creer les tables
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS `inventory_items` (
            `name` VARCHAR(50) PRIMARY KEY,
            `label` VARCHAR(100) NOT NULL,
            `weight` FLOAT DEFAULT 0.1,
            `max_stack` INT DEFAULT 99,
            `type` VARCHAR(20) DEFAULT 'item',
            `weapon_hash` VARCHAR(50) DEFAULT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS `player_inventories` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `owner` VARCHAR(60) NOT NULL,
            `slot` INT NOT NULL,
            `item_name` VARCHAR(50) NOT NULL,
            `amount` INT DEFAULT 1,
            `metadata` TEXT DEFAULT NULL,
            UNIQUE KEY `owner_slot` (`owner`, `slot`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS `player_hotbar` (
            `owner` VARCHAR(60) NOT NULL,
            `slot` INT NOT NULL,
            `inventory_slot` INT NOT NULL,
            PRIMARY KEY (`owner`, `slot`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    
    Wait(500)
    
    -- Charger items
    exports.oxmysql:execute('SELECT * FROM inventory_items', {}, function(results)
        if results then
            for _, item in ipairs(results) do
                registeredItems[item.name] = item
            end
            print('^2[vAvA_inventory]^7 ' .. #results .. ' items charges')
        end
    end)
    
    print('^2[vAvA_inventory]^7 Systeme initialise')
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- HELPER
-- ═══════════════════════════════════════════════════════════════════════════

function GetPlayerIdentifier(source)
    for _, id in pairs(GetPlayerIdentifiers(source) or {}) do
        if string.find(id, 'license:') then return id end
    end
    return nil
end

-- ═══════════════════════════════════════════════════════════════════════════
-- INVENTAIRE - 100% ASYNC
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_inventory:requestInventory')
AddEventHandler('vAvA_inventory:requestInventory', function()
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end
    
    -- Une seule requete, pas de callback imbrique
    exports.oxmysql:execute([[
        SELECT pi.slot, pi.item_name, pi.amount, pi.metadata, 
               COALESCE(ii.label, pi.item_name) as label,
               COALESCE(ii.weight, 0.1) as weight,
               COALESCE(ii.type, 'item') as type,
               ii.max_stack, ii.weapon_hash
        FROM player_inventories pi
        LEFT JOIN inventory_items ii ON pi.item_name = ii.name
        WHERE pi.owner = ?
    ]], {identifier}, function(items)
        
        local inventory = {}
        local weight = 0
        
        for _, item in ipairs(items or {}) do
            inventory[#inventory+1] = {
                slot = item.slot,
                name = item.item_name,
                label = item.label,
                amount = item.amount,
                weight = item.weight,
                type = item.type,
                maxStack = item.max_stack or 99
            }
            weight = weight + (item.weight * item.amount)
        end
        
        -- Hotbar en parallele
        exports.oxmysql:execute('SELECT slot, inventory_slot FROM player_hotbar WHERE owner = ?', {identifier}, function(hb)
            local hotbar = {}
            for _, h in ipairs(hb or {}) do
                hotbar[h.slot] = h.inventory_slot
            end
            
            TriggerClientEvent('vAvA_inventory:open', src, {
                inventory = inventory,
                hotbar = hotbar,
                maxSlots = 50,
                maxWeight = 120,
                weight = weight
            })
        end)
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- ADD ITEM - ASYNC
-- ═══════════════════════════════════════════════════════════════════════════

function AddItem(source, itemName, amount, callback)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then if callback then callback(false) end return end
    
    local itemData = registeredItems[itemName]
    if not itemData then 
        print('^1[vAvA_inventory]^7 Item inconnu: ' .. tostring(itemName))
        if callback then callback(false) end 
        return 
    end
    
    amount = amount or 1
    
    -- Chercher slot existant
    exports.oxmysql:execute(
        'SELECT slot, amount FROM player_inventories WHERE owner = ? AND item_name = ? LIMIT 1',
        {identifier, itemName},
        function(result)
            if result and result[1] and (result[1].amount + amount) <= (itemData.max_stack or 99) then
                -- Stacker
                exports.oxmysql:execute(
                    'UPDATE player_inventories SET amount = amount + ? WHERE owner = ? AND slot = ?',
                    {amount, identifier, result[1].slot},
                    function() 
                        SendInventoryUpdate(src, identifier)
                        if callback then callback(true) end
                    end
                )
            else
                -- Trouver slot libre
                exports.oxmysql:execute('SELECT slot FROM player_inventories WHERE owner = ?', {identifier}, function(slots)
                    local used = {}
                    for _, s in ipairs(slots or {}) do used[s.slot] = true end
                    
                    local free = nil
                    for i = 1, 50 do
                        if not used[i] then free = i break end
                    end
                    
                    if free then
                        exports.oxmysql:execute(
                            'INSERT INTO player_inventories (owner, slot, item_name, amount) VALUES (?, ?, ?, ?)',
                            {identifier, free, itemName, amount},
                            function()
                                SendInventoryUpdate(src, identifier)
                                if callback then callback(true) end
                            end
                        )
                    else
                        TriggerClientEvent('vAvA_inventory:notify', src, 'Inventaire plein!')
                        if callback then callback(false) end
                    end
                end)
            end
        end
    )
end

-- ═══════════════════════════════════════════════════════════════════════════
-- REMOVE ITEM - ASYNC
-- ═══════════════════════════════════════════════════════════════════════════

function RemoveItem(source, itemName, amount, callback)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then if callback then callback(false) end return end
    
    amount = amount or 1
    
    exports.oxmysql:execute(
        'SELECT slot, amount FROM player_inventories WHERE owner = ? AND item_name = ?',
        {identifier, itemName},
        function(result)
            if not result or #result == 0 then 
                if callback then callback(false) end 
                return 
            end
            
            local item = result[1]
            if item.amount <= amount then
                exports.oxmysql:execute('DELETE FROM player_inventories WHERE owner = ? AND slot = ?', {identifier, item.slot}, function()
                    SendInventoryUpdate(src, identifier)
                    if callback then callback(true) end
                end)
            else
                exports.oxmysql:execute('UPDATE player_inventories SET amount = amount - ? WHERE owner = ? AND slot = ?', {amount, identifier, item.slot}, function()
                    SendInventoryUpdate(src, identifier)
                    if callback then callback(true) end
                end)
            end
        end
    )
end

-- ═══════════════════════════════════════════════════════════════════════════
-- REFRESH INVENTAIRE
-- ═══════════════════════════════════════════════════════════════════════════

function SendInventoryUpdate(source, identifier)
    exports.oxmysql:execute([[
        SELECT pi.slot, pi.item_name, pi.amount,
               COALESCE(ii.label, pi.item_name) as label,
               COALESCE(ii.weight, 0.1) as weight,
               COALESCE(ii.type, 'item') as type
        FROM player_inventories pi
        LEFT JOIN inventory_items ii ON pi.item_name = ii.name
        WHERE pi.owner = ?
    ]], {identifier}, function(items)
        local inventory = {}
        local weight = 0
        
        for _, item in ipairs(items or {}) do
            inventory[#inventory+1] = {
                slot = item.slot,
                name = item.item_name,
                label = item.label,
                amount = item.amount,
                weight = item.weight,
                type = item.type
            }
            weight = weight + (item.weight * item.amount)
        end
        
        TriggerClientEvent('vAvA_inventory:updateInventory', source, inventory, weight)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EVENTS JOUEUR
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_inventory:useItem')
AddEventHandler('vAvA_inventory:useItem', function(slot)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end
    
    exports.oxmysql:execute([[
        SELECT pi.item_name, ii.type, ii.weapon_hash, ii.label 
        FROM player_inventories pi 
        LEFT JOIN inventory_items ii ON pi.item_name = ii.name 
        WHERE pi.owner = ? AND pi.slot = ?
    ]], {identifier, slot}, function(result)
        if not result or #result == 0 then return end
        local item = result[1]
        
        if item.type == 'weapon' and item.weapon_hash then
            TriggerClientEvent('vAvA_inventory:equipWeapon', src, item.weapon_hash, 100)
        elseif item.type == 'food' or item.type == 'drink' then
            RemoveItem(src, item.item_name, 1)
            TriggerClientEvent('vAvA_inventory:notify', src, 'Consomme: ' .. (item.label or item.item_name))
        end
    end)
end)

RegisterNetEvent('vAvA_inventory:dropItem')
AddEventHandler('vAvA_inventory:dropItem', function(slot, amount)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end
    
    exports.oxmysql:execute('SELECT amount FROM player_inventories WHERE owner = ? AND slot = ?', {identifier, slot}, function(result)
        if not result or #result == 0 then return end
        local dropAmt = math.min(amount or result[1].amount, result[1].amount)
        
        if result[1].amount <= dropAmt then
            exports.oxmysql:execute('DELETE FROM player_inventories WHERE owner = ? AND slot = ?', {identifier, slot}, function()
                SendInventoryUpdate(src, identifier)
            end)
        else
            exports.oxmysql:execute('UPDATE player_inventories SET amount = amount - ? WHERE owner = ? AND slot = ?', {dropAmt, identifier, slot}, function()
                SendInventoryUpdate(src, identifier)
            end)
        end
    end)
end)

RegisterNetEvent('vAvA_inventory:moveItem')
AddEventHandler('vAvA_inventory:moveItem', function(fromSlot, toSlot)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end
    
    exports.oxmysql:execute('SELECT slot FROM player_inventories WHERE owner = ? AND slot = ?', {identifier, toSlot}, function(exists)
        if exists and #exists > 0 then
            -- Swap
            exports.oxmysql:execute('UPDATE player_inventories SET slot = -999 WHERE owner = ? AND slot = ?', {identifier, fromSlot})
            exports.oxmysql:execute('UPDATE player_inventories SET slot = ? WHERE owner = ? AND slot = ?', {fromSlot, identifier, toSlot})
            exports.oxmysql:execute('UPDATE player_inventories SET slot = ? WHERE owner = ? AND slot = -999', {toSlot, identifier}, function()
                SendInventoryUpdate(src, identifier)
            end)
        else
            exports.oxmysql:execute('UPDATE player_inventories SET slot = ? WHERE owner = ? AND slot = ?', {toSlot, identifier, fromSlot}, function()
                SendInventoryUpdate(src, identifier)
            end)
        end
    end)
end)

RegisterNetEvent('vAvA_inventory:setHotbar')
AddEventHandler('vAvA_inventory:setHotbar', function(hSlot, iSlot)
    local identifier = GetPlayerIdentifier(source)
    if identifier then
        exports.oxmysql:execute('REPLACE INTO player_hotbar VALUES (?, ?, ?)', {identifier, hSlot, iSlot})
    end
end)

RegisterNetEvent('vAvA_inventory:useHotbar')
AddEventHandler('vAvA_inventory:useHotbar', function(hSlot)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end
    
    exports.oxmysql:execute('SELECT inventory_slot FROM player_hotbar WHERE owner = ? AND slot = ?', {identifier, hSlot}, function(r)
        if r and r[1] then
            TriggerEvent('vAvA_inventory:useItem', r[1].inventory_slot)
        end
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMANDES ADMIN
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('createitem', function(src, args)
    if src > 0 and not IsPlayerAceAllowed(src, 'command') then return end
    local name, label = args[1], args[2] or args[1]
    local weight, stack = tonumber(args[3]) or 0.1, tonumber(args[4]) or 99
    local itype = args[5] or 'item'
    
    if not name then print('Usage: /createitem name label weight stack type') return end
    
    exports.oxmysql:execute(
        'INSERT INTO inventory_items (name,label,weight,max_stack,type) VALUES (?,?,?,?,?) ON DUPLICATE KEY UPDATE label=?,weight=?,max_stack=?,type=?',
        {name,label,weight,stack,itype,label,weight,stack,itype},
        function()
            registeredItems[name] = {name=name,label=label,weight=weight,max_stack=stack,type=itype}
            print('^2[vAvA_inventory]^7 Item cree: ' .. name)
        end
    )
end, true)

RegisterCommand('createweapon', function(src, args)
    if src > 0 and not IsPlayerAceAllowed(src, 'command') then return end
    local name, label = args[1], args[2] or args[1]
    local hash = args[3] or ('WEAPON_' .. string.upper(args[1]))
    
    if not name then print('Usage: /createweapon name label hash') return end
    
    exports.oxmysql:execute(
        'INSERT INTO inventory_items (name,label,weight,max_stack,type,weapon_hash) VALUES (?,?,2,1,"weapon",?) ON DUPLICATE KEY UPDATE label=?,weapon_hash=?',
        {name,label,hash,label,hash},
        function()
            registeredItems[name] = {name=name,label=label,weight=2,max_stack=1,type='weapon',weapon_hash=hash}
            print('^2[vAvA_inventory]^7 Arme creee: ' .. name)
        end
    )
end, true)

RegisterCommand('giveitem', function(src, args)
    if src > 0 and not IsPlayerAceAllowed(src, 'command') then return end
    local target, item, amt = tonumber(args[1]), args[2], tonumber(args[3]) or 1
    if not target or not item then print('Usage: /giveitem id item amount') return end
    AddItem(target, item, amt, function(ok)
        print('^2[vAvA_inventory]^7 ' .. (ok and 'Donne' or 'Echec') .. ': ' .. amt .. 'x ' .. item)
    end)
end, true)

RegisterCommand('listitems', function(src)
    if src > 0 and not IsPlayerAceAllowed(src, 'command') then return end
    print('^3=== ITEMS ===^7')
    for name, data in pairs(registeredItems) do
        print('  ' .. name .. ' (' .. (data.label or name) .. ')')
    end
end, true)

RegisterCommand('reloaditems', function(src)
    if src > 0 and not IsPlayerAceAllowed(src, 'command') then return end
    exports.oxmysql:execute('SELECT * FROM inventory_items', {}, function(results)
        registeredItems = {}
        for _, item in ipairs(results or {}) do
            registeredItems[item.name] = item
        end
        print('^2[vAvA_inventory]^7 ' .. #(results or {}) .. ' items recharges')
    end)
end, true)

RegisterCommand('clearinv', function(src, args)
    if src > 0 and not IsPlayerAceAllowed(src, 'command') then return end
    local target = tonumber(args[1]) or src
    local id = GetPlayerIdentifier(target)
    if id then
        exports.oxmysql:execute('DELETE FROM player_inventories WHERE owner = ?', {id})
        exports.oxmysql:execute('DELETE FROM player_hotbar WHERE owner = ?', {id})
        SendInventoryUpdate(target, id)
        print('^2[vAvA_inventory]^7 Inventaire vide')
    end
end, true)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('AddItem', AddItem)
exports('RemoveItem', RemoveItem)
exports('GetItemData', function(n) return registeredItems[n] end)

-- Nettoyage
AddEventHandler('playerDropped', function()
    local id = GetPlayerIdentifier(source)
    if id then playerInventories[id], playerHotbars[id] = nil, nil end
end)
