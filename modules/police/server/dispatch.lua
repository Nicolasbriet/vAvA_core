--[[
    vAvA_police - Server Dispatch
    Système d'alertes automatiques
]]

-- ═══════════════════════════════════════════════════════════════════════════
-- ENVOYER ALERTE
-- ═══════════════════════════════════════════════════════════════════════════

function SendDispatchAlert(code, message, coords, priority)
    priority = priority or 3
    
    -- Trouver le type d'alerte
    local alertType = nil
    for _, alert in ipairs(PoliceConfig.Dispatch.AlertTypes) do
        if alert.code == code then
            alertType = alert
            break
        end
    end
    
    if not alertType then
        print('^1[vAvA_police] Code d\'alerte inconnu: ' .. code .. '^0')
        return
    end
    
    -- Créer alerte en BDD
    exports['vAvA_police']:CreateAlert({
        code = code,
        type = alertType.label,
        message = message,
        coords = coords,
        priority = priority
    })
    
    -- Envoyer à tous les policiers en service
    local onDutyCount, onDutyList = exports['vAvA_police']:GetOnDutyPolice()
    
    for playerId, _ in pairs(onDutyList) do
        TriggerClientEvent('vAvA_police:client:ReceiveAlert', playerId, {
            code = code,
            type = alertType.label,
            message = message,
            coords = coords,
            priority = priority,
            color = alertType.color,
            timestamp = os.time()
        })
    end
    
    print(string.format('^3[vAvA_police] Alerte %s envoyée à %d policier(s)^0', code, onDutyCount))
end

-- ═══════════════════════════════════════════════════════════════════════════
-- DEMANDE DE RENFORT
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_police:server:RequestBackup', function(coords)
    local src = source
    local vCore = exports['vAvA_core']:GetCoreObject()
    local player = vCore.GetPlayer(src)
    
    if not player then return end
    
    local officerName = player.PlayerData.firstName .. ' ' .. player.PlayerData.lastName
    
    -- Envoyer à tous les autres policiers
    local onDutyCount, onDutyList = exports['vAvA_police']:GetOnDutyPolice()
    
    for playerId, _ in pairs(onDutyList) do
        if playerId ~= src then
            TriggerClientEvent('vAvA_police:client:BackupRequested', playerId, officerName, coords)
        end
    end
    
    -- Logger
    exports['vAvA_police']:LogPoliceAction({
        officer_id = player.PlayerData.citizenid,
        officer_name = officerName,
        action = 'backup_request',
        details = string.format('Demande renfort à %.2f, %.2f, %.2f', coords.x, coords.y, coords.z)
    })
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- RÉPONDRE À ALERTE
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_police:server:RespondToAlert', function(alertId)
    local src = source
    local vCore = exports['vAvA_core']:GetCoreObject()
    local player = vCore.GetPlayer(src)
    
    if not player then return end
    
    exports['vAvA_police']:RespondToAlert(alertId, player.PlayerData.citizenid)
    
    -- Notifier autres policiers
    local onDutyCount, onDutyList = exports['vAvA_police']:GetOnDutyPolice()
    local officerName = player.PlayerData.firstName .. ' ' .. player.PlayerData.lastName
    
    for playerId, _ in pairs(onDutyList) do
        if playerId ~= src then
            TriggerClientEvent('vAvA:Notify', playerId, officerName .. ' a pris en charge l\'alerte', 'info')
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- CALLBACKS POUR TABLETTE
-- ═══════════════════════════════════════════════════════════════════════════

local vCore = exports['vAvA_core']:GetCoreObject()

vCore.CreateCallback('vAvA_police:server:GetRecentAlerts', function(source, cb)
    exports['vAvA_police']:GetRecentAlerts(20, function(alerts)
        cb(alerts)
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('SendDispatchAlert', SendDispatchAlert)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXEMPLES D'ALERTES AUTO (À INTÉGRER DANS AUTRES MODULES)
-- ═══════════════════════════════════════════════════════════════════════════

--[[
    USAGE DANS AUTRES RESSOURCES:
    
    -- Cambriolage détecté
    exports['vAvA_police']:SendDispatchAlert('10-90', 'Cambriolage en cours - 24/7 Store', coords, 2)
    
    -- Vol de véhicule
    exports['vAvA_police']:SendDispatchAlert('10-60', 'Vol de véhicule signalé', coords, 2)
    
    -- Tir détecté
    exports['vAvA_police']:SendDispatchAlert('10-32', 'Coups de feu signalés', coords, 1)
    
    -- Accident
    exports['vAvA_police']:SendDispatchAlert('10-50', 'Accident de la route', coords, 3)
]]
