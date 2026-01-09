--[[
    vAvA Core - Module Concessionnaire
    Serveur: Gestion des véhicules, achats et administration
]]

-- Récupérer l'objet vCore
local vCore = nil
local vCoreReady = false

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
    CreateTables()
    print('^2[vCore:Concess] Module concessionnaire initialisé^0')
end)

-- Variables
local vehicles = {}
local vehiclesFile = 'vehicles.json'

-- ================================
-- CRÉATION AUTOMATIQUE DES TABLES
-- ================================

function CreateTables()
    -- Créer la table player_vehicles si elle n'existe pas
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
            `stored` tinyint(4) NOT NULL DEFAULT 1,
            `last_update` timestamp NULL DEFAULT NULL,
            `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `plate` (`plate`),
            KEY `idx_citizenid` (`citizenid`),
            KEY `idx_garage` (`garage`),
            KEY `idx_state` (`state`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {}, function()
        print('[vCore:Concess] Table player_vehicles créée/vérifiée')
    end)
end

-- ================================
-- FONCTIONS UTILITAIRES
-- ================================

-- Convertir le type de véhicule pour la BDD
local function ConvertVehicleTypeForDB(scriptType)
    return ConcessConfig.VehicleTypeDB[scriptType] or 'car'
end

-- Générer une plaque unique
local function GeneratePlate()
    local charset = {}
    for c = 48, 57 do table.insert(charset, string.char(c)) end -- 0-9
    for c = 65, 90 do table.insert(charset, string.char(c)) end -- A-Z
    math.randomseed(os.time() + math.random(1000))
    local plate = ''
    for i = 1, 8 do 
        plate = plate .. charset[math.random(1, #charset)] 
    end
    return plate
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
    
    -- Compatibilité WaveAdmin
    if IsPlayerAceAllowed(src, 'WaveAdmin.admin') then return true end
    if IsPlayerAceAllowed(src, 'WaveAdmin.superadmin') then return true end
    if IsPlayerAceAllowed(src, 'WaveAdmin.owner') then return true end
    
    return false
end

-- Récupérer l'identifiant citizenid d'un joueur
local function GetPlayerCitizenId(src)
    if vCore then
        local player = vCore.Functions.GetPlayer(src)
        if player and player.PlayerData then
            return player.PlayerData.citizenid
        end
    end
    return nil
end

-- Récupérer la license d'un joueur
local function GetPlayerLicense(src)
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if string.sub(id, 1, 8) == "license:" then
            return id:sub(9)
        end
    end
    return nil
end

-- Donner les clés du véhicule
local function GiveVehicleKeys(src, plate, model)
    if not ConcessConfig.VehicleKeys.Enabled then return end
    
    if ConcessConfig.VehicleKeys.UseIntegratedKeys then
        -- Utiliser le module keys intégré
        local success, result = pcall(function()
            return exports['vAvA_core']:GiveKeys(src, plate)
        end)
        
        if not success then
            -- Fallback sur le module externe
            pcall(function()
                exports[ConcessConfig.VehicleKeys.ExternalResource][ConcessConfig.VehicleKeys.ExportName](src, model)
            end)
        end
    else
        pcall(function()
            exports[ConcessConfig.VehicleKeys.ExternalResource][ConcessConfig.VehicleKeys.ExportName](src, model)
        end)
    end
    
    print('^2[vCore:Concess] Clés données pour: ' .. plate .. '^0')
end

-- ================================
-- CHARGEMENT DES VEHICULES
-- ================================

function LoadVehicles()
    local file = LoadResourceFile(GetCurrentResourceName(), vehiclesFile)
    if file then
        vehicles = json.decode(file) or {}
        print('^2[vCore:Concess] ' .. #vehicles .. ' véhicules chargés^0')
    else
        vehicles = {}
        print('^3[vCore:Concess] Aucun fichier vehicles.json trouvé, liste vide^0')
    end
end

function SaveVehicles()
    local jsonStr = json.encode(vehicles, { indent = true })
    SaveResourceFile(GetCurrentResourceName(), vehiclesFile, jsonStr, -1)
end

-- Charger les véhicules au démarrage
Citizen.CreateThread(function()
    Wait(500)
    LoadVehicles()
end)

-- ================================
-- EXPORTS SERVEUR
-- ================================

-- Récupérer la liste des véhicules
exports('GetVehicles', function()
    return vehicles
end)

-- Ajouter un véhicule
exports('AddVehicle', function(vehicleData)
    vehicleData.id = #vehicles + 1
    table.insert(vehicles, vehicleData)
    SaveVehicles()
    TriggerClientEvent('vcore_concess:updateVehicleCache', -1, vehicles)
    return vehicleData.id
end)

-- Supprimer un véhicule
exports('RemoveVehicle', function(model)
    for i, v in ipairs(vehicles) do
        if v.model == model then
            table.remove(vehicles, i)
            SaveVehicles()
            TriggerClientEvent('vcore_concess:updateVehicleCache', -1, vehicles)
            return true
        end
    end
    return false
end)

-- Mettre à jour un véhicule
exports('UpdateVehicle', function(model, newData)
    for i, v in ipairs(vehicles) do
        if v.model == model then
            for key, value in pairs(newData) do
                vehicles[i][key] = value
            end
            SaveVehicles()
            TriggerClientEvent('vcore_concess:updateVehicleCache', -1, vehicles)
            return true
        end
    end
    return false
end)

-- ================================
-- EVENTS SERVEUR
-- ================================

-- Demande de véhicules par le client
RegisterNetEvent('vcore_concess:requestVehicles')
AddEventHandler('vcore_concess:requestVehicles', function(isJobOnly, vehicleType)
    local src = source
    
    -- Attendre que vCore soit initialisé (max 5 secondes)
    if not WaitForVCore(50) or not vCore.Functions then 
        print('[vAvA Concess] En attente de vCore...')
        TriggerClientEvent('vcore_concess:error', src, 'Le serveur démarre, réessayez dans quelques secondes.')
        return 
    end
    
    local player = vCore.Functions.GetPlayer(src)
    if not player then return end
    
    vehicleType = vehicleType or 'cars'
    local isAdmin = IsPlayerAdmin(src)
    local playerJob = nil
    
    if player.PlayerData.job and player.PlayerData.job.name then
        playerJob = player.PlayerData.job.name
    end
    
    -- Filtrer les véhicules
    local validCategories = ConcessConfig.Categories[vehicleType] or {'compacts'}
    local vehList = {}
    
    for _, v in ipairs(vehicles) do
        local categoryValid = false
        for _, cat in ipairs(validCategories) do
            if v.category == cat then
                categoryValid = true
                break
            end
        end
        
        if categoryValid then
            if isJobOnly then
                -- Mode job: véhicules avec job défini
                if v.job and v.job ~= "" then
                    table.insert(vehList, v)
                end
            else
                -- Mode civil: véhicules sans job
                if not v.job or v.job == "" then
                    table.insert(vehList, v)
                end
            end
        end
    end
    
    TriggerClientEvent('vcore_concess:sendVehicles', src, vehList, isAdmin, playerJob, vehicleType, isJobOnly)
end)

-- Achat d'un véhicule
RegisterNetEvent('vcore_concess:buyVehicle')
AddEventHandler('vcore_concess:buyVehicle', function(data)
    local src = source
    
    -- Attendre que vCore soit initialisé si nécessaire
    if not WaitForVCore(50) or not vCore.Functions then return end
    
    local player = vCore.Functions.GetPlayer(src)
    if not player then return end
    
    -- Trouver le véhicule
    local veh = nil
    for _, v in ipairs(vehicles) do
        if v.model == data.model then
            veh = v
            break
        end
    end
    
    if not veh then
        vCore.Functions.Notify(src, 'Véhicule introuvable', 'error')
        return
    end
    
    local price = veh.price
    local paymentMethod = data.method or 'cash'
    local paid = false
    
    -- Traitement du paiement via vCore
    if paymentMethod == 'cash' then
        if player.Functions.GetMoney('cash') >= price then
            paid = player.Functions.RemoveMoney('cash', price, 'vehicle-purchase')
            if paid then
                vCore.Functions.Notify(src, '💵 Paiement en espèces: $' .. price, 'success')
            end
        else
            vCore.Functions.Notify(src, '❌ Pas assez d\'espèces ($' .. price .. ')', 'error')
            return
        end
    elseif paymentMethod == 'bank' then
        if player.Functions.GetMoney('bank') >= price then
            paid = player.Functions.RemoveMoney('bank', price, 'vehicle-purchase')
            if paid then
                vCore.Functions.Notify(src, '🏦 Virement bancaire: $' .. price, 'success')
            end
        else
            vCore.Functions.Notify(src, '❌ Pas assez en banque ($' .. price .. ')', 'error')
            return
        end
    end
    
    if not paid then
        vCore.Functions.Notify(src, '❌ Paiement refusé', 'error')
        return
    end
    
    -- Générer plaque et enregistrer le véhicule
    local plate = GeneratePlate()
    local citizenid = player.PlayerData.citizenid
    local license = GetPlayerLicense(src)
    
    -- Job uniquement si concess job
    local vehicleJob = nil
    if data.isJobOnly == true then
        if player.PlayerData.job and player.PlayerData.job.name then
            vehicleJob = player.PlayerData.job.name
        end
    end
    
    -- Données du véhicule
    local primaryColor = tonumber(data.primaryColor) or 0
    local secondaryColor = tonumber(data.secondaryColor) or 0
    local livery = tonumber(data.livery) or -1
    
    local vehicleMods = {}
    if livery >= 0 then
        vehicleMods.modLivery = livery
    end
    
    local vehicleData = {
        license = license,
        citizenid = citizenid,
        vehicle = veh.model,
        hash = veh.model,
        mods = json.encode(vehicleMods),
        plate = plate,
        fakeplate = '',
        garage = nil,
        fuel = 100,
        engine = 1000,
        body = 1000,
        state = 1,
        depotprice = 0,
        drivingdistance = 0,
        status = '{}',
        balance = 0,
        paymentamount = 0,
        paymentsleft = 0,
        financetime = 0,
        job = vehicleJob,
        type = ConvertVehicleTypeForDB(data.vehicleType),
        stored = 3,
        glovebox = '{}',
        trunk = '{}',
        mileage = 0,
        last_update = os.date('%Y-%m-%d %H:%M:%S')
    }
    
    -- Construire la requête SQL dynamique
    local columns, values, params = {}, {}, {}
    for k, v in pairs(vehicleData) do
        table.insert(columns, k)
        table.insert(values, '@' .. k)
        params['@' .. k] = v
    end
    
    local sql = string.format('INSERT INTO player_vehicles (%s) VALUES (%s)', 
        table.concat(columns, ','), 
        table.concat(values, ','))
    
    exports.oxmysql:execute(sql, params, function(insertId)
        -- Forcer garage à NULL
        exports.oxmysql:execute('UPDATE player_vehicles SET garage = NULL WHERE plate = ?', {plate})
        
        -- Donner les clés
        GiveVehicleKeys(src, plate, veh.model)
        
        -- Spawn le véhicule côté client
        TriggerClientEvent('vcore_concess:spawnVehicle', src, veh.model, plate, livery, primaryColor, secondaryColor)
        TriggerClientEvent('vcore_concess:closeNUI', src)
        vCore.Functions.Notify(src, '✅ Véhicule acheté et enregistré!', 'success')
        
        print('^2[vCore:Concess] Véhicule vendu: ' .. veh.model .. ' à ' .. GetPlayerName(src) .. ' (plaque: ' .. plate .. ')^0')
    end)
end)

-- Protection du véhicule contre le despawn
RegisterNetEvent('vcore_concess:protectVehicle')
AddEventHandler('vcore_concess:protectVehicle', function(netId)
    if not netId then return end
    
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 then return end
    
    local vehicleState = Entity(veh).state
    vehicleState:set('vAvA_persist', true, true)
    vehicleState:set('isPersistent', true, true)
end)

-- ================================
-- ADMINISTRATION
-- ================================

RegisterNetEvent('vcore_concess:adminAction')
AddEventHandler('vcore_concess:adminAction', function(data)
    local src = source
    
    if not IsPlayerAdmin(src) then
        if vCore then
            vCore.Functions.Notify(src, '❌ Accès refusé', 'error')
        end
        print('^1[vCore:Concess] Tentative admin refusée: ' .. GetPlayerName(src) .. '^0')
        return
    end
    
    print('^4[vCore:Concess] Action admin: ' .. (data.action or 'inconnue') .. ' par ' .. GetPlayerName(src) .. '^0')
    
    if data.action == 'addVehicle' then
        local newVeh = {
            name = data.name,
            model = data.model,
            category = data.category,
            price = tonumber(data.price),
            image = "img/" .. data.model .. ".png",
            vehicleType = data.vehicleType or 'cars',
            job = data.job or '',
            jobOnly = data.jobOnly or false,
            id = #vehicles + 1
        }
        table.insert(vehicles, newVeh)
        SaveVehicles()
        
        TriggerClientEvent('vcore_concess:updateVehicleCache', -1, vehicles)
        if vCore then
            vCore.Functions.Notify(src, '✅ Véhicule ajouté', 'success')
        end
        
    elseif data.action == 'editVehicle' then
        for i, v in ipairs(vehicles) do
            if v.model == data.vehicleId or tostring(v.id) == tostring(data.vehicleId) then
                vehicles[i].name = data.name
                vehicles[i].model = data.model
                vehicles[i].category = data.category
                vehicles[i].price = tonumber(data.price)
                vehicles[i].vehicleType = data.vehicleType or 'cars'
                vehicles[i].job = data.job or ''
                vehicles[i].jobOnly = data.jobOnly or false
                break
            end
        end
        SaveVehicles()
        TriggerClientEvent('vcore_concess:updateVehicleCache', -1, vehicles)
        if vCore then
            vCore.Functions.Notify(src, '✅ Véhicule modifié', 'success')
        end
        
    elseif data.action == 'deleteVehicle' then
        for i, v in ipairs(vehicles) do
            if v.model == data.vehicleId or tostring(v.id) == tostring(data.vehicleId) then
                table.remove(vehicles, i)
                break
            end
        end
        SaveVehicles()
        TriggerClientEvent('vcore_concess:updateVehicleCache', -1, vehicles)
        if vCore then
            vCore.Functions.Notify(src, '✅ Véhicule supprimé', 'success')
        end
        
    elseif data.action == 'getVehiclesList' then
        TriggerClientEvent('vcore_concess:receiveVehiclesAdmin', src, vehicles)
        
    elseif data.action == 'reloadVehicles' then
        LoadVehicles()
        TriggerClientEvent('vcore_concess:updateVehicleCache', -1, vehicles)
        if vCore then
            vCore.Functions.Notify(src, '✅ Configuration rechargée', 'success')
        end
    end
end)

-- Commande admin
RegisterCommand('vadmin', function(source, args, rawCommand)
    local src = source
    
    if not IsPlayerAdmin(src) then
        if vCore then
            vCore.Functions.Notify(src, '❌ Permissions insuffisantes', 'error')
        end
        return
    end
    
    TriggerClientEvent('vcore_concess:openAdminPanel', src)
end, false)

-- Afficher sa licence
RegisterCommand('mylicense', function(source, args, rawCommand)
    local src = source
    local license = GetPlayerLicense(src)
    
    if license and vCore then
        vCore.Functions.Notify(src, 'Votre licence: ' .. license, 'primary')
        print('[vCore:Concess] License de ' .. GetPlayerName(src) .. ': ' .. license)
    end
end, false)
