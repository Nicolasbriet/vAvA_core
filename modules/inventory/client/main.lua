--[[
    vAvA_inventory - Client Main
    Gestion principale de l'inventaire côté client
]]

local isOpen = false
local playerInventory = {}
local hotbarItems = {}
local currentWeapon = nil
local weaponAmmo = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- INITIALISATION
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    -- Attendre que le joueur soit chargé
    while not LocalPlayer.state.isLoggedIn do
        Wait(500)
    end
    
    -- Charger l'inventaire
    LoadInventory()
    
    -- Désactiver la roue des armes
    if InventoryConfig.Weapons.disableWeaponWheel then
        DisableWeaponWheel()
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- KEYBINDS
-- ═══════════════════════════════════════════════════════════════════════════

-- Touche pour ouvrir l'inventaire
RegisterKeyMapping('inventory', 'Ouvrir l\'inventaire', 'keyboard', InventoryConfig.OpenKey)
RegisterCommand('inventory', function()
    ToggleInventory()
end, false)

-- Hotbar keys (1-5)
if InventoryConfig.Hotbar.enabled then
    for i, key in ipairs(InventoryConfig.Hotbar.keys) do
        RegisterKeyMapping('hotbar_' .. i, 'Hotbar Slot ' .. i, 'keyboard', key)
        RegisterCommand('hotbar_' .. i, function()
            UseHotbarSlot(i)
        end, false)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS PRINCIPALES
-- ═══════════════════════════════════════════════════════════════════════════

function LoadInventory()
    TriggerServerCallback('vAvA_inventory:getInventory', function(inventory, hotbar)
        playerInventory = inventory or {}
        hotbarItems = hotbar or {}
        UpdateHotbarUI()
    end)
end

function ToggleInventory()
    if isOpen then
        CloseInventory()
    else
        OpenInventory()
    end
end

function OpenInventory()
    if isOpen then return end
    isOpen = true
    
    -- Récupérer l'inventaire à jour
    TriggerServerCallback('vAvA_inventory:getInventory', function(inventory, hotbar)
        playerInventory = inventory or {}
        hotbarItems = hotbar or {}
        
        local weight = Inventory.CalculateWeight(playerInventory)
        
        SendNUIMessage({
            action = 'openInventory',
            inventory = playerInventory,
            hotbar = hotbarItems,
            maxSlots = InventoryConfig.MaxSlots,
            maxWeight = InventoryConfig.MaxWeight,
            currentWeight = weight
        })
        
        SetNuiFocus(true, true)
    end)
end

function CloseInventory()
    if not isOpen then return end
    isOpen = false
    
    SendNUIMessage({
        action = 'closeInventory'
    })
    
    SetNuiFocus(false, false)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- HOTBAR
-- ═══════════════════════════════════════════════════════════════════════════

function UpdateHotbarUI()
    SendNUIMessage({
        action = 'updateHotbar',
        hotbar = hotbarItems
    })
end

function UseHotbarSlot(slot)
    local item = hotbarItems[slot]
    if not item then return end
    
    if Inventory.IsWeapon(item.name) then
        EquipWeapon(item)
    else
        UseItem(item)
    end
end

function SetHotbarSlot(slot, item)
    TriggerServerEvent('vAvA_inventory:setHotbar', slot, item)
    hotbarItems[slot] = item
    UpdateHotbarUI()
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ARMES
-- ═══════════════════════════════════════════════════════════════════════════

function DisableWeaponWheel()
    CreateThread(function()
        while true do
            Wait(0)
            
            -- Désactiver les touches de la roue des armes
            DisableControlAction(0, 37, true)  -- TAB
            DisableControlAction(0, 157, true) -- Select next weapon
            DisableControlAction(0, 158, true) -- Select previous weapon
            DisableControlAction(0, 160, true) -- Select next weapon in slot
            DisableControlAction(0, 164, true) -- Select previous weapon in slot
            DisableControlAction(0, 165, true) -- Select melee
            
            -- Bloquer les armes non équipées via l'inventaire
            local ped = PlayerPedId()
            local currentWeaponHash = GetSelectedPedWeapon(ped)
            
            if currentWeaponHash ~= `WEAPON_UNARMED` then
                if not IsWeaponEquippedFromInventory(currentWeaponHash) then
                    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
                end
            end
        end
    end)
end

function IsWeaponEquippedFromInventory(weaponHash)
    if not currentWeapon then return false end
    local equippedHash = Inventory.GetWeaponHash(currentWeapon.name)
    return equippedHash == weaponHash
end

function EquipWeapon(item)
    local ped = PlayerPedId()
    local weaponName = string.upper(item.name)
    local weaponHash = joaat(weaponName)
    
    -- Si déjà équipé, déséquiper
    if currentWeapon and currentWeapon.name == item.name then
        UnequipWeapon()
        return
    end
    
    -- Vérifier les munitions si nécessaire
    local weaponData = Inventory.GetWeaponData(item.name)
    local ammoCount = 0
    
    if weaponData and weaponData.ammo and InventoryConfig.Weapons.requireAmmo then
        ammoCount = GetAmmoCount(weaponData.ammo)
        if ammoCount <= 0 then
            TriggerEvent('vAvA:notify', 'Vous n\'avez pas de munitions !', 'error')
            return
        end
    else
        ammoCount = 9999
    end
    
    -- Retirer l'arme actuelle
    if currentWeapon then
        UnequipWeapon()
    end
    
    -- Animation d'équipement
    local animData = InventoryConfig.Weapons.equipAnimations[weaponData and weaponData.category] or 
                     InventoryConfig.Weapons.equipAnimations.default
    
    if animData then
        RequestAnimDict(animData.dict)
        while not HasAnimDictLoaded(animData.dict) do Wait(10) end
        TaskPlayAnim(ped, animData.dict, animData.anim, 8.0, -8.0, animData.duration, 0, 0, false, false, false)
        Wait(animData.duration)
    end
    
    -- Donner l'arme
    GiveWeaponToPed(ped, weaponHash, ammoCount, false, true)
    SetCurrentPedWeapon(ped, weaponHash, true)
    
    currentWeapon = item
    weaponAmmo[weaponName] = ammoCount
    
    TriggerEvent('vAvA:notify', 'Arme équipée: ' .. (weaponData and weaponData.label or item.label), 'success')
end

function UnequipWeapon()
    local ped = PlayerPedId()
    
    if currentWeapon then
        local weaponHash = Inventory.GetWeaponHash(currentWeapon.name)
        
        -- Sauvegarder les munitions restantes
        local ammo = GetAmmoInPedWeapon(ped, weaponHash)
        if weaponAmmo[string.upper(currentWeapon.name)] then
            -- Sync munitions avec serveur
            local weaponData = Inventory.GetWeaponData(currentWeapon.name)
            if weaponData and weaponData.ammo then
                TriggerServerEvent('vAvA_inventory:syncAmmo', weaponData.ammo, ammo)
            end
        end
        
        RemoveWeaponFromPed(ped, weaponHash)
    end
    
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    currentWeapon = nil
end

function GetAmmoCount(ammoType)
    local count = 0
    for _, item in ipairs(playerInventory) do
        local ammoData = InventoryConfig.AmmoItems[string.lower(item.name)]
        if ammoData and ammoData.ammoType == ammoType then
            count = count + (item.amount * ammoData.count)
        end
    end
    return count
end

-- ═══════════════════════════════════════════════════════════════════════════
-- UTILISATION ITEMS
-- ═══════════════════════════════════════════════════════════════════════════

function UseItem(item)
    if not item then return end
    
    TriggerServerEvent('vAvA_inventory:useItem', item.slot, item.name)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- NUI CALLBACKS
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNUICallback('closeInventory', function(data, cb)
    CloseInventory()
    cb('ok')
end)

RegisterNUICallback('useItem', function(data, cb)
    local item = data.item
    if Inventory.IsWeapon(item.name) then
        EquipWeapon(item)
    else
        UseItem(item)
    end
    cb('ok')
end)

RegisterNUICallback('dropItem', function(data, cb)
    TriggerServerEvent('vAvA_inventory:dropItem', data.slot, data.amount)
    cb('ok')
end)

RegisterNUICallback('giveItem', function(data, cb)
    -- Trouver le joueur le plus proche
    local closestPlayer = GetClosestPlayer()
    if closestPlayer then
        TriggerServerEvent('vAvA_inventory:giveItem', GetPlayerServerId(closestPlayer), data.slot, data.amount)
    else
        TriggerEvent('vAvA:notify', 'Aucun joueur à proximité', 'error')
    end
    cb('ok')
end)

RegisterNUICallback('moveItem', function(data, cb)
    TriggerServerEvent('vAvA_inventory:moveItem', data.fromSlot, data.toSlot, data.amount)
    cb('ok')
end)

RegisterNUICallback('setHotbar', function(data, cb)
    SetHotbarSlot(data.slot, data.item)
    cb('ok')
end)

RegisterNUICallback('splitStack', function(data, cb)
    TriggerServerEvent('vAvA_inventory:splitStack', data.slot, data.amount)
    cb('ok')
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════════════════

function GetClosestPlayer()
    local players = GetActivePlayers()
    local closestPlayer = nil
    local closestDistance = 3.0
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    for _, player in ipairs(players) do
        if player ~= PlayerId() then
            local targetPed = GetPlayerPed(player)
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(playerCoords - targetCoords)
            
            if distance < closestDistance then
                closestDistance = distance
                closestPlayer = player
            end
        end
    end
    
    return closestPlayer
end

-- Callback helper
function TriggerServerCallback(name, cb, ...)
    local requestId = math.random(1, 999999)
    
    RegisterNetEvent('vAvA_inventory:callback:' .. requestId)
    AddEventHandler('vAvA_inventory:callback:' .. requestId, function(...)
        cb(...)
    end)
    
    TriggerServerEvent('vAvA_inventory:triggerCallback', name, requestId, ...)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EVENTS
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_inventory:refresh')
AddEventHandler('vAvA_inventory:refresh', function()
    LoadInventory()
end)

RegisterNetEvent('vAvA_inventory:updateInventory')
AddEventHandler('vAvA_inventory:updateInventory', function(inventory)
    playerInventory = inventory
    if isOpen then
        SendNUIMessage({
            action = 'updateInventory',
            inventory = playerInventory,
            currentWeight = Inventory.CalculateWeight(playerInventory)
        })
    end
end)

-- Export
exports('IsInventoryOpen', function()
    return isOpen
end)

exports('GetPlayerInventory', function()
    return playerInventory
end)

exports('GetCurrentWeapon', function()
    return currentWeapon
end)
