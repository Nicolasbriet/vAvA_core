--[[
    vAvA Core - Module Persist
    Client-side
]]

local vCore = nil
local PlayerData = {}
local trackedVehicles = {}
local appliedMods = {}
local locationBlips = {}

-- Initialisation du framework
CreateThread(function()
    TriggerEvent('vCore:getSharedObject', function(obj) vCore = obj end)
    
    if not vCore then
        local success, result = pcall(function()
            return exports['vAvA_core']:GetCoreObject()
        end)
        if success then
            vCore = result
        end
    end
    
    Wait(2000)
    
    if vCore and vCore.Functions and vCore.Functions.GetPlayerData then
        PlayerData = vCore.Functions.GetPlayerData()
    end
    
    -- Demander les véhicules persistants
    TriggerServerEvent('vCore:persist:requestVehicles')
end)

-- ================================
-- FONCTIONS UTILITAIRES
-- ================================

local function DebugLog(msg)
    if PersistConfig.Debug then
        print('[vAvA Core - Persist] ' .. tostring(msg))
    end
end

local function NormalizePlate(plate)
    if not plate then return nil end
    return string.upper(string.gsub(tostring(plate), "%s+", ""))
end

local function Notify(message, type)
    if GetResourceState('ox_lib') == 'started' then
        exports.ox_lib:notify({
            title = 'Véhicule',
            description = message,
            type = type or 'info'
        })
    else
        TriggerEvent('vCore:notification', message, type)
    end
end

-- ================================
-- PROTECTION ANTI-NPC
-- ================================

local function IsPlayerVehicle(entity, plate)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return false
    end
    
    -- Véhicules joueurs sont toujours "mission entity"
    if not IsEntityAMissionEntity(entity) then
        return false
    end
    
    -- Vérifier state bag
    local stateBag = Entity(entity).state
    if stateBag.isPlayerVehicle == false then
        return false
    end
    
    -- Vérifier si networké
    if not NetworkGetEntityIsNetworked(entity) then
        return false
    end
    
    return true
end

-- ================================
-- STATE BAGS HANDLERS
-- ================================

if PersistConfig.StateBags.engine then
    AddStateBagChangeHandler('engine', nil, function(bagName, key, value)
        if not value then return end
        local entity = GetEntityFromStateBagName(bagName)
        if not entity or entity == 0 then return end
        
        local plate = DoesEntityExist(entity) and IsEntityAVehicle(entity) and GetVehicleNumberPlateText(entity) or nil
        if not IsPlayerVehicle(entity, plate) then return end
        
        if DoesEntityExist(entity) then
            SetVehicleEngineHealth(entity, value + 0.0)
            DebugLog('Engine appliqué: ' .. (plate or 'UNKNOWN'))
        end
    end)
end

if PersistConfig.StateBags.body then
    AddStateBagChangeHandler('body', nil, function(bagName, key, value)
        if not value then return end
        local entity = GetEntityFromStateBagName(bagName)
        if not entity or entity == 0 then return end
        
        local plate = DoesEntityExist(entity) and IsEntityAVehicle(entity) and GetVehicleNumberPlateText(entity) or nil
        if not IsPlayerVehicle(entity, plate) then return end
        
        if DoesEntityExist(entity) then
            SetVehicleBodyHealth(entity, value + 0.0)
            DebugLog('Body appliqué: ' .. (plate or 'UNKNOWN'))
        end
    end)
end

if PersistConfig.StateBags.mods then
    AddStateBagChangeHandler('mods', nil, function(bagName, key, value)
        if not value then return end
        
        Wait(500)
        
        local entity = GetEntityFromStateBagName(bagName)
        if not entity or entity == 0 then return end
        
        local plate = DoesEntityExist(entity) and IsEntityAVehicle(entity) and GetVehicleNumberPlateText(entity) or nil
        if not IsPlayerVehicle(entity, plate) then return end
        
        -- Éviter doublons
        if plate and appliedMods[plate] and appliedMods[plate].entity == entity then
            return
        end
        
        -- Attendre synchronisation
        local retries = 0
        while retries < 50 and (not DoesEntityExist(entity) or not IsEntityAVehicle(entity) or not NetworkGetEntityIsNetworked(entity)) do
            Wait(100)
            retries = retries + 1
        end
        
        if not DoesEntityExist(entity) or not IsEntityAVehicle(entity) then return end
        
        -- Demander contrôle réseau
        if not NetworkHasControlOfEntity(entity) then
            NetworkRequestControlOfEntity(entity)
            local controlRetries = 0
            while not NetworkHasControlOfEntity(entity) and controlRetries < 30 do
                Wait(100)
                controlRetries = controlRetries + 1
            end
        end
        
        if not NetworkHasControlOfEntity(entity) then return end
        
        Wait(300)
        
        -- Appliquer les mods
        ApplyVehicleMods(entity, value)
        
        if plate then
            appliedMods[plate] = { entity = entity, time = GetGameTimer() }
            DebugLog('Mods appliqués: ' .. plate)
        end
    end)
end

-- ================================
-- APPLICATION DES MODS
-- ================================

function ApplyVehicleMods(entity, mods)
    if not DoesEntityExist(entity) or not mods then return end
    
    -- Couleurs customs
    if mods.customPrimaryColor then 
        SetVehicleCustomPrimaryColour(entity, mods.customPrimaryColor[1], mods.customPrimaryColor[2], mods.customPrimaryColor[3]) 
    end
    if mods.customSecondaryColor then 
        SetVehicleCustomSecondaryColour(entity, mods.customSecondaryColor[1], mods.customSecondaryColor[2], mods.customSecondaryColor[3]) 
    end
    
    -- Couleurs standards
    if mods.color1 and type(mods.color1) == 'number' then 
        local color2 = type(mods.color2) == 'number' and mods.color2 or mods.color1
        SetVehicleColours(entity, mods.color1, color2) 
    end
    
    if mods.pearlescentColor and type(mods.pearlescentColor) == 'number' then 
        local wheelColor = type(mods.wheelColor) == 'number' and mods.wheelColor or 0
        SetVehicleExtraColours(entity, mods.pearlescentColor, wheelColor) 
    end
    
    -- Mods performance
    SetVehicleModKit(entity, 0)
    if mods.modEngine then SetVehicleMod(entity, 11, mods.modEngine, false) end
    if mods.modBrakes then SetVehicleMod(entity, 12, mods.modBrakes, false) end
    if mods.modTransmission then SetVehicleMod(entity, 13, mods.modTransmission, false) end
    if mods.modSuspension then SetVehicleMod(entity, 15, mods.modSuspension, false) end
    if mods.modArmor then SetVehicleMod(entity, 16, mods.modArmor, false) end
    
    -- Mods toggleables
    if mods.modTurbo ~= nil then ToggleVehicleMod(entity, 18, mods.modTurbo) end
    if mods.modXenon ~= nil then
        ToggleVehicleMod(entity, 22, mods.modXenon)
        if mods.xenonColor and mods.modXenon then
            SetVehicleXenonLightsColor(entity, mods.xenonColor)
        end
    end
    if mods.modSmokeEnabled ~= nil then ToggleVehicleMod(entity, 20, mods.modSmokeEnabled) end
    
    -- Visuels
    if mods.modLivery and mods.modLivery ~= -1 then SetVehicleLivery(entity, mods.modLivery) end
    if mods.windowTint then SetVehicleWindowTint(entity, mods.windowTint) end
    if mods.plateIndex then SetVehicleNumberPlateTextIndex(entity, mods.plateIndex) end
    
    -- Jantes
    if mods.wheels and type(mods.wheels) == "table" then
        if mods.wheels.type then SetVehicleWheelType(entity, mods.wheels.type) end
        if mods.modFrontWheels then SetVehicleMod(entity, 23, mods.modFrontWheels, mods.wheels.custom or false) end
        if mods.modBackWheels then SetVehicleMod(entity, 24, mods.modBackWheels, mods.wheels.custom or false) end
    end
    
    -- Néons
    if mods.neonEnabled then
        SetVehicleNeonLightEnabled(entity, 0, mods.neonEnabled[1] or false)
        SetVehicleNeonLightEnabled(entity, 1, mods.neonEnabled[2] or false)
        SetVehicleNeonLightEnabled(entity, 2, mods.neonEnabled[3] or false)
        SetVehicleNeonLightEnabled(entity, 3, mods.neonEnabled[4] or false)
    end
    if mods.neonColor then
        SetVehicleNeonLightsColour(entity, mods.neonColor[1], mods.neonColor[2], mods.neonColor[3])
    end
end

-- ================================
-- RÉCEPTION DES VÉHICULES PERSISTANTS
-- ================================

RegisterNetEvent('vCore:persist:receiveVehicles', function(vehicles)
    if not vehicles then return end
    
    DebugLog('Réception de ' .. #vehicles .. ' véhicules persistants')
    
    for _, v in ipairs(vehicles) do
        if v.parking and v.vehicle then
            -- Les véhicules seront spawnés par le garage ou autre système
            trackedVehicles[v.plate] = {
                vehicle = v.vehicle,
                coords = v.parking,
                mods = v.mods,
                tuning = v.tuning,
                engine = v.engine,
                body = v.body,
                fuel = v.fuel
            }
        end
    end
end)

-- ================================
-- LOCALISATION DE VÉHICULE
-- ================================

RegisterNetEvent('vCore:persist:createBlip', function(plate, coords)
    -- Supprimer ancien blip si existant
    if locationBlips[plate] then
        RemoveBlip(locationBlips[plate])
    end
    
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, PersistConfig.LocationBlip.sprite)
    SetBlipColour(blip, PersistConfig.LocationBlip.color)
    SetBlipScale(blip, PersistConfig.LocationBlip.scale)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, PersistConfig.LocationBlip.color)
    
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Véhicule: " .. plate)
    EndTextCommandSetBlipName(blip)
    
    locationBlips[plate] = blip
    
    -- Supprimer après un délai
    SetTimeout(PersistConfig.LocationBlip.duration, function()
        if locationBlips[plate] then
            RemoveBlip(locationBlips[plate])
            locationBlips[plate] = nil
        end
    end)
end)

-- ================================
-- SAUVEGARDE AUTOMATIQUE
-- ================================

CreateThread(function()
    while true do
        Wait(PersistConfig.SaveInterval)
        
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            if DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle, -1) == ped then
                local plate = NormalizePlate(GetVehicleNumberPlateText(vehicle))
                if plate and IsPlayerVehicle(vehicle, plate) then
                    local coords = GetEntityCoords(vehicle)
                    local heading = GetEntityHeading(vehicle)
                    local engine = GetVehicleEngineHealth(vehicle)
                    local body = GetVehicleBodyHealth(vehicle)
                    local fuel = GetVehicleFuelLevel and GetVehicleFuelLevel(vehicle) or 100
                    
                    TriggerServerEvent('vCore:persist:savePosition', plate, coords, heading, engine, body, fuel)
                end
            end
        end
    end
end)

-- ================================
-- SYNC VÉHICULE
-- ================================

RegisterNetEvent('vCore:persist:applySync', function(data)
    if not data or not data.plate then return end
    
    -- Trouver le véhicule par plaque
    local vehicle = nil
    local playerVehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    
    if DoesEntityExist(playerVehicle) then
        local plate = NormalizePlate(GetVehicleNumberPlateText(playerVehicle))
        if plate == data.plate then
            vehicle = playerVehicle
        end
    end
    
    if not vehicle then return end
    
    -- Appliquer les données
    if data.engine then SetVehicleEngineHealth(vehicle, data.engine + 0.0) end
    if data.body then SetVehicleBodyHealth(vehicle, data.body + 0.0) end
    if data.mods then ApplyVehicleMods(vehicle, data.mods) end
end)

-- ================================
-- EXPORTS CLIENT
-- ================================

exports('SaveVehiclePosition', function(plate)
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if not DoesEntityExist(vehicle) then return false end
    
    local currentPlate = NormalizePlate(GetVehicleNumberPlateText(vehicle))
    if plate and currentPlate ~= plate then return false end
    
    local coords = GetEntityCoords(vehicle)
    local heading = GetEntityHeading(vehicle)
    local engine = GetVehicleEngineHealth(vehicle)
    local body = GetVehicleBodyHealth(vehicle)
    local fuel = GetVehicleFuelLevel and GetVehicleFuelLevel(vehicle) or 100
    
    TriggerServerEvent('vCore:persist:savePosition', currentPlate, coords, heading, engine, body, fuel)
    return true
end)

exports('GetPersistentVehicles', function()
    return trackedVehicles
end)

exports('LocateVehicle', function(plate)
    TriggerServerEvent('vCore:persist:locateVehicle', plate)
end)

exports('IsPlayerVehicle', function(entity)
    return IsPlayerVehicle(entity)
end)

-- ================================
-- EVENTS FRAMEWORK
-- ================================

RegisterNetEvent('vCore:Client:OnPlayerLoaded', function()
    if vCore and vCore.Functions and vCore.Functions.GetPlayerData then
        PlayerData = vCore.Functions.GetPlayerData()
    end
    Wait(2000)
    TriggerServerEvent('vCore:persist:requestVehicles')
end)

-- ================================
-- CLEANUP
-- ================================

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        Wait(2000)
        TriggerServerEvent('vCore:persist:requestVehicles')
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        -- Supprimer tous les blips
        for plate, blip in pairs(locationBlips) do
            if DoesBlipExist(blip) then
                RemoveBlip(blip)
            end
        end
    end
end)
