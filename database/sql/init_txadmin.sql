-- ═══════════════════════════════════════════════════════════════════════════
-- vAvA_core - Script d'initialisation SQL (Version simplifiée pour txAdmin)
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

-- Table des inventaires
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
    INDEX `idx_plate` (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des bans
CREATE TABLE IF NOT EXISTS `bans` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(60) NOT NULL,
    `reason` TEXT NOT NULL,
    `banned_by` VARCHAR(60) DEFAULT 'System',
    `expire_at` TIMESTAMP NULL,
    `permanent` TINYINT(1) DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_identifier` (`identifier`)
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
    INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des métiers
CREATE TABLE IF NOT EXISTS `jobs` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(60) NOT NULL UNIQUE,
    `label` VARCHAR(100) NOT NULL,
    `grades` LONGTEXT,
    `metadata` LONGTEXT,
    INDEX `idx_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Jobs par défaut
INSERT IGNORE INTO `jobs` (`name`, `label`, `grades`) VALUES
('unemployed', 'Sans emploi', '[{"grade":0,"label":"Sans emploi","salary":0}]'),
('police', 'Police', '[{"grade":0,"label":"Cadet","salary":500},{"grade":1,"label":"Officier","salary":750},{"grade":2,"label":"Sergent","salary":1000},{"grade":3,"label":"Lieutenant","salary":1250},{"grade":4,"label":"Chef","salary":1500}]'),
('ambulance', 'EMS', '[{"grade":0,"label":"Stagiaire","salary":500},{"grade":1,"label":"Ambulancier","salary":750},{"grade":2,"label":"Médecin","salary":1000},{"grade":3,"label":"Chef des urgences","salary":1250}]'),
('mechanic', 'Mécanicien', '[{"grade":0,"label":"Apprenti","salary":400},{"grade":1,"label":"Mécanicien","salary":600},{"grade":2,"label":"Chef atelier","salary":800}]');
