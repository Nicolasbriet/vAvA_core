--[[
    vAvA_core - Client Vehicles
    Gestion des véhicules côté client
]]

vCore = vCore or {}
vCore.Vehicles = {}

-- Véhicules spawnés
local spawnedVehicles = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- SPAWN VÉHICULE
-- ═══════════════════════════════════════════════════════════════════════════

---Spawn un véhicule
---@param model string
---@param coords vector3
---@param heading number
---@param callback? function
function vCore.Vehicles.Spawn(model, coords, heading, callback)
    local hash = type(model) == 'string' and GetHashKey(model) or model
    
    if not IsModelInCdimage(hash) then
        vCore.Notify('Modèle invalide', 'error')
        return
    end
    
    RequestModel(hash)
    
    local timeout = 5000
    while not HasModelLoaded(hash) and timeout > 0 do
        Wait(10)
        timeout = timeout - 10
    end
    
    if not HasModelLoaded(hash) then
        vCore.Notify('Impossible de charger le modèle', 'error')
        return
    end
    
    local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, heading, true, false)
    
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetVehRadioStation(vehicle, 'OFF')
    SetVehicleFuelLevel(vehicle, 100.0)
    SetModelAsNoLongerNeeded(hash)
    
    if callback then
        callback(vehicle)
    end
    
    return vehicle
end

---Spawn un véhicule et place le joueur dedans
---@param model string
---@param coords vector3
---@param heading number
---@param callback? function
function vCore.Vehicles.SpawnAndEnter(model, coords, heading, callback)
    local vehicle = vCore.Vehicles.Spawn(model, coords, heading, function(veh)
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
        
        if callback then
            callback(veh)
        end
    end)
    
    return vehicle
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SPAWN DEPUIS GARAGE
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vCore:doSpawnVehicle', function(vehicleData)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    
    -- Trouver un spawn point
    local spawnCoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 5.0, 0.0)
    
    vCore.Vehicles.Spawn(vehicleData.model, spawnCoords, heading, function(vehicle)
        -- Appliquer les propriétés sauvegardées
        if vehicleData.props then
            local props = json.decode(vehicleData.props)
            if props then
                SetVehicleProperties(vehicle, props)
            end
        end
        
        -- Définir la plaque
        SetVehicleNumberPlateText(vehicle, vehicleData.plate)
        
        -- Carburant
        if vehicleData.fuel then
            SetVehicleFuelLevel(vehicle, vehicleData.fuel + 0.0)
        end
        
        -- État
        if vehicleData.body then
            SetVehicleBodyHealth(vehicle, vehicleData.body + 0.0)
        end
        if vehicleData.engine then
            SetVehicleEngineHealth(vehicle, vehicleData.engine + 0.0)
        end
        
        -- Stocker le véhicule
        spawnedVehicles[vehicleData.plate] = vehicle
        
        -- Monter dedans
        TaskWarpPedIntoVehicle(ped, vehicle, -1)
        
        vCore.Notify(Lang('vehicle_spawned'), 'success')
        
        TriggerEvent(vCore.Events.VEHICLE_SPAWNED, vehicle, vehicleData.plate)
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS VÉHICULE
-- ═══════════════════════════════════════════════════════════════════════════

---Retourne les propriétés d'un véhicule
---@param vehicle number
---@return table
function vCore.Vehicles.GetProperties(vehicle)
    if not DoesEntityExist(vehicle) then return {} end
    
    local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
    local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)
    local plateIndex = GetVehicleNumberPlateTextIndex(vehicle)
    
    local extras = {}
    for i = 0, 12 do
        if DoesExtraExist(vehicle, i) then
            extras[tostring(i)] = IsVehicleExtraTurnedOn(vehicle, i)
        end
    end
    
    local mods = {}
    for i = 0, 49 do
        mods[i] = GetVehicleMod(vehicle, i)
    end
    
    return {
        model = GetEntityModel(vehicle),
        plate = GetVehicleNumberPlateText(vehicle),
        plateIndex = plateIndex,
        
        bodyHealth = GetVehicleBodyHealth(vehicle),
        engineHealth = GetVehicleEngineHealth(vehicle),
        tankHealth = GetVehiclePetrolTankHealth(vehicle),
        
        fuelLevel = GetVehicleFuelLevel(vehicle),
        dirtLevel = GetVehicleDirtLevel(vehicle),
        
        color1 = colorPrimary,
        color2 = colorSecondary,
        pearlescentColor = pearlescentColor,
        wheelColor = wheelColor,
        
        wheels = GetVehicleWheelType(vehicle),
        windowTint = GetVehicleWindowTint(vehicle),
        
        neonEnabled = {
            IsVehicleNeonLightEnabled(vehicle, 0),
            IsVehicleNeonLightEnabled(vehicle, 1),
            IsVehicleNeonLightEnabled(vehicle, 2),
            IsVehicleNeonLightEnabled(vehicle, 3)
        },
        neonColor = table.pack(GetVehicleNeonLightsColour(vehicle)),
        
        extras = extras,
        mods = mods,
        
        livery = GetVehicleLivery(vehicle),
        
        xenonColor = GetVehicleXenonLightsColour(vehicle),
        
        tyreSmokeColor = table.pack(GetVehicleTyreSmokeColor(vehicle))
    }
end

---Applique des propriétés à un véhicule
---@param vehicle number
---@param props table
function vCore.Vehicles.SetProperties(vehicle, props)
    if not DoesEntityExist(vehicle) then return end
    
    SetVehicleModKit(vehicle, 0)
    
    if props.plate then
        SetVehicleNumberPlateText(vehicle, props.plate)
    end
    if props.plateIndex then
        SetVehicleNumberPlateTextIndex(vehicle, props.plateIndex)
    end
    
    if props.bodyHealth then
        SetVehicleBodyHealth(vehicle, props.bodyHealth + 0.0)
    end
    if props.engineHealth then
        SetVehicleEngineHealth(vehicle, props.engineHealth + 0.0)
    end
    if props.tankHealth then
        SetVehiclePetrolTankHealth(vehicle, props.tankHealth + 0.0)
    end
    
    if props.fuelLevel then
        SetVehicleFuelLevel(vehicle, props.fuelLevel + 0.0)
    end
    if props.dirtLevel then
        SetVehicleDirtLevel(vehicle, props.dirtLevel + 0.0)
    end
    
    if props.color1 and props.color2 then
        SetVehicleColours(vehicle, props.color1, props.color2)
    end
    if props.pearlescentColor and props.wheelColor then
        SetVehicleExtraColours(vehicle, props.pearlescentColor, props.wheelColor)
    end
    
    if props.wheels then
        SetVehicleWheelType(vehicle, props.wheels)
    end
    if props.windowTint then
        SetVehicleWindowTint(vehicle, props.windowTint)
    end
    
    if props.neonEnabled then
        for i = 1, 4 do
            SetVehicleNeonLightEnabled(vehicle, i - 1, props.neonEnabled[i])
        end
    end
    if props.neonColor then
        SetVehicleNeonLightsColour(vehicle, props.neonColor[1], props.neonColor[2], props.neonColor[3])
    end
    
    if props.extras then
        for id, enabled in pairs(props.extras) do
            SetVehicleExtra(vehicle, tonumber(id), not enabled)
        end
    end
    
    if props.mods then
        for modType, modIndex in pairs(props.mods) do
            SetVehicleMod(vehicle, tonumber(modType), modIndex, false)
        end
    end
    
    if props.livery then
        SetVehicleLivery(vehicle, props.livery)
    end
    
    if props.xenonColor then
        SetVehicleXenonLightsColour(vehicle, props.xenonColor)
    end
    
    if props.tyreSmokeColor then
        SetVehicleTyreSmokeColor(vehicle, props.tyreSmokeColor[1], props.tyreSmokeColor[2], props.tyreSmokeColor[3])
    end
end

-- Fonction globale pour compatibilité
SetVehicleProperties = vCore.Vehicles.SetProperties
GetVehicleProperties = vCore.Vehicles.GetProperties

-- ═══════════════════════════════════════════════════════════════════════════
-- CLÉS VÉHICULE
-- ═══════════════════════════════════════════════════════════════════════════

---Verrouille/Déverrouille le véhicule
function vCore.Vehicles.ToggleLock()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, true)
    
    if vehicle == 0 then
        vehicle = GetClosestVehicle(GetEntityCoords(ped).x, GetEntityCoords(ped).y, GetEntityCoords(ped).z, 5.0, 0, 70)
    end
    
    if vehicle == 0 then return end
    
    local plate = GetVehicleNumberPlateText(vehicle)
    local isLocked = GetVehicleDoorLockStatus(vehicle) == 2
    
    if isLocked then
        SetVehicleDoorsLocked(vehicle, 1)
        vCore.Notify(Lang('vehicle_unlocked'), 'info')
    else
        SetVehicleDoorsLocked(vehicle, 2)
        vCore.Notify(Lang('vehicle_locked'), 'info')
    end
    
    -- Animation
    TaskPlayAnim(ped, 'anim@mp_player_intmenu@key_fob@', 'fob_click', 8.0, 8.0, -1, 48, 1, false, false, false)
    
    Wait(500)
    ClearPedTasks(ped)
end

-- Keybind verrouillage (U)
RegisterCommand('+lockVehicle', function()
    if vCore.IsLoaded then
        vCore.Vehicles.ToggleLock()
    end
end, false)

RegisterKeyMapping('+lockVehicle', 'Verrouiller/Déverrouiller véhicule', 'keyboard', 'U')

-- ═══════════════════════════════════════════════════════════════════════════
-- MOTEUR VÉHICULE
-- ═══════════════════════════════════════════════════════════════════════════

---Toggle le moteur
function vCore.Vehicles.ToggleEngine()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    if vehicle == 0 then return end
    if GetPedInVehicleSeat(vehicle, -1) ~= ped then return end
    
    local isRunning = GetIsVehicleEngineRunning(vehicle)
    
    SetVehicleEngineOn(vehicle, not isRunning, false, true)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SAUVEGARDE VÉHICULE
-- ═══════════════════════════════════════════════════════════════════════════

-- Sauvegarder les props du véhicule régulièrement
CreateThread(function()
    while true do
        Wait(30000) -- Toutes les 30 secondes
        
        if vCore.IsLoaded then
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)
            
            if vehicle ~= 0 then
                local plate = GetVehicleNumberPlateText(vehicle)
                local props = vCore.Vehicles.GetProperties(vehicle)
                local fuel = GetVehicleFuelLevel(vehicle)
                local body = GetVehicleBodyHealth(vehicle)
                local engine = GetVehicleEngineHealth(vehicle)
                
                TriggerServerEvent('vCore:updateVehicleProps', plate, props, fuel, body, engine)
            end
        end
    end
end)
