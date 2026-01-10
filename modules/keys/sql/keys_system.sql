-- ═══════════════════════════════════════════════════════════════════════════
-- vAvA_keys - Tables Base de Données
-- Système de Clés Véhicules
-- ═══════════════════════════════════════════════════════════════════════════

-- Table: Clés de véhicules partagées
CREATE TABLE IF NOT EXISTS `shared_vehicle_keys` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `plate` VARCHAR(15) NOT NULL COMMENT 'Plaque du véhicule',
    `owner_citizenid` VARCHAR(50) NOT NULL COMMENT 'Propriétaire du véhicule',
    `target_citizenid` VARCHAR(50) NOT NULL COMMENT 'Personne recevant la clé',
    `mode` ENUM('perm','temp') NOT NULL DEFAULT 'perm' COMMENT 'Type de clé (permanent/temporaire)',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `expires_at` TIMESTAMP NULL DEFAULT NULL COMMENT 'Date d\'expiration pour clés temporaires',
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_share` (`plate`, `owner_citizenid`, `target_citizenid`),
    INDEX `idx_target_citizenid` (`target_citizenid`),
    INDEX `idx_plate` (`plate`),
    INDEX `idx_mode` (`mode`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: Historique des clés (logs)
CREATE TABLE IF NOT EXISTS `vehicle_keys_history` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `plate` VARCHAR(15) NOT NULL COMMENT 'Plaque du véhicule',
    `owner_citizenid` VARCHAR(50) NOT NULL COMMENT 'Propriétaire',
    `target_citizenid` VARCHAR(50) NULL COMMENT 'Destinataire',
    `action` VARCHAR(50) NOT NULL COMMENT 'Action (given, removed, duplicated, stolen)',
    `mode` VARCHAR(20) NULL COMMENT 'Type de clé',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_plate` (`plate`),
    INDEX `idx_owner` (`owner_citizenid`),
    INDEX `idx_action` (`action`),
    INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: Lockpick/Crochetage attempts (sécurité)
CREATE TABLE IF NOT EXISTS `vehicle_lockpick_attempts` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL COMMENT 'Identifiant du joueur',
    `player_name` VARCHAR(100) NOT NULL COMMENT 'Nom du joueur',
    `plate` VARCHAR(15) NOT NULL COMMENT 'Plaque du véhicule',
    `vehicle_model` VARCHAR(50) NULL COMMENT 'Modèle du véhicule',
    `success` TINYINT(1) NOT NULL COMMENT '0 = échec, 1 = réussi',
    `coords_x` FLOAT NOT NULL COMMENT 'Position X',
    `coords_y` FLOAT NOT NULL COMMENT 'Position Y',
    `coords_z` FLOAT NOT NULL COMMENT 'Position Z',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_citizenid` (`citizenid`),
    INDEX `idx_plate` (`plate`),
    INDEX `idx_success` (`success`),
    INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: Configuration des véhicules (lockpick difficulty, etc.)
CREATE TABLE IF NOT EXISTS `vehicle_keys_config` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `vehicle_class` INT NOT NULL COMMENT 'Classe du véhicule (0-21)',
    `lockpick_difficulty` INT NOT NULL DEFAULT 50 COMMENT 'Difficulté de crochetage (1-100)',
    `alarm_enabled` TINYINT(1) DEFAULT 1 COMMENT 'Alarme activée par défaut',
    `alarm_duration` INT DEFAULT 30 COMMENT 'Durée de l\'alarme (secondes)',
    `can_hotwire` TINYINT(1) DEFAULT 1 COMMENT 'Peut être démarré sans clé',
    `hotwire_time` INT DEFAULT 10 COMMENT 'Temps pour démarrer (secondes)',
    UNIQUE KEY `unique_class` (`vehicle_class`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insertion des configurations par défaut pour chaque classe
INSERT INTO `vehicle_keys_config` (`vehicle_class`, `lockpick_difficulty`, `alarm_enabled`, `alarm_duration`, `can_hotwire`, `hotwire_time`) VALUES
(0, 30, 1, 30, 1, 10),  -- Compacts
(1, 35, 1, 30, 1, 10),  -- Sedans
(2, 40, 1, 30, 1, 12),  -- SUVs
(3, 35, 1, 30, 1, 10),  -- Coupes
(4, 40, 1, 30, 1, 12),  -- Muscle
(5, 45, 1, 30, 1, 15),  -- Sports Classics
(6, 50, 1, 30, 1, 15),  -- Sports
(7, 60, 1, 30, 1, 20),  -- Super
(8, 25, 0, 30, 1, 8),   -- Motorcycles
(9, 20, 0, 30, 1, 8),   -- Off-road
(10, 15, 0, 30, 1, 5),  -- Industrial
(11, 20, 0, 30, 1, 8),  -- Utility
(12, 30, 1, 30, 1, 10), -- Vans
(13, 10, 0, 30, 1, 5),  -- Cycles
(14, 0, 0, 30, 0, 0),   -- Boats
(15, 0, 0, 30, 0, 0),   -- Helicopters
(16, 0, 0, 30, 0, 0),   -- Planes
(17, 15, 0, 30, 1, 5),  -- Service
(18, 100, 1, 60, 0, 0), -- Emergency
(19, 15, 0, 30, 1, 5),  -- Military
(20, 10, 0, 30, 1, 5),  -- Commercial
(21, 0, 0, 30, 0, 0)    -- Trains
ON DUPLICATE KEY UPDATE lockpick_difficulty = VALUES(lockpick_difficulty);
