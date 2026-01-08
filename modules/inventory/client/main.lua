--[[
    vAvA_inventory - Client Main
    Version avec statuts faim/soif et désactivation weapon wheel
]]

local isOpen = false
local playerInventory = {}
local hotbarItems = {}
local currentWeapon = nil

-- Statuts joueur
local PlayerStatus = {
    hunger = 100,
    thirst = 100
}

-- ═══════════════════════════════════════════════════════════════════════════
-- DÉSACTIVER LA ROUE DES ARMES NATIVE
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(0)
        -- Bloquer la roue des armes (TAB par défaut)
        DisableControlAction(0, 37, true)  -- INPUT_SELECT_WEAPON (TAB)
        DisableControlAction(0, 157, true) -- INPUT_SELECT_WEAPON_UNARMED
        DisableControlAction(0, 158, true) -- INPUT_SELECT_WEAPON_MELEE
        DisableControlAction(0, 159, true) -- INPUT_SELECT_WEAPON_HANDGUN
        DisableControlAction(0, 160, true) -- INPUT_SELECT_WEAPON_SHOTGUN
        DisableControlAction(0, 161, true) -- INPUT_SELECT_WEAPON_SMG
        DisableControlAction(0, 162, true) -- INPUT_SELECT_WEAPON_AUTO_RIFLE
        DisableControlAction(0, 163, true) -- INPUT_SELECT_WEAPON_SNIPER
        DisableControlAction(0, 164, true) -- INPUT_SELECT_WEAPON_HEAVY
        DisableControlAction(0, 165, true) -- INPUT_SELECT_WEAPON_SPECIAL
        
        -- Bloquer le switch d'arme avec molette
        DisableControlAction(0, 14, true)  -- INPUT_WEAPON_WHEEL_NEXT
        DisableControlAction(0, 15, true)  -- INPUT_WEAPON_WHEEL_PREV
        DisableControlAction(0, 16, true)  -- INPUT_SELECT_NEXT_WEAPON
        DisableControlAction(0, 17, true)  -- INPUT_SELECT_PREV_WEAPON
        
        -- Cacher le HUD de sélection d'arme
        HideHudComponentThisFrame(19) -- WEAPON_WHEEL
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMANDES
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('inventory', function() ToggleInventory() end, false)
RegisterCommand('inv', function() ToggleInventory() end, false)
RegisterKeyMapping('inventory', 'Ouvrir l\'inventaire', 'keyboard', 'F2')

-- Hotbar - les touches 1-5 utilisent les items
RegisterCommand('hotbar1', function() UseHotbarItem(1) end, false)
RegisterCommand('hotbar2', function() UseHotbarItem(2) end, false)
RegisterCommand('hotbar3', function() UseHotbarItem(3) end, false)
RegisterCommand('hotbar4', function() UseHotbarItem(4) end, false)
RegisterCommand('hotbar5', function() UseHotbarItem(5) end, false)

RegisterKeyMapping('hotbar1', 'Utiliser Raccourci 1', 'keyboard', '1')
RegisterKeyMapping('hotbar2', 'Utiliser Raccourci 2', 'keyboard', '2')
RegisterKeyMapping('hotbar3', 'Utiliser Raccourci 3', 'keyboard', '3')
RegisterKeyMapping('hotbar4', 'Utiliser Raccourci 4', 'keyboard', '4')
RegisterKeyMapping('hotbar5', 'Utiliser Raccourci 5', 'keyboard', '5')

function UseHotbarItem(slot)
    if isOpen then return end -- Ne pas utiliser si inventaire ouvert
    TriggerServerEvent('vAvA_inventory:useHotbar', slot)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS PRINCIPALES
-- ═══════════════════════════════════════════════════════════════════════════

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
    TriggerServerEvent('vAvA_inventory:requestInventory')
end

function CloseInventory()
    if not isOpen then return end
    isOpen = false
    SendNUIMessage({ action = 'closeInventory' })
    SetNuiFocus(false, false)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ANIMATIONS CONSOMMABLES
-- ═══════════════════════════════════════════════════════════════════════════

local isConsuming = false

function PlayEatAnimation(callback)
    if isConsuming then return end
    isConsuming = true
    
    local ped = PlayerPedId()
    
    -- Charger l'animation
    RequestAnimDict("mp_player_inteat@burger")
    while not HasAnimDictLoaded("mp_player_inteat@burger") do Wait(10) end
    
    -- Créer le prop (burger)
    local prop = CreateObject(GetHashKey("prop_cs_burger_01"), 0, 0, 0, true, true, true)
    local boneIndex = GetPedBoneIndex(ped, 18905) -- Main droite
    AttachEntityToEntity(prop, ped, boneIndex, 0.13, 0.05, 0.02, -50.0, 16.0, 60.0, true, true, false, true, 1, true)
    
    -- Jouer l'animation
    TaskPlayAnim(ped, "mp_player_inteat@burger", "mp_player_int_eat_burger", 8.0, -8.0, 3000, 49, 0, false, false, false)
    
    Wait(3000)
    
    -- Nettoyer
    DeleteObject(prop)
    ClearPedTasks(ped)
    isConsuming = false
    
    if callback then callback() end
end

function PlayDrinkAnimation(callback)
    if isConsuming then return end
    isConsuming = true
    
    local ped = PlayerPedId()
    
    -- Charger l'animation
    RequestAnimDict("mp_player_intdrink")
    while not HasAnimDictLoaded("mp_player_intdrink") do Wait(10) end
    
    -- Créer le prop (bouteille)
    local prop = CreateObject(GetHashKey("prop_ld_flow_bottle"), 0, 0, 0, true, true, true)
    local boneIndex = GetPedBoneIndex(ped, 18905) -- Main droite
    AttachEntityToEntity(prop, ped, boneIndex, 0.12, 0.028, 0.001, 10.0, 175.0, 0.0, true, true, false, true, 1, true)
    
    -- Jouer l'animation
    TaskPlayAnim(ped, "mp_player_intdrink", "loop_bottle", 8.0, -8.0, 3000, 49, 0, false, false, false)
    
    Wait(3000)
    
    -- Nettoyer
    DeleteObject(prop)
    ClearPedTasks(ped)
    isConsuming = false
    
    if callback then callback() end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EVENTS SERVEUR
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_inventory:open')
AddEventHandler('vAvA_inventory:open', function(data)
    playerInventory = data.inventory or {}
    hotbarItems = data.hotbar or {}
    
    SendNUIMessage({
        action = 'openInventory',
        inventory = playerInventory,
        hotbar = hotbarItems,
        maxSlots = data.maxSlots or 50,
        maxWeight = data.maxWeight or 120,
        currentWeight = data.weight or 0
    })
    
    SetNuiFocus(true, true)
end)

RegisterNetEvent('vAvA_inventory:updateInventory')
AddEventHandler('vAvA_inventory:updateInventory', function(inventory, weight)
    playerInventory = inventory or {}
    if isOpen then
        SendNUIMessage({
            action = 'updateInventory',
            inventory = playerInventory,
            currentWeight = weight or 0
        })
    end
end)

RegisterNetEvent('vAvA_inventory:updateHotbar')
AddEventHandler('vAvA_inventory:updateHotbar', function(hotbar)
    hotbarItems = hotbar or {}
end)

RegisterNetEvent('vAvA_inventory:equipWeapon')
AddEventHandler('vAvA_inventory:equipWeapon', function(weaponName, ammo)
    local ped = PlayerPedId()
    local hash = joaat(string.upper(weaponName))
    
    if currentWeapon then
        RemoveWeaponFromPed(ped, joaat(string.upper(currentWeapon)))
    end
    
    GiveWeaponToPed(ped, hash, ammo or 100, false, true)
    SetCurrentPedWeapon(ped, hash, true)
    currentWeapon = weaponName
end)

RegisterNetEvent('vAvA_inventory:unequipWeapon')
AddEventHandler('vAvA_inventory:unequipWeapon', function()
    local ped = PlayerPedId()
    if currentWeapon then
        RemoveWeaponFromPed(ped, joaat(string.upper(currentWeapon)))
        currentWeapon = nil
    end
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
end)

-- Consommer nourriture (remonte faim)
RegisterNetEvent('vAvA_inventory:consumeFood')
AddEventHandler('vAvA_inventory:consumeFood', function(amount)
    -- Fermer l'inventaire d'abord
    CloseInventory()
    
    -- Jouer l'animation
    PlayEatAnimation(function()
        PlayerStatus.hunger = math.min(100, PlayerStatus.hunger + (amount or 25))
        TriggerEvent('vAvA_inventory:notify', 'Faim restaurée: ' .. PlayerStatus.hunger .. '%', 'success')
    end)
end)

-- Consommer boisson (remonte soif)
RegisterNetEvent('vAvA_inventory:consumeDrink')
AddEventHandler('vAvA_inventory:consumeDrink', function(amount)
    -- Fermer l'inventaire d'abord
    CloseInventory()
    
    -- Jouer l'animation
    PlayDrinkAnimation(function()
        PlayerStatus.thirst = math.min(100, PlayerStatus.thirst + (amount or 25))
        TriggerEvent('vAvA_inventory:notify', 'Soif restaurée: ' .. PlayerStatus.thirst .. '%', 'success')
    end)
end)

RegisterNetEvent('vAvA_inventory:notify')
AddEventHandler('vAvA_inventory:notify', function(msg, type)
    TriggerEvent('chat:addMessage', { args = { msg } })
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- NUI CALLBACKS
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNUICallback('closeInventory', function(_, cb) CloseInventory() cb('ok') end)
RegisterNUICallback('useItem', function(data, cb) TriggerServerEvent('vAvA_inventory:useItem', data.slot) cb('ok') end)
RegisterNUICallback('dropItem', function(data, cb) TriggerServerEvent('vAvA_inventory:dropItem', data.slot, data.amount) cb('ok') end)
RegisterNUICallback('moveItem', function(data, cb) TriggerServerEvent('vAvA_inventory:moveItem', data.fromSlot, data.toSlot, data.amount) cb('ok') end)
RegisterNUICallback('setHotbar', function(data, cb) TriggerServerEvent('vAvA_inventory:setHotbar', data.slot, data.itemSlot) cb('ok') end)
RegisterNUICallback('splitStack', function(data, cb) TriggerServerEvent('vAvA_inventory:splitStack', data.slot, data.amount) cb('ok') end)

RegisterNUICallback('giveItem', function(data, cb)
    local closestPlayer, distance = GetClosestPlayer()
    if closestPlayer then
        TriggerServerEvent('vAvA_inventory:giveItem', GetPlayerServerId(closestPlayer), data.slot, data.amount)
    else
        TriggerEvent('vAvA_inventory:notify', 'Aucun joueur à proximité', 'error')
    end
    cb('ok')
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════════════════

function GetClosestPlayer()
    local players = GetActivePlayers()
    local closestPlayer, closestDistance = nil, 3.0
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    
    for _, player in ipairs(players) do
        if player ~= PlayerId() then
            local dist = #(myCoords - GetEntityCoords(GetPlayerPed(player)))
            if dist < closestDistance then
                closestDistance, closestPlayer = dist, player
            end
        end
    end
    return closestPlayer, closestDistance
end

exports('IsInventoryOpen', function() return isOpen end)
exports('GetPlayerInventory', function() return playerInventory end)
exports('GetHunger', function() return PlayerStatus.hunger end)
exports('GetThirst', function() return PlayerStatus.thirst end)
exports('SetHunger', function(v) PlayerStatus.hunger = math.max(0, math.min(100, v)) end)
exports('SetThirst', function(v) PlayerStatus.thirst = math.max(0, math.min(100, v)) end)
