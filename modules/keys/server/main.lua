--[[
    vAvA_keys - Server Main
    Système principal côté serveur
]]

-- ═══════════════════════════════════════════════════════════════════════════
-- INITIALISATION
-- ═══════════════════════════════════════════════════════════════════════════

local playerKeys = {}

CreateThread(function()
    print([[^5
    ╔═══════════════════════════════════════╗
    ║         vAvA_keys - Module            ║
    ║    Système de Clés Véhicules          ║
    ╚═══════════════════════════════════════╝
    ^0]])
    print('^2[vAvA_keys] Module démarré avec succès!^0')
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS UTILITAIRES
-- ═══════════════════════════════════════════════════════════════════════════

-- Récupérer le citizenid d'un joueur via vCore
local function GetPlayerCitizenId(source)
    local vCore = exports['vAvA_core']:GetCoreObject()
    if vCore and vCore.GetPlayer then
        local player = vCore.GetPlayer(source)
        if player and player.PlayerData then
            return player.PlayerData.charId or player:GetIdentifier()
        end
    end
    
    -- Fallback: identifiant license
    local identifiers = GetPlayerIdentifiers(source)
    for _, id in ipairs(identifiers) do
        if string.sub(id, 1, 9) == "license2:" then
            return id
        end
    end
    return nil
end

-- Récupérer le job d'un joueur
local function GetPlayerJob(source)
    local vCore = exports['vAvA_core']:GetCoreObject()
    if vCore and vCore.GetPlayer then
        local player = vCore.GetPlayer(source)
        if player and player.PlayerData and player.PlayerData.job then
            return player.PlayerData.job.name
        end
    end
    return nil
end

-- Notification au joueur
local function NotifyPlayer(source, message, type)
    local vCore = exports['vAvA_core']:GetCoreObject()
    if vCore and vCore.Notify then
        vCore.Notify(source, message, type)
    else
        TriggerClientEvent('vAvA_keys:notify', source, message, type)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

-- Donner les clés d'un véhicule
exports('GiveKeys', function(source, plate, vehicle)
    if not source or not plate then return false end
    
    plate = string.gsub(plate, "%s+", "")
    local citizenid = GetPlayerCitizenId(source)
    
    if not citizenid then return false end
    
    if not playerKeys[citizenid] then
        playerKeys[citizenid] = {}
    end
    
    playerKeys[citizenid][plate] = true
    TriggerClientEvent('vAvA_keys:syncKeys', source, playerKeys[citizenid])
    
    if KeysConfig.Debug then
        print('^2[vAvA_keys]^0 Clés données: ' .. plate .. ' à ' .. source)
    end
    
    return true
end)

-- Retirer les clés d'un véhicule
exports('RemoveKeys', function(source, plate)
    if not source or not plate then return false end
    
    plate = string.gsub(plate, "%s+", "")
    local citizenid = GetPlayerCitizenId(source)
    
    if not citizenid or not playerKeys[citizenid] then return false end
    
    playerKeys[citizenid][plate] = nil
    TriggerClientEvent('vAvA_keys:syncKeys', source, playerKeys[citizenid])
    
    return true
end)

-- Vérifier si un joueur a les clés
exports('HasKeys', function(source, plate)
    if not source or not plate then return false end
    
    plate = string.gsub(plate, "%s+", "")
    local citizenid = GetPlayerCitizenId(source)
    
    if not citizenid or not playerKeys[citizenid] then return false end
    
    return playerKeys[citizenid][plate] == true
end)

-- Récupérer toutes les clés d'un joueur
exports('GetPlayerKeys', function(source)
    local citizenid = GetPlayerCitizenId(source)
    if not citizenid then return {} end
    return playerKeys[citizenid] or {}
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS SERVEUR
-- ═══════════════════════════════════════════════════════════════════════════

-- Demande des clés par le client
RegisterServerEvent('vAvA_keys:requestKeys')
AddEventHandler('vAvA_keys:requestKeys', function()
    local src = source
    local citizenid = GetPlayerCitizenId(src)
    
    if not citizenid then return end
    
    -- Charger les clés depuis la base de données (véhicules possédés)
    MySQL.Async.fetchAll(
        'SELECT ' .. KeysConfig.Database.Columns.Plate .. ' FROM ' .. KeysConfig.Database.PlayerVehiclesTable .. 
        ' WHERE ' .. KeysConfig.Database.Columns.CitizenId .. ' = ?',
        {citizenid},
        function(vehicles)
            local keys = {}
            
            for _, vehicle in ipairs(vehicles or {}) do
                local plate = vehicle[KeysConfig.Database.Columns.Plate]
                if plate then
                    keys[string.gsub(plate, "%s+", "")] = true
                end
            end
            
            -- Charger les clés partagées
            MySQL.Async.fetchAll(
                'SELECT plate FROM ' .. KeysConfig.Database.SharedKeysTable .. 
                ' WHERE target_citizenid = ? AND (mode = "perm" OR (mode = "temp" AND created_at >= DATE_SUB(NOW(), INTERVAL ? MINUTE)))',
                {citizenid, KeysConfig.Keys.TempKeyDuration},
                function(shared)
                    for _, s in ipairs(shared or {}) do
                        if s.plate then
                            keys[string.gsub(s.plate, "%s+", "")] = true
                        end
                    end
                    
                    playerKeys[citizenid] = keys
                    TriggerClientEvent('vAvA_keys:syncKeys', src, keys)
                    
                    if KeysConfig.Debug then
                        print('^2[vAvA_keys]^0 Clés chargées pour ' .. citizenid .. ': ' .. json.encode(keys))
                    end
                end
            )
        end
    )
end)

-- Synchronisation du verrouillage
RegisterServerEvent('vAvA_keys:syncVehicleLock')
AddEventHandler('vAvA_keys:syncVehicleLock', function(netId, isLocked)
    local src = source
    if not netId then return end
    
    -- Broadcaster à tous les joueurs
    TriggerClientEvent('vAvA_keys:syncVehicleLockFromServer', -1, netId, isLocked)
    
    if KeysConfig.Debug then
        print('^2[vAvA_keys]^0 Lock sync: netId=' .. netId .. ', locked=' .. tostring(isLocked))
    end
end)

-- Vérification accès job
RegisterServerEvent('vAvA_keys:checkJobAccess')
AddEventHandler('vAvA_keys:checkJobAccess', function(plate)
    local src = source
    local playerJob = GetPlayerJob(src)
    
    if not playerJob or not plate then
        TriggerClientEvent('vAvA_keys:jobAccessResponse', src, plate, false)
        return
    end
    
    plate = string.gsub(plate, "%s+", "")
    
    -- Vérifier si le véhicule appartient au job du joueur
    MySQL.Async.fetchAll(
        'SELECT job FROM ' .. KeysConfig.Database.PlayerVehiclesTable .. 
        ' WHERE ' .. KeysConfig.Database.Columns.Plate .. ' = ?',
        {plate},
        function(result)
            local hasAccess = false
            
            if result and #result > 0 then
                local vehicleJob = result[1].job
                if vehicleJob and vehicleJob == playerJob then
                    hasAccess = true
                end
            end
            
            TriggerClientEvent('vAvA_keys:jobAccessResponse', src, plate, hasAccess)
        end
    )
end)

-- Nettoyage automatique des clés temporaires
CreateThread(function()
    while true do
        Wait(300000) -- 5 minutes
        MySQL.Async.execute(
            'DELETE FROM ' .. KeysConfig.Database.SharedKeysTable .. 
            ' WHERE mode = "temp" AND created_at < DATE_SUB(NOW(), INTERVAL ? MINUTE)',
            {KeysConfig.Keys.TempKeyDuration}
        )
    end
end)
