-- ═══════════════════════════════════════════════════════════════════════════
-- vAvA_core - Installation Base de Données Complète
-- Version: 1.0.0
-- Date: 11/01/2025
-- ═══════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════
-- TABLES USERS & CHARACTERS
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `users` (
    `identifier` VARCHAR(50) NOT NULL PRIMARY KEY,
    `group` VARCHAR(50) NOT NULL DEFAULT 'user',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `last_connection` TIMESTAMP NULL DEFAULT NULL,
    INDEX `idx_group` (`group`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `characters` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(50) NOT NULL,
    `firstname` VARCHAR(50) NOT NULL,
    `lastname` VARCHAR(50) NOT NULL,
    `dob` VARCHAR(10) NOT NULL,
    `gender` TINYINT NOT NULL DEFAULT 0,
    `money` TEXT NOT NULL,
    `job` TEXT NOT NULL,
    `gang` TEXT NOT NULL,
    `position` TEXT NOT NULL,
    `status` TEXT NOT NULL,
    `inventory` LONGTEXT NOT NULL,
    `metadata` TEXT NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_name` (`firstname`, `lastname`),
    CONSTRAINT `fk_characters_users` FOREIGN KEY (`identifier`) REFERENCES `users`(`identifier`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ═══════════════════════════════════════════════════════════════════════════
-- TABLES ITEMS & INVENTORY
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `items` (
    `name` VARCHAR(50) NOT NULL PRIMARY KEY,
    `label` VARCHAR(100) NOT NULL,
    `description` TEXT NULL,
    `weight` INT NOT NULL DEFAULT 100,
    `type` VARCHAR(20) NOT NULL DEFAULT 'item',
    `unique` TINYINT(1) NOT NULL DEFAULT 0,
    `useable` TINYINT(1) NOT NULL DEFAULT 0,
    `image` VARCHAR(100) NULL,
    `metadata` TEXT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Items de base
INSERT INTO `items` (`name`, `label`, `description`, `weight`, `type`, `useable`, `image`) VALUES
('bread', 'Pain', 'Un pain frais', 100, 'food', 1, 'bread.png'),
('water', 'Bouteille d\'eau', 'Une bouteille d\'eau fraîche', 200, 'drink', 1, 'water.png'),
('phone', 'Téléphone', 'Un téléphone portable', 300, 'item', 1, 'phone.png'),
('id_card', 'Carte d\'identité', 'Votre carte d\'identité', 50, 'item', 0, 'id_card.png'),
('driver_license', 'Permis de conduire', 'Votre permis de conduire', 50, 'item', 0, 'driver_license.png'),
('money', 'Argent liquide', 'Liasse de billets', 0, 'money', 0, 'money.png'),
('black_money', 'Argent sale', 'Argent non-traçable', 0, 'money', 0, 'black_money.png')
ON DUPLICATE KEY UPDATE `label` = VALUES(`label`);

-- ═══════════════════════════════════════════════════════════════════════════
-- TABLES VEHICLES
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `vehicles` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `owner` VARCHAR(50) NOT NULL,
    `plate` VARCHAR(8) NOT NULL UNIQUE,
    `model` VARCHAR(50) NOT NULL,
    `props` LONGTEXT NOT NULL,
    `state` VARCHAR(20) NOT NULL DEFAULT 'garaged',
    `garage` VARCHAR(50) NOT NULL DEFAULT 'default',
    `fuel` FLOAT NOT NULL DEFAULT 100.0,
    `engine` FLOAT NOT NULL DEFAULT 1000.0,
    `body` FLOAT NOT NULL DEFAULT 1000.0,
    `mileage` FLOAT NOT NULL DEFAULT 0.0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_owner` (`owner`),
    INDEX `idx_plate` (`plate`),
    INDEX `idx_state` (`state`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vehicle_keys` (
    `plate` VARCHAR(8) NOT NULL,
    `identifier` VARCHAR(50) NOT NULL,
    `type` VARCHAR(20) NOT NULL DEFAULT 'owner',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`plate`, `identifier`),
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_plate` (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ═══════════════════════════════════════════════════════════════════════════
-- TABLES JOBS
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `job_grades` (
    `job` VARCHAR(50) NOT NULL,
    `grade` INT NOT NULL,
    `label` VARCHAR(100) NOT NULL,
    `salary` INT NOT NULL DEFAULT 0,
    `permissions` TEXT NULL,
    PRIMARY KEY (`job`, `grade`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Grades par défaut
INSERT INTO `job_grades` (`job`, `grade`, `label`, `salary`, `permissions`) VALUES
('unemployed', 0, 'Chômeur', 100, NULL),
('police', 0, 'Recrue', 500, '["police.search"]'),
('police', 1, 'Officier', 750, '["police.search","police.handcuff","police.fine"]'),
('police', 2, 'Sergent', 1000, '["police.search","police.handcuff","police.fine","police.jail"]'),
('police', 3, 'Lieutenant', 1500, '["police.search","police.handcuff","police.fine","police.jail","police.armory"]'),
('police', 4, 'Commandant', 2000, '["police.search","police.handcuff","police.fine","police.jail","police.armory","police.announce"]'),
('ambulance', 0, 'Ambulancier', 500, '["ambulance.heal"]'),
('ambulance', 1, 'Infirmier', 750, '["ambulance.heal","ambulance.revive"]'),
('ambulance', 2, 'Médecin', 1250, '["ambulance.heal","ambulance.revive","ambulance.pharmacy"]'),
('ambulance', 3, 'Chef des urgences', 1750, '["ambulance.heal","ambulance.revive","ambulance.pharmacy","ambulance.announce"]'),
('mechanic', 0, 'Apprenti', 400, '["mechanic.repair"]'),
('mechanic', 1, 'Mécanicien', 700, '["mechanic.repair","mechanic.clean"]'),
('mechanic', 2, 'Chef d\'atelier', 1200, '["mechanic.repair","mechanic.clean","mechanic.impound","mechanic.craft"]')
ON DUPLICATE KEY UPDATE `label` = VALUES(`label`), `salary` = VALUES(`salary`);

-- ═══════════════════════════════════════════════════════════════════════════
-- TABLES LOGS
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `logs` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `type` VARCHAR(50) NOT NULL,
    `identifier` VARCHAR(50) NULL,
    `message` TEXT NOT NULL,
    `data` TEXT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_type` (`type`),
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ═══════════════════════════════════════════════════════════════════════════
-- TABLES BANS
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `bans` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(50) NOT NULL,
    `reason` TEXT NOT NULL,
    `banned_by` VARCHAR(100) NOT NULL,
    `expire_at` TIMESTAMP NULL DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_expire` (`expire_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ═══════════════════════════════════════════════════════════════════════════
-- TABLES ECONOMY
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `transactions` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `identifier_from` VARCHAR(50) NULL,
    `identifier_to` VARCHAR(50) NULL,
    `type` VARCHAR(20) NOT NULL,
    `amount` INT NOT NULL,
    `reason` VARCHAR(255) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_from` (`identifier_from`),
    INDEX `idx_to` (`identifier_to`),
    INDEX `idx_type` (`type`),
    INDEX `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `society_accounts` (
    `society` VARCHAR(50) NOT NULL PRIMARY KEY,
    `label` VARCHAR(100) NOT NULL,
    `money` INT NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Comptes société par défaut
INSERT INTO `society_accounts` (`society`, `label`, `money`) VALUES
('police', 'Police Nationale', 50000),
('ambulance', 'Service Médical', 30000),
('mechanic', 'Garage Mécanique', 20000)
ON DUPLICATE KEY UPDATE `label` = VALUES(`label`);

-- ═══════════════════════════════════════════════════════════════════════════
-- TABLES SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `system_info` (
    `key` VARCHAR(50) NOT NULL PRIMARY KEY,
    `value` TEXT NOT NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Version du framework
INSERT INTO `system_info` (`key`, `value`) VALUES
('framework_version', '1.0.0'),
('database_version', '1')
ON DUPLICATE KEY UPDATE `value` = VALUES(`value`);

-- ═══════════════════════════════════════════════════════════════════════════
-- TABLES GARAGES
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `garages` (
    `name` VARCHAR(50) NOT NULL PRIMARY KEY,
    `label` VARCHAR(100) NOT NULL,
    `type` VARCHAR(20) NOT NULL DEFAULT 'public',
    `coords` TEXT NOT NULL,
    `spawn_points` TEXT NOT NULL,
    `job` VARCHAR(50) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Garages par défaut
INSERT INTO `garages` (`name`, `label`, `type`, `coords`, `spawn_points`, `job`) VALUES
('main_garage', 'Garage Central', 'public', '{"x":215.8,"y":-810.1,"z":30.7}', '[{"x":229.7,"y":-800.1,"z":30.5,"h":157.8}]', NULL),
('police_garage', 'Garage Police', 'job', '{"x":452.3,"y":-1024.2,"z":28.5}', '[{"x":438.4,"y":-1018.3,"z":27.7,"h":90.0}]', 'police'),
('ambulance_garage', 'Garage EMS', 'job', '{"x":307.2,"y":-1432.4,"z":29.8}', '[{"x":294.5,"y":-1447.9,"z":29.8,"h":49.6}]', 'ambulance'),
('mechanic_garage', 'Garage Mécanique', 'job', '{"x":-191.8,"y":-1290.5,"z":31.3}', '[{"x":-188.5,"y":-1278.4,"z":31.3,"h":90.0}]', 'mechanic')
ON DUPLICATE KEY UPDATE `label` = VALUES(`label`);

-- ═══════════════════════════════════════════════════════════════════════════
-- TABLES MODULES ADDITIONNELS
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `player_contacts` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(50) NOT NULL,
    `contact_name` VARCHAR(100) NOT NULL,
    `contact_number` VARCHAR(20) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `player_notes` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(50) NOT NULL,
    `title` VARCHAR(100) NOT NULL,
    `content` TEXT NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `billing` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(50) NOT NULL,
    `label` VARCHAR(255) NOT NULL,
    `amount` INT NOT NULL,
    `society` VARCHAR(50) NOT NULL,
    `created_by` VARCHAR(50) NOT NULL,
    `paid` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_paid` (`paid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `properties` (
    `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(50) NOT NULL UNIQUE,
    `label` VARCHAR(100) NOT NULL,
    `owner` VARCHAR(50) NULL,
    `price` INT NOT NULL DEFAULT 100000,
    `garage` TINYINT(1) NOT NULL DEFAULT 0,
    `coords` TEXT NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_owner` (`owner`),
    INDEX `idx_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ═══════════════════════════════════════════════════════════════════════════
-- OPTIMISATION & NETTOYAGE
-- ═══════════════════════════════════════════════════════════════════════════

-- Nettoyage logs anciens (> 30 jours)
CREATE EVENT IF NOT EXISTS `cleanup_old_logs`
ON SCHEDULE EVERY 1 DAY
DO DELETE FROM `logs` WHERE `created_at` < DATE_SUB(NOW(), INTERVAL 30 DAY);

-- Nettoyage bans expirés
CREATE EVENT IF NOT EXISTS `cleanup_expired_bans`
ON SCHEDULE EVERY 1 HOUR
DO DELETE FROM `bans` WHERE `expire_at` IS NOT NULL AND `expire_at` < NOW();

-- ═══════════════════════════════════════════════════════════════════════════
-- FIN INSTALLATION
-- ═══════════════════════════════════════════════════════════════════════════

-- Vérification installation
SELECT 
    'users' as table_name, COUNT(*) as row_count FROM users
UNION ALL
SELECT 'characters', COUNT(*) FROM characters
UNION ALL
SELECT 'items', COUNT(*) FROM items
UNION ALL
SELECT 'vehicles', COUNT(*) FROM vehicles
UNION ALL
SELECT 'job_grades', COUNT(*) FROM job_grades
UNION ALL
SELECT 'logs', COUNT(*) FROM logs
UNION ALL
SELECT 'bans', COUNT(*) FROM bans
UNION ALL
SELECT 'system_info', COUNT(*) FROM system_info;

SELECT '🎉 Installation vAvA_core database complete!' as status;
