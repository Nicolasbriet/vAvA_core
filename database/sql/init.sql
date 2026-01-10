-- ═══════════════════════════════════════════════════════════════════════════
-- vAvA_core - Script d'initialisation SQL
-- Exécutez ce script dans votre base de données MySQL/MariaDB
-- ═══════════════════════════════════════════════════════════════════════════

-- Table des utilisateurs
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

-- Table des personnages
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

-- Trigger pour définir les valeurs par défaut des LONGTEXT
DROP TRIGGER IF EXISTS `characters_before_insert`;

DELIMITER //
CREATE TRIGGER `characters_before_insert` 
BEFORE INSERT ON `characters`
FOR EACH ROW
BEGIN
    IF NEW.money IS NULL THEN SET NEW.money = '{"cash":5000,"bank":10000,"black_money":0}'; END IF;
    IF NEW.job IS NULL THEN SET NEW.job = '{"name":"unemployed","grade":0}'; END IF;
    IF NEW.gang IS NULL THEN SET NEW.gang = '{"name":"none","grade":0}'; END IF;
    IF NEW.position IS NULL THEN SET NEW.position = '{"x":-269.4,"y":-955.3,"z":31.2,"heading":205.0}'; END IF;
    IF NEW.status IS NULL THEN SET NEW.status = '{"hunger":100,"thirst":100,"stress":0}'; END IF;
    IF NEW.inventory IS NULL THEN SET NEW.inventory = '[]'; END IF;
    IF NEW.metadata IS NULL THEN SET NEW.metadata = '{}'; END IF;
END//
DELIMITER ;

-- Table des items
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

-- Table des inventaires (coffres, etc.)
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

-- Table des véhicules
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

-- Table des bans
CREATE TABLE IF NOT EXISTS `bans` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(60) NOT NULL,
    `license` VARCHAR(60) DEFAULT NULL,
    `steam` VARCHAR(60) DEFAULT NULL,
    `discord` VARCHAR(60) DEFAULT NULL,
    `ip` VARCHAR(50) DEFAULT NULL,
    `reason` TEXT NOT NULL,
    `expire_at` DATETIME DEFAULT NULL,
    `permanent` TINYINT(1) DEFAULT 0,
    `banned_by` VARCHAR(60) DEFAULT 'System',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_license` (`license`),
    INDEX `idx_steam` (`steam`),
    INDEX `idx_discord` (`discord`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des logs
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

-- Table des jobs (optionnel - si vous voulez les stocker en DB)
CREATE TABLE IF NOT EXISTS `jobs` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(60) NOT NULL UNIQUE,
    `label` VARCHAR(100) NOT NULL,
    `grades` LONGTEXT,
    `metadata` LONGTEXT,
    INDEX `idx_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des migrations
CREATE TABLE IF NOT EXISTS `vcore_migrations` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `migration` VARCHAR(100) NOT NULL UNIQUE,
    `executed_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ═══════════════════════════════════════════════════════════════════════════
-- DONNÉES PAR DÉFAUT
-- ═══════════════════════════════════════════════════════════════════════════

-- Items par défaut
INSERT IGNORE INTO `items` (`name`, `label`, `description`, `weight`, `type`, `useable`) VALUES
('bread', 'Pain', 'Un pain frais', 200, 'consumable', 1),
('water', 'Bouteille d''eau', 'Une bouteille d''eau fraîche', 500, 'consumable', 1),
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
('id_card', 'Carte d''identité', 'Votre carte d''identité', 10, 'item', 1),
('driver_license', 'Permis de conduire', 'Votre permis de conduire', 10, 'item', 1),
('weapon_flashlight', 'Lampe torche', 'Une lampe torche', 200, 'item', 1),
('weapon_knife', 'Couteau', 'Un couteau', 300, 'weapon', 1),
('weapon_bat', 'Batte de baseball', 'Une batte de baseball', 800, 'weapon', 1),
('weapon_pistol', 'Pistolet', 'Un pistolet 9mm', 1000, 'weapon', 1),
('ammo_pistol', 'Munitions pistolet', 'Chargeur pour pistolet', 100, 'item', 1),
('armor', 'Gilet pare-balles', 'Un gilet pare-balles', 2000, 'item', 1);

-- Marquer les migrations initiales comme exécutées
INSERT IGNORE INTO `vcore_migrations` (`migration`) VALUES
('create_users_table'),
('create_characters_table'),
('create_items_table'),
('create_inventories_table'),
('create_vehicles_table'),
('create_bans_table'),
('create_logs_table'),
('create_jobs_table'),
('create_migrations_table'),
('insert_default_items');
