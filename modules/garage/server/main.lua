--[[
    vAvA Core - Module Garage
    Serveur: Gestion des véhicules, stockage et fourrière
]]

-- Récupérer l'objet vCore
local vCore = nil
local vCoreReady = false

-- Vérifier si le module economy est chargé
local EconomyEnabled = false

-- Fonction helper pour attendre vCore
local function WaitForVCore(maxAttempts)
    maxAttempts = maxAttempts or 50
    local attempts = 0
    while not vCore and attempts < maxAttempts do
        Wait(100)
        attempts = attempts + 1
    end
    return vCore ~= nil
end

Citizen.CreateThread(function()
    while vCore == nil do
        TriggerEvent('vCore:getSharedObject', function(obj) vCore = obj end)
        
        if vCore == nil then
            local success, result = pcall(function()
                return exports['vAvA_core']:GetCoreObject()
            end)
            if success then vCore = result end
        end
        
        Wait(100)
    end
    
    vCoreReady = true
    
    -- Vérifier economy après l'init de vCore
    Wait(2000)
    if GetResourceState('vAvA_economy') == 'started' then
        EconomyEnabled = true
        print('^2[vCore:Garage] Module economy détecté et activé^0')
    else
        print('^3[vCore:Garage] Module economy non trouvé - Prix fixes utilisés^0')
    end
    
    print('^2[vCore:Garage] Module garage initialisé^0')
end)

---Obtenir le prix de fourrière via le système economy
---@param basePrice number
---@return number
local function GetImpoundPrice(basePrice)
    if not EconomyEnabled then
        -- Prix fixe si economy non disponible
        return basePrice or GarageConfig.ImpoundPrice
    end
    
    -- Appliquer la taxe
    return exports['vAvA_economy']:ApplyTax('vehicule', basePrice or GarageConfig.ImpoundPrice)
end

-- Variables
local DynamicGarages = {}
local garagesFile = 'garages.json'

-- ================================
-- CRÉATION AUTOMATIQUE DES TABLES
-- ================================

function CreateTables()
    -- Vérifier/créer la table player_vehicles si elle n'existe pas
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS `player_vehicles` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `citizenid` varchar(50) NOT NULL,
            `vehicle` varchar(50) NOT NULL,
            `plate` varchar(15) NOT NULL,
            `mods` longtext DEFAULT NULL,
            `fuel` int(11) NOT NULL DEFAULT 100,
            `engine` float NOT NULL DEFAULT 1000,
            `body` float NOT NULL DEFAULT 1000,
            `garage` varchar(50) DEFAULT NULL,
            `state` tinyint(4) NOT NULL DEFAULT 1,
            `type` varchar(20) NOT NULL DEFAULT 'car',
            `parking` longtext DEFAULT NULL,
            `tuning_data` longtext DEFAULT NULL,
            `last_update` timestamp NULL DEFAULT NULL,
            `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `plate` (`plate`),
            KEY `idx_citizenid` (`citizenid`),
            KEY `idx_garage` (`garage`),
            KEY `idx_state` (`state`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {}, function()
        print('[vCore:Garage] Table player_vehicles créée/vérifiée')
    end)
end

-- ================================
-- FONCTIONS UTILITAIRES
-- ================================

-- Charger les garages dynamiques
function LoadDynamicGarages()
    local file = LoadResourceFile(GetCurrentResourceName(), garagesFile)
    if file then
        local data = json.decode(file)
        if data then
            DynamicGarages = data.garages or {}
        end
    end
    print('^2[vCore:Garage] Garages dynamiques chargés^0')
end

-- Sauvegarder les garages dynamiques
function SaveDynamicGarages()
    local data = {garages = DynamicGarages}
    SaveResourceFile(GetCurrentResourceName(), garagesFile, json.encode(data, {indent = true}), -1)
end

-- Obtenir tous les garages (config + dynamiques)
function GetAllGarages()
    local allGarages = {}
    for k, v in pairs(GarageConfig.Garages) do
        allGarages[k] = v
    end
    for k, v in pairs(DynamicGarages) do
        allGarages[k] = v
    end
    return allGarages
end

-- Vérifier si un joueur est admin (utilise le système txAdmin ACE de vCore)
local function IsPlayerAdmin(src)
    -- Méthode principale: utiliser vCore.IsAdmin (basé sur txAdmin ACE)
    if vCore and vCore.IsAdmin then
        return vCore.IsAdmin(src)
    end
    
    -- Fallback: vérifier directement les ACE
    if IsPlayerAceAllowed(src, 'vava.admin') then return true end
    if IsPlayerAceAllowed(src, 'vava.superadmin') then return true end
    if IsPlayerAceAllowed(src, 'vava.owner') then return true end
    if IsPlayerAceAllowed(src, 'txadmin.operator') then return true end
    
    return false
end

-- Vérifier si un joueur peut utiliser la fourrière
local function CanUseImpound(src)
    if not vCore then 
        WaitForVCore(30)
    end
    if not vCore then return false end
    local player = vCore.Functions.GetPlayer(src)
    if not player then return false end
    
    local jobName = player.PlayerData.job and player.PlayerData.job.name or nil
    for _, job in ipairs(GarageConfig.ImpoundJobs) do
        if jobName == job then
            return true
        end
    end
    return false
end

-- Récupérer le citizenid d'un joueur
local function GetPlayerCitizenId(src)
    if vCore then
        local player = vCore.Functions.GetPlayer(src)
        if player and player.PlayerData then
            return player.PlayerData.citizenid
        end
    end
    return nil
end

-- Donner les clés du véhicule
local function GiveVehicleKeys(src, plate)
    if not GarageConfig.VehicleKeys.Enabled then return end
    
    if GarageConfig.VehicleKeys.UseIntegratedKeys then
        pcall(function()
            exports['vAvA_core']:GiveKeys(src, plate)
        end)
    else
        pcall(function()
            exports[GarageConfig.VehicleKeys.ExternalResource]:GiveKeys(plate, src)
        end)
    end
end

-- Trouver un spawn disponible
local function FindFreeSpawn(spawns)
    for _, spawn in ipairs(spawns) do
        local x, y, z, h = spawn.x, spawn.y, spawn.z, spawn.w
        local vehicles = GetAllVehicles()
        local isFree = true
        
        for _, veh in ipairs(vehicles) do
            if DoesEntityExist(veh) then
                local vehCoords = GetEntityCoords(veh)
                if #(vector3(x, y, z) - vehCoords) < 3.0 then
                    isFree = false
                    break
                end
            end
        end
        
        if isFree then
            return spawn
        end
    end
    
    return spawns[1] -- Fallback sur le premier spawn
end

-- Charger au démarrage
Citizen.CreateThread(function()
    Wait(500)
    CreateTables()
    Wait(500)
    LoadDynamicGarages()
end)

-- ================================
-- EXPORTS SERVEUR
-- ================================

-- Récupérer les véhicules d'un joueur
exports('GetPlayerVehicles', function(citizenid, garageName)
    local vehicles = {}
    
    local query = garageName 
        and 'SELECT * FROM player_vehicles WHERE citizenid = ? AND (garage = ? OR garage IS NULL) AND state = 1'
        or 'SELECT * FROM player_vehicles WHERE citizenid = ?'
    
    local params = garageName and {citizenid, garageName} or {citizenid}
    
    local result = exports.oxmysql:executeSync(query, params)
    
    if result then
        for _, row in ipairs(result) do
            table.insert(vehicles, {
                plate = row.plate,
                vehicle = row.vehicle,
                mods = row.mods,
                fuel = row.fuel or 100,
                engine = row.engine or 1000,
                body = row.body or 1000,
                garage = row.garage,
                state = row.state,
                type = row.type or 'car'
            })
        end
    end
    
    return vehicles
end)

-- Mettre un véhicule en fourrière
exports('ImpoundVehicle', function(plate, impoundName)
    impoundName = impoundName or 'fourriere'
    local cleanPlate = string.gsub(plate, '%s+', '')
    
    exports.oxmysql:execute(
        'UPDATE player_vehicles SET stored = 0, garage = ?, parking = NULL, last_update = NOW() WHERE REPLACE(plate, " ", "") = ?',
        {impoundName, cleanPlate}
    )
    
    -- Notifier persist
    TriggerEvent('vava_persist:removeVehicleTracking', cleanPlate)
    
    -- Supprimer côté client
    TriggerClientEvent('vcore_garage:deleteVehicleByPlate', -1, plate)
    
    print('^3[vCore:Garage] Véhicule ' .. cleanPlate .. ' mis en fourrière^0')
    return true
end)

-- Sortir un véhicule de la fourrière
exports('ReleaseFromImpound', function(plate, newGarage)
    newGarage = newGarage or nil
    local cleanPlate = string.gsub(plate, '%s+', '')
    
    exports.oxmysql:execute(
        'UPDATE player_vehicles SET stored = 1, garage = ?, last_update = NOW() WHERE REPLACE(plate, " ", "") = ?',
        {newGarage, cleanPlate}
    )
    
    return true
end)

-- Récupérer tous les garages
exports('GetGarages', function()
    return GetAllGarages()
end)

-- Ajouter un garage dynamique
exports('AddGarage', function(garageId, garageData)
    DynamicGarages[garageId] = garageData
    SaveDynamicGarages()
    TriggerClientEvent('vcore_garage:syncGarages', -1)
    return true
end)

-- ================================
-- EVENTS SERVEUR
-- ================================

-- Demande des véhicules du joueur
RegisterNetEvent('vcore_garage:requestVehicles')
AddEventHandler('vcore_garage:requestVehicles', function(garageName, vehicleType, isImpound)
    local src = source
    if not vCore then return end
    
    local player = vCore.Functions.GetPlayer(src)
    if not player then return end
    
    local citizenid = player.PlayerData.citizenid
    local query, params
    
    if isImpound then
        -- Véhicules en fourrière
        query = 'SELECT * FROM player_vehicles WHERE citizenid = ? AND stored = 0'
        params = {citizenid}
    else
        -- Véhicules dans le garage
        query = 'SELECT * FROM player_vehicles WHERE citizenid = ? AND stored = 1 AND (garage = ? OR garage IS NULL)'
        params = {citizenid, garageName}
    end
    
    -- Filtrer par type si spécifié
    if vehicleType then
        query = query .. ' AND type = ?'
        table.insert(params, vehicleType)
    end
    
    exports.oxmysql:execute(query, params, function(result)
        local vehicles = {}
        
        if result then
            for _, row in ipairs(result) do
                local mods = {}
                if row.mods then
                    local success, decoded = pcall(json.decode, row.mods)
                    if success then mods = decoded end
                end
                
                table.insert(vehicles, {
                    plate = row.plate,
                    vehicle = row.vehicle,
                    mods = mods,
                    fuel = row.fuel or 100,
                    engine = row.engine or 1000,
                    body = row.body or 1000,
                    garage = row.garage,
                    state = row.state,
                    type = row.type or 'car'
                })
            end
        end
        
        TriggerClientEvent('vcore_garage:sendVehicles', src, vehicles, garageName, isImpound)
    end)
end)

-- Sortir un véhicule
RegisterNetEvent('vcore_garage:spawnVehicle')
AddEventHandler('vcore_garage:spawnVehicle', function(plate, garageName, isImpound)
    local src = source
    if not vCore then return end
    
    local player = vCore.Functions.GetPlayer(src)
    if not player then return end
    
    local citizenid = player.PlayerData.citizenid
    local cleanPlate = string.gsub(plate, '%s+', '')
    
    -- Vérifier la propriété
    exports.oxmysql:execute(
        'SELECT * FROM player_vehicles WHERE citizenid = ? AND REPLACE(plate, " ", "") = ?',
        {citizenid, cleanPlate},
        function(result)
            if not result or #result == 0 then
                vCore.Functions.Notify(src, 'Véhicule non trouvé', 'error')
                return
            end
            
            local vehicleData = result[1]
            
            -- Vérifier si véhicule en fourrière
            if vehicleData.stored == 0 and not isImpound then
                vCore.Functions.Notify(src, 'Ce véhicule est en fourrière!', 'error')
                return
            end
            
            -- Si fourrière, payer
            if isImpound then
                local basePrice = GarageConfig.General.ImpoundPrice
                local price = GetImpoundPrice(basePrice)
                
                if player.Functions.GetMoney('cash') >= price then
                    player.Functions.RemoveMoney('cash', price, 'impound-fee')
                    vCore.Functions.Notify(src, '💵 Frais de fourrière payés: $' .. price, 'success')
                elseif player.Functions.GetMoney('bank') >= price then
                    player.Functions.RemoveMoney('bank', price, 'impound-fee')
                    vCore.Functions.Notify(src, '🏦 Frais de fourrière payés: $' .. price, 'success')
                else
                    vCore.Functions.Notify(src, 'Pas assez d\'argent ($' .. price .. ')', 'error')
                    return
                end
                
                -- Enregistrer la transaction dans economy (si disponible)
                if EconomyEnabled then
                    exports['vAvA_economy']:RegisterTransaction(
                        'service',
                        'impound_fee',
                        'service',
                        1,
                        price
                    )
                end
            end
            
            -- Trouver le spawn
            local garages = GetAllGarages()
            local impounds = GarageConfig.Impounds
            local location = isImpound and impounds[garageName] or garages[garageName]
            
            if not location or not location.spawns then
                vCore.Functions.Notify(src, 'Garage invalide', 'error')
                return
            end
            
            local spawn = FindFreeSpawn(location.spawns)
            
            -- Créer le véhicule côté serveur
            local model = vehicleData.vehicle
            local hash = GetHashKey(model)
            
            local veh = CreateVehicleServerSetter(hash, 'automobile', spawn.x, spawn.y, spawn.z, spawn.w)
            
            if not veh or veh == 0 then
                vCore.Functions.Notify(src, 'Erreur de spawn', 'error')
                return
            end
            
            -- Attendre que le véhicule existe
            local tries = 0
            while not DoesEntityExist(veh) and tries < 50 do
                Wait(100)
                tries = tries + 1
            end
            
            if not DoesEntityExist(veh) then
                vCore.Functions.Notify(src, 'Erreur de spawn', 'error')
                return
            end
            
            -- Configurer le véhicule
            SetVehicleNumberPlateText(veh, plate)
            SetEntityAsMissionEntity(veh, true, true)
            
            -- Marquer comme sorti
            local netId = NetworkGetNetworkIdFromEntity(veh)
            
            -- State bags pour les mods
            local vehicleState = Entity(veh).state
            vehicleState:set('plate', plate, true)
            vehicleState:set('fuel', vehicleData.fuel or 100, true)
            
            local mods = {}
            if vehicleData.mods then
                local success, decoded = pcall(json.decode, vehicleData.mods)
                if success then mods = decoded end
            end
            vehicleState:set('mods', mods, true)
            
            -- Mettre à jour la BDD
            exports.oxmysql:execute(
                'UPDATE player_vehicles SET stored = 1, garage = NULL, last_update = NOW() WHERE plate = ?',
                {plate}
            )
            
            -- Donner les clés
            GiveVehicleKeys(src, plate)
            
            -- Notifier le client
            TriggerClientEvent('vcore_garage:vehicleSpawned', src, netId, mods, {
                plate = plate,
                fuel = vehicleData.fuel or 100,
                engine = vehicleData.engine or 1000,
                body = vehicleData.body or 1000
            }, isImpound and GarageConfig.General.RepairOnImpoundRelease or false)
            
            vCore.Functions.Notify(src, 'Véhicule sorti du garage', 'success')
        end
    )
end)

-- Ranger un véhicule
RegisterNetEvent('vcore_garage:storeVehicle')
AddEventHandler('vcore_garage:storeVehicle', function(netId, garageName)
    local src = source
    if not vCore then return end
    
    local player = vCore.Functions.GetPlayer(src)
    if not player then return end
    
    local citizenid = player.PlayerData.citizenid
    local veh = NetworkGetEntityFromNetworkId(netId)
    
    if not veh or not DoesEntityExist(veh) then
        vCore.Functions.Notify(src, 'Véhicule introuvable', 'error')
        return
    end
    
    local plate = GetVehicleNumberPlateText(veh)
    local cleanPlate = string.gsub(plate, '%s+', '')
    
    -- Vérifier la propriété
    exports.oxmysql:execute(
        'SELECT * FROM player_vehicles WHERE REPLACE(plate, " ", "") = ?',
        {cleanPlate},
        function(result)
            if not result or #result == 0 then
                vCore.Functions.Notify(src, 'Véhicule non enregistré', 'error')
                return
            end
            
            local vehicleData = result[1]
            
            if vehicleData.citizenid ~= citizenid then
                vCore.Functions.Notify(src, 'Ce véhicule ne vous appartient pas', 'error')
                return
            end
            
            -- Récupérer les propriétés du véhicule
            local fuel = Entity(veh).state.fuel or 100
            local engine = GetVehicleEngineHealth(veh)
            local body = GetVehicleBodyHealth(veh)
            
            -- Mettre à jour la BDD
            exports.oxmysql:execute(
                'UPDATE player_vehicles SET stored = 1, garage = ?, fuel = ?, engine = ?, body = ?, last_update = NOW() WHERE REPLACE(plate, " ", "") = ?',
                {garageName, fuel, engine, body, cleanPlate},
                function()
                    -- Supprimer le véhicule
                    DeleteEntity(veh)
                    
                    -- Notifier persist
                    TriggerEvent('vava_persist:removeVehicleTracking', cleanPlate)
                    
                    vCore.Functions.Notify(src, 'Véhicule rangé', 'success')
                    TriggerClientEvent('vcore_garage:vehicleStored', src)
                end
            )
        end
    )
end)

-- Mise en fourrière par police/mechanic
RegisterNetEvent('vcore_garage:impoundVehicle')
AddEventHandler('vcore_garage:impoundVehicle', function(plate, netId)
    local src = source
    if not CanUseImpound(src) then
        if vCore then
            vCore.Functions.Notify(src, 'Non autorisé', 'error')
        end
        return
    end
    
    exports['vAvA_core']:ImpoundVehicle(plate, 'fourriere')
    
    -- Supprimer le véhicule
    if netId then
        local veh = NetworkGetEntityFromNetworkId(netId)
        if veh and DoesEntityExist(veh) then
            DeleteEntity(veh)
        end
    end
    
    if vCore then
        vCore.Functions.Notify(src, 'Véhicule envoyé en fourrière', 'success')
    end
end)

-- Synchroniser les garages
RegisterNetEvent('vcore_garage:requestGarages')
AddEventHandler('vcore_garage:requestGarages', function()
    local src = source
    TriggerClientEvent('vcore_garage:syncGarages', src, GetAllGarages(), GarageConfig.Impounds)
end)

-- Ajouter un garage dynamique
RegisterNetEvent('vcore_garage:addGarage')
AddEventHandler('vcore_garage:addGarage', function(garageId, garageData)
    local src = source
    
    if not IsPlayerAdmin(src) then
        if vCore then
            vCore.Functions.Notify(src, 'Non autorisé', 'error')
        end
        return
    end
    
    DynamicGarages[garageId] = garageData
    SaveDynamicGarages()
    
    TriggerClientEvent('vcore_garage:syncGarages', -1, GetAllGarages(), GarageConfig.Impounds)
    
    if vCore then
        vCore.Functions.Notify(src, 'Garage créé: ' .. (garageData.label or garageId), 'success')
    end
end)

-- Supprimer un garage dynamique
RegisterNetEvent('vcore_garage:deleteGarage')
AddEventHandler('vcore_garage:deleteGarage', function(garageId)
    local src = source
    
    if not IsPlayerAdmin(src) then
        if vCore then
            vCore.Functions.Notify(src, 'Non autorisé', 'error')
        end
        return
    end
    
    if DynamicGarages[garageId] then
        DynamicGarages[garageId] = nil
        SaveDynamicGarages()
        
        TriggerClientEvent('vcore_garage:syncGarages', -1, GetAllGarages(), GarageConfig.Impounds)
        
        if vCore then
            vCore.Functions.Notify(src, 'Garage supprimé', 'success')
        end
    end
end)

-- ================================
-- COMMANDES
-- ================================

RegisterCommand('garageadmin', function(source, args)
    local src = source
    
    if not IsPlayerAdmin(src) then
        if vCore then
            vCore.Functions.Notify(src, 'Non autorisé', 'error')
        end
        return
    end
    
    TriggerClientEvent('vcore_garage:openAdminPanel', src)
end, false)
