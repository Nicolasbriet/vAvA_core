--[[
    vAvA_core - Système de migrations SQL
]]

vCore = vCore or {}
vCore.Migrations = {}

local migrations = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- DÉFINITION DES MIGRATIONS
-- ═══════════════════════════════════════════════════════════════════════════

migrations[1] = {
    name = 'create_users_table',
    query = [[
        CREATE TABLE IF NOT EXISTS `users` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `identifier` VARCHAR(60) NOT NULL UNIQUE,
            `license` VARCHAR(60) DEFAULT NULL,
            `steam` VARCHAR(60) DEFAULT NULL,
            `discord` VARCHAR(60) DEFAULT NULL,
            `name` VARCHAR(60) DEFAULT 'Unknown',
            `group` VARCHAR(30) DEFAULT 'user',
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `last_seen` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX `idx_identifier` (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]
}

migrations[2] = {
    name = 'create_characters_table',
    query = [[
        CREATE TABLE IF NOT EXISTS `characters` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `identifier` VARCHAR(60) NOT NULL,
            `firstname` VARCHAR(60) NOT NULL,
            `lastname` VARCHAR(60) NOT NULL,
            `dob` VARCHAR(20) DEFAULT '01/01/2000',
            `gender` TINYINT DEFAULT 0,
            `money` LONGTEXT DEFAULT '{"cash":5000,"bank":10000,"black_money":0}',
            `job` LONGTEXT DEFAULT '{"name":"unemployed","grade":0}',
            `gang` LONGTEXT DEFAULT '{"name":"none","grade":0}',
            `position` LONGTEXT DEFAULT '{"x":-269.4,"y":-955.3,"z":31.2,"heading":205.0}',
            `status` LONGTEXT DEFAULT '{"hunger":100,"thirst":100,"stress":0}',
            `inventory` LONGTEXT DEFAULT '[]',
            `metadata` LONGTEXT DEFAULT '{}',
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `last_played` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX `idx_identifier` (`identifier`),
            FOREIGN KEY (`identifier`) REFERENCES `users`(`identifier`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]
}

migrations[3] = {
    name = 'create_items_table',
    query = [[
        CREATE TABLE IF NOT EXISTS `items` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `name` VARCHAR(60) NOT NULL UNIQUE,
            `label` VARCHAR(100) NOT NULL,
            `description` TEXT DEFAULT NULL,
            `weight` INT DEFAULT 100,
            `type` VARCHAR(30) DEFAULT 'item',
            `unique` TINYINT(1) DEFAULT 0,
            `useable` TINYINT(1) DEFAULT 1,
            `image` VARCHAR(100) DEFAULT NULL,
            `metadata` LONGTEXT DEFAULT '{}',
            INDEX `idx_name` (`name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]
}

migrations[4] = {
    name = 'create_inventories_table',
    query = [[
        CREATE TABLE IF NOT EXISTS `inventories` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `identifier` VARCHAR(100) NOT NULL UNIQUE,
            `type` VARCHAR(30) DEFAULT 'stash',
            `items` LONGTEXT DEFAULT '[]',
            `max_weight` INT DEFAULT 100000,
            `max_slots` INT DEFAULT 100,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_identifier` (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]
}

migrations[5] = {
    name = 'create_vehicles_table',
    query = [[
        CREATE TABLE IF NOT EXISTS `vehicles` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `owner` VARCHAR(60) NOT NULL,
            `plate` VARCHAR(10) NOT NULL UNIQUE,
            `model` VARCHAR(60) NOT NULL,
            `props` LONGTEXT DEFAULT '{}',
            `state` ENUM('garaged', 'out', 'impounded', 'destroyed') DEFAULT 'garaged',
            `garage` VARCHAR(60) DEFAULT 'default',
            `fuel` INT DEFAULT 100,
            `body` FLOAT DEFAULT 1000.0,
            `engine` FLOAT DEFAULT 1000.0,
            `mileage` INT DEFAULT 0,
            `insurance` TINYINT(1) DEFAULT 0,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_owner` (`owner`),
            INDEX `idx_plate` (`plate`),
            FOREIGN KEY (`owner`) REFERENCES `users`(`identifier`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]
}

migrations[6] = {
    name = 'create_bans_table',
    query = [[
        CREATE TABLE IF NOT EXISTS `bans` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `identifier` VARCHAR(60) NOT NULL,
            `license` VARCHAR(60) DEFAULT NULL,
            `steam` VARCHAR(60) DEFAULT NULL,
            `discord` VARCHAR(60) DEFAULT NULL,
            `ip` VARCHAR(50) DEFAULT NULL,
            `reason` TEXT NOT NULL,
            `expire` DATETIME DEFAULT NULL,
            `permanent` TINYINT(1) DEFAULT 0,
            `banned_by` VARCHAR(60) DEFAULT 'System',
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_identifier` (`identifier`),
            INDEX `idx_license` (`license`),
            INDEX `idx_steam` (`steam`),
            INDEX `idx_discord` (`discord`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]
}

migrations[7] = {
    name = 'create_logs_table',
    query = [[
        CREATE TABLE IF NOT EXISTS `logs` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `type` VARCHAR(30) NOT NULL,
            `identifier` VARCHAR(60) DEFAULT NULL,
            `message` TEXT NOT NULL,
            `data` LONGTEXT DEFAULT '{}',
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_type` (`type`),
            INDEX `idx_identifier` (`identifier`),
            INDEX `idx_created` (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]
}

migrations[8] = {
    name = 'create_jobs_table',
    query = [[
        CREATE TABLE IF NOT EXISTS `jobs` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `name` VARCHAR(60) NOT NULL UNIQUE,
            `label` VARCHAR(100) NOT NULL,
            `grades` LONGTEXT DEFAULT '[]',
            `metadata` LONGTEXT DEFAULT '{}',
            INDEX `idx_name` (`name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]
}

migrations[9] = {
    name = 'create_migrations_table',
    query = [[
        CREATE TABLE IF NOT EXISTS `vcore_migrations` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `migration` VARCHAR(100) NOT NULL UNIQUE,
            `executed_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]
}

migrations[10] = {
    name = 'insert_default_items',
    query = [[
        INSERT IGNORE INTO `items` (`name`, `label`, `description`, `weight`, `type`, `useable`) VALUES
        ('bread', 'Pain', 'Un pain frais', 200, 'consumable', 1),
        ('water', 'Bouteille d\'eau', 'Une bouteille d\'eau fraîche', 500, 'consumable', 1),
        ('burger', 'Burger', 'Un délicieux burger', 300, 'consumable', 1),
        ('sandwich', 'Sandwich', 'Un sandwich', 250, 'consumable', 1),
        ('coffee', 'Café', 'Une tasse de café chaud', 200, 'consumable', 1),
        ('soda', 'Soda', 'Une canette de soda', 400, 'consumable', 1),
        ('bandage', 'Bandage', 'Un bandage de premiers soins', 100, 'item', 1),
        ('medikit', 'Kit médical', 'Un kit médical complet', 500, 'item', 1),
        ('phone', 'Téléphone', 'Un téléphone portable', 200, 'item', 0),
        ('radio', 'Radio', 'Une radio portable', 300, 'item', 1),
        ('lockpick', 'Crochet', 'Un crochet de serrure', 50, 'tool', 1),
        ('repairkit', 'Kit de réparation', 'Un kit de réparation véhicule', 1000, 'tool', 1),
        ('id_card', 'Carte d\'identité', 'Votre carte d\'identité', 10, 'item', 1),
        ('driver_license', 'Permis de conduire', 'Votre permis de conduire', 10, 'item', 1);
    ]]
}

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS DE MIGRATION
-- ═══════════════════════════════════════════════════════════════════════════

---Vérifie si une migration a été exécutée
---@param migrationName string
---@return boolean
function vCore.Migrations.IsExecuted(migrationName)
    local result = vCore.DB.Scalar(
        'SELECT COUNT(*) FROM vcore_migrations WHERE migration = ?',
        {migrationName}
    )
    return result and result > 0
end

---Marque une migration comme exécutée
---@param migrationName string
function vCore.Migrations.MarkExecuted(migrationName)
    vCore.DB.Execute(
        'INSERT IGNORE INTO vcore_migrations (migration) VALUES (?)',
        {migrationName}
    )
end

---Exécute toutes les migrations en attente
function vCore.Migrations.Run()
    vCore.Utils.Print('Vérification des migrations...')
    
    -- Créer d'abord la table de migrations
    vCore.DB.Execute(migrations[9].query)
    
    local executed = 0
    
    for i, migration in ipairs(migrations) do
        if not vCore.Migrations.IsExecuted(migration.name) then
            vCore.Utils.Print('Exécution de la migration:', migration.name)
            
            local success, err = pcall(function()
                vCore.DB.Execute(migration.query)
            end)
            
            if success then
                vCore.Migrations.MarkExecuted(migration.name)
                executed = executed + 1
            else
                vCore.Utils.Error('Échec de la migration:', migration.name, err)
            end
        end
    end
    
    if executed > 0 then
        vCore.Utils.Print(executed, 'migration(s) exécutée(s)')
    else
        vCore.Utils.Print('Base de données à jour')
    end
end

---Réinitialise les migrations (DANGEREUX)
function vCore.Migrations.Reset()
    vCore.Utils.Warn('Réinitialisation des migrations...')
    
    local tables = {'logs', 'bans', 'vehicles', 'inventories', 'items', 'characters', 'users', 'jobs', 'vcore_migrations'}
    
    for _, tableName in ipairs(tables) do
        vCore.DB.Execute('DROP TABLE IF EXISTS `' .. tableName .. '`')
    end
    
    vCore.Utils.Print('Tables supprimées, relancement des migrations...')
    vCore.Migrations.Run()
end
