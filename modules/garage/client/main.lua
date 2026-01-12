--[[
    vAvA Core - Module Garage
    Client: Interface utilisateur et gestion des véhicules
]]

-- Variables
local Garages = {}
local Impounds = {}
local garageBlips = {}
local nuiOpen = false
local currentGarage = nil
local currentIsImpound = false

-- ================================
-- EXPORTS CLIENT
-- ================================

-- Ouvrir un garage
exports('OpenGarage', function(garageName)
    if not Garages[garageName] then
        return false
    end
    
    currentGarage = garageName
    currentIsImpound = false
    TriggerServerEvent('vcore_garage:requestVehicles', garageName, Garages[garageName].vehicleType, false)
    return true
end)

-- Ouvrir une fourrière
exports('OpenImpound', function(impoundName)
    if not Impounds[impoundName] then
        return false
    end
    
    currentGarage = impoundName
    currentIsImpound = true
    TriggerServerEvent('vcore_garage:requestVehicles', impoundName, Impounds[impoundName].vehicleType, true)
    return true
end)

-- Ranger un véhicule
exports('StoreVehicle', function(garageName)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    
    if not veh or veh == 0 then
        return false
    end
    
    local netId = NetworkGetNetworkIdFromEntity(veh)
    TriggerServerEvent('vcore_garage:storeVehicle', netId, garageName)
    return true
end)

-- ================================
-- FONCTIONS UTILITAIRES
-- ================================

-- Notification (vCore)
local function Notify(message, type)
    if vCore and vCore.Notify then
        vCore.Notify(message, type or 'info')
    else
        -- Fallback
        SetNotificationTextEntry('STRING')
        AddTextComponentString(message)
        DrawNotification(false, true)
    end
end

-- Énumérer les véhicules
function EnumerateVehicles()
    return coroutine.wrap(function()
        local handle, veh = FindFirstVehicle()
        if not handle or handle == 0 then return end
        local finished = false
        repeat
            coroutine.yield(veh)
            finished, veh = FindNextVehicle(handle)
        until not finished
        EndFindVehicle(handle)
    end)
end

-- Créer les blips des garages
local function CreateBlips()
    -- Supprimer les anciens blips
    for _, blip in pairs(garageBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    garageBlips = {}
    
    -- Blips des garages
    for id, garage in pairs(Garages) do
        if garage.showBlip ~= false and garage.blip then
            local blip = AddBlipForCoord(garage.position.x, garage.position.y, garage.position.z)
            SetBlipSprite(blip, garage.blip.sprite or 357)
            SetBlipColour(blip, garage.blip.color or 3)
            SetBlipScale(blip, garage.blip.scale or 0.8)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(garage.blip.label or garage.label or "Garage")
            EndTextCommandSetBlipName(blip)
            
            garageBlips[id] = blip
        end
    end
    
    -- Blips des fourrières
    for id, impound in pairs(Impounds) do
        if impound.blip then
            local blip = AddBlipForCoord(impound.position.x, impound.position.y, impound.position.z)
            SetBlipSprite(blip, impound.blip.sprite or 524)
            SetBlipColour(blip, impound.blip.color or 1)
            SetBlipScale(blip, impound.blip.scale or 0.8)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(impound.blip.label or impound.label or "Fourrière")
            EndTextCommandSetBlipName(blip)
            
            garageBlips['impound_' .. id] = blip
        end
    end
end

-- ================================
-- NUI CALLBACKS
-- ================================

RegisterNUICallback('close', function(_, cb)
    cb('ok')
    SetNuiFocus(false, false)
    nuiOpen = false
    SendNUIMessage({action = 'close'})
end)

RegisterNUICallback('spawnVehicle', function(data, cb)
    cb('ok')
    
    TriggerServerEvent('vcore_garage:spawnVehicle', data.plate, currentGarage, currentIsImpound)
    
    SetNuiFocus(false, false)
    nuiOpen = false
    SendNUIMessage({action = 'close'})
end)

RegisterNUICallback('storeVehicle', function(_, cb)
    cb('ok')
    
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    
    if veh and veh ~= 0 then
        local netId = NetworkGetNetworkIdFromEntity(veh)
        TriggerServerEvent('vcore_garage:storeVehicle', netId, currentGarage)
    end
    
    SetNuiFocus(false, false)
    nuiOpen = false
    SendNUIMessage({action = 'close'})
end)

-- ================================
-- EVENTS CLIENT
-- ================================

-- Réception des véhicules
RegisterNetEvent('vcore_garage:sendVehicles')
AddEventHandler('vcore_garage:sendVehicles', function(vehicles, garageName, isImpound)
    local location = isImpound and Impounds[garageName] or Garages[garageName]
    local label = location and location.label or garageName
    
    SetNuiFocus(true, true)
    nuiOpen = true
    SendNUIMessage({
        action = 'open',
        vehicles = vehicles,
        garageName = label,
        isImpound = isImpound,
        impoundPrice = isImpound and GarageConfig.General.ImpoundPrice or 0
    })
end)

-- Véhicule spawné
RegisterNetEvent('vcore_garage:vehicleSpawned')
AddEventHandler('vcore_garage:vehicleSpawned', function(netId, mods, props, repair)
    -- Attendre que le véhicule existe
    local tries = 0
    local veh = nil
    
    while tries < 50 do
        if NetworkDoesEntityExistWithNetworkId(netId) then
            veh = NetworkGetEntityFromNetworkId(netId)
            if DoesEntityExist(veh) then
                break
            end
        end
        Wait(100)
        tries = tries + 1
    end
    
    if not veh or not DoesEntityExist(veh) then
        Notify('Erreur de spawn', 'error')
        return
    end
    
    -- Prendre le contrôle
    local controlTries = 0
    while not NetworkHasControlOfEntity(veh) and controlTries < 20 do
        NetworkRequestControlOfEntity(veh)
        Wait(50)
        controlTries = controlTries + 1
    end
    
    -- Appliquer la plaque
    if props.plate then
        SetVehicleNumberPlateText(veh, props.plate)
    end
    
    -- Appliquer les mods
    if mods and type(mods) == 'table' then
        -- Appliquer via QBCore si disponible
        local success, _ = pcall(function()
            local QBCore = exports['qb-core']:GetCoreObject()
            QBCore.Functions.SetVehicleProperties(veh, mods)
        end)
        
        if not success then
            -- Appliquer manuellement les couleurs de base
            if mods.color1 then
                SetVehicleColours(veh, mods.color1, mods.color2 or mods.color1)
            end
        end
    end
    
    -- Réparer si sortie de fourrière
    if repair then
        SetVehicleFixed(veh)
        SetVehicleEngineHealth(veh, 1000.0)
        SetVehicleBodyHealth(veh, 1000.0)
        SetVehicleDeformationFixed(veh)
    else
        -- Appliquer l'état
        if props.engine then
            SetVehicleEngineHealth(veh, props.engine)
        end
        if props.body then
            SetVehicleBodyHealth(veh, props.body)
        end
    end
    
    -- Appliquer le fuel
    local fuel = props.fuel or 100
    Entity(veh).state:set('fuel', fuel, true)
    SetVehicleFuelLevel(veh, fuel + 0.0)
    
    -- Compatibilité fuel scripts
    pcall(function() exports['LegacyFuel']:SetFuel(veh, fuel) end)
    pcall(function() exports['lc_fuel']:SetFuel(veh, fuel) end)
    
    -- Warp le joueur
    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
    
    Notify('Véhicule sorti du garage', 'success')
end)

-- Véhicule rangé
RegisterNetEvent('vcore_garage:vehicleStored')
AddEventHandler('vcore_garage:vehicleStored', function()
    Notify('Véhicule rangé', 'success')
end)

-- Synchronisation des garages
RegisterNetEvent('vcore_garage:syncGarages')
AddEventHandler('vcore_garage:syncGarages', function(garages, impounds)
    if garages then Garages = garages end
    if impounds then Impounds = impounds end
    CreateBlips()
end)

-- Supprimer véhicule par plaque
RegisterNetEvent('vcore_garage:deleteVehicleByPlate')
AddEventHandler('vcore_garage:deleteVehicleByPlate', function(plate)
    for veh in EnumerateVehicles() do
        if DoesEntityExist(veh) then
            local vehPlate = GetVehicleNumberPlateText(veh)
            if vehPlate == plate then
                local tries = 0
                while not NetworkHasControlOfEntity(veh) and tries < 20 do
                    NetworkRequestControlOfEntity(veh)
                    Wait(50)
                    tries = tries + 1
                end
                
                SetEntityAsMissionEntity(veh, true, true)
                DeleteEntity(veh)
            end
        end
    end
end)

-- Panel admin
RegisterNetEvent('vcore_garage:openAdminPanel')
AddEventHandler('vcore_garage:openAdminPanel', function()
    SetNuiFocus(true, true)
    nuiOpen = true
    SendNUIMessage({
        action = 'openAdmin',
        garages = Garages
    })
end)

-- ================================
-- THREADS
-- ================================

-- Initialisation
Citizen.CreateThread(function()
    -- Charger les configs locales
    Garages = GarageConfig.Garages
    Impounds = GarageConfig.Impounds
    
    -- Demander la sync serveur
    Wait(2000)
    TriggerServerEvent('vcore_garage:requestGarages')
end)

-- Thread d'interaction
Citizen.CreateThread(function()
    while true do
        Wait(0)
        
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local nearLocation = false
        local nearLocationId = nil
        local nearIsImpound = false
        
        -- Vérifier garages
        for id, garage in pairs(Garages) do
            local dist = #(coords - garage.position)
            
            if dist <= GarageConfig.General.InteractionDistance then
                nearLocation = true
                nearLocationId = id
                nearIsImpound = false
                
                -- Afficher le texte d'aide
                SetTextComponentFormat('STRING')
                AddTextComponentString('[E] ' .. (garage.label or 'Garage'))
                DisplayHelpTextFromStringLabel(0, 0, 1, -1)
                
                -- Interaction
                if IsControlJustReleased(0, 38) and not nuiOpen then -- E
                    local veh = GetVehiclePedIsIn(ped, false)
                    
                    if veh and veh ~= 0 then
                        -- Ranger le véhicule
                        local netId = NetworkGetNetworkIdFromEntity(veh)
                        TriggerServerEvent('vcore_garage:storeVehicle', netId, id)
                    else
                        -- Ouvrir le garage
                        currentGarage = id
                        currentIsImpound = false
                        TriggerServerEvent('vcore_garage:requestVehicles', id, garage.vehicleType, false)
                    end
                end
                
                break
            end
        end
        
        -- Vérifier fourrières
        if not nearLocation then
            for id, impound in pairs(Impounds) do
                local dist = #(coords - impound.position)
                
                if dist <= GarageConfig.General.InteractionDistance then
                    nearLocation = true
                    nearLocationId = id
                    nearIsImpound = true
                    
                    SetTextComponentFormat('STRING')
                    AddTextComponentString('[E] ' .. (impound.label or 'Fourrière'))
                    DisplayHelpTextFromStringLabel(0, 0, 1, -1)
                    
                    if IsControlJustReleased(0, 38) and not nuiOpen then
                        currentGarage = id
                        currentIsImpound = true
                        TriggerServerEvent('vcore_garage:requestVehicles', id, impound.vehicleType, true)
                    end
                    
                    break
                end
            end
        end
        
        if not nearLocation then
            Wait(500) -- Optimisation
        end
    end
end)

-- Thread Escape
Citizen.CreateThread(function()
    while true do
        Wait(0)
        if nuiOpen then
            if IsControlJustReleased(0, 177) then
                SetNuiFocus(false, false)
                nuiOpen = false
                SendNUIMessage({action = 'close'})
            end
            Wait(100)
        end
    end
end)

print('^2[vCore:Garage] Client initialisé^0')
