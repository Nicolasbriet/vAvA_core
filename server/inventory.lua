--[[
    vAvA_core - Server Inventory
    Système d'inventaire complet
]]

vCore = vCore or {}
vCore.Inventory = {}

-- Registre des items utilisables
local usableItems = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS PRINCIPALES
-- ═══════════════════════════════════════════════════════════════════════════

---Ajoute un item à un joueur
---@param source number
---@param itemName string
---@param amount number
---@param metadata? table
---@return boolean
function vCore.Inventory.AddItem(source, itemName, amount, metadata)
    local player = vCore.GetPlayer(source)
    if not player then return false end
    
    amount = math.floor(amount)
    if amount <= 0 then return false end
    
    -- Récupérer les infos de l'item
    local itemData = vCore.Cache.Items.Get(itemName)
    if not itemData then
        vCore.Utils.Warn('Item inexistant:', itemName)
        return false
    end
    
    -- Vérifier le poids
    local addWeight = (itemData.weight or 0) * amount
    if not player:CanCarry(addWeight) then
        vCore.Notify(source, Lang('inventory_full'), 'error')
        return false
    end
    
    local inventory = player:GetInventory()
    local added = false
    
    -- Si l'item n'est pas unique, chercher un stack existant
    if not itemData.unique then
        for i, item in ipairs(inventory) do
            if item.name == itemName then
                -- Vérifier les métadonnées
                local sameMetadata = true
                if metadata and item.metadata then
                    sameMetadata = json.encode(metadata) == json.encode(item.metadata)
                end
                
                if sameMetadata then
                    inventory[i].amount = inventory[i].amount + amount
                    added = true
                    break
                end
            end
        end
    end
    
    -- Sinon créer un nouveau slot
    if not added then
        table.insert(inventory, {
            name = itemName,
            label = itemData.label,
            amount = amount,
            weight = itemData.weight,
            type = itemData.type,
            unique = itemData.unique,
            useable = itemData.useable,
            image = itemData.image,
            metadata = metadata or {}
        })
    end
    
    -- Log
    vCore.Log('inventory', player:GetIdentifier(),
        'AddItem: ' .. amount .. 'x ' .. itemName,
        {item = itemName, amount = amount, metadata = metadata}
    )
    
    -- Notification
    vCore.Notify(source, Lang('item_received', amount, itemData.label), 'success')
    
    -- Event
    TriggerEvent(vCore.Events.ITEM_ADDED, source, itemName, amount, metadata)
    TriggerClientEvent(vCore.Events.ITEM_ADDED, source, itemName, amount, metadata)
    
    return true
end

---Retire un item à un joueur
---@param source number
---@param itemName string
---@param amount number
---@return boolean
function vCore.Inventory.RemoveItem(source, itemName, amount)
    local player = vCore.GetPlayer(source)
    if not player then return false end
    
    amount = math.floor(amount)
    if amount <= 0 then return false end
    
    -- Vérifier que le joueur a l'item
    if not player:HasItem(itemName, amount) then
        vCore.Notify(source, Lang('item_not_enough', itemName), 'error')
        return false
    end
    
    local inventory = player:GetInventory()
    local remaining = amount
    
    for i = #inventory, 1, -1 do
        if inventory[i].name == itemName then
            if inventory[i].amount <= remaining then
                remaining = remaining - inventory[i].amount
                table.remove(inventory, i)
            else
                inventory[i].amount = inventory[i].amount - remaining
                remaining = 0
            end
            
            if remaining <= 0 then break end
        end
    end
    
    local itemData = vCore.Cache.Items.Get(itemName)
    local label = itemData and itemData.label or itemName
    
    -- Log
    vCore.Log('inventory', player:GetIdentifier(),
        'RemoveItem: ' .. amount .. 'x ' .. itemName,
        {item = itemName, amount = amount}
    )
    
    -- Notification
    vCore.Notify(source, Lang('item_removed', amount, label), 'info')
    
    -- Event
    TriggerEvent(vCore.Events.ITEM_REMOVED, source, itemName, amount)
    TriggerClientEvent(vCore.Events.ITEM_REMOVED, source, itemName, amount)
    
    return true
end

---Retourne un item d'un joueur
---@param source number
---@param itemName string
---@return table|nil
function vCore.Inventory.GetItem(source, itemName)
    local player = vCore.GetPlayer(source)
    if not player then return nil end
    
    return player:GetItem(itemName)
end

---Vérifie si un joueur a un item
---@param source number
---@param itemName string
---@param amount? number
---@return boolean
function vCore.Inventory.HasItem(source, itemName, amount)
    local player = vCore.GetPlayer(source)
    if not player then return false end
    
    return player:HasItem(itemName, amount or 1)
end

---Retourne l'inventaire complet
---@param source number
---@return table
function vCore.Inventory.GetInventory(source)
    local player = vCore.GetPlayer(source)
    if not player then return {} end
    
    return player:GetInventory()
end

---Vide l'inventaire
---@param source number
function vCore.Inventory.ClearInventory(source)
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    player.inventory = {}
    
    vCore.Log('inventory', player:GetIdentifier(), 'Inventaire vidé')
end

---Retourne le poids de l'inventaire
---@param source number
---@return number
function vCore.Inventory.GetWeight(source)
    local player = vCore.GetPlayer(source)
    if not player then return 0 end
    
    return player:GetInventoryWeight()
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ITEMS UTILISABLES
-- ═══════════════════════════════════════════════════════════════════════════

---Enregistre un item utilisable
---@param itemName string
---@param callback function
function vCore.Inventory.RegisterUsableItem(itemName, callback)
    usableItems[itemName] = callback
    vCore.Utils.Debug('Item utilisable enregistré:', itemName)
end

---Utilise un item
---@param source number
---@param itemName string
---@return boolean
function vCore.Inventory.UseItem(source, itemName)
    local player = vCore.GetPlayer(source)
    if not player then return false end
    
    if not player:HasItem(itemName) then
        vCore.Notify(source, Lang('item_not_found'), 'error')
        return false
    end
    
    local callback = usableItems[itemName]
    if not callback then
        vCore.Notify(source, Lang('item_cannot_use'), 'error')
        return false
    end
    
    -- Exécuter le callback
    callback(source, player:GetItem(itemName))
    
    -- Event
    TriggerEvent(vCore.Events.ITEM_USED, source, itemName)
    
    return true
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ITEMS PAR DÉFAUT
-- ═══════════════════════════════════════════════════════════════════════════

-- Bandage
vCore.Inventory.RegisterUsableItem('bandage', function(source, item)
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    -- Soigner de 25 HP
    local ped = GetPlayerPed(source)
    local health = GetEntityHealth(ped)
    SetEntityHealth(ped, math.min(health + 25, 200))
    
    vCore.Inventory.RemoveItem(source, 'bandage', 1)
    vCore.Notify(source, Lang('item_used', 'Bandage'), 'success')
end)

-- Kit médical
vCore.Inventory.RegisterUsableItem('medikit', function(source, item)
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    -- Soigner complètement
    local ped = GetPlayerPed(source)
    SetEntityHealth(ped, 200)
    
    vCore.Inventory.RemoveItem(source, 'medikit', 1)
    vCore.Notify(source, Lang('item_used', 'Kit médical'), 'success')
end)

-- Pain
vCore.Inventory.RegisterUsableItem('bread', function(source, item)
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    player:AddStatus('hunger', 20)
    vCore.Inventory.RemoveItem(source, 'bread', 1)
    vCore.Notify(source, Lang('item_used', 'Pain'), 'success')
end)

-- Burger
vCore.Inventory.RegisterUsableItem('burger', function(source, item)
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    player:AddStatus('hunger', 35)
    vCore.Inventory.RemoveItem(source, 'burger', 1)
    vCore.Notify(source, Lang('item_used', 'Burger'), 'success')
end)

-- Eau
vCore.Inventory.RegisterUsableItem('water', function(source, item)
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    player:AddStatus('thirst', 30)
    vCore.Inventory.RemoveItem(source, 'water', 1)
    vCore.Notify(source, Lang('item_used', 'Eau'), 'success')
end)

-- Café
vCore.Inventory.RegisterUsableItem('coffee', function(source, item)
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    player:AddStatus('thirst', 20)
    player:RemoveStatus('stress', 10)
    vCore.Inventory.RemoveItem(source, 'coffee', 1)
    vCore.Notify(source, Lang('item_used', 'Café'), 'success')
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('AddItem', function(source, itemName, amount, metadata)
    return vCore.Inventory.AddItem(source, itemName, amount, metadata)
end)

exports('RemoveItem', function(source, itemName, amount)
    return vCore.Inventory.RemoveItem(source, itemName, amount)
end)

exports('GetItem', function(source, itemName)
    return vCore.Inventory.GetItem(source, itemName)
end)

exports('HasItem', function(source, itemName, amount)
    return vCore.Inventory.HasItem(source, itemName, amount)
end)

exports('GetInventory', function(source)
    return vCore.Inventory.GetInventory(source)
end)

exports('RegisterUsableItem', function(itemName, callback)
    vCore.Inventory.RegisterUsableItem(itemName, callback)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS
-- ═══════════════════════════════════════════════════════════════════════════

-- Utiliser un item
RegisterNetEvent('vCore:useItem', function(itemName)
    local source = source
    vCore.Inventory.UseItem(source, itemName)
end)

-- Drop un item
RegisterNetEvent('vCore:dropItem', function(itemName, amount)
    local source = source
    local player = vCore.GetPlayer(source)
    
    if not player then return end
    
    if vCore.Inventory.RemoveItem(source, itemName, amount) then
        -- TODO: Créer l'objet au sol
        local itemData = vCore.Cache.Items.Get(itemName)
        local label = itemData and itemData.label or itemName
        vCore.Notify(source, Lang('item_dropped', amount, label), 'info')
    end
end)

-- Donner un item
RegisterNetEvent('vCore:giveItem', function(targetId, itemName, amount)
    local source = source
    local player = vCore.GetPlayer(source)
    local target = vCore.GetPlayer(targetId)
    
    if not player or not target then return end
    
    if vCore.Inventory.RemoveItem(source, itemName, amount) then
        vCore.Inventory.AddItem(targetId, itemName, amount)
        
        local itemData = vCore.Cache.Items.Get(itemName)
        local label = itemData and itemData.label or itemName
        
        vCore.Notify(source, Lang('item_give', amount, label), 'success')
        vCore.Notify(targetId, Lang('item_give_received', amount, label, player:GetName()), 'success')
    end
end)
