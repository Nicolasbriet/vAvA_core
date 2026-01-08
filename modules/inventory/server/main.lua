--[[
    vAvA_inventory - Server Main
    Version CACHE - reponse immediate, sync BDD en background
]]

local Cache = {
    inventories = {},
    hotbars = {},
    items = {}
}

-- ═══════════════════════════════════════════════════════════════════════════
-- INIT - Charger tout en cache au demarrage
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    Wait(3000)
    
    -- Creer tables
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS inventory_items (
            name VARCHAR(50) PRIMARY KEY,
            label VARCHAR(100),
            weight FLOAT DEFAULT 0.1,
            max_stack INT DEFAULT 99,
            type VARCHAR(20) DEFAULT 'item',
            weapon_hash VARCHAR(50)
        )
    ]])
    
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS player_inventories (
            id INT AUTO_INCREMENT PRIMARY KEY,
            owner VARCHAR(60),
            slot INT,
            item_name VARCHAR(50),
            amount INT DEFAULT 1,
            UNIQUE KEY owner_slot (owner, slot)
        )
    ]])
    
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS player_hotbar (
            owner VARCHAR(60),
            slot INT,
            inventory_slot INT,
            PRIMARY KEY (owner, slot)
        )
    ]])
    
    Wait(1000)
    
    -- Charger items
    MySQL.Async.fetchAll('SELECT * FROM inventory_items', {}, function(items)
        for _, item in ipairs(items or {}) do
            Cache.items[item.name] = item
        end
        print('^2[vAvA_inventory]^7 ' .. #(items or {}) .. ' items en cache')
    end)
    
    print('^2[vAvA_inventory]^7 Systeme pret')
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- HELPER
-- ═══════════════════════════════════════════════════════════════════════════

local function GetIdentifier(src)
    for _, id in pairs(GetPlayerIdentifiers(src) or {}) do
        if string.find(id, 'license:') then return id end
    end
end

-- Charger inventaire en cache (background)
local function LoadPlayerCache(src, identifier, cb)
    if Cache.inventories[identifier] then
        if cb then cb() end
        return
    end
    
    Cache.inventories[identifier] = {}
    Cache.hotbars[identifier] = {}
    
    MySQL.Async.fetchAll([[
        SELECT pi.slot, pi.item_name, pi.amount,
               COALESCE(ii.label, pi.item_name) as label,
               COALESCE(ii.weight, 0.1) as weight,
               COALESCE(ii.type, 'item') as type,
               COALESCE(ii.max_stack, 99) as max_stack
        FROM player_inventories pi
        LEFT JOIN inventory_items ii ON pi.item_name = ii.name
        WHERE pi.owner = ?
    ]], {identifier}, function(items)
        for _, item in ipairs(items or {}) do
            Cache.inventories[identifier][item.slot] = {
                name = item.item_name,
                label = item.label,
                amount = item.amount,
                weight = item.weight,
                type = item.type,
                maxStack = item.max_stack
            }
        end
        
        MySQL.Async.fetchAll('SELECT slot, inventory_slot FROM player_hotbar WHERE owner = ?', {identifier}, function(hb)
            for _, h in ipairs(hb or {}) do
                Cache.hotbars[identifier][h.slot] = h.inventory_slot
            end
            if cb then cb() end
        end)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- OUVRIR INVENTAIRE - REPONSE IMMEDIATE DEPUIS CACHE
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_inventory:requestInventory')
AddEventHandler('vAvA_inventory:requestInventory', function()
    local src = source
    local identifier = GetIdentifier(src)
    if not identifier then return end
    
    -- Repondre IMMEDIATEMENT avec le cache (meme vide)
    local inv = Cache.inventories[identifier] or {}
    local hb = Cache.hotbars[identifier] or {}
    
    local inventory = {}
    local weight = 0
    
    for slot, item in pairs(inv) do
        inventory[#inventory+1] = {
            slot = slot,
            name = item.name,
            label = item.label,
            amount = item.amount,
            weight = item.weight,
            type = item.type,
            maxStack = item.maxStack
        }
        weight = weight + (item.weight * item.amount)
    end
    
    -- Envoyer immediatement
    TriggerClientEvent('vAvA_inventory:open', src, {
        inventory = inventory,
        hotbar = hb,
        maxSlots = 50,
        maxWeight = 120,
        weight = weight
    })
    
    -- Si cache vide, charger en background et re-envoyer
    if not Cache.inventories[identifier] then
        LoadPlayerCache(src, identifier, function()
            -- Re-envoyer update apres chargement
            SendUpdate(src, identifier)
        end)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- CHARGER CACHE A LA CONNEXION
-- ═══════════════════════════════════════════════════════════════════════════

AddEventHandler('playerConnecting', function()
    local src = source
    SetTimeout(5000, function()
        local identifier = GetIdentifier(src)
        if identifier then
            LoadPlayerCache(src, identifier)
        end
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- ENVOYER UPDATE
-- ═══════════════════════════════════════════════════════════════════════════

function SendUpdate(src, identifier)
    local inv = Cache.inventories[identifier] or {}
    local inventory = {}
    local weight = 0
    
    for slot, item in pairs(inv) do
        inventory[#inventory+1] = {
            slot = slot,
            name = item.name,
            label = item.label,
            amount = item.amount,
            weight = item.weight,
            type = item.type
        }
        weight = weight + (item.weight * item.amount)
    end
    
    TriggerClientEvent('vAvA_inventory:updateInventory', src, inventory, weight)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ADD ITEM
-- ═══════════════════════════════════════════════════════════════════════════

function AddItem(src, itemName, amount)
    local identifier = GetIdentifier(src)
    if not identifier then return false end
    
    local itemData = Cache.items[itemName]
    if not itemData then
        print('^1[vAvA_inventory]^7 Item inconnu: ' .. tostring(itemName))
        return false
    end
    
    amount = amount or 1
    local inv = Cache.inventories[identifier] or {}
    Cache.inventories[identifier] = inv
    
    -- Chercher slot pour stacker
    local targetSlot = nil
    for slot, item in pairs(inv) do
        if item.name == itemName and item.amount + amount <= (itemData.max_stack or 99) then
            targetSlot = slot
            break
        end
    end
    
    if targetSlot then
        inv[targetSlot].amount = inv[targetSlot].amount + amount
        MySQL.Async.execute('UPDATE player_inventories SET amount = ? WHERE owner = ? AND slot = ?', 
            {inv[targetSlot].amount, identifier, targetSlot})
    else
        -- Trouver slot libre
        local free = nil
        for i = 1, 50 do
            if not inv[i] then free = i break end
        end
        
        if not free then
            TriggerClientEvent('vAvA_inventory:notify', src, 'Inventaire plein!')
            return false
        end
        
        inv[free] = {
            name = itemName,
            label = itemData.label or itemName,
            amount = amount,
            weight = itemData.weight or 0.1,
            type = itemData.type or 'item',
            maxStack = itemData.max_stack or 99
        }
        
        MySQL.Async.execute('INSERT INTO player_inventories (owner, slot, item_name, amount) VALUES (?, ?, ?, ?)',
            {identifier, free, itemName, amount})
    end
    
    SendUpdate(src, identifier)
    return true
end

-- ═══════════════════════════════════════════════════════════════════════════
-- REMOVE ITEM
-- ═══════════════════════════════════════════════════════════════════════════

function RemoveItem(src, itemName, amount)
    local identifier = GetIdentifier(src)
    if not identifier then return false end
    
    amount = amount or 1
    local inv = Cache.inventories[identifier]
    if not inv then return false end
    
    for slot, item in pairs(inv) do
        if item.name == itemName then
            if item.amount <= amount then
                inv[slot] = nil
                MySQL.Async.execute('DELETE FROM player_inventories WHERE owner = ? AND slot = ?', {identifier, slot})
            else
                item.amount = item.amount - amount
                MySQL.Async.execute('UPDATE player_inventories SET amount = ? WHERE owner = ? AND slot = ?', 
                    {item.amount, identifier, slot})
            end
            SendUpdate(src, identifier)
            return true
        end
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EVENTS
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_inventory:useItem')
AddEventHandler('vAvA_inventory:useItem', function(slot)
    local src = source
    local identifier = GetIdentifier(src)
    if not identifier then return end
    
    local inv = Cache.inventories[identifier]
    if not inv or not inv[slot] then return end
    
    local item = inv[slot]
    local itemData = Cache.items[item.name]
    
    if itemData and itemData.type == 'weapon' and itemData.weapon_hash then
        TriggerClientEvent('vAvA_inventory:equipWeapon', src, itemData.weapon_hash, 100)
    elseif itemData and (itemData.type == 'food' or itemData.type == 'drink') then
        RemoveItem(src, item.name, 1)
        TriggerClientEvent('vAvA_inventory:notify', src, 'Consomme: ' .. item.label)
    end
end)

RegisterNetEvent('vAvA_inventory:dropItem')
AddEventHandler('vAvA_inventory:dropItem', function(slot, amount)
    local src = source
    local identifier = GetIdentifier(src)
    if not identifier then return end
    
    local inv = Cache.inventories[identifier]
    if not inv or not inv[slot] then return end
    
    local item = inv[slot]
    local dropAmt = math.min(amount or item.amount, item.amount)
    
    if item.amount <= dropAmt then
        inv[slot] = nil
        MySQL.Async.execute('DELETE FROM player_inventories WHERE owner = ? AND slot = ?', {identifier, slot})
    else
        item.amount = item.amount - dropAmt
        MySQL.Async.execute('UPDATE player_inventories SET amount = ? WHERE owner = ? AND slot = ?', 
            {item.amount, identifier, slot})
    end
    
    SendUpdate(src, identifier)
end)

RegisterNetEvent('vAvA_inventory:moveItem')
AddEventHandler('vAvA_inventory:moveItem', function(from, to)
    local src = source
    local identifier = GetIdentifier(src)
    if not identifier then return end
    
    local inv = Cache.inventories[identifier]
    if not inv or not inv[from] then return end
    
    -- Swap en cache
    local temp = inv[to]
    inv[to] = inv[from]
    inv[from] = temp
    
    -- Sync BDD
    if temp then
        MySQL.Async.execute('UPDATE player_inventories SET slot = -999 WHERE owner = ? AND slot = ?', {identifier, from})
        MySQL.Async.execute('UPDATE player_inventories SET slot = ? WHERE owner = ? AND slot = ?', {from, identifier, to})
        MySQL.Async.execute('UPDATE player_inventories SET slot = ? WHERE owner = ? AND slot = -999', {to, identifier})
    else
        MySQL.Async.execute('UPDATE player_inventories SET slot = ? WHERE owner = ? AND slot = ?', {to, identifier, from})
    end
    
    SendUpdate(src, identifier)
end)

RegisterNetEvent('vAvA_inventory:setHotbar')
AddEventHandler('vAvA_inventory:setHotbar', function(hSlot, iSlot)
    local identifier = GetIdentifier(source)
    if not identifier then return end
    Cache.hotbars[identifier] = Cache.hotbars[identifier] or {}
    Cache.hotbars[identifier][hSlot] = iSlot
    MySQL.Async.execute('REPLACE INTO player_hotbar VALUES (?, ?, ?)', {identifier, hSlot, iSlot})
end)

RegisterNetEvent('vAvA_inventory:useHotbar')
AddEventHandler('vAvA_inventory:useHotbar', function(hSlot)
    local src = source
    local identifier = GetIdentifier(src)
    if not identifier then return end
    
    local hb = Cache.hotbars[identifier]
    if hb and hb[hSlot] then
        TriggerEvent('vAvA_inventory:useItem', hb[hSlot])
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMANDES ADMIN
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('createitem', function(src, args)
    if src > 0 and not IsPlayerAceAllowed(src, 'command') then return end
    local name, label = args[1], args[2] or args[1]
    local weight, stack = tonumber(args[3]) or 0.1, tonumber(args[4]) or 99
    local itype = args[5] or 'item'
    
    if not name then print('/createitem name label weight stack type') return end
    
    Cache.items[name] = {name=name, label=label, weight=weight, max_stack=stack, type=itype}
    MySQL.Async.execute(
        'INSERT INTO inventory_items (name,label,weight,max_stack,type) VALUES (?,?,?,?,?) ON DUPLICATE KEY UPDATE label=?,weight=?,max_stack=?,type=?',
        {name,label,weight,stack,itype, label,weight,stack,itype}
    )
    print('^2[vAvA_inventory]^7 Item: ' .. name)
end, true)

RegisterCommand('createweapon', function(src, args)
    if src > 0 and not IsPlayerAceAllowed(src, 'command') then return end
    local name, label = args[1], args[2] or args[1]
    local hash = args[3] or ('WEAPON_' .. string.upper(args[1]))
    
    if not name then print('/createweapon name label hash') return end
    
    Cache.items[name] = {name=name, label=label, weight=2, max_stack=1, type='weapon', weapon_hash=hash}
    MySQL.Async.execute(
        'INSERT INTO inventory_items (name,label,weight,max_stack,type,weapon_hash) VALUES (?,?,2,1,"weapon",?) ON DUPLICATE KEY UPDATE label=?,weapon_hash=?',
        {name,label,hash, label,hash}
    )
    print('^2[vAvA_inventory]^7 Arme: ' .. name)
end, true)

RegisterCommand('giveitem', function(src, args)
    if src > 0 and not IsPlayerAceAllowed(src, 'command') then return end
    local target, item, amt = tonumber(args[1]), args[2], tonumber(args[3]) or 1
    if not target or not item then print('/giveitem id item amount') return end
    local ok = AddItem(target, item, amt)
    print('^2[vAvA_inventory]^7 ' .. (ok and 'OK' or 'FAIL'))
end, true)

RegisterCommand('listitems', function()
    print('^3=== ITEMS ===^7')
    for n, d in pairs(Cache.items) do print('  ' .. n) end
end, true)

RegisterCommand('clearinv', function(src, args)
    if src > 0 and not IsPlayerAceAllowed(src, 'command') then return end
    local target = tonumber(args[1]) or src
    local id = GetIdentifier(target)
    if id then
        Cache.inventories[id] = {}
        Cache.hotbars[id] = {}
        MySQL.Async.execute('DELETE FROM player_inventories WHERE owner = ?', {id})
        MySQL.Async.execute('DELETE FROM player_hotbar WHERE owner = ?', {id})
        SendUpdate(target, id)
    end
end, true)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS + CLEANUP
-- ═══════════════════════════════════════════════════════════════════════════

exports('AddItem', AddItem)
exports('RemoveItem', RemoveItem)
exports('GetItemData', function(n) return Cache.items[n] end)

AddEventHandler('playerDropped', function()
    local id = GetIdentifier(source)
    if id then
        Cache.inventories[id] = nil
        Cache.hotbars[id] = nil
    end
end)
