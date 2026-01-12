--[[
    vAvA Core - Module Concessionnaire
    Serveur: Gestion des véhicules, achats et administration
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
    CreateTables()
    
    -- Vérifier economy après l'init de vCore
    Wait(2000)
    if GetResourceState('vAvA_economy') == 'started' then
        EconomyEnabled = true
        print('^2[vCore:Concess] Module economy détecté et activé^0')
    else
        print('^3[vCore:Concess] Module economy non trouvé - Prix fixes utilisés^0')
    end
    
    print('^2[vCore:Concess] Module concessionnaire initialisé^0')
end)

---Formate un nombre avec des espaces
---@param number number
---@return string
local function formatNumber(number)
    local formatted = tostring(math.floor(number))
    local k
    while true do  
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1 %2')
        if k == 0 then break end
    end
    return formatted
end

---Obtenir le prix d'un véhicule via le système economy
---@param vehicleModel string
---@param vehicleType string
---@return number
local function GetVehiclePrice(vehicleModel, vehicleType)
    if not EconomyEnabled then
        -- Prix fixes par défaut si economy non disponible
        return 50000  -- Prix par défaut
    end
    
    -- Utiliser le système economy
    local shop = 'dealership'
    if vehicleType == 'boats' then shop = 'dealership_boat'
    elseif vehicleType == 'aircraft' then shop = 'dealership_air'
    end
    
    return exports['vAvA_economy']:GetPrice(vehicleModel, shop, 1)
end

---Appliquer une taxe sur l'achat de véhicule
---@param amount number
---@return number
local function ApplyTax(amount)
    if not EconomyEnabled then
        -- Taxe fixe de 20% si economy non disponible
        return math.floor(amount * 1.20)
    end
    
    return exports['vAvA_economy']:ApplyTax('vehicule', amount)
end

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
        local player = vCore.GetPlayer(src)
        if player then
            -- vCore utilise charId (véhicule lié au personnage)
            return player.charId
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
    print('[vCore:Concess] Requête reçue de ' .. src .. ' - isJobOnly: ' .. tostring(isJobOnly) .. ' vehicleType: ' .. tostring(vehicleType))
    
    -- Attendre que vCore soit initialisé (max 5 secondes)
    if not WaitForVCore(50) or not vCore.Functions then 
        print('[vCore:Concess] ERREUR: vCore non disponible')
        TriggerClientEvent('vcore_concess:error', src, 'Le serveur démarre, réessayez dans quelques secondes.')
        return 
    end
    
    -- Attendre que les données du joueur soient chargées (max 5 secondes)
    local player = nil
    local attempts = 0
    while attempts < 50 do
        player = vCore.GetPlayer(src)
        if player and player.job then
            break
        end
        attempts = attempts + 1
        Wait(100)
    end
    
    if not player then 
        print('[vCore:Concess] ERREUR: Joueur non chargé pour ' .. src .. ' après ' .. attempts .. ' tentatives')
        TriggerClientEvent('vcore_concess:error', src, 'Vos données joueur ne sont pas chargées. Reconnectez-vous ou attendez quelques secondes.')
        return 
    end
    
    vehicleType = vehicleType or 'cars'
    local isAdmin = IsPlayerAdmin(src)
    local playerJob = nil
    
    -- vCore utilise directement player.job, pas player.PlayerData.job
    if player.job and player.job.name then
        playerJob = player.job.name
    end
    
    print('[vCore:Concess] ConcessConfig.Categories existe?', ConcessConfig and ConcessConfig.Categories and 'OUI' or 'NON')
    print('[vCore:Concess] vehicleType:', vehicleType)
    print('[vCore:Concess] isJobOnly:', isJobOnly)
    
    -- Filtrer les véhicules
    local validCategories = ConcessConfig.Categories[vehicleType] or {'compacts'}
    print('[vCore:Concess] Catégories valides:', json.encode(validCategories))
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
                    -- Calculer le prix avec taxe
                    local vehicleCopy = {}
                    for k, val in pairs(v) do
                        vehicleCopy[k] = val
                    end
                    vehicleCopy.priceWithTax = ApplyTax(v.price)
                    table.insert(vehList, vehicleCopy)
                end
            else
                -- Mode civil: véhicules sans job
                if not v.job or v.job == "" then
                    -- Calculer le prix avec taxe
                    local vehicleCopy = {}
                    for k, val in pairs(v) do
                        vehicleCopy[k] = val
                    end
                    vehicleCopy.priceWithTax = ApplyTax(v.price)
                    table.insert(vehList, vehicleCopy)
                end
            end
        end
    end
    
    print('[vCore:Concess] Total véhicules disponibles: ' .. #vehicles)
    print('[vCore:Concess] Véhicules filtrés pour le client: ' .. #vehList)
    print('[vCore:Concess] TriggerClientEvent vers src:', src)
    print('[vCore:Concess] Envoi de ' .. #vehList .. ' véhicules au client ' .. src)
    TriggerClientEvent('vcore_concess:sendVehicles', src, vehList, isAdmin, playerJob, vehicleType, isJobOnly)
end)

-- Achat d'un véhicule
RegisterNetEvent('vcore_concess:buyVehicle')
AddEventHandler('vcore_concess:buyVehicle', function(data)
    local src = source
    
    -- Attendre que vCore soit initialisé si nécessaire
    if not WaitForVCore(50) or not vCore then 
        print('[vCore:Concess] ERREUR: vCore non disponible')
        return 
    end
    
    local player = vCore.GetPlayer(src)
    if not player then 
        print('[vCore:Concess] ERREUR: Player non trouvé pour source ' .. src)
        return 
    end
    
    -- Debug: vérifier le type de l'objet player
    print('[vCore:Concess] Type de player:', type(player))
    print('[vCore:Concess] Player GetMoney existe?', type(player.GetMoney))
    if player.money then
        print('[vCore:Concess] player.money existe, type:', type(player.money))
    end
    
    -- Trouver le véhicule
    local veh = nil
    for _, v in ipairs(vehicles) do
        if v.model == data.model then
            veh = v
            break
        end
    end
    
    if not veh then
        vCore.Notify(src, 'Véhicule introuvable', 'error')
        return
    end
    
    -- Debug prix
    print('[vCore:Concess] Véhicule trouvé:', veh.model)
    print('[vCore:Concess] Prix du véhicule:', veh.price)
    print('[vCore:Concess] EconomyEnabled:', EconomyEnabled)
    
    -- Obtenir le prix - toujours utiliser veh.price comme base
    local basePrice = veh.price
    
    -- Si economy est activé, essayer d'obtenir le prix depuis economy (mais fallback sur veh.price)
    if EconomyEnabled then
        local economyPrice = GetVehiclePrice(veh.model, data.vehicleType)
        if economyPrice and economyPrice > 0 then
            basePrice = economyPrice
            print('[vCore:Concess] Prix economy utilisé:', economyPrice)
        else
            print('[vCore:Concess] Economy retourne 0, utilisation du prix du véhicule')
        end
    end
    
    print('[vCore:Concess] basePrice:', basePrice)
    
    local price = ApplyTax(basePrice)
    print('[vCore:Concess] Prix final après taxe:', price)
    
    local paymentMethod = data.method or 'cash'
    local paid = false
    
    -- Traitement du paiement - Utiliser les fonctions vCore simplifiées
    if paymentMethod == 'cash' then
        local playerCash = vCore.GetPlayerMoney(src, 'cash')
        print('[vCore:Concess] Cash du joueur:', playerCash, 'Prix:', price)
        if playerCash >= price then
            paid = vCore.RemovePlayerMoney(src, 'cash', price, 'vehicle-purchase')
            if paid then
                vCore.Notify(src, '💵 Véhicule acheté en espèces pour $' .. formatNumber(price), 'success')
            else
                vCore.Notify(src, '❌ Erreur lors du paiement', 'error')
                return
            end
        else
            local manque = price - playerCash
            vCore.Notify(src, '❌ Argent insuffisant! Il vous manque $' .. formatNumber(manque) .. ' en espèces', 'error')
            return
        end
    elseif paymentMethod == 'bank' then
        local playerBank = vCore.GetPlayerMoney(src, 'bank')
        print('[vCore:Concess] Banque du joueur:', playerBank, 'Prix:', price)
        if playerBank >= price then
            paid = vCore.RemovePlayerMoney(src, 'bank', price, 'vehicle-purchase')
            if paid then
                vCore.Notify(src, '🏦 Véhicule acheté par virement bancaire pour $' .. formatNumber(price), 'success')
            else
                vCore.Notify(src, '❌ Erreur lors du paiement', 'error')
                return
            end
        else
            local manque = price - playerBank
            vCore.Notify(src, '❌ Fonds insuffisants! Il vous manque $' .. formatNumber(manque) .. ' en banque', 'error')
            return
        end
    end
    
    if not paid then
        vCore.Notify(src, '❌ Paiement refusé', 'error')
        return
    end
    
    -- Générer plaque et enregistrer le véhicule
    local plate = GeneratePlate()
    local citizenid = player.charId  -- Utiliser charId (véhicule lié au personnage)
    local license = GetPlayerLicense(src)
    
    -- Job uniquement si concess job
    local vehicleJob = nil
    if data.isJobOnly == true then
        if player.job and player.job.name then
            vehicleJob = player.job.name
        end
    end
    
    -- Données du véhicule - Structure simplifiée compatible vCore
    local primaryColor = tonumber(data.primaryColor) or 0
    local secondaryColor = tonumber(data.secondaryColor) or 0
    local livery = tonumber(data.livery) or -1
    
    local vehicleMods = {
        primaryColor = primaryColor,
        secondaryColor = secondaryColor
    }
    if livery >= 0 then
        vehicleMods.modLivery = livery
    end
    
    -- Structure simplifiée d'insertion
    local sql = [[
        INSERT INTO player_vehicles (citizenid, plate, vehicle, mods, stored, garage, fuel, engine, body, state, type)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]]
    
    local params = {
        citizenid,              -- citizenid (charId du personnage)
        plate,                  -- plaque
        veh.model,             -- modèle du véhicule
        json.encode(vehicleMods), -- mods (JSON)
        1,                     -- stored (1 = en garage)
        nil,                   -- garage (NULL = pas de garage spécifique)
        100,                   -- fuel
        1000,                  -- engine
        1000,                  -- body
        1,                     -- state (1 = bon état)
        ConvertVehicleTypeForDB(data.vehicleType) -- type (car, boat, etc.)
    }
    
    exports.oxmysql:execute(sql, params, function(insertId)
        if not insertId then
            print('[vCore:Concess] ERREUR: Impossible d\'enregistrer le véhicule en base')
            vCore.Notify(src, '❌ Erreur d\'enregistrement du véhicule', 'error')
            return
        end
        
        -- Donner les clés
        GiveVehicleKeys(src, plate, veh.model)
        
        -- Spawn le véhicule côté client
        TriggerClientEvent('vcore_concess:spawnVehicle', src, veh.model, plate, livery, primaryColor, secondaryColor)
        TriggerClientEvent('vcore_concess:closeNUI', src)
        vCore.Notify(src, '✅ Véhicule acheté et enregistré! Prix: $' .. price, 'success')
        
        -- Enregistrer la transaction dans economy (si disponible)
        if EconomyEnabled then
            exports['vAvA_economy']:RegisterTransaction(
                'achat',
                veh.model,
                'vehicle',
                1,
                price
            )
        end
        
        print('^2[vCore:Concess] Véhicule vendu: ' .. veh.model .. ' à ' .. GetPlayerName(src) .. ' (plaque: ' .. plate .. ', prix: $' .. price .. ')^0')
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
            vCore.Notify(src, '❌ Accès refusé', 'error')
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
            vCore.Notify(src, '✅ Véhicule ajouté', 'success')
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
            vCore.Notify(src, '✅ Véhicule modifié', 'success')
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
            vCore.Notify(src, '✅ Véhicule supprimé', 'success')
        end
        
    elseif data.action == 'getVehiclesList' then
        TriggerClientEvent('vcore_concess:receiveVehiclesAdmin', src, vehicles)
        
    elseif data.action == 'reloadVehicles' then
        LoadVehicles()
        TriggerClientEvent('vcore_concess:updateVehicleCache', -1, vehicles)
        if vCore then
            vCore.Notify(src, '✅ Configuration rechargée', 'success')
        end
    end
end)

-- Commande admin
RegisterCommand('vadmin', function(source, args, rawCommand)
    local src = source
    
    if not IsPlayerAdmin(src) then
        if vCore then
            vCore.Notify(src, '❌ Permissions insuffisantes', 'error')
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
        vCore.Notify(src, 'Votre licence: ' .. license, 'primary')
        print('[vCore:Concess] License de ' .. GetPlayerName(src) .. ': ' .. license)
    end
end, false)

