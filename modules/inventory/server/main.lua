--[[
    vAvA_inventory - Server Main
    Version SYNC - pas de callbacks imbriques
]]

local playerInventories = {}
local playerHotbars = {}
local registeredItems = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- HELPERS MySQL SYNC (avec promise pour eviter blocage)
-- ═══════════════════════════════════════════════════════════════════════════

local function MySQL_Execute(query, params)
    local p = promise.new()
    exports.oxmysql:execute(query, params or {}, function(result)
        p:resolve(result)
    end)
    return Citizen.Await(p)
end

local function MySQL_Insert(query, params)
    local p = promise.new()
    exports.oxmysql:insert(query, params or {}, function(result)
        p:resolve(result)
    end)
    return Citizen.Await(p)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- INITIALISATION
-- ═══════════════════════════════════════════════════════════════════════════

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    -- Creer les tables (async ok pour init)
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS `inventory_items` (
            `name` VARCHAR(50) PRIMARY KEY,
            `label` VARCHAR(100) NOT NULL,
            `description` TEXT DEFAULT NULL,
            `weight` FLOAT DEFAULT 0.1,
            `max_stack` INT DEFAULT 99,
            `usable` TINYINT(1) DEFAULT 1,
            `type` ENUM('item', 'weapon', 'ammo', 'food', 'drink', 'tool') DEFAULT 'item',
            `image` VARCHAR(100) DEFAULT NULL,
            `weapon_hash` VARCHAR(50) DEFAULT NULL,
            `ammo_type` VARCHAR(50) DEFAULT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS `player_inventories` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `owner` VARCHAR(60) NOT NULL,
            `slot` INT NOT NULL,
            `item_name` VARCHAR(50) NOT NULL,
            `amount` INT DEFAULT 1,
            `metadata` LONGTEXT DEFAULT NULL,
            UNIQUE KEY `owner_slot` (`owner`, `slot`),
            INDEX `idx_owner` (`owner`)
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
    
    -- Charger les items apres un delai
    SetTimeout(1000, function()
        LoadItemsFromDatabase()
    end)
    
    print('^2[vAvA_inventory]^7 Systeme d\'inventaire demarre')
end)

function LoadItemsFromDatabase()
    local results = MySQL_Execute('SELECT * FROM inventory_items')
    registeredItems = {}
    if results then
        for _, item in ipairs(results) do
            registeredItems[item.name] = item
        end
        print('^2[vAvA_inventory]^7 ' .. #results .. ' items charges')
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- IDENTIFIANT JOUEUR
-- ═══════════════════════════════════════════════════════════════════════════

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
-- CHARGEMENT INVENTAIRE
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_inventory:requestInventory')
AddEventHandler('vAvA_inventory:requestInventory', function()
    local src = source
    local identifier = GetPlayerIdentifier(src)
    
    if not identifier then
        TriggerClientEvent('vAvA_inventory:notify', src, 'Erreur: identifiant manquant', 'error')
        return
    end
    
    -- SetTimeout libere le thread principal immediatement
    SetTimeout(0, function()
        local items = MySQL_Execute([[
            SELECT pi.slot, pi.item_name, pi.amount, pi.metadata, ii.label, ii.weight, ii.type, ii.image, ii.max_stack
            FROM player_inventories pi
            LEFT JOIN inventory_items ii ON pi.item_name = ii.name
            WHERE pi.owner = ?
            ORDER BY pi.slot
        ]], {identifier})
        
        local hotbarData = MySQL_Execute('SELECT slot, inventory_slot FROM player_hotbar WHERE owner = ?', {identifier})
        
        local inventory = {}
        local weight = 0
        
        if items then
            for _, item in ipairs(items) do
                table.insert(inventory, {
                    slot = item.slot,
                    name = item.item_name,
                    label = item.label or item.item_name,
                    amount = item.amount,
                    weight = item.weight or 0.1,
                    type = item.type or 'item',
                    image = item.image,
                    maxStack = item.max_stack or 99,
                    metadata = item.metadata and json.decode(item.metadata) or {}
                })
                weight = weight + ((item.weight or 0.1) * item.amount)
            end
        end
        
        local hotbar = {}
        if hotbarData then
            for _, h in ipairs(hotbarData) do
                hotbar[h.slot] = h.inventory_slot
            end
        end
        
        playerInventories[identifier] = inventory
        playerHotbars[identifier] = hotbar
        
        TriggerClientEvent('vAvA_inventory:open', src, {
            inventory = inventory,
            hotbar = hotbar,
            maxSlots = 50,
            maxWeight = 120,
            weight = weight
        })
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- GESTION ITEMS
-- ═══════════════════════════════════════════════════════════════════════════

function AddItem(source, itemName, amount, metadata)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return false end
    
    local itemData = registeredItems[itemName]
    if not itemData then
        print('^1[vAvA_inventory]^7 Item inconnu: ' .. tostring(itemName))
        return false
    end
    
    amount = amount or 1
    local src = source
    
    SetTimeout(0, function()
        local result = MySQL_Execute(
            'SELECT slot, amount FROM player_inventories WHERE owner = ? AND item_name = ? ORDER BY slot LIMIT 1',
            {identifier, itemName}
        )
        
        if result and result[1] and (result[1].amount + amount) <= (itemData.max_stack or 99) then
            MySQL_Execute('UPDATE player_inventories SET amount = amount + ? WHERE owner = ? AND slot = ?', {amount, identifier, result[1].slot})
        else
            local slots = MySQL_Execute('SELECT slot FROM player_inventories WHERE owner = ? ORDER BY slot', {identifier})
            local usedSlots = {}
            if slots then
                for _, s in ipairs(slots) do usedSlots[s.slot] = true end
            end
            
            local freeSlot = nil
            for i = 1, 50 do
                if not usedSlots[i] then freeSlot = i break end
            end
            
            if freeSlot then
                MySQL_Insert(
                    'INSERT INTO player_inventories (owner, slot, item_name, amount, metadata) VALUES (?, ?, ?, ?, ?)',
                    {identifier, freeSlot, itemName, amount, metadata and json.encode(metadata) or nil}
                )
            else
                TriggerClientEvent('vAvA_inventory:notify', src, 'Inventaire plein!', 'error')
                return
            end
        end
        
        RefreshPlayerInventory(src, identifier)
    end)
    
    return true
end

function RemoveItem(source, itemName, amount)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return false end
    
    amount = amount or 1
    local src = source
    
    SetTimeout(0, function()
        local result = MySQL_Execute(
            'SELECT slot, amount FROM player_inventories WHERE owner = ? AND item_name = ? ORDER BY slot',
            {identifier, itemName}
        )
        
        if not result or #result == 0 then return end
        
        local remaining = amount
        for _, item in ipairs(result) do
            if remaining <= 0 then break end
            
            if item.amount <= remaining then
                MySQL_Execute('DELETE FROM player_inventories WHERE owner = ? AND slot = ?', {identifier, item.slot})
                remaining = remaining - item.amount
            else
                MySQL_Execute('UPDATE player_inventories SET amount = amount - ? WHERE owner = ? AND slot = ?', {remaining, identifier, item.slot})
                remaining = 0
            end
        end
        
        RefreshPlayerInventory(src, identifier)
    end)
    
    return true
end

function RefreshPlayerInventory(source, identifier)
    SetTimeout(0, function()
        local items = MySQL_Execute([[
            SELECT pi.slot, pi.item_name, pi.amount, pi.metadata, ii.label, ii.weight, ii.type, ii.image
            FROM player_inventories pi
            LEFT JOIN inventory_items ii ON pi.item_name = ii.name
            WHERE pi.owner = ?
        ]], {identifier})
        
        local inventory = {}
        local weight = 0
        
        if items then
            for _, item in ipairs(items) do
                table.insert(inventory, {
                    slot = item.slot,
                    name = item.item_name,
                    label = item.label or item.item_name,
                    amount = item.amount,
                    weight = item.weight or 0.1,
                    type = item.type or 'item',
                    image = item.image,
                    metadata = item.metadata and json.decode(item.metadata) or {}
                })
                weight = weight + ((item.weight or 0.1) * item.amount)
            end
        end
        
        playerInventories[identifier] = inventory
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
    
    SetTimeout(0, function()
        local result = MySQL_Execute(
            'SELECT pi.*, ii.type, ii.weapon_hash, ii.label FROM player_inventories pi LEFT JOIN inventory_items ii ON pi.item_name = ii.name WHERE pi.owner = ? AND pi.slot = ?',
            {identifier, slot}
        )
        
        if not result or #result == 0 then return end
        
        local item = result[1]
        
        if item.type == 'weapon' and item.weapon_hash then
            TriggerClientEvent('vAvA_inventory:equipWeapon', src, item.weapon_hash, 100)
        elseif item.type == 'food' or item.type == 'drink' then
            RemoveItem(src, item.item_name, 1)
            TriggerClientEvent('vAvA_inventory:notify', src, 'Vous avez consomme ' .. (item.label or item.item_name))
        else
            TriggerClientEvent('vAvA_inventory:notify', src, 'Item utilise: ' .. (item.label or item.item_name))
        end
    end)
end)

RegisterNetEvent('vAvA_inventory:dropItem')
AddEventHandler('vAvA_inventory:dropItem', function(slot, amount)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end
    
    SetTimeout(0, function()
        local result = MySQL_Execute('SELECT * FROM player_inventories WHERE owner = ? AND slot = ?', {identifier, slot})
        if not result or #result == 0 then return end
        
        local item = result[1]
        local dropAmount = math.min(amount or item.amount, item.amount)
        
        if item.amount <= dropAmount then
            MySQL_Execute('DELETE FROM player_inventories WHERE owner = ? AND slot = ?', {identifier, slot})
        else
            MySQL_Execute('UPDATE player_inventories SET amount = amount - ? WHERE owner = ? AND slot = ?', {dropAmount, identifier, slot})
        end
        
        RefreshPlayerInventory(src, identifier)
        TriggerClientEvent('vAvA_inventory:notify', src, 'Item jete')
    end)
end)

RegisterNetEvent('vAvA_inventory:moveItem')
AddEventHandler('vAvA_inventory:moveItem', function(fromSlot, toSlot, amount)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end
    
    SetTimeout(0, function()
        local result = MySQL_Execute('SELECT * FROM player_inventories WHERE owner = ? AND slot IN (?, ?)', {identifier, fromSlot, toSlot})
        
        local fromItem, toItem = nil, nil
        if result then
            for _, item in ipairs(result) do
                if item.slot == fromSlot then fromItem = item
                elseif item.slot == toSlot then toItem = item end
            end
        end
        
        if not fromItem then return end
        
        if toItem then
            MySQL_Execute('UPDATE player_inventories SET slot = -1 WHERE owner = ? AND slot = ?', {identifier, fromSlot})
            MySQL_Execute('UPDATE player_inventories SET slot = ? WHERE owner = ? AND slot = ?', {fromSlot, identifier, toSlot})
            MySQL_Execute('UPDATE player_inventories SET slot = ? WHERE owner = ? AND slot = -1', {toSlot, identifier})
        else
            MySQL_Execute('UPDATE player_inventories SET slot = ? WHERE owner = ? AND slot = ?', {toSlot, identifier, fromSlot})
        end
        
        RefreshPlayerInventory(src, identifier)
    end)
end)

RegisterNetEvent('vAvA_inventory:setHotbar')
AddEventHandler('vAvA_inventory:setHotbar', function(hotbarSlot, inventorySlot)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return end
    MySQL_Execute('REPLACE INTO player_hotbar (owner, slot, inventory_slot) VALUES (?, ?, ?)', {identifier, hotbarSlot, inventorySlot})
end)

RegisterNetEvent('vAvA_inventory:useHotbar')
AddEventHandler('vAvA_inventory:useHotbar', function(hotbarSlot)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end
    
    SetTimeout(0, function()
        local result = MySQL_Execute('SELECT inventory_slot FROM player_hotbar WHERE owner = ? AND slot = ?', {identifier, hotbarSlot})
        if result and result[1] then
            TriggerEvent('vAvA_inventory:useItem', result[1].inventory_slot)
        end
    end)
end)

RegisterNetEvent('vAvA_inventory:giveItem')
AddEventHandler('vAvA_inventory:giveItem', function(targetId, slot, amount)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    local targetIdentifier = GetPlayerIdentifier(targetId)
    
    if not identifier or not targetIdentifier then return end
    
    SetTimeout(0, function()
        local result = MySQL_Execute('SELECT * FROM player_inventories WHERE owner = ? AND slot = ?', {identifier, slot})
        if not result or #result == 0 then return end
        
        local item = result[1]
        local giveAmount = math.min(amount or item.amount, item.amount)
        
        if item.amount <= giveAmount then
            MySQL_Execute('DELETE FROM player_inventories WHERE owner = ? AND slot = ?', {identifier, slot})
        else
            MySQL_Execute('UPDATE player_inventories SET amount = amount - ? WHERE owner = ? AND slot = ?', {giveAmount, identifier, slot})
        end
        
        AddItem(targetId, item.item_name, giveAmount)
        RefreshPlayerInventory(src, identifier)
        TriggerClientEvent('vAvA_inventory:notify', src, 'Item donne!')
        TriggerClientEvent('vAvA_inventory:notify', targetId, 'Vous avez recu un item!')
    end)
end)

RegisterNetEvent('vAvA_inventory:splitStack')
AddEventHandler('vAvA_inventory:splitStack', function(slot, amount)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end
    
    SetTimeout(0, function()
        local result = MySQL_Execute('SELECT * FROM player_inventories WHERE owner = ? AND slot = ?', {identifier, slot})
        if not result or #result == 0 then return end
        
        local item = result[1]
        if item.amount <= amount then return end
        
        local slots = MySQL_Execute('SELECT slot FROM player_inventories WHERE owner = ?', {identifier})
        local usedSlots = {}
        if slots then
            for _, s in ipairs(slots) do usedSlots[s.slot] = true end
        end
        
        local freeSlot = nil
        for i = 1, 50 do
            if not usedSlots[i] then freeSlot = i break end
        end
        
        if freeSlot then
            MySQL_Execute('UPDATE player_inventories SET amount = amount - ? WHERE owner = ? AND slot = ?', {amount, identifier, slot})
            MySQL_Insert('INSERT INTO player_inventories (owner, slot, item_name, amount, metadata) VALUES (?, ?, ?, ?, ?)', {identifier, freeSlot, item.item_name, amount, item.metadata})
            RefreshPlayerInventory(src, identifier)
        end
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMANDES ADMIN
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('createitem', function(source, args)
    if source > 0 and not IsPlayerAceAllowed(source, 'command') then
        TriggerClientEvent('vAvA_inventory:notify', source, 'Pas la permission', 'error')
        return
    end
    
    local name = args[1]
    local label = args[2] or args[1]
    local weight = tonumber(args[3]) or 0.1
    local maxStack = tonumber(args[4]) or 99
    local itemType = args[5] or 'item'
    
    if not name then
        print('Usage: /createitem [name] [label] [weight] [maxStack] [type]')
        return
    end
    
    SetTimeout(0, function()
        MySQL_Execute(
            'INSERT INTO inventory_items (name, label, weight, max_stack, type) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE label=?, weight=?, max_stack=?, type=?',
            {name, label, weight, maxStack, itemType, label, weight, maxStack, itemType}
        )
        LoadItemsFromDatabase()
        print('^2[vAvA_inventory]^7 Item cree: ' .. name)
        if source > 0 then
            TriggerClientEvent('vAvA_inventory:notify', source, 'Item cree: ' .. name)
        end
    end)
end, true)

RegisterCommand('createweapon', function(source, args)
    if source > 0 and not IsPlayerAceAllowed(source, 'command') then return end
    
    local name = args[1]
    local label = args[2] or args[1]
    local weaponHash = args[3] or string.upper(args[1])
    
    if not name then
        print('Usage: /createweapon [name] [label] [weapon_hash]')
        return
    end
    
    SetTimeout(0, function()
        MySQL_Execute(
            'INSERT INTO inventory_items (name, label, weight, max_stack, type, weapon_hash) VALUES (?, ?, 2.0, 1, "weapon", ?) ON DUPLICATE KEY UPDATE label=?, weapon_hash=?',
            {name, label, weaponHash, label, weaponHash}
        )
        LoadItemsFromDatabase()
        print('^2[vAvA_inventory]^7 Arme creee: ' .. name)
    end)
end, true)

RegisterCommand('giveitem', function(source, args)
    if source > 0 and not IsPlayerAceAllowed(source, 'command') then return end
    
    local targetId = tonumber(args[1])
    local itemName = args[2]
    local amount = tonumber(args[3]) or 1
    
    if not targetId or not itemName then
        print('Usage: /giveitem [playerId] [itemName] [amount]')
        return
    end
    
    AddItem(targetId, itemName, amount)
    print('^2[vAvA_inventory]^7 Donne ' .. amount .. 'x ' .. itemName .. ' au joueur ' .. targetId)
end, true)

RegisterCommand('listitems', function(source)
    if source > 0 and not IsPlayerAceAllowed(source, 'command') then return end
    
    SetTimeout(0, function()
        local results = MySQL_Execute('SELECT name, label, type FROM inventory_items ORDER BY name')
        print('^3=== ITEMS EN BDD ===^7')
        if results then
            for _, item in ipairs(results) do
                print('  ' .. item.name .. ' (' .. item.label .. ') - ' .. item.type)
            end
            print('^3Total: ' .. #results .. ' items^7')
        end
    end)
end, true)

RegisterCommand('deleteitem', function(source, args)
    if source > 0 and not IsPlayerAceAllowed(source, 'command') then return end
    
    local name = args[1]
    if not name then print('Usage: /deleteitem [name]') return end
    
    SetTimeout(0, function()
        MySQL_Execute('DELETE FROM inventory_items WHERE name = ?', {name})
        LoadItemsFromDatabase()
        print('^2[vAvA_inventory]^7 Item supprime: ' .. name)
    end)
end, true)

RegisterCommand('reloaditems', function(source)
    if source > 0 and not IsPlayerAceAllowed(source, 'command') then return end
    LoadItemsFromDatabase()
    print('^2[vAvA_inventory]^7 Items recharges')
end, true)

RegisterCommand('clearinv', function(source, args)
    if source > 0 and not IsPlayerAceAllowed(source, 'command') then return end
    
    local targetId = tonumber(args[1]) or source
    local identifier = GetPlayerIdentifier(targetId)
    
    if identifier then
        SetTimeout(0, function()
            MySQL_Execute('DELETE FROM player_inventories WHERE owner = ?', {identifier})
            MySQL_Execute('DELETE FROM player_hotbar WHERE owner = ?', {identifier})
            RefreshPlayerInventory(targetId, identifier)
            print('^2[vAvA_inventory]^7 Inventaire vide pour joueur ' .. targetId)
        end)
    end
end, true)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('AddItem', AddItem)
exports('RemoveItem', RemoveItem)
exports('GetItemData', function(name) return registeredItems[name] end)
exports('RefreshItems', LoadItemsFromDatabase)

-- ═══════════════════════════════════════════════════════════════════════════
-- NETTOYAGE
-- ═══════════════════════════════════════════════════════════════════════════

AddEventHandler('playerDropped', function()
    local identifier = GetPlayerIdentifier(source)
    if identifier then
        playerInventories[identifier] = nil
        playerHotbars[identifier] = nil
    end
end)
