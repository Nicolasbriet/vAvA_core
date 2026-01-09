-- ═══════════════════════════════════════════════════════════════════════════
-- vAvA_core - Système de Jobs Avancé
-- Tables pour la gestion des jobs, points d'interaction, farm, craft, etc.
-- ═══════════════════════════════════════════════════════════════════════════

-- Table principale des jobs
CREATE TABLE IF NOT EXISTS `jobs_config` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(60) NOT NULL UNIQUE,
    `label` VARCHAR(100) NOT NULL,
    `icon` VARCHAR(100) DEFAULT 'briefcase',
    `description` TEXT DEFAULT NULL,
    `default_salary` INT DEFAULT 0,
    `society_account` TINYINT(1) DEFAULT 1,
    `whitelisted` TINYINT(1) DEFAULT 0,
    `type` ENUM('public', 'ems', 'police', 'mechanic', 'custom') DEFAULT 'custom',
    `blip` LONGTEXT DEFAULT NULL,
    `offduty_name` VARCHAR(60) DEFAULT NULL,
    `metadata` LONGTEXT DEFAULT NULL,
    `enabled` TINYINT(1) DEFAULT 1,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_name` (`name`),
    INDEX `idx_type` (`type`),
    INDEX `idx_enabled` (`enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des grades de jobs
CREATE TABLE IF NOT EXISTS `job_grades` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `job_name` VARCHAR(60) NOT NULL,
    `grade` INT NOT NULL,
    `name` VARCHAR(60) NOT NULL,
    `label` VARCHAR(100) NOT NULL,
    `salary` INT DEFAULT 0,
    `permissions` LONGTEXT DEFAULT NULL,
    `metadata` LONGTEXT DEFAULT NULL,
    UNIQUE KEY `job_grade` (`job_name`, `grade`),
    INDEX `idx_job_name` (`job_name`),
    FOREIGN KEY (`job_name`) REFERENCES `jobs_config`(`name`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des points d'interaction
CREATE TABLE IF NOT EXISTS `job_interactions` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `job_name` VARCHAR(60) NOT NULL,
    `type` ENUM('duty', 'wardrobe', 'vehicle', 'storage', 'boss', 'shop', 'farm', 'craft', 'process', 'sell', 'custom') NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    `label` VARCHAR(100) DEFAULT NULL,
    `position` LONGTEXT NOT NULL,
    `heading` FLOAT DEFAULT 0.0,
    `marker` LONGTEXT DEFAULT NULL,
    `blip` LONGTEXT DEFAULT NULL,
    `config` LONGTEXT DEFAULT NULL,
    `min_grade` INT DEFAULT 0,
    `enabled` TINYINT(1) DEFAULT 1,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_job_name` (`job_name`),
    INDEX `idx_type` (`type`),
    FOREIGN KEY (`job_name`) REFERENCES `jobs_config`(`name`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des véhicules de job
CREATE TABLE IF NOT EXISTS `job_vehicles` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `job_name` VARCHAR(60) NOT NULL,
    `category` VARCHAR(60) DEFAULT 'service',
    `model` VARCHAR(60) NOT NULL,
    `label` VARCHAR(100) NOT NULL,
    `price` INT DEFAULT 0,
    `min_grade` INT DEFAULT 0,
    `livery` INT DEFAULT NULL,
    `extras` LONGTEXT DEFAULT NULL,
    `enabled` TINYINT(1) DEFAULT 1,
    INDEX `idx_job_name` (`job_name`),
    INDEX `idx_category` (`category`),
    FOREIGN KEY (`job_name`) REFERENCES `jobs_config`(`name`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des vêtements de job
CREATE TABLE IF NOT EXISTS `job_outfits` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `job_name` VARCHAR(60) NOT NULL,
    `gender` ENUM('male', 'female') NOT NULL,
    `grade` INT DEFAULT 0,
    `label` VARCHAR(100) NOT NULL,
    `outfit` LONGTEXT NOT NULL,
    `enabled` TINYINT(1) DEFAULT 1,
    INDEX `idx_job_name` (`job_name`),
    INDEX `idx_gender` (`gender`),
    FOREIGN KEY (`job_name`) REFERENCES `jobs_config`(`name`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des items de farm
CREATE TABLE IF NOT EXISTS `job_farm_items` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `interaction_id` INT NOT NULL,
    `item_name` VARCHAR(60) NOT NULL,
    `amount_min` INT DEFAULT 1,
    `amount_max` INT DEFAULT 3,
    `chance` FLOAT DEFAULT 100.0,
    `required_item` VARCHAR(60) DEFAULT NULL,
    `remove_required` TINYINT(1) DEFAULT 0,
    `time` INT DEFAULT 5000,
    `animation` LONGTEXT DEFAULT NULL,
    INDEX `idx_interaction` (`interaction_id`),
    FOREIGN KEY (`interaction_id`) REFERENCES `job_interactions`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des recettes de craft
CREATE TABLE IF NOT EXISTS `job_craft_recipes` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `interaction_id` INT NOT NULL,
    `name` VARCHAR(60) NOT NULL,
    `label` VARCHAR(100) NOT NULL,
    `result_item` VARCHAR(60) NOT NULL,
    `result_amount` INT DEFAULT 1,
    `ingredients` LONGTEXT NOT NULL,
    `time` INT DEFAULT 10000,
    `required_grade` INT DEFAULT 0,
    `enabled` TINYINT(1) DEFAULT 1,
    INDEX `idx_interaction` (`interaction_id`),
    FOREIGN KEY (`interaction_id`) REFERENCES `job_interactions`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des items à vendre
CREATE TABLE IF NOT EXISTS `job_sell_items` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `interaction_id` INT NOT NULL,
    `item_name` VARCHAR(60) NOT NULL,
    `price` INT NOT NULL,
    `label` VARCHAR(100) DEFAULT NULL,
    `enabled` TINYINT(1) DEFAULT 1,
    INDEX `idx_interaction` (`interaction_id`),
    FOREIGN KEY (`interaction_id`) REFERENCES `job_interactions`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des comptes société
CREATE TABLE IF NOT EXISTS `job_accounts` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `job_name` VARCHAR(60) NOT NULL UNIQUE,
    `money` INT DEFAULT 0,
    INDEX `idx_job_name` (`job_name`),
    FOREIGN KEY (`job_name`) REFERENCES `jobs_config`(`name`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des logs de jobs
CREATE TABLE IF NOT EXISTS `job_logs` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `job_name` VARCHAR(60) NOT NULL,
    `player_identifier` VARCHAR(60) NOT NULL,
    `action` VARCHAR(60) NOT NULL,
    `description` TEXT DEFAULT NULL,
    `data` LONGTEXT DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_job_name` (`job_name`),
    INDEX `idx_identifier` (`player_identifier`),
    INDEX `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ═══════════════════════════════════════════════════════════════════════════
-- DONNÉES PAR DÉFAUT - JOBS
-- ═══════════════════════════════════════════════════════════════════════════

-- Job EMS
INSERT IGNORE INTO `jobs_config` (`name`, `label`, `icon`, `description`, `type`, `whitelisted`, `society_account`) VALUES
('ambulance', 'EMS', 'ambulance', 'Service médical d\'urgence', 'ems', 1, 1);

INSERT IGNORE INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`, `permissions`) VALUES
('ambulance', 0, 'recruit', 'Recrue', 20, '[]'),
('ambulance', 1, 'paramedic', 'Ambulancier', 40, '["revive","heal"]'),
('ambulance', 2, 'doctor', 'Médecin', 60, '["revive","heal","pharmacy"]'),
('ambulance', 3, 'chief_doctor', 'Médecin Chef', 80, '["revive","heal","pharmacy","hire","fire"]'),
('ambulance', 4, 'boss', 'Directeur', 100, '["revive","heal","pharmacy","hire","fire","manage","withdraw"]');

-- Job Police
INSERT IGNORE INTO `jobs_config` (`name`, `label`, `icon`, `description`, `type`, `whitelisted`, `society_account`) VALUES
('police', 'Police', 'shield-alt', 'Police Nationale', 'police', 1, 1);

INSERT IGNORE INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`, `permissions`) VALUES
('police', 0, 'recruit', 'Cadet', 20, '[]'),
('police', 1, 'officer', 'Officier', 40, '["cuff","search","fine"]'),
('police', 2, 'sergeant', 'Sergent', 60, '["cuff","search","fine","jail","impound"]'),
('police', 3, 'lieutenant', 'Lieutenant', 80, '["cuff","search","fine","jail","impound","hire","fire"]'),
('police', 4, 'boss', 'Commissaire', 100, '["cuff","search","fine","jail","impound","hire","fire","manage","withdraw"]');

-- Job Mechanic
INSERT IGNORE INTO `jobs_config` (`name`, `label`, `icon`, `description`, `type`, `whitelisted`, `society_account`) VALUES
('mechanic', 'Mécano', 'wrench', 'Garage mécanique et customs', 'mechanic', 0, 1);

INSERT IGNORE INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`, `permissions`) VALUES
('mechanic', 0, 'recruit', 'Apprenti', 12, '["repair"]'),
('mechanic', 1, 'novice', 'Novice', 24, '["repair","impound"]'),
('mechanic', 2, 'experienced', 'Expérimenté', 36, '["repair","impound","customs"]'),
('mechanic', 3, 'chief', 'Chef d\'atelier', 48, '["repair","impound","customs","hire","fire"]'),
('mechanic', 4, 'boss', 'Patron', 60, '["repair","impound","customs","hire","fire","manage","withdraw"]');

-- Job Unemployed (par défaut)
INSERT IGNORE INTO `jobs_config` (`name`, `label`, `icon`, `description`, `type`, `whitelisted`, `society_account`) VALUES
('unemployed', 'Sans emploi', 'user', 'Aucun emploi', 'public', 0, 0);

INSERT IGNORE INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`, `permissions`) VALUES
('unemployed', 0, 'unemployed', 'Chômeur', 10, '[]');

-- Créer les comptes société
INSERT IGNORE INTO `job_accounts` (`job_name`, `money`) VALUES
('ambulance', 50000),
('police', 100000),
('mechanic', 25000);

-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRATIONS
-- ═══════════════════════════════════════════════════════════════════════════

INSERT IGNORE INTO `vcore_migrations` (`migration`) VALUES
('create_jobs_config_table'),
('create_job_grades_table'),
('create_job_interactions_table'),
('create_job_vehicles_table'),
('create_job_outfits_table'),
('create_job_farm_items_table'),
('create_job_craft_recipes_table'),
('create_job_sell_items_table'),
('create_job_accounts_table'),
('create_job_logs_table'),
('insert_default_jobs'),
('insert_default_job_grades');
