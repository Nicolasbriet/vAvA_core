-- ========================================
-- SYSTÈME EMS - SERVEUR PRINCIPAL
-- ========================================

local vCore = exports['vAvA_core']
local EMSPlayers = {}
local EmergencyCalls = {}
local BloodStock = {}

-- ========================================
-- INITIALISATION
-- ========================================

CreateThread(function()
    -- Créer les tables si elles n'existent pas
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS player_medical (
            id INT AUTO_INCREMENT PRIMARY KEY,
            identifier VARCHAR(50) NOT NULL,
            blood_type VARCHAR(3) DEFAULT 'O+',
            last_checkup INT DEFAULT 0,
            last_blood_donation INT DEFAULT 0,
            medical_history TEXT,
            UNIQUE KEY (identifier)
        )
    ]])
    
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS player_injuries (
            id INT AUTO_INCREMENT PRIMARY KEY,
            identifier VARCHAR(50) NOT NULL,
            injury_type VARCHAR(50) NOT NULL,
            body_part VARCHAR(20) NOT NULL,
            severity INT NOT NULL,
            timestamp INT NOT NULL,
            treated BOOLEAN DEFAULT FALSE,
            INDEX (identifier)
        )
    ]])
    
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS hospital_blood_stock (
            id INT AUTO_INCREMENT PRIMARY KEY,
            blood_type VARCHAR(3) NOT NULL,
            units INT DEFAULT 0,
            last_update INT NOT NULL,
            UNIQUE KEY (blood_type)
        )
    ]])
    
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS emergency_calls (
            id INT AUTO_INCREMENT PRIMARY KEY,
            caller VARCHAR(50),
            location VARCHAR(255) NOT NULL,
            coords VARCHAR(100) NOT NULL,
            call_type VARCHAR(20) NOT NULL,
            priority INT NOT NULL,
            status VARCHAR(20) DEFAULT 'pending',
            assigned_to VARCHAR(50),
            timestamp INT NOT NULL,
            INDEX (status)
        )
    ]])
    
    -- Initialiser le stock de sang
    InitializeBloodStock()
    
    print("^2[vAvA_ems]^7 Module EMS chargé avec succès")
end)

-- Initialiser le stock de sang
function InitializeBloodStock()
    for bloodType, units in pairs(EMSConfig.InitialBloodStock) do
        MySQL.query('INSERT INTO hospital_blood_stock (blood_type, units, last_update) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE units = units',
            {bloodType, units, os.time()})
        BloodStock[bloodType] = units
    end
end

-- ========================================
-- GESTION DES JOUEURS
-- ========================================

-- Charger les données médicales d'un joueur
function LoadPlayerMedicalData(source)
    local xPlayer = vCore:GetPlayer(source)
    if not xPlayer then return end
    
    local identifier = xPlayer.identifier
    
    -- Charger les données médicales
    local result = MySQL.query.await('SELECT * FROM player_medical WHERE identifier = ?', {identifier})
    
    if not result or #result == 0 then
        -- Créer un nouveau profil médical
        local bloodType = GetRandomBloodType()
        MySQL.insert('INSERT INTO player_medical (identifier, blood_type, last_checkup, last_blood_donation) VALUES (?, ?, ?, ?)',
            {identifier, bloodType, 0, 0})
        
        EMSPlayers[source] = {
            identifier = identifier,
            bloodType = bloodType,
            state = EMSConfig.MedicalStates.NORMAL,
            vitalSigns = table.clone(EMSConfig.NormalVitalSigns),
            injuries = {},
            lastUpdate = os.time()
        }
    else
        local data = result[1]
        EMSPlayers[source] = {
            identifier = identifier,
            bloodType = data.blood_type,
            state = EMSConfig.MedicalStates.NORMAL,
            vitalSigns = table.clone(EMSConfig.NormalVitalSigns),
            injuries = {},
            lastUpdate = os.time()
        }
        
        -- Charger les blessures non traitées
        LoadPlayerInjuries(source)
    end
    
    TriggerClientEvent('vAvA_ems:client:updateMedicalState', source, EMSPlayers[source])
end

-- Charger les blessures d'un joueur
function LoadPlayerInjuries(source)
    local player = EMSPlayers[source]
    if not player then return end
    
    local result = MySQL.query.await('SELECT * FROM player_injuries WHERE identifier = ? AND treated = FALSE', {player.identifier})
    
    if result and #result > 0 then
        for _, injury in ipairs(result) do
            table.insert(player.injuries, {
                id = injury.id,
                type = injury.injury_type,
                bodyPart = injury.body_part,
                severity = injury.severity,
                timestamp = injury.timestamp
            })
        end
        
        -- Recalculer l'état médical
        UpdatePlayerMedicalState(source)
    end
end

-- Sauvegarder les données médicales
function SavePlayerMedicalData(source)
    local player = EMSPlayers[source]
    if not player then return end
    
    -- Sauvegarder les signes vitaux et l'état
    -- Note: Les blessures sont sauvegardées individuellement
    
    if EMSConfig.Debug then
        print(string.format("^3[DEBUG]^7 Données médicales sauvegardées pour %s", GetPlayerName(source)))
    end
end

-- Obtenir un groupe sanguin aléatoire
function GetRandomBloodType()
    local random = math.random(1, 100)
    if random <= 7 then return 'O-'
    elseif random <= 45 then return 'O+'
    elseif random <= 52 then return 'A-'
    elseif random <= 82 then return 'A+'
    elseif random <= 84 then return 'B-'
    elseif random <= 93 then return 'B+'
    elseif random <= 94 then return 'AB-'
    else return 'AB+' end
end

-- ========================================
-- SYSTÈME MÉDICAL - ÉTATS & SIGNES VITAUX
-- ========================================

-- Mettre à jour l'état médical d'un joueur
function UpdatePlayerMedicalState(source)
    local player = EMSPlayers[source]
    if not player then return end
    
    local newState = EMSConfig.MedicalStates.NORMAL
    
    -- Déterminer l'état en fonction des blessures et signes vitaux
    if player.vitalSigns.bloodVolume <= 0 or player.vitalSigns.pulse <= 0 then
        newState = EMSConfig.MedicalStates.CARDIAC_ARREST
    elseif player.vitalSigns.bloodVolume < 30 then
        newState = EMSConfig.MedicalStates.UNCONSCIOUS
    elseif #player.injuries > 0 then
        local totalSeverity = 0
        local hasBleed = false
        
        for _, injury in ipairs(player.injuries) do
            totalSeverity = totalSeverity + injury.severity
            if string.find(injury.type, 'bleeding') or string.find(injury.type, 'wound') then
                hasBleed = true
            end
        end
        
        if hasBleed then
            newState = EMSConfig.MedicalStates.BLEEDING
        elseif totalSeverity >= 10 then
            newState = EMSConfig.MedicalStates.SEVERE_PAIN
        elseif totalSeverity >= 6 then
            newState = EMSConfig.MedicalStates.MODERATE_PAIN
        elseif totalSeverity >= 3 then
            newState = EMSConfig.MedicalStates.LIGHT_PAIN
        end
    end
    
    player.state = newState
    player.lastUpdate = os.time()
    
    -- Envoyer au client
    TriggerClientEvent('vAvA_ems:client:updateMedicalState', source, player)
    
    -- Alertes EMS si état critique
    if newState == EMSConfig.MedicalStates.CARDIAC_ARREST or newState == EMSConfig.MedicalStates.UNCONSCIOUS then
        CreateAutoEmergencyCall(source)
    end
end

-- Définir un signe vital
function SetVitalSign(source, vitalSign, value)
    local player = EMSPlayers[source]
    if not player then return false end
    
    if player.vitalSigns[vitalSign] == nil then return false end
    
    -- Appliquer les limites
    local limits = EMSConfig.CriticalLimits[vitalSign]
    if limits then
        value = math.max(limits.min, math.min(limits.max, value))
    end
    
    player.vitalSigns[vitalSign] = value
    UpdatePlayerMedicalState(source)
    
    return true
end

-- Obtenir les signes vitaux
function GetVitalSigns(source)
    local player = EMSPlayers[source]
    if not player then return nil end
    
    return player.vitalSigns
end

-- ========================================
-- SYSTÈME DE BLESSURES
-- ========================================

-- Ajouter une blessure
function AddInjury(source, injuryType, bodyPart, severity)
    local player = EMSPlayers[source]
    if not player then return false end
    
    -- Vérifier que le type de blessure existe
    local validType = false
    for _, type in ipairs(EMSConfig.InjuryTypes) do
        if type == injuryType then
            validType = true
            break
        end
    end
    if not validType then return false end
    
    -- Vérifier que la partie du corps existe
    local validPart = false
    for _, part in ipairs(EMSConfig.BodyParts) do
        if part == bodyPart then
            validPart = true
            break
        end
    end
    if not validPart then return false end
    
    -- Limiter la sévérité
    severity = math.max(1, math.min(4, severity))
    
    -- Insérer en BDD
    local id = MySQL.insert.await('INSERT INTO player_injuries (identifier, injury_type, body_part, severity, timestamp, treated) VALUES (?, ?, ?, ?, ?, ?)',
        {player.identifier, injuryType, bodyPart, severity, os.time(), false})
    
    -- Ajouter à la table locale
    table.insert(player.injuries, {
        id = id,
        type = injuryType,
        bodyPart = bodyPart,
        severity = severity,
        timestamp = os.time()
    })
    
    -- Mettre à jour l'état médical
    UpdatePlayerMedicalState(source)
    
    -- Notification
    TriggerClientEvent('vAvA_core:Notify', source, Lang('injury_received'), 'error')
    
    if EMSConfig.Debug then
        print(string.format("^3[DEBUG]^7 Blessure ajoutée: %s sur %s (sévérité: %d) pour %s", 
            injuryType, bodyPart, severity, GetPlayerName(source)))
    end
    
    return true
end

-- Retirer une blessure
function RemoveInjury(source, injuryId)
    local player = EMSPlayers[source]
    if not player then return false end
    
    -- Marquer comme traitée en BDD
    MySQL.update('UPDATE player_injuries SET treated = TRUE WHERE id = ?', {injuryId})
    
    -- Retirer de la table locale
    for i, injury in ipairs(player.injuries) do
        if injury.id == injuryId then
            table.remove(player.injuries, i)
            break
        end
    end
    
    UpdatePlayerMedicalState(source)
    
    return true
end

-- Soigner toutes les blessures d'une partie du corps
function TreatBodyPart(source, bodyPart)
    local player = EMSPlayers[source]
    if not player then return false end
    
    local treated = 0
    for i = #player.injuries, 1, -1 do
        if player.injuries[i].bodyPart == bodyPart then
            RemoveInjury(source, player.injuries[i].id)
            treated = treated + 1
        end
    end
    
    if treated > 0 then
        TriggerClientEvent('vAvA_core:Notify', source, Lang('bodypart_treated', {part = bodyPart, count = treated}), 'success')
        return true
    end
    
    return false
end

-- ========================================
-- SYSTÈME DE SANG & TRANSFUSIONS
-- ========================================

-- Obtenir le groupe sanguin d'un joueur
function GetBloodType(source)
    local player = EMSPlayers[source]
    if not player then return nil end
    
    return player.bloodType
end

-- Définir le groupe sanguin (pour tests/admin)
function SetBloodType(source, bloodType)
    local player = EMSPlayers[source]
    if not player then return false end
    
    -- Vérifier que le groupe sanguin existe
    local valid = false
    for _, type in ipairs(EMSConfig.BloodTypes) do
        if type == bloodType then
            valid = true
            break
        end
    end
    if not valid then return false end
    
    player.bloodType = bloodType
    MySQL.update('UPDATE player_medical SET blood_type = ? WHERE identifier = ?', {bloodType, player.identifier})
    
    return true
end

-- Obtenir le stock de sang
function GetBloodStock(bloodType)
    if bloodType then
        return BloodStock[bloodType] or 0
    else
        return BloodStock
    end
end

-- Ajouter du sang au stock
function AddBloodStock(bloodType, units)
    if not BloodStock[bloodType] then return false end
    
    BloodStock[bloodType] = BloodStock[bloodType] + units
    MySQL.update('UPDATE hospital_blood_stock SET units = units + ?, last_update = ? WHERE blood_type = ?',
        {units, os.time(), bloodType})
    
    -- Notifier tous les EMS en service
    NotifyAllEMS(Lang('blood_stock_updated', {type = bloodType, units = BloodStock[bloodType]}), 'info')
    
    return true
end

-- Retirer du sang du stock
function RemoveBloodStock(bloodType, units)
    if not BloodStock[bloodType] then return false end
    if BloodStock[bloodType] < units then return false end
    
    BloodStock[bloodType] = BloodStock[bloodType] - units
    MySQL.update('UPDATE hospital_blood_stock SET units = units - ?, last_update = ? WHERE blood_type = ?',
        {units, os.time(), bloodType})
    
    return true
end

-- Transfuser du sang
function TransfuseBlood(source, targetSource, bloodType)
    local medic = EMSPlayers[source]
    local patient = EMSPlayers[targetSource]
    
    if not medic or not patient then return false end
    
    -- Vérifier compatibilité
    local compatible = false
    for _, compatibleType in ipairs(EMSConfig.BloodCompatibility[patient.bloodType]) do
        if compatibleType == bloodType then
            compatible = true
            break
        end
    end
    
    if not compatible then
        TriggerClientEvent('vAvA_core:Notify', source, Lang('blood_incompatible'), 'error')
        return false
    end
    
    -- Vérifier stock
    if GetBloodStock(bloodType) < 1 then
        TriggerClientEvent('vAvA_core:Notify', source, Lang('blood_stock_empty'), 'error')
        return false
    end
    
    -- Effectuer la transfusion
    RemoveBloodStock(bloodType, 1)
    
    -- Restaurer volume sanguin
    local newVolume = math.min(100, patient.vitalSigns.bloodVolume + 20)
    SetVitalSign(targetSource, 'bloodVolume', newVolume)
    
    TriggerClientEvent('vAvA_core:Notify', source, Lang('transfusion_success'), 'success')
    TriggerClientEvent('vAvA_core:Notify', targetSource, Lang('transfusion_received'), 'info')
    
    -- Log
    if EMSConfig.Debug then
        print(string.format("^2[TRANSFUSION]^7 %s a transfusé %s à %s", 
            GetPlayerName(source), bloodType, GetPlayerName(targetSource)))
    end
    
    return true
end

-- Don de sang
RegisterNetEvent('vAvA_ems:server:donateBlood', function()
    local source = source
    local player = EMSPlayers[source]
    if not player then return end
    
    local xPlayer = vCore:GetPlayer(source)
    if not xPlayer then return end
    
    -- Vérifier cooldown
    local result = MySQL.query.await('SELECT last_blood_donation FROM player_medical WHERE identifier = ?', {player.identifier})
    if result and #result > 0 then
        local lastDonation = result[1].last_blood_donation
        local timeSince = os.time() - lastDonation
        
        if timeSince < EMSConfig.BloodDonation.cooldown then
            local remaining = EMSConfig.BloodDonation.cooldown - timeSince
            TriggerClientEvent('vAvA_core:Notify', source, Lang('blood_donation_cooldown', {time = math.ceil(remaining / 86400)}), 'error')
            return
        end
    end
    
    -- Vérifier santé
    local health = GetEntityHealth(GetPlayerPed(source))
    if health < EMSConfig.BloodDonation.minHealth then
        TriggerClientEvent('vAvA_core:Notify', source, Lang('blood_donation_health_too_low'), 'error')
        return
    end
    
    -- Effectuer le don
    AddBloodStock(player.bloodType, EMSConfig.BloodDonation.unitsPerDonation)
    
    -- Récompense
    xPlayer:AddMoney('cash', EMSConfig.BloodDonation.reward)
    
    -- Mettre à jour la date
    MySQL.update('UPDATE player_medical SET last_blood_donation = ? WHERE identifier = ?', {os.time(), player.identifier})
    
    -- Appliquer effets temporaires
    TriggerClientEvent('vAvA_ems:client:bloodDonationEffects', source, EMSConfig.BloodDonation.effectDuration)
    
    TriggerClientEvent('vAvA_core:Notify', source, Lang('blood_donation_success', {reward = EMSConfig.BloodDonation.reward}), 'success')
end)

-- ========================================
-- SYSTÈME D'APPELS D'URGENCE
-- ========================================

-- Créer un appel d'urgence
function CreateEmergencyCall(source, callType, message)
    local coords = GetEntityCoords(GetPlayerPed(source))
    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local streetName = GetStreetNameFromHashKey(streetHash)
    
    local priority = 3
    if callType == 'RED' then priority = 1
    elseif callType == 'ORANGE' then priority = 2
    elseif callType == 'YELLOW' then priority = 3
    else priority = 4 end
    
    local callId = MySQL.insert.await('INSERT INTO emergency_calls (caller, location, coords, call_type, priority, status, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)',
        {GetPlayerIdentifier(source, 0), streetName, json.encode(coords), callType, priority, 'pending', os.time()})
    
    local call = {
        id = callId,
        caller = source,
        callerName = GetPlayerName(source),
        location = streetName,
        coords = coords,
        type = callType,
        priority = priority,
        message = message or '',
        timestamp = os.time()
    }
    
    EmergencyCalls[callId] = call
    
    -- Notifier tous les EMS
    NotifyAllEMS(Lang('emergency_call_received', {code = EMSConfig.EmergencyCalls.codes[callType].label, location = streetName}), 'info')
    TriggerClientEvent('vAvA_ems:client:newEmergencyCall', -1, call)
    
    return callId
end

-- Créer un appel automatique
function CreateAutoEmergencyCall(source)
    if not EMSConfig.EmergencyCalls.autoDetect then return end
    
    local player = EMSPlayers[source]
    if not player then return end
    
    -- Vérifier cooldown
    if player.lastEmergencyCall and (os.time() - player.lastEmergencyCall) < EMSConfig.EmergencyCalls.cooldown then
        return
    end
    
    local callType = 'ORANGE'
    if player.state == EMSConfig.MedicalStates.CARDIAC_ARREST then
        callType = 'RED'
    end
    
    CreateEmergencyCall(source, callType, 'Détection automatique')
    player.lastEmergencyCall = os.time()
end

-- Obtenir les appels actifs
function GetActiveCalls()
    return EmergencyCalls
end

-- Notifier tous les EMS
function NotifyAllEMS(message, type)
    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        local xPlayer = vCore:GetPlayer(tonumber(playerId))
        if xPlayer and xPlayer:GetJob().name == EMSConfig.EMSJob then
            TriggerClientEvent('vAvA_core:Notify', tonumber(playerId), message, type or 'info')
        end
    end
end

-- ========================================
-- EVENTS
-- ========================================

RegisterNetEvent('vAvA_ems:server:requestMedicalData', function()
    local source = source
    LoadPlayerMedicalData(source)
end)

RegisterNetEvent('vAvA_ems:server:emergencyCall', function(callType, message)
    local source = source
    CreateEmergencyCall(source, callType, message)
end)

-- ========================================
-- EXPORTS
-- ========================================

exports('GetPlayerMedicalState', function(source)
    return EMSPlayers[source]
end)

exports('SetPlayerMedicalState', function(source, state)
    local player = EMSPlayers[source]
    if not player then return false end
    player.state = state
    UpdatePlayerMedicalState(source)
    return true
end)

exports('AddInjury', AddInjury)
exports('RemoveInjury', RemoveInjury)
exports('GetVitalSigns', GetVitalSigns)
exports('SetVitalSign', SetVitalSign)
exports('GetBloodType', GetBloodType)
exports('SetBloodType', SetBloodType)
exports('GetBloodStock', GetBloodStock)
exports('AddBloodStock', AddBloodStock)
exports('RemoveBloodStock', RemoveBloodStock)
exports('TransfuseBlood', TransfuseBlood)
exports('CreateEmergencyCall', CreateEmergencyCall)
exports('GetActiveCalls', GetActiveCalls)

-- ========================================
-- THREADS
-- ========================================

-- Sauvegarde automatique
CreateThread(function()
    while true do
        Wait(EMSConfig.Save.interval * 1000)
        
        for source, _ in pairs(EMSPlayers) do
            SavePlayerMedicalData(source)
        end
    end
end)

-- Mise à jour des signes vitaux
CreateThread(function()
    while true do
        Wait(5000) -- Toutes les 5 secondes
        
        for source, player in pairs(EMSPlayers) do
            if player.state ~= EMSConfig.MedicalStates.NORMAL then
                -- Perte de sang si saignement
                if player.state == EMSConfig.MedicalStates.BLEEDING then
                    local bleedRate = EMSConfig.BleedingRates.active
                    local newVolume = math.max(0, player.vitalSigns.bloodVolume - bleedRate * 5)
                    SetVitalSign(source, 'bloodVolume', newVolume)
                end
                
                -- DÉSACTIVÉ: Les natives SetEntityHealth sont CLIENT-SIDE ONLY
                -- Ce code ne fonctionne pas sur le serveur
                -- TODO: Envoyer un event au client pour appliquer les dégâts si nécessaire
                --[[
                if player.state == EMSConfig.MedicalStates.SEVERE_PAIN then
                    local ped = GetPlayerPed(source)
                    local health = GetEntityHealth(ped)
                    if health > 100 then
                        SetEntityHealth(ped, health - 1)
                    end
                end
                ]]
            end
        end
    end
end)

-- ========================================
-- HANDLERS
-- ========================================

AddEventHandler('playerDropped', function(reason)
    local source = source
    SavePlayerMedicalData(source)
    EMSPlayers[source] = nil
end)

AddEventHandler('vCore:playerLoaded', function(source, xPlayer)
    LoadPlayerMedicalData(source)
end)
