--[[
    vAvA_keys - Server Keys Management
    Gestion avancée des clés
]]

-- Partager une clé
RegisterServerEvent('vAvA_keys:shareKey')
AddEventHandler('vAvA_keys:shareKey', function(plate, targetId, mode)
    local src = source
    local ownerCitizenid = GetPlayerCitizenId(src)
    local targetCitizenid = GetPlayerCitizenId(targetId)
    
    if not ownerCitizenid or not targetCitizenid or not plate then
        TriggerClientEvent('vAvA_keys:notify', src, 'Impossible de partager les clés', 'error')
        return
    end
    
    plate = string.gsub(plate, "%s+", "")
    mode = mode or 'perm'
    
    -- Vérifier que le joueur est propriétaire
    MySQL.Async.fetchAll(
        'SELECT ' .. KeysConfig.Database.Columns.Plate .. ' FROM ' .. KeysConfig.Database.PlayerVehiclesTable .. 
        ' WHERE ' .. KeysConfig.Database.Columns.CitizenId .. ' = ? AND ' .. KeysConfig.Database.Columns.Plate .. ' = ?',
        {ownerCitizenid, plate},
        function(vehicles)
            if not vehicles or #vehicles == 0 then
                TriggerClientEvent('vAvA_keys:notify', src, 'Vous n\'êtes pas propriétaire de ce véhicule', 'error')
                return
            end
            
            -- Insérer ou mettre à jour le partage
            MySQL.Async.execute(
                'INSERT INTO ' .. KeysConfig.Database.SharedKeysTable .. 
                ' (plate, owner_citizenid, target_citizenid, mode) VALUES (?, ?, ?, ?) ' ..
                'ON DUPLICATE KEY UPDATE mode = ?, created_at = NOW()',
                {plate, ownerCitizenid, targetCitizenid, mode, mode},
                function(rowsChanged)
                    if rowsChanged > 0 then
                        TriggerClientEvent('vAvA_keys:notify', src, 'Clés partagées avec succès', 'success')
                        
                        -- Notifier le joueur cible
                        local typeText = mode == 'temp' and 'temporaires' or 'permanentes'
                        TriggerClientEvent('vAvA_keys:receiveKey', targetId, plate, mode)
                        TriggerClientEvent('vAvA_keys:notify', targetId, 'Vous avez reçu des clés ' .. typeText, 'success')
                        
                        -- Resynchroniser
                        TriggerEvent('vAvA_keys:requestKeys')
                    else
                        TriggerClientEvent('vAvA_keys:notify', src, 'Erreur lors du partage', 'error')
                    end
                end
            )
        end
    )
end)

-- Retirer une clé partagée
RegisterServerEvent('vAvA_keys:removeSharedKey')
AddEventHandler('vAvA_keys:removeSharedKey', function(plate, targetCitizenid)
    local src = source
    local ownerCitizenid = GetPlayerCitizenId(src)
    
    if not ownerCitizenid or not targetCitizenid or not plate then return end
    
    plate = string.gsub(plate, "%s+", "")
    
    MySQL.Async.execute(
        'DELETE FROM ' .. KeysConfig.Database.SharedKeysTable .. 
        ' WHERE plate = ? AND owner_citizenid = ? AND target_citizenid = ?',
        {plate, ownerCitizenid, targetCitizenid},
        function(rowsDeleted)
            if rowsDeleted > 0 then
                TriggerClientEvent('vAvA_keys:notify', src, 'Clés retirées', 'success')
                
                -- Trouver et notifier le joueur cible s'il est connecté
                for _, playerId in ipairs(GetPlayers()) do
                    local playerCid = GetPlayerCitizenId(tonumber(playerId))
                    if playerCid == targetCitizenid then
                        TriggerClientEvent('vAvA_keys:notify', tonumber(playerId), 'Vos clés ont été retirées', 'info')
                        TriggerServerEvent('vAvA_keys:requestKeys')
                        break
                    end
                end
            end
        end
    )
end)

-- Récupérer la liste des clés partagées
RegisterServerEvent('vAvA_keys:getSharedKeysList')
AddEventHandler('vAvA_keys:getSharedKeysList', function(plate)
    local src = source
    local citizenid = GetPlayerCitizenId(src)
    
    if not citizenid or not plate then return end
    
    plate = string.gsub(plate, "%s+", "")
    
    MySQL.Async.fetchAll(
        'SELECT target_citizenid, mode, created_at FROM ' .. KeysConfig.Database.SharedKeysTable .. 
        ' WHERE plate = ? AND owner_citizenid = ?',
        {plate, citizenid},
        function(results)
            TriggerClientEvent('vAvA_keys:receiveSharedKeysList', src, plate, results or {})
        end
    )
end)
