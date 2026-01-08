--[[
    vAvA_keys - Server Share
    Gestion des partages de clés
]]

-- Export pour partager des clés via API
exports('ShareKeys', function(ownerSource, targetSource, plate, mode)
    if not ownerSource or not targetSource or not plate then return false end
    
    local ownerCitizenid = GetPlayerCitizenId(ownerSource)
    local targetCitizenid = GetPlayerCitizenId(targetSource)
    
    if not ownerCitizenid or not targetCitizenid then return false end
    
    plate = string.gsub(plate, "%s+", "")
    mode = mode or 'perm'
    
    local success = MySQL.Sync.execute(
        'INSERT INTO ' .. KeysConfig.Database.SharedKeysTable .. 
        ' (plate, owner_citizenid, target_citizenid, mode) VALUES (?, ?, ?, ?) ' ..
        'ON DUPLICATE KEY UPDATE mode = ?, created_at = NOW()',
        {plate, ownerCitizenid, targetCitizenid, mode, mode}
    )
    
    if success and success > 0 then
        TriggerClientEvent('vAvA_keys:receiveKey', targetSource, plate, mode)
        return true
    end
    
    return false
end)
