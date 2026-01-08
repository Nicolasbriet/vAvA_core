--[[
    vAvA_inventory - Client Main
    Version SANS THREADS - 100% basé sur events
]]

local isOpen = false
local playerInventory = {}
local hotbarItems = {}
local currentWeapon = nil

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMANDES
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('inventory', function() ToggleInventory() end, false)
RegisterCommand('inv', function() ToggleInventory() end, false)
RegisterKeyMapping('inventory', 'Ouvrir l\'inventaire', 'keyboard', 'F2')

-- Hotbar
RegisterCommand('hotbar1', function() TriggerServerEvent('vAvA_inventory:useHotbar', 1) end, false)
RegisterCommand('hotbar2', function() TriggerServerEvent('vAvA_inventory:useHotbar', 2) end, false)
RegisterCommand('hotbar3', function() TriggerServerEvent('vAvA_inventory:useHotbar', 3) end, false)
RegisterCommand('hotbar4', function() TriggerServerEvent('vAvA_inventory:useHotbar', 4) end, false)
RegisterCommand('hotbar5', function() TriggerServerEvent('vAvA_inventory:useHotbar', 5) end, false)

RegisterKeyMapping('hotbar1', 'Hotbar 1', 'keyboard', '1')
RegisterKeyMapping('hotbar2', 'Hotbar 2', 'keyboard', '2')
RegisterKeyMapping('hotbar3', 'Hotbar 3', 'keyboard', '3')
RegisterKeyMapping('hotbar4', 'Hotbar 4', 'keyboard', '4')
RegisterKeyMapping('hotbar5', 'Hotbar 5', 'keyboard', '5')

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
    SendNUIMessage({ action = 'updateHotbar', hotbar = hotbarItems })
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
