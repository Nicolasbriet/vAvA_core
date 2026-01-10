--[[
    vAvA_core - Client Main
    Point d'entrée principal côté client
]]

vCore = vCore or {}
vCore.PlayerData = {}
vCore.IsLoaded = false

-- ═══════════════════════════════════════════════════════════════════════════
-- INITIALISATION
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(0)
        if NetworkIsSessionStarted() then
            break
        end
    end
    
    vCore.Utils.Print('Client initialisé')
    
    -- Attendre le chargement du spawn
    Wait(1000)
    
    -- Déclencher le chargement
    TriggerEvent('vCore:clientReady')
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

---Retourne les données du joueur
---@return table
exports('GetPlayerData', function()
    return vCore.PlayerData
end)

---Retourne l'objet vCore
---@return table
exports('GetCoreObject', function()
    return vCore
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS GLOBALES
-- ═══════════════════════════════════════════════════════════════════════════

---Retourne les données du joueur
---@return table
function vCore.GetPlayerData()
    return vCore.PlayerData
end

---Vérifie si le joueur est chargé
---@return boolean
function vCore.IsPlayerLoaded()
    return vCore.IsLoaded
end

---Retourne le ped du joueur
---@return number
function vCore.GetPed()
    return PlayerPedId()
end

---Retourne les coordonnées du joueur
---@return vector3
function vCore.GetCoords()
    return GetEntityCoords(PlayerPedId())
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENT DE CHARGEMENT
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vCore:playerLoaded', function(playerData)
    vCore.PlayerData = playerData
    vCore.IsLoaded = true
    
    vCore.Utils.Print('Données joueur chargées:', playerData.firstName, playerData.lastName)
    
    -- Spawn le joueur
    local spawn = playerData.position or Config.Players.DefaultSpawn
    
    DoScreenFadeOut(500)
    Wait(500)
    
    local ped = PlayerPedId()
    
    SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, true)
    SetEntityHeading(ped, spawn.heading or 0.0)
    
    FreezeEntityPosition(ped, false)
    SetPlayerInvincible(PlayerId(), false)
    
    Wait(500)
    DoScreenFadeIn(500)
    
    -- Notification de bienvenue
    vCore.Notify(Lang('welcome', Config.ServerName), 'success')
    
    -- Initialiser le HUD avec les données du joueur
    Wait(1000)
    TriggerEvent('vAvA:initHUD')
    
    -- Déclencher l'événement de spawn
    TriggerEvent(vCore.Events.PLAYER_SPAWNED, playerData)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- MISE À JOUR DES DONNÉES
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent(vCore.Events.MONEY_ADDED, function(moneyType, amount)
    if vCore.PlayerData.money then
        vCore.PlayerData.money[moneyType] = (vCore.PlayerData.money[moneyType] or 0) + amount
        
        -- Mettre à jour le HUD
        TriggerEvent('vAvA:setMoney', vCore.PlayerData.money)
    end
end)

RegisterNetEvent(vCore.Events.MONEY_REMOVED, function(moneyType, amount)
    if vCore.PlayerData.money then
        vCore.PlayerData.money[moneyType] = (vCore.PlayerData.money[moneyType] or 0) - amount
        
        -- Mettre à jour le HUD
        TriggerEvent('vAvA:setMoney', vCore.PlayerData.money)
    end
end)

RegisterNetEvent(vCore.Events.MONEY_SET, function(moneyType, amount)
    if vCore.PlayerData.money then
        vCore.PlayerData.money[moneyType] = amount
        
        -- Mettre à jour le HUD
        TriggerEvent('vAvA:setMoney', vCore.PlayerData.money)
    end
end)

RegisterNetEvent(vCore.Events.JOB_CHANGED, function(job)
    vCore.PlayerData.job = job
    
    -- Mettre à jour le HUD
    TriggerEvent('vAvA:setJob', job)
end)

RegisterNetEvent(vCore.Events.JOB_DUTY_CHANGED, function(onDuty)
    vCore.PlayerData.onDuty = onDuty
end)

RegisterNetEvent(vCore.Events.STATUS_UPDATED, function(statusType, value)
    if vCore.PlayerData.status then
        vCore.PlayerData.status[statusType] = value
    else
        vCore.PlayerData.status = {}
        vCore.PlayerData.status[statusType] = value
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMANDES ADMIN
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vCore:teleport', function(x, y, z)
    local ped = PlayerPedId()
    SetEntityCoords(ped, x, y, z, false, false, false, true)
end)

RegisterNetEvent('vCore:heal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 100)
end)

RegisterNetEvent('vCore:revive', function()
    local ped = PlayerPedId()
    
    local coords = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 0)
    ClearPedBloodDamage(ped)
end)

RegisterNetEvent('vCore:spawnVehicleAdmin', function(model)
    local hash = GetHashKey(model)
    
    if not IsModelInCdimage(hash) then
        vCore.Notify('Modèle invalide', 'error')
        return
    end
    
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(10)
    end
    
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    
    local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, heading, true, false)
    
    SetPedIntoVehicle(ped, vehicle, -1)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetEntityAsNoLongerNeeded(vehicle)
    SetModelAsNoLongerNeeded(hash)
    
    vCore.Notify('Véhicule spawné', 'success')
end)

RegisterNetEvent('vCore:deleteVehicle', function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    if vehicle == 0 then
        vehicle = GetClosestVehicle(GetEntityCoords(ped).x, GetEntityCoords(ped).y, GetEntityCoords(ped).z, 5.0, 0, 70)
    end
    
    if vehicle ~= 0 then
        DeleteEntity(vehicle)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- SAUVEGARDE POSITION
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(60000) -- Toutes les minutes
        
        if vCore.IsLoaded then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            
            TriggerServerEvent('vCore:updatePosition', coords, heading)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- RESSOURCE STOP
-- ═══════════════════════════════════════════════════════════════════════════

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    
    -- Sauvegarder avant arrêt
    if vCore.IsLoaded then
        TriggerServerEvent('vCore:savePlayer')
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMANDES ADMIN (Events)
-- ═══════════════════════════════════════════════════════════════════════════

-- Téléportation simple
RegisterNetEvent('vCore:teleport', function(x, y, z)
    local ped = PlayerPedId()
    SetEntityCoords(ped, x, y, z, false, false, false, false)
    vCore.ShowNotification('Téléporté', 'success')
end)

-- Téléportation au marker
RegisterNetEvent('vCore:teleportToMarker', function()
    local waypoint = GetFirstBlipInfoId(8)
    if not DoesBlipExist(waypoint) then
        vCore.ShowNotification('Aucun marker placé', 'error')
        return
    end
    
    local coords = GetBlipCoords(waypoint)
    local ped = PlayerPedId()
    
    -- Trouver le sol
    local found, z = GetGroundZFor_3dCoord(coords.x, coords.y, 1000.0, false)
    if found then
        coords = vector3(coords.x, coords.y, z)
    end
    
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    vCore.ShowNotification('Téléporté au marker', 'success')
end)

-- Spawn véhicule admin
RegisterNetEvent('vCore:spawnVehicleAdmin', function(model)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    
    -- Charger le modèle
    local modelHash = GetHashKey(model)
    if not IsModelInCdimage(modelHash) or not IsModelAVehicle(modelHash) then
        vCore.ShowNotification('Modèle de véhicule invalide', 'error')
        return
    end
    
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(10)
    end
    
    -- Spawn
    local vehicle = CreateVehicle(modelHash, coords.x + 2.0, coords.y + 2.0, coords.z, heading, true, false)
    SetPedIntoVehicle(ped, vehicle, -1)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetVehicleNumberPlateText(vehicle, 'ADMIN')
    
    -- Custom properties
    SetVehicleModKit(vehicle, 0)
    SetVehicleMod(vehicle, 11, 3, false) -- Moteur Max
    SetVehicleMod(vehicle, 12, 2, false) -- Freins Max
    SetVehicleMod(vehicle, 13, 2, false) -- Transmission Max
    ToggleVehicleMod(vehicle, 18, true)  -- Turbo
    
    SetModelAsNoLongerNeeded(modelHash)
    vCore.ShowNotification('Véhicule spawné: ' .. model, 'success')
end)

-- Delete véhicule
RegisterNetEvent('vCore:deleteVehicle', function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    if vehicle == 0 then
        vCore.ShowNotification('Vous n\'êtes pas dans un véhicule', 'error')
        return
    end
    
    DeleteVehicle(vehicle)
    vCore.ShowNotification('Véhicule supprimé', 'success')
end)

-- Heal
RegisterNetEvent('vCore:heal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    vCore.ShowNotification('Soigné', 'success')
end)

-- Revive
RegisterNetEvent('vCore:revive', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedTasksImmediately(ped)
    
    vCore.ShowNotification('Réanimé', 'success')
end)

-- Freeze
RegisterNetEvent('vCore:freeze', function(state)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, state)
    
    if state then
        vCore.ShowNotification('Vous avez été gelé', 'error')
    else
        vCore.ShowNotification('Vous avez été dégelé', 'success')
    end
end)

-- Météo
RegisterNetEvent('vCore:setWeather', function(weather)
    SetWeatherTypeNowPersist(weather)
    vCore.ShowNotification('Météo: ' .. weather, 'info')
end)

-- Heure
RegisterNetEvent('vCore:setTime', function(hour, minute)
    NetworkOverrideClockTime(hour, minute, 0)
    vCore.ShowNotification(string.format('Heure: %02d:%02d', hour, minute), 'info')
end)

print('[vAvA_core] ^2✓^7 Client admin events loaded')
