--[[
    vAvA Core - Module Persist
    Server-side
]]

local vCore = nil
local spawnedVehicles = {}
local activePlayerVehicles = {}

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
    ValidateDatabase()
end)

-- ================================
-- FONCTIONS UTILITAIRES
-- ================================

local function GetPlayer(source)
    if vCore and vCore.Functions and vCore.Functions.GetPlayer then
        return vCore.Functions.GetPlayer(source)
    end
    return nil
end

local function Notify(source, message, type)
    if GetResourceState('ox_lib') == 'started' then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Véhicule',
            description = message,
            type = type or 'info'
        })
    else
        TriggerClientEvent('vCore:notification', source, message, type)
    end
end

local function DebugLog(msg)
    if PersistConfig.Debug then
        print('[vAvA Core - Persist] ' .. tostring(msg))
    end
end

-- ================================
-- VALIDATION BDD
-- ================================

function ValidateDatabase()
    MySQL.Async.fetchAll('SHOW COLUMNS FROM player_vehicles LIKE ?', {'parking'}, function(result)
        if #result == 0 then
            print('^1[vAvA Core - Persist] ERREUR: La colonne \'parking\' n\'existe pas!')
            print('^1[vAvA Core - Persist] Exécutez la migration SQL!')
        else
            DebugLog('Structure BDD validée')
        end
    end)
end

-- ================================
-- TRACKING DES VÉHICULES
-- ================================

RegisterNetEvent('vCore:persist:registerVehicle', function(plate, netId, citizenid, model)
    if not plate then return end
    
    activePlayerVehicles[plate] = {
        netId = netId,
        citizenid = citizenid,
        spawnTime = os.time(),
        model = model or 'unknown',
        source = source
    }
    
    spawnedVehicles[plate] = {
        netId = netId,
        citizenid = citizenid
    }
    
    DebugLog('Véhicule enregistré: ' .. plate)
end)

RegisterNetEvent('vCore:persist:unregisterVehicle', function(plate)
    if activePlayerVehicles[plate] then
        activePlayerVehicles[plate] = nil
        DebugLog('Véhicule désenregistré: ' .. plate)
    end
    
    if spawnedVehicles[plate] then
        spawnedVehicles[plate] = nil
    end
end)

-- ================================
-- SAUVEGARDE DE POSITION
-- ================================

RegisterNetEvent('vCore:persist:savePosition', function(plate, coords, heading, engineHealth, bodyHealth, fuel)
    if not plate or plate == '' then return end
    
    local parkingData = json.encode({
        coords = {
            x = coords.x,
            y = coords.y,
            z = coords.z
        },
        heading = heading or 0.0
    })
    
    MySQL.Async.execute([[
        UPDATE player_vehicles 
        SET parking = ?, engine = ?, body = ?, fuel = ?, stored = 3, last_update = NOW()
        WHERE plate = ?
    ]], {
        parkingData,
        engineHealth or 1000,
        bodyHealth or 1000,
        fuel or 100,
        plate
    }, function(affectedRows)
        if affectedRows > 0 then
            DebugLog('Position sauvegardée pour: ' .. plate)
        end
    end)
end)

RegisterNetEvent('vCore:persist:savePositionNow', function(plate, parking, engineHealth, bodyHealth, fuel)
    if not plate or not parking then return end
    
    MySQL.Async.execute([[
        UPDATE player_vehicles 
        SET parking = ?, engine = ?, body = ?, fuel = ?, stored = 3, last_update = NOW()
        WHERE plate = ?
    ]], {
        parking,
        engineHealth or 1000,
        bodyHealth or 1000,
        fuel or 100,
        plate
    })
end)

-- ================================
-- RÉCUPÉRATION DES VÉHICULES PERSISTANTS
-- ================================

RegisterNetEvent('vCore:persist:requestVehicles', function()
    local src = source
    
    MySQL.Async.fetchAll([[
        SELECT plate, mods, tuning_data, vehicle, parking, stored, engine, body, fuel
        FROM player_vehicles 
        WHERE stored = 3 AND parking IS NOT NULL AND parking != ''
        ORDER BY plate, last_update DESC
    ]], {}, function(vehicles)
        local decoded = {}
        local processedPlates = {}
        
        for _, v in ipairs(vehicles) do
            if not processedPlates[v.plate] then
                processedPlates[v.plate] = true
                
                local mods = nil
                local tuning = nil
                local parking = nil
                
                if v.mods and v.mods ~= "" then
                    local ok, res = pcall(function() return json.decode(v.mods) end)
                    if ok and res then mods = res end
                end
                
                if v.tuning_data and v.tuning_data ~= "" then
                    local ok, res = pcall(function() return json.decode(v.tuning_data) end)
                    if ok and res then tuning = res end
                end
                
                if v.parking and v.parking ~= "" then
                    local ok, res = pcall(function() return json.decode(v.parking) end)
                    if ok and res and res.coords then 
                        parking = res.coords
                        parking.heading = res.heading or 0.0
                    end
                end
                
                if parking then
                    table.insert(decoded, {
                        plate = v.plate,
                        vehicle = v.vehicle,
                        mods = mods,
                        tuning = tuning,
                        parking = parking,
                        engine = v.engine or 1000,
                        body = v.body or 1000,
                        fuel = v.fuel or 100
                    })
                end
            end
        end
        
        TriggerClientEvent('vCore:persist:receiveVehicles', src, decoded)
    end)
end)

-- ================================
-- LOCALISATION DE VÉHICULE
-- ================================

RegisterNetEvent('vCore:persist:locateVehicle', function(plate)
    local src = source
    local Player = GetPlayer(src)
    
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    MySQL.Async.fetchSingle([[
        SELECT parking FROM player_vehicles 
        WHERE citizenid = ? AND plate = ? AND stored = 3
    ]], {citizenid, plate}, function(result)
        if result and result.parking then
            local parkingData = json.decode(result.parking)
            if parkingData and parkingData.coords then
                Notify(src, PersistConfig.Messages.vehicle_located, 'success')
                TriggerClientEvent('vCore:persist:createBlip', src, plate, parkingData.coords)
            else
                Notify(src, PersistConfig.Messages.vehicle_not_found, 'error')
            end
        else
            Notify(src, PersistConfig.Messages.vehicle_not_found, 'error')
        end
    end)
end)

-- ================================
-- SYNCHRONISATION VÉHICULE
-- ================================

RegisterNetEvent('vCore:persist:requestSync', function(netId)
    local src = source
    if not netId then return end
    
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle and DoesEntityExist(vehicle) then
        local plate = GetVehicleNumberPlateText(vehicle)
        if plate and plate ~= '' then
            MySQL.Async.fetchSingle([[
                SELECT plate, mods, tuning_data, engine, body, fuel
                FROM player_vehicles WHERE plate = ?
            ]], {plate}, function(result)
                if result then
                    local mods = nil
                    local tuning = nil
                    
                    if result.mods and result.mods ~= "" then
                        local ok, res = pcall(function() return json.decode(result.mods) end)
                        if ok and res then mods = res end
                    end
                    
                    if result.tuning_data and result.tuning_data ~= "" then
                        local ok, res = pcall(function() return json.decode(result.tuning_data) end)
                        if ok and res then tuning = res end
                    end
                    
                    TriggerClientEvent('vCore:persist:applySync', src, {
                        plate = result.plate,
                        mods = mods,
                        tuning = tuning,
                        engine = result.engine,
                        body = result.body,
                        fuel = result.fuel
                    })
                end
            end)
        end
    end
end)

-- ================================
-- VÉRIFICATION VÉHICULE JOUEUR
-- ================================

RegisterNetEvent('vCore:persist:checkPlayerVehicle', function(plate, callbackEvent)
    local src = source
    if not plate then 
        TriggerClientEvent(callbackEvent, src, false)
        return
    end
    
    if activePlayerVehicles[plate] then
        TriggerClientEvent(callbackEvent, src, true)
        return
    end
    
    MySQL.Async.fetchSingle('SELECT citizenid FROM player_vehicles WHERE plate = ?', {plate}, function(result)
        TriggerClientEvent(callbackEvent, src, result ~= nil)
    end)
end)

-- ================================
-- SUPPRESSION DE TRACKING
-- ================================

RegisterNetEvent('vCore:persist:removeTracking', function(plate)
    if spawnedVehicles[plate] then
        spawnedVehicles[plate] = nil
    end
end)

-- ================================
-- EXPORTS SERVEUR
-- ================================

exports('SaveVehicle', function(plate, data)
    if not plate then return false end
    
    local parkingData = json.encode({
        coords = data.coords,
        heading = data.heading or 0.0
    })
    
    MySQL.Async.execute([[
        UPDATE player_vehicles 
        SET parking = ?, engine = ?, body = ?, fuel = ?, stored = 3, last_update = NOW()
        WHERE plate = ?
    ]], {
        parkingData,
        data.engine or 1000,
        data.body or 1000,
        data.fuel or 100,
        plate
    })
    
    return true
end)

exports('GetSpawnedVehicles', function()
    return spawnedVehicles
end)

exports('RegisterPlayerVehicle', function(plate, netId, citizenid)
    activePlayerVehicles[plate] = {
        netId = netId,
        citizenid = citizenid,
        spawnTime = os.time()
    }
    spawnedVehicles[plate] = { netId = netId, citizenid = citizenid }
end)

exports('UnregisterPlayerVehicle', function(plate)
    activePlayerVehicles[plate] = nil
    spawnedVehicles[plate] = nil
end)

exports('IsPlayerVehicle', function(plate)
    return activePlayerVehicles[plate] ~= nil
end)

-- ================================
-- CLEANUP
-- ================================

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        Wait(2000)
        ValidateDatabase()
    end
end)

-- Nettoyer le tracking quand un joueur se déconnecte
AddEventHandler('playerDropped', function()
    local src = source
    
    -- Parcourir et retirer les véhicules de ce joueur
    for plate, data in pairs(activePlayerVehicles) do
        if data.source == src then
            -- Sauvegarder la position avant de retirer du tracking
            local vehicle = NetworkGetEntityFromNetworkId(data.netId)
            if vehicle and DoesEntityExist(vehicle) then
                local coords = GetEntityCoords(vehicle)
                local heading = GetEntityHeading(vehicle)
                local engine = GetVehicleEngineHealth(vehicle)
                local body = GetVehicleBodyHealth(vehicle)
                
                TriggerEvent('vCore:persist:savePosition', plate, coords, heading, engine, body, 100)
            end
            
            activePlayerVehicles[plate] = nil
            spawnedVehicles[plate] = nil
        end
    end
end)
