--[[
    vAvA_inventory - Server Main
    Version 6 - Cache + Items de base + Money en item
]]

local Cache = {
    inventories = {},
    hotbars = {},
    items = {}
}

-- Items de base pour nouveaux joueurs
local STARTER_ITEMS = {
    {name = 'bread', amount = 5},
    {name = 'water', amount = 5},
    {name = 'phone', amount = 1},
    {name = 'money', amount = 500}  -- Argent liquide = item
}

-- ═══════════════════════════════════════════════════════════════════════════
-- INIT
-- ═══════════════════════════════════════════════════════════════════════════

-- Vérifier si le module economy est chargé
local EconomyEnabled = false
CreateThread(function()
    Wait(5000)  -- Attendre que tous les modules soient chargés
    if GetResourceState('vAvA_economy') == 'started' then
        EconomyEnabled = true
        print('^2[vAvA_inventory]^7 Module economy détecté et activé')
    else
        print('^3[vAvA_inventory]^7 Module economy non trouvé - Prix fixes utilisés')
    end
end)

CreateThread(function()
    Wait(3000)
    
    -- Drop et recreer les tables pour avoir la bonne structure
    MySQL.Async.execute('DROP TABLE IF EXISTS player_inventories')
    MySQL.Async.execute('DROP TABLE IF EXISTS player_hotbar')
    
    Wait(500)
    
    -- Table items
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS inventory_items (
            name VARCHAR(50) PRIMARY KEY,
            label VARCHAR(100) NOT NULL,
            weight FLOAT DEFAULT 0.1,
            max_stack INT DEFAULT 99,
            type VARCHAR(20) DEFAULT 'item',
            weapon_hash VARCHAR(50) DEFAULT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    
    -- Table inventaires
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS player_inventories (
            id INT AUTO_INCREMENT PRIMARY KEY,
            owner VARCHAR(100) NOT NULL,
            slot INT NOT NULL,
            item_name VARCHAR(50) NOT NULL,
            amount INT DEFAULT 1,
            metadata TEXT DEFAULT NULL,
            UNIQUE KEY unique_owner_slot (owner, slot),
            INDEX idx_owner (owner)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    
    -- Table hotbar
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS player_hotbar (
            owner VARCHAR(100) NOT NULL,
            slot INT NOT NULL,
            inventory_slot INT NOT NULL,
            PRIMARY KEY (owner, slot)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    
    Wait(1000)
    
    -- Items de base - ajouter directement au cache ET BDD
    local defaultItems = {
        {name='bread', label='Pain', weight=0.2, max_stack=50, type='food'},
        {name='water', label='Bouteille d\'eau', weight=0.3, max_stack=50, type='drink'},
        {name='phone', label='Telephone', weight=0.1, max_stack=1, type='item'},
        {name='money', label='Argent Liquide', weight=0.001, max_stack=999999, type='money'},
        {name='id_card', label='Carte d\'identite', weight=0.01, max_stack=1, type='item'},
        {name='bandage', label='Bandage', weight=0.1, max_stack=20, type='item'},
        {name='lockpick', label='Crochet', weight=0.1, max_stack=5, type='tool'}
    }
    
    -- Charger IMMEDIATEMENT dans le cache
    for _, item in ipairs(defaultItems) do
        Cache.items[item.name] = {
            name = item.name,
            label = item.label,
            weight = item.weight,
            max_stack = item.max_stack,
            type = item.type
        }
        -- Aussi sauvegarder en BDD
        MySQL.Async.execute(
            'INSERT IGNORE INTO inventory_items (name, label, weight, max_stack, type) VALUES (?, ?, ?, ?, ?)',
            {item.name, item.label, item.weight, item.max_stack, item.type}
        )
    end
    
    print('^2[vAvA_inventory]^7 ' .. #defaultItems .. ' items charges')
    print('^2[vAvA_inventory]^7 Systeme initialise')
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════════════════

local function GetIdentifier(src)
    for _, id in pairs(GetPlayerIdentifiers(src) or {}) do
        if string.find(id, 'license:') then return id end
    end
end

---Obtenir le prix d'un item via le système economy
---@param itemName string
---@param shop string|nil
---@param quantity number|nil
---@return number
local function GetItemPrice(itemName, shop, quantity)
    if not EconomyEnabled then
        -- Prix fixes si economy non disponible
        local defaultPrices = {
            bread = 5,
            water = 3,
            phone = 500,
            money = 1,
            bandage = 10,
            lockpick = 50
        }
        return (defaultPrices[itemName] or 10) * (quantity or 1)
    end
    
    -- Utiliser le système economy
    return exports['vAvA_economy']:GetPrice(itemName, shop or 'general', quantity or 1)
end

---Appliquer une taxe via le système economy
---@param taxType string
---@param amount number
---@return number
local function ApplyTax(taxType, amount)
    if not EconomyEnabled then
        -- Taxe fixe de 5% si economy non disponible
        return math.floor(amount * 1.05)
    end
    
    return exports['vAvA_economy']:ApplyTax(taxType, amount)
end

---Enregistrer une transaction dans le système economy
---@param transactionType string
---@param itemName string
---@param quantity number
---@param price number
local function RegisterTransaction(transactionType, itemName, quantity, price)
    if not EconomyEnabled then return end
    
    exports['vAvA_economy']:RegisterTransaction(
        transactionType,
        itemName,
        'item',
        quantity,
        price
    )
end

-- ═══════════════════════════════════════════════════════════════════════════
-- CHARGER INVENTAIRE EN CACHE
-- ═══════════════════════════════════════════════════════════════════════════

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
        local hasItems = items and #items > 0
        
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
        
        -- Si nouveau joueur, donner items de base
        if not hasItems then
            print('^3[vAvA_inventory]^7 Nouveau joueur - ajout items de base')
            local slot = 1
            for _, starter in ipairs(STARTER_ITEMS) do
                local itemData = Cache.items[starter.name]
                if itemData then
                    Cache.inventories[identifier][slot] = {
                        name = starter.name,
                        label = itemData.label or starter.name,
                        amount = starter.amount,
                        weight = itemData.weight or 0.1,
                        type = itemData.type or 'item',
                        maxStack = itemData.max_stack or 99
                    }
                    MySQL.Async.execute(
                        'INSERT INTO player_inventories (owner, slot, item_name, amount) VALUES (?, ?, ?, ?)',
                        {identifier, slot, starter.name, starter.amount}
                    )
                    slot = slot + 1
                end
            end
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
-- OUVRIR INVENTAIRE
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_inventory:requestInventory')
AddEventHandler('vAvA_inventory:requestInventory', function()
    local src = source
    local identifier = GetIdentifier(src)
    if not identifier then return end
    
    -- Repondre depuis cache
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
    
    TriggerClientEvent('vAvA_inventory:open', src, {
        inventory = inventory,
        hotbar = hb,
        maxSlots = 50,
        maxWeight = 120,
        weight = weight
    })
    
    -- Si pas en cache, charger
    if not Cache.inventories[identifier] then
        LoadPlayerCache(src, identifier, function()
            SendUpdate(src, identifier)
        end)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- CHARGER A LA CONNEXION
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
    if not Cache.inventories[identifier] then
        Cache.inventories[identifier] = {}
    end
    local inv = Cache.inventories[identifier]
    
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
-- MONEY FUNCTIONS (argent = item)
-- ═══════════════════════════════════════════════════════════════════════════

function GetMoney(src)
    local identifier = GetIdentifier(src)
    if not identifier then return 0 end
    
    local inv = Cache.inventories[identifier]
    if not inv then return 0 end
    
    for _, item in pairs(inv) do
        if item.name == 'money' then
            return item.amount
        end
    end
    return 0
end

function AddMoney(src, amount)
    return AddItem(src, 'money', amount)
end

function RemoveMoney(src, amount)
    local current = GetMoney(src)
    if current >= amount then
        return RemoveItem(src, 'money', amount)
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
        -- Équiper l'arme
        TriggerClientEvent('vAvA_inventory:equipWeapon', src, itemData.weapon_hash, 100)
    elseif itemData and (itemData.type == 'food' or itemData.type == 'drink') then
        -- Tenter de consommer via le module status
        local statusModule = GetResourceState('vAvA_status')
        
        if statusModule == 'started' then
            -- Utiliser le module status pour gérer la consommation
            local success = exports['vAvA_status']:ConsumeItem(src, item.name)
            
            if success then
                -- Item consommé avec succès, retirer de l'inventaire
                RemoveItem(src, item.name, 1)
                TriggerClientEvent('vAvA_inventory:notify', src, 'Vous avez consommé: ' .. itemData.label, 'success')
            else
                -- Item non reconnu par le module status, utiliser l'ancien système
                RemoveItem(src, item.name, 1)
                if itemData.type == 'food' then
                    TriggerClientEvent('vAvA_inventory:consumeFood', src, 25)
                else
                    TriggerClientEvent('vAvA_inventory:consumeDrink', src, 25)
                end
            end
        else
            -- Module status non chargé, utiliser l'ancien système
            RemoveItem(src, item.name, 1)
            if itemData.type == 'food' then
                TriggerClientEvent('vAvA_inventory:consumeFood', src, 25)
            else
                TriggerClientEvent('vAvA_inventory:consumeDrink', src, 25)
            end
        end
    elseif itemData and itemData.type == 'money' then
        TriggerClientEvent('vAvA_inventory:notify', src, 'Vous avez $' .. item.amount)
    else
        -- Item générique - juste notifier
        TriggerClientEvent('vAvA_inventory:notify', src, 'Utilisé: ' .. itemData.label)
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
    
    local temp = inv[to]
    inv[to] = inv[from]
    inv[from] = temp
    
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
    if not hSlot or not iSlot then return end -- Protection null
    
    Cache.hotbars[identifier] = Cache.hotbars[identifier] or {}
    Cache.hotbars[identifier][hSlot] = iSlot
    MySQL.Async.execute('REPLACE INTO player_hotbar (owner, slot, inventory_slot) VALUES (?, ?, ?)', {identifier, hSlot, iSlot})
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
-- GIVE ITEM (transfert entre joueurs)
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_inventory:giveItem')
AddEventHandler('vAvA_inventory:giveItem', function(targetId, slot, amount)
    local src = source
    local srcIdentifier = GetIdentifier(src)
    local tgtIdentifier = GetIdentifier(targetId)
    
    if not srcIdentifier or not tgtIdentifier then
        TriggerClientEvent('vAvA_inventory:notify', src, 'Joueur introuvable')
        return
    end
    
    local srcInv = Cache.inventories[srcIdentifier]
    if not srcInv or not srcInv[slot] then
        TriggerClientEvent('vAvA_inventory:notify', src, 'Item introuvable')
        return
    end
    
    local item = srcInv[slot]
    local giveAmount = math.min(amount or item.amount, item.amount)
    
    -- Ajouter à la cible
    local itemData = Cache.items[item.name]
    if not itemData then
        TriggerClientEvent('vAvA_inventory:notify', src, 'Données item introuvables')
        return
    end
    
    -- Charger inventaire cible si pas en cache
    if not Cache.inventories[tgtIdentifier] then
        Cache.inventories[tgtIdentifier] = {}
    end
    
    local tgtInv = Cache.inventories[tgtIdentifier]
    
    -- Chercher slot pour stacker chez la cible
    local targetSlot = nil
    for s, itm in pairs(tgtInv) do
        if itm.name == item.name and itm.amount + giveAmount <= (itemData.max_stack or 99) then
            targetSlot = s
            break
        end
    end
    
    if targetSlot then
        tgtInv[targetSlot].amount = tgtInv[targetSlot].amount + giveAmount
        MySQL.Async.execute('UPDATE player_inventories SET amount = ? WHERE owner = ? AND slot = ?', 
            {tgtInv[targetSlot].amount, tgtIdentifier, targetSlot})
    else
        -- Trouver slot libre chez la cible
        local freeSlot = nil
        for i = 1, 50 do
            if not tgtInv[i] then freeSlot = i break end
        end
        
        if not freeSlot then
            TriggerClientEvent('vAvA_inventory:notify', src, 'Inventaire du joueur plein')
            return
        end
        
        tgtInv[freeSlot] = {
            name = item.name,
            label = item.label,
            amount = giveAmount,
            weight = item.weight,
            type = item.type,
            maxStack = item.maxStack
        }
        
        MySQL.Async.execute('INSERT INTO player_inventories (owner, slot, item_name, amount) VALUES (?, ?, ?, ?)',
            {tgtIdentifier, freeSlot, item.name, giveAmount})
    end
    
    -- Retirer du donneur
    if item.amount <= giveAmount then
        srcInv[slot] = nil
        MySQL.Async.execute('DELETE FROM player_inventories WHERE owner = ? AND slot = ?', {srcIdentifier, slot})
    else
        item.amount = item.amount - giveAmount
        MySQL.Async.execute('UPDATE player_inventories SET amount = ? WHERE owner = ? AND slot = ?', 
            {item.amount, srcIdentifier, slot})
    end
    
    -- Notifications
    TriggerClientEvent('vAvA_inventory:notify', src, 'Donné ' .. giveAmount .. 'x ' .. item.label)
    TriggerClientEvent('vAvA_inventory:notify', targetId, 'Reçu ' .. giveAmount .. 'x ' .. item.label)
    
    -- Updates
    SendUpdate(src, srcIdentifier)
    SendUpdate(targetId, tgtIdentifier)
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
    print('^2[vAvA_inventory]^7 Item cree: ' .. name)
    if src > 0 then TriggerClientEvent('vAvA_inventory:notify', src, 'Item cree: ' .. name) end
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
    print('^2[vAvA_inventory]^7 Arme creee: ' .. name)
    if src > 0 then TriggerClientEvent('vAvA_inventory:notify', src, 'Arme creee: ' .. name) end
end, true)

RegisterCommand('giveitem', function(src, args)
    if src > 0 and not IsPlayerAceAllowed(src, 'command') then return end
    local target, item, amt = tonumber(args[1]), args[2], tonumber(args[3]) or 1
    if not target or not item then print('/giveitem id item amount') return end
    local ok = AddItem(target, item, amt)
    print('^2[vAvA_inventory]^7 ' .. (ok and 'OK' or 'FAIL') .. ': ' .. amt .. 'x ' .. item)
end, true)

RegisterCommand('givemoney', function(src, args)
    if src > 0 and not IsPlayerAceAllowed(src, 'command') then return end
    local target, amt = tonumber(args[1]), tonumber(args[2]) or 100
    if not target then print('/givemoney id amount') return end
    AddMoney(target, amt)
    print('^2[vAvA_inventory]^7 Donne $' .. amt)
end, true)

RegisterCommand('listitems', function()
    print('^3=== ITEMS ===^7')
    for n, d in pairs(Cache.items) do 
        print('  ' .. n .. ' (' .. (d.label or n) .. ') - ' .. (d.type or 'item'))
    end
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
        print('^2[vAvA_inventory]^7 Inventaire vide')
    end
end, true)

RegisterCommand('reloaditems', function(src)
    if src > 0 and not IsPlayerAceAllowed(src, 'command') then return end
    MySQL.Async.fetchAll('SELECT * FROM inventory_items', {}, function(items)
        Cache.items = {}
        for _, item in ipairs(items or {}) do
            Cache.items[item.name] = item
        end
        print('^2[vAvA_inventory]^7 ' .. #(items or {}) .. ' items recharges')
    end)
end, true)

-- ═══════════════════════════════════════════════════════════════════════════
-- EVENTS ECONOMY - ACHETER/VENDRE ITEMS
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_inventory:buyItem')
AddEventHandler('vAvA_inventory:buyItem', function(itemName, quantity, shop)
    local src = source
    local identifier = GetIdentifier(src)
    if not identifier then return end
    
    local itemData = Cache.items[itemName]
    if not itemData then
        TriggerClientEvent('vAvA_inventory:notify', src, '❌ Item introuvable')
        return
    end
    
    -- Calculer prix avec taxe
    local basePrice = GetItemPrice(itemName, shop, quantity)
    local finalPrice = ApplyTax('achat', basePrice)
    
    -- Vérifier argent
    local money = GetMoney(src)
    if money < finalPrice then
        TriggerClientEvent('vAvA_inventory:notify', src, '❌ Pas assez d\'argent ($' .. finalPrice .. ')')
        return
    end
    
    -- Retirer argent
    if not RemoveMoney(src, finalPrice) then
        TriggerClientEvent('vAvA_inventory:notify', src, '❌ Erreur de paiement')
        return
    end
    
    -- Ajouter item
    if AddItem(src, itemName, quantity) then
        TriggerClientEvent('vAvA_inventory:notify', src, '✅ Acheté ' .. quantity .. 'x ' .. itemData.label .. ' ($' .. finalPrice .. ')')
        RegisterTransaction('achat', itemName, quantity, finalPrice)
    else
        -- Rembourser si échec
        AddMoney(src, finalPrice)
        TriggerClientEvent('vAvA_inventory:notify', src, '❌ Inventaire plein')
    end
end)

RegisterNetEvent('vAvA_inventory:sellItem')
AddEventHandler('vAvA_inventory:sellItem', function(slot, quantity, shop)
    local src = source
    local identifier = GetIdentifier(src)
    if not identifier then return end
    
    local inv = Cache.inventories[identifier]
    if not inv or not inv[slot] then
        TriggerClientEvent('vAvA_inventory:notify', src, '❌ Item introuvable')
        return
    end
    
    local item = inv[slot]
    local sellQty = math.min(quantity or item.amount, item.amount)
    
    -- Calculer prix de vente (75% du prix d'achat)
    local basePrice = GetItemPrice(item.name, shop, sellQty)
    local sellPrice = math.floor(basePrice * 0.75)
    local finalPrice = ApplyTax('vente', sellPrice)
    
    -- Retirer item
    if RemoveItem(src, item.name, sellQty) then
        AddMoney(src, finalPrice)
        TriggerClientEvent('vAvA_inventory:notify', src, '✅ Vendu ' .. sellQty .. 'x ' .. item.label .. ' (+$' .. finalPrice .. ')')
        RegisterTransaction('vente', item.name, sellQty, finalPrice)
    else
        TriggerClientEvent('vAvA_inventory:notify', src, '❌ Erreur de vente')
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- ADMIN PANEL EVENTS
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_inventory:requestAdminPanel')
AddEventHandler('vAvA_inventory:requestAdminPanel', function()
    local src = source
    
    -- Vérifier permissions admin
    if not IsPlayerAceAllowed(src, 'command') then
        TriggerClientEvent('vAvA_inventory:notify', src, '❌ Accès refusé - Permissions admin requises')
        return
    end
    
    -- Récupérer tous les items
    local itemsList = {}
    for name, data in pairs(Cache.items) do
        table.insert(itemsList, {
            name = name,
            label = data.label,
            weight = data.weight,
            max_stack = data.max_stack,
            type = data.type,
            weapon_hash = data.weapon_hash
        })
    end
    
    -- Récupérer tous les joueurs en ligne
    local playersList = {}
    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        local identifier = GetIdentifier(playerId)
        if identifier then
            local inv = Cache.inventories[identifier] or {}
            local itemCount = 0
            local totalWeight = 0
            
            for _, item in pairs(inv) do
                itemCount = itemCount + 1
                totalWeight = totalWeight + (item.weight * item.amount)
            end
            
            table.insert(playersList, {
                id = tonumber(playerId),
                name = GetPlayerName(playerId),
                identifier = identifier,
                itemCount = itemCount,
                weight = math.floor(totalWeight * 10) / 10
            })
        end
    end
    
    TriggerClientEvent('vAvA_inventory:openAdminPanel', src, itemsList, playersList)
end)

RegisterNetEvent('vAvA_inventory:adminSaveItem')
AddEventHandler('vAvA_inventory:adminSaveItem', function(itemData, isNew)
    local src = source
    
    if not IsPlayerAceAllowed(src, 'command') then return end
    
    -- Validation
    if not itemData.name or not itemData.label then
        TriggerClientEvent('vAvA_inventory:notify', src, '❌ Données invalides')
        return
    end
    
    -- Sauvegarder en cache
    Cache.items[itemData.name] = {
        name = itemData.name,
        label = itemData.label,
        weight = itemData.weight or 0.1,
        max_stack = itemData.max_stack or 99,
        type = itemData.type or 'item',
        weapon_hash = itemData.weapon_hash
    }
    
    -- Sauvegarder en BDD
    if isNew then
        MySQL.Async.execute(
            'INSERT INTO inventory_items (name, label, weight, max_stack, type, weapon_hash) VALUES (?, ?, ?, ?, ?, ?)',
            {itemData.name, itemData.label, itemData.weight, itemData.max_stack, itemData.type, itemData.weapon_hash},
            function()
                TriggerClientEvent('vAvA_inventory:notify', src, '✅ Item créé: ' .. itemData.label)
            end
        )
    else
        MySQL.Async.execute(
            'UPDATE inventory_items SET label = ?, weight = ?, max_stack = ?, type = ?, weapon_hash = ? WHERE name = ?',
            {itemData.label, itemData.weight, itemData.max_stack, itemData.type, itemData.weapon_hash, itemData.name},
            function()
                TriggerClientEvent('vAvA_inventory:notify', src, '✅ Item modifié: ' .. itemData.label)
            end
        )
    end
end)

RegisterNetEvent('vAvA_inventory:adminDeleteItem')
AddEventHandler('vAvA_inventory:adminDeleteItem', function(itemName)
    local src = source
    
    if not IsPlayerAceAllowed(src, 'command') then return end
    
    -- Retirer du cache
    Cache.items[itemName] = nil
    
    -- Supprimer de la BDD
    MySQL.Async.execute('DELETE FROM inventory_items WHERE name = ?', {itemName}, function()
        TriggerClientEvent('vAvA_inventory:notify', src, '✅ Item supprimé: ' .. itemName)
    end)
end)

RegisterNetEvent('vAvA_inventory:adminGetPlayerInventory')
AddEventHandler('vAvA_inventory:adminGetPlayerInventory', function(playerId)
    local src = source
    
    if not IsPlayerAceAllowed(src, 'command') then return end
    
    local identifier = GetIdentifier(playerId)
    if not identifier then return end
    
    local inv = Cache.inventories[identifier] or {}
    local inventoryData = {}
    
    for slot, item in pairs(inv) do
        table.insert(inventoryData, {
            slot = slot,
            name = item.name,
            label = item.label,
            amount = item.amount
        })
    end
    
    -- Envoyer au client pour affichage
    TriggerClientEvent('vAvA_inventory:updatePlayerInventory', src, inventoryData)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

-- Fonction pour obtenir le nombre de slots d'un joueur
local function GetSlots(identifier)
    if not identifier then return nil end
    local id = GetIdentifier(identifier)
    if not id then return Config.MaxSlots end
    return Config.MaxSlots
end

-- Fonction pour utiliser un item
local function UseItem(identifier, itemName)
    if not identifier or not itemName then return false end
    local id = GetIdentifier(identifier)
    if not id then return false end
    
    local item = Cache.items[itemName]
    if not item or not item.usable then return false end
    
    -- Vérifier si le joueur possède l'item
    local inventory = Cache.inventories[id] or {}
    for slot, invItem in pairs(inventory) do
        if invItem.name == itemName and invItem.amount > 0 then
            -- Retirer 1 item
            RemoveItem(identifier, itemName, 1)
            return true
        end
    end
    
    return false
end

-- Fonction pour obtenir l'inventaire complet
local function GetInventory(identifier)
    if not identifier then return nil end
    local id = GetIdentifier(identifier)
    if not id then return {} end
    return Cache.inventories[id] or {}
end

-- Fonction pour compter les items
local function GetItemCount(identifier, itemName)
    if not identifier or not itemName then return 0 end
    local id = GetIdentifier(identifier)
    if not id then return 0 end
    
    local inventory = Cache.inventories[id] or {}
    local count = 0
    for _, item in pairs(inventory) do
        if item.name == itemName then
            count = count + item.amount
        end
    end
    return count
end

-- Fonction pour obtenir le poids maximum
local function GetMaxWeight(identifier)
    return Config.MaxWeight or 120
end

-- Fonction pour définir un slot hotbar
local function SetHotbarSlot(identifier, slot, itemName)
    if not identifier or not slot then return false end
    local id = GetIdentifier(identifier)
    if not id then return false end
    
    -- Initialiser hotbar si nécessaire
    if not Cache.hotbars[id] then
        Cache.hotbars[id] = {}
    end
    
    -- Définir le slot
    Cache.hotbars[id][slot] = itemName
    
    -- Sauvegarder en BDD
    MySQL.Async.execute('INSERT INTO player_hotbar (owner, slot, item_name) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE item_name = VALUES(item_name)', 
        {id, slot, itemName})
    
    return true
end

exports('AddItem', AddItem)
exports('RemoveItem', RemoveItem)
exports('GetItemData', function(n) return Cache.items[n] end)
exports('GetMoney', GetMoney)
exports('AddMoney', AddMoney)
exports('RemoveMoney', RemoveMoney)
exports('GetItemPrice', GetItemPrice)
exports('ApplyTax', ApplyTax)
exports('GetSlots', GetSlots)
exports('UseItem', UseItem)
exports('GetInventory', GetInventory)
exports('GetItemCount', GetItemCount)
exports('GetMaxWeight', GetMaxWeight)
exports('SetHotbarSlot', SetHotbarSlot)

-- Cleanup
AddEventHandler('playerDropped', function()
    local id = GetIdentifier(source)
    if id then
        Cache.inventories[id] = nil
        Cache.hotbars[id] = nil
    end
end)
