--[[
    vAvA_player_manager - Server History
    Gestion des événements historiques
]]

local PMConfig = PlayerManagerConfig

-- ═══════════════════════════════════════════════════════════════════════════
-- NETTOYAGE AUTOMATIQUE
-- ═══════════════════════════════════════════════════════════════════════════

if PMConfig.History.HistoryRetention > 0 then
    CreateThread(function()
        while true do
            Wait(86400000)  -- 24 heures
            
            local cutoffDate = os.date('%Y-%m-%d', os.time() - (PMConfig.History.HistoryRetention * 86400))
            
            MySQL.update('DELETE FROM player_history WHERE created_at < ?', {cutoffDate}, function(affectedRows)
                if affectedRows > 0 then
                    print(string.format('[vAvA_player_manager] Nettoyé %d entrées d\'historique anciennes', affectedRows))
                end
            end)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- LOGGER AUTOMATIQUE
-- ═══════════════════════════════════════════════════════════════════════════

-- Hook changement job
RegisterNetEvent('vAvA_core:server:SetJob', function(citizenId, job, grade)
    if PMConfig.History.TrackJobChanges then
        exports['vAvA_player_manager']:AddHistory(
            citizenId,
            'job_change',
            string.format('Changement d\'emploi: %s (Grade %d)', job, grade),
            {job = job, grade = grade},
            nil,
            nil
        )
    end
end)

-- Hook transactions bancaires
RegisterNetEvent('vAvA_player_manager:server:LogBankTransaction', function(citizenId, type, amount, targetId)
    if not PMConfig.History.TrackBanks then return end
    
    local description = ''
    local eventType = ''
    
    if type == 'deposit' then
        description = 'Dépôt bancaire'
        eventType = 'bank_deposit'
    elseif type == 'withdraw' then
        description = 'Retrait bancaire'
        eventType = 'bank_withdraw'
    elseif type == 'transfer' then
        description = 'Virement bancaire'
        eventType = 'bank_transfer'
    end
    
    exports['vAvA_player_manager']:AddHistory(citizenId, eventType, description, nil, amount, targetId)
end)

-- Hook propriétés
RegisterNetEvent('vAvA_player_manager:server:LogProperty', function(citizenId, action, propertyName, amount)
    if not PMConfig.History.TrackProperties then return end
    
    local description = action == 'buy' and 'Achat propriété: ' .. propertyName or 'Vente propriété: ' .. propertyName
    local eventType = action == 'buy' and 'property_buy' or 'property_sell'
    
    exports['vAvA_player_manager']:AddHistory(citizenId, eventType, description, {property = propertyName}, amount, nil)
end)

-- Hook véhicules
RegisterNetEvent('vAvA_player_manager:server:LogVehicle', function(citizenId, action, vehicleModel, amount)
    if not PMConfig.History.TrackVehicles then return end
    
    local description = action == 'buy' and 'Achat véhicule: ' .. vehicleModel or 'Vente véhicule: ' .. vehicleModel
    local eventType = action == 'buy' and 'vehicle_buy' or 'vehicle_sell'
    
    exports['vAvA_player_manager']:AddHistory(citizenId, eventType, description, {model = vehicleModel}, amount, nil)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('LogJobChange', function(citizenId, job, grade)
    TriggerEvent('vAvA_core:server:SetJob', citizenId, job, grade)
end)

exports('LogBankTransaction', function(citizenId, type, amount, targetId)
    TriggerEvent('vAvA_player_manager:server:LogBankTransaction', citizenId, type, amount, targetId)
end)

exports('LogProperty', function(citizenId, action, propertyName, amount)
    TriggerEvent('vAvA_player_manager:server:LogProperty', citizenId, action, propertyName, amount)
end)

exports('LogVehicle', function(citizenId, action, vehicleModel, amount)
    TriggerEvent('vAvA_player_manager:server:LogVehicle', citizenId, action, vehicleModel, amount)
end)
