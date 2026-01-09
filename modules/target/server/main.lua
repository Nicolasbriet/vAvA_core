-- ============================================
-- vAvA Target - Server Main
-- Validation, sécurité, anti-cheat
-- ============================================

local playerInteractions = {}
local playerWarnings = {}

-- ============================================
-- VALIDATION DES INTERACTIONS
-- ============================================

RegisterNetEvent('vava_target:validateInteraction')
AddEventHandler('vava_target:validateInteraction', function(data)
    local src = source
    
    if not data or not data.event then
        print(string.format('[vAvA Target] Invalid interaction from player %s', src))
        return
    end
    
    -- Anti-spam
    if not CheckRateLimit(src) then
        SendWarning(src, 'rate_limit')
        return
    end
    
    -- Vérifier distance si entité fournie
    if data.entity and TargetConfig.Security.ValidateDistance then
        if not ValidateDistance(src, data.entity) then
            SendWarning(src, 'invalid_distance')
            return
        end
    end
    
    -- Vérifier que l'entité existe
    if data.entity and TargetConfig.Security.ValidateEntity then
        local entity = NetworkGetEntityFromNetworkId(data.entity)
        
        if not DoesEntityExist(entity) then
            SendWarning(src, 'invalid_entity')
            return
        end
    end
    
    -- Vérifier permissions (job, grade, item)
    -- Cette logique dépend de l'option, donc c'est à l'event déclenché de gérer
    
    -- Logger l'interaction
    if TargetConfig.Security.LogInteractions then
        LogInteraction(src, data)
    end
    
    -- Déclencher l'event validé
    TriggerClientEvent(data.event, src, {
        entity = data.entity,
        data = data.data
    })
end)

-- ============================================
-- RATE LIMITING
-- ============================================

function CheckRateLimit(playerId)
    local now = os.time()
    
    if not playerInteractions[playerId] then
        playerInteractions[playerId] = {
            count = 1,
            lastReset = now
        }
        return true
    end
    
    local playerData = playerInteractions[playerId]
    
    -- Reset toutes les 60 secondes
    if now - playerData.lastReset >= 60 then
        playerData.count = 1
        playerData.lastReset = now
        return true
    end
    
    -- Vérifier limite
    if playerData.count >= TargetConfig.Security.MaxInteractionsPerMinute then
        return false
    end
    
    playerData.count = playerData.count + 1
    return true
end

-- ============================================
-- VALIDATION DISTANCE
-- ============================================

function ValidateDistance(playerId, networkId)
    local playerPed = GetPlayerPed(playerId)
    
    if not DoesEntityExist(playerPed) then
        return false
    end
    
    local entity = NetworkGetEntityFromNetworkId(networkId)
    
    if not DoesEntityExist(entity) then
        return false
    end
    
    local playerCoords = GetEntityCoords(playerPed)
    local entityCoords = GetEntityCoords(entity)
    local distance = #(playerCoords - entityCoords)
    
    -- Distance max + marge de sécurité
    local maxDistance = TargetConfig.MaxDistance * 1.5
    
    return distance <= maxDistance
end

-- ============================================
-- SYSTÈME D'AVERTISSEMENTS
-- ============================================

function SendWarning(playerId, reason)
    if not playerWarnings[playerId] then
        playerWarnings[playerId] = {}
    end
    
    table.insert(playerWarnings[playerId], {
        reason = reason,
        timestamp = os.time()
    })
    
    local warningCount = #playerWarnings[playerId]
    
    -- Logging
    if TargetConfig.Debug then
        print(string.format('[vAvA Target] Warning %s for player %s (Total: %d)', reason, playerId, warningCount))
    end
    
    -- Log en BDD si activé
    if TargetConfig.Security.LogToDatabase then
        -- TODO: Intégration avec système de logs vAvA_core
    end
    
    -- Sanctions
    if warningCount >= TargetConfig.Security.WarningsBeforeKick then
        if TargetConfig.Security.AutoKick then
            DropPlayer(playerId, '[vAvA Target] Trop de tentatives d\'interaction suspectes')
            
            print(string.format('[vAvA Target] Player %s kicked for suspicious interactions', playerId))
        end
        
        if TargetConfig.Security.AutoBan then
            -- TODO: Intégration avec système de ban vAvA_core
            -- TriggerEvent('vava_admin:banPlayer', playerId, 'Target anti-cheat')
        end
    end
end

-- ============================================
-- LOGGING
-- ============================================

function LogInteraction(playerId, data)
    local logLevel = TargetConfig.Security.LogLevel
    
    if logLevel == 'debug' then
        print(string.format('[vAvA Target] Interaction: Player %s -> Event %s', playerId, data.event))
    end
    
    if TargetConfig.Security.LogToDatabase then
        -- TODO: Sauvegarder en BDD
        local logData = {
            player_id = playerId,
            event = data.event,
            entity = data.entity,
            data = json.encode(data.data or {}),
            timestamp = os.time()
        }
        
        -- MySQL.Async.execute('INSERT INTO vava_target_logs ...', logData)
    end
end

-- ============================================
-- EXPORTS SERVEUR
-- ============================================

-- Valider une interaction manuellement
function ValidateInteraction(playerId, eventName, entityNetworkId, data)
    local interactionData = {
        event = eventName,
        entity = entityNetworkId,
        data = data
    }
    
    TriggerEvent('vava_target:validateInteraction', interactionData)
end

-- Logger une interaction manuellement
function LogInteractionExport(playerId, eventName, details)
    LogInteraction(playerId, {
        event = eventName,
        data = details
    })
end

exports('ValidateInteraction', ValidateInteraction)
exports('LogInteraction', LogInteractionExport)

-- ============================================
-- COMMANDES ADMIN
-- ============================================

RegisterCommand('target_debug', function(source, args, rawCommand)
    local src = source
    
    -- TODO: Vérifier permissions admin
    -- if not IsPlayerAdmin(src) then return end
    
    TargetConfig.Debug = not TargetConfig.Debug
    
    TriggerClientEvent('chat:addMessage', src, {
        args = {'[vAvA Target]', 'Debug mode: ' .. (TargetConfig.Debug and 'ON' or 'OFF')}
    })
end, false)

RegisterCommand('target_stats', function(source, args, rawCommand)
    local src = source
    
    -- TODO: Vérifier permissions admin
    
    local stats = {
        totalInteractions = 0,
        totalWarnings = 0,
        playersWithWarnings = 0
    }
    
    for playerId, data in pairs(playerInteractions) do
        stats.totalInteractions = stats.totalInteractions + data.count
    end
    
    for playerId, warnings in pairs(playerWarnings) do
        stats.totalWarnings = stats.totalWarnings + #warnings
        stats.playersWithWarnings = stats.playersWithWarnings + 1
    end
    
    TriggerClientEvent('chat:addMessage', src, {
        args = {'[vAvA Target]', string.format('Stats - Interactions: %d | Warnings: %d | Players with warnings: %d', 
            stats.totalInteractions, stats.totalWarnings, stats.playersWithWarnings)}
    })
end, false)

-- ============================================
-- CLEANUP
-- ============================================

-- Nettoyer les données des joueurs déconnectés
AddEventHandler('playerDropped', function(reason)
    local src = source
    
    playerInteractions[src] = nil
    playerWarnings[src] = nil
end)

-- Nettoyer les anciennes données (toutes les heures)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(3600000) -- 1 heure
        
        local now = os.time()
        
        -- Nettoyer interactions vieilles de plus de 10 minutes
        for playerId, data in pairs(playerInteractions) do
            if now - data.lastReset > 600 then
                playerInteractions[playerId] = nil
            end
        end
        
        -- Nettoyer warnings vieux de plus de 1 heure
        for playerId, warnings in pairs(playerWarnings) do
            local newWarnings = {}
            
            for _, warning in ipairs(warnings) do
                if now - warning.timestamp <= 3600 then
                    table.insert(newWarnings, warning)
                end
            end
            
            if #newWarnings == 0 then
                playerWarnings[playerId] = nil
            else
                playerWarnings[playerId] = newWarnings
            end
        end
        
        if TargetConfig.Debug then
            print('[vAvA Target] Cleaned up old interaction data')
        end
    end
end)

-- ============================================
-- INITIALISATION
-- ============================================

Citizen.CreateThread(function()
    print('[vAvA Target] Server initialized successfully')
    print(string.format('[vAvA Target] Security - Anti-cheat: %s | Logging: %s | Max interactions/min: %d', 
        TargetConfig.Security.EnableAntiCheat and 'ON' or 'OFF',
        TargetConfig.Security.LogInteractions and 'ON' or 'OFF',
        TargetConfig.Security.MaxInteractionsPerMinute
    ))
end)
