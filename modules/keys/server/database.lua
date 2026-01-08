--[[
    vAvA_keys - Server Database
    Auto-création des tables au démarrage
]]

local function CreateTables()
    if KeysConfig.ShowDatabaseLogs then
        print('^3[vAvA_keys]^0 Vérification et création des tables...')
    end
    
    -- Table pour les clés partagées
    local createSharedKeysTable = [[
        CREATE TABLE IF NOT EXISTS `shared_vehicle_keys` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `plate` varchar(15) NOT NULL,
            `owner_citizenid` varchar(50) NOT NULL,
            `target_citizenid` varchar(50) NOT NULL,
            `mode` enum('perm','temp') NOT NULL DEFAULT 'perm',
            `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `expires_at` timestamp NULL DEFAULT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `unique_share` (`plate`,`owner_citizenid`,`target_citizenid`),
            KEY `idx_target_citizenid` (`target_citizenid`),
            KEY `idx_plate` (`plate`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]
    
    MySQL.Async.execute(createSharedKeysTable, {}, function(result)
        if KeysConfig.ShowDatabaseLogs then
            print('^2[vAvA_keys]^0 Table shared_vehicle_keys créée/vérifiée')
        end
    end)
end

-- Initialisation
CreateThread(function()
    if not KeysConfig.AutoCreateDatabase then
        return
    end
    
    Wait(1000)
    CreateTables()
    
    -- Nettoyer les clés expirées
    MySQL.Async.execute(
        'DELETE FROM shared_vehicle_keys WHERE mode = "temp" AND created_at < DATE_SUB(NOW(), INTERVAL ? MINUTE)',
        {KeysConfig.Keys.TempKeyDuration}
    )
end)
