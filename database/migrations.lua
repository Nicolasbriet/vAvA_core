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
            `money` LONGTEXT,
            `job` LONGTEXT,
            `gang` LONGTEXT,
            `position` LONGTEXT,
            `status` LONGTEXT,
            `inventory` LONGTEXT,
            `metadata` LONGTEXT,
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
            `metadata` LONGTEXT,
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
            `items` LONGTEXT,
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
            `props` LONGTEXT,
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
            `data` LONGTEXT,
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
            `grades` LONGTEXT,
            `metadata` LONGTEXT,
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
-- MIGRATIONS ECONOMY SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════

migrations[11] = {
    name = 'create_economy_state_table',
    query = [[
        CREATE TABLE IF NOT EXISTS `economy_state` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `inflation` DECIMAL(10,4) NOT NULL DEFAULT 1.0000,
            `base_multiplier` DECIMAL(10,4) NOT NULL DEFAULT 1.0000,
            `profile` VARCHAR(50) NOT NULL DEFAULT 'normal',
            `last_update` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            `updated_by` VARCHAR(50) DEFAULT NULL,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]
}

migrations[12] = {
    name = 'insert_economy_state_default',
    query = [[
        INSERT INTO `economy_state` (`inflation`, `base_multiplier`, `profile`) 
        VALUES (1.0000, 1.0000, 'normal')
        ON DUPLICATE KEY UPDATE `id` = `id`;
    ]]
}

migrations[13] = {
    name = 'create_economy_items_table',
    query = [[
        CREATE TABLE IF NOT EXISTS `economy_items` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `item_name` VARCHAR(100) NOT NULL,
            `base_price` DECIMAL(10,2) NOT NULL,
            `current_price` DECIMAL(10,2) NOT NULL,
            `rarity` INT(11) NOT NULL DEFAULT 1,
            `category` VARCHAR(50) NOT NULL,
            `buy_count` INT(11) NOT NULL DEFAULT 0,
            `sell_count` INT(11) NOT NULL DEFAULT 0,
            `last_price_update` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `item_name` (`item_name`),
            KEY `category` (`category`),
            KEY `rarity` (`rarity`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]
}

migrations[14] = {
    name = 'create_economy_jobs_table',
    query = [[
        CREATE TABLE IF NOT EXISTS `economy_jobs` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `job_name` VARCHAR(100) NOT NULL,
            `base_salary` DECIMAL(10,2) NOT NULL,
            `current_salary` DECIMAL(10,2) NOT NULL,
            `bonus` DECIMAL(10,4) NOT NULL DEFAULT 1.0000,
            `essential` TINYINT(1) NOT NULL DEFAULT 0,
            `active_players` INT(11) NOT NULL DEFAULT 0,
            `last_salary_update` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `job_name` (`job_name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]
}

migrations[15] = {
    name = 'create_economy_logs_table',
    query = [[
        CREATE TABLE IF NOT EXISTS `economy_logs` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `log_type` ENUM('price', 'salary', 'tax', 'inflation', 'recalculate', 'override', 'alert') NOT NULL,
            `item_or_job` VARCHAR(100) DEFAULT NULL,
            `old_value` DECIMAL(10,2) DEFAULT NULL,
            `new_value` DECIMAL(10,2) DEFAULT NULL,
            `variation_percent` DECIMAL(10,4) DEFAULT NULL,
            `source` ENUM('auto', 'admin', 'system', 'monitoring') NOT NULL DEFAULT 'auto',
            `admin_identifier` VARCHAR(100) DEFAULT NULL,
            `reason` TEXT DEFAULT NULL,
            `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `log_type` (`log_type`),
            KEY `timestamp` (`timestamp`),
            KEY `item_or_job` (`item_or_job`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]
}

migrations[16] = {
    name = 'create_economy_transactions_table',
    query = [[
        CREATE TABLE IF NOT EXISTS `economy_transactions` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `item_name` VARCHAR(100) NOT NULL,
            `transaction_type` ENUM('buy', 'sell') NOT NULL,
            `quantity` INT(11) NOT NULL DEFAULT 1,
            `price` DECIMAL(10,2) NOT NULL,
            `shop` VARCHAR(50) DEFAULT NULL,
            `player_identifier` VARCHAR(100) DEFAULT NULL,
            `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `item_name` (`item_name`),
            KEY `transaction_type` (`transaction_type`),
            KEY `timestamp` (`timestamp`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]
}

migrations[17] = {
    name = 'create_economy_shops_table',
    query = [[
        CREATE TABLE IF NOT EXISTS `economy_shops` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `shop_name` VARCHAR(100) NOT NULL,
            `multiplier` DECIMAL(10,4) NOT NULL DEFAULT 1.0000,
            `zone_type` ENUM('poor', 'normal', 'rich', 'luxury') NOT NULL DEFAULT 'normal',
            `transaction_count` INT(11) NOT NULL DEFAULT 0,
            `last_update` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `shop_name` (`shop_name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]
}

migrations[18] = {
    name = 'create_economy_taxes_table',
    query = [[
        CREATE TABLE IF NOT EXISTS `economy_taxes` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `tax_type` VARCHAR(50) NOT NULL,
            `rate` DECIMAL(10,4) NOT NULL DEFAULT 0.0500,
            `description` VARCHAR(255) DEFAULT NULL,
            `last_update` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `tax_type` (`tax_type`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]
}

migrations[19] = {
    name = 'insert_economy_taxes_default',
    query = [[
        INSERT INTO `economy_taxes` (`tax_type`, `rate`, `description`) VALUES
        ('achat', 0.0500, 'Taxe sur les achats'),
        ('vente', 0.0300, 'Taxe sur les ventes'),
        ('salaire', 0.0200, 'Taxe sur les salaires'),
        ('transfert', 0.0100, 'Taxe sur les transferts bancaires'),
        ('vehicule', 0.1000, 'Taxe sur l\'achat de véhicules'),
        ('immobilier', 0.1500, 'Taxe sur l\'achat immobilier')
        ON DUPLICATE KEY UPDATE `id` = `id`;
    ]]
}

migrations[20] = {
    name = 'create_economy_reports_table',
    query = [[
        CREATE TABLE IF NOT EXISTS `economy_reports` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `report_type` ENUM('hourly', 'daily', 'weekly', 'monthly', 'custom') NOT NULL DEFAULT 'hourly',
            `report_data` JSON NOT NULL,
            `generated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `generated_by` VARCHAR(100) DEFAULT 'system',
            PRIMARY KEY (`id`),
            KEY `report_type` (`report_type`),
            KEY `generated_at` (`generated_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
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
