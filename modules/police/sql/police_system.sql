-- ═══════════════════════════════════════════════════════════════════════════
-- vAvA_police - Base de données SQL
-- Tables nécessaires au système de police
-- ═══════════════════════════════════════════════════════════════════════════

-- Table des amendes
CREATE TABLE IF NOT EXISTS `police_fines` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `officer_id` VARCHAR(50) NOT NULL COMMENT 'Identifiant du policier',
    `officer_name` VARCHAR(100) NOT NULL COMMENT 'Nom du policier',
    `citizen_id` VARCHAR(50) NOT NULL COMMENT 'Identifiant du citoyen',
    `citizen_name` VARCHAR(100) NOT NULL COMMENT 'Nom du citoyen',
    `amount` INT NOT NULL COMMENT 'Montant de l\'amende',
    `reason` TEXT NOT NULL COMMENT 'Motif de l\'amende',
    `paid` TINYINT(1) DEFAULT 0 COMMENT '0 = non payée, 1 = payée',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `paid_at` TIMESTAMP NULL DEFAULT NULL,
    INDEX `idx_citizen` (`citizen_id`),
    INDEX `idx_officer` (`officer_id`),
    INDEX `idx_paid` (`paid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table du casier judiciaire
CREATE TABLE IF NOT EXISTS `police_criminal_records` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizen_id` VARCHAR(50) NOT NULL COMMENT 'Identifiant du citoyen',
    `citizen_name` VARCHAR(100) NOT NULL COMMENT 'Nom du citoyen',
    `officer_id` VARCHAR(50) NOT NULL COMMENT 'Identifiant du policier',
    `officer_name` VARCHAR(100) NOT NULL COMMENT 'Nom du policier',
    `offense` VARCHAR(255) NOT NULL COMMENT 'Délit commis',
    `description` TEXT NULL COMMENT 'Description détaillée',
    `fine_amount` INT DEFAULT 0 COMMENT 'Montant de l\'amende',
    `jail_time` INT DEFAULT 0 COMMENT 'Temps de prison (minutes)',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_citizen` (`citizen_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des prisonniers actifs
CREATE TABLE IF NOT EXISTS `police_prisoners` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizen_id` VARCHAR(50) NOT NULL UNIQUE COMMENT 'Identifiant du prisonnier',
    `citizen_name` VARCHAR(100) NOT NULL COMMENT 'Nom du prisonnier',
    `officer_id` VARCHAR(50) NOT NULL COMMENT 'Identifiant du policier ayant arrêté',
    `officer_name` VARCHAR(100) NOT NULL COMMENT 'Nom du policier',
    `jail_time` INT NOT NULL COMMENT 'Temps de prison total (minutes)',
    `time_remaining` INT NOT NULL COMMENT 'Temps restant (minutes)',
    `reason` TEXT NOT NULL COMMENT 'Raison de l\'emprisonnement',
    `jailed_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `release_at` TIMESTAMP NULL DEFAULT NULL,
    INDEX `idx_citizen` (`citizen_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des véhicules saisis
CREATE TABLE IF NOT EXISTS `police_impounded_vehicles` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `plate` VARCHAR(20) NOT NULL COMMENT 'Plaque du véhicule',
    `owner_id` VARCHAR(50) NOT NULL COMMENT 'Propriétaire du véhicule',
    `owner_name` VARCHAR(100) NOT NULL COMMENT 'Nom du propriétaire',
    `officer_id` VARCHAR(50) NOT NULL COMMENT 'Officier ayant saisi',
    `officer_name` VARCHAR(100) NOT NULL COMMENT 'Nom de l\'officier',
    `reason` TEXT NOT NULL COMMENT 'Raison de la saisie',
    `impound_fee` INT DEFAULT 500 COMMENT 'Frais de fourrière',
    `impounded_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `released_at` TIMESTAMP NULL DEFAULT NULL,
    INDEX `idx_plate` (`plate`),
    INDEX `idx_owner` (`owner_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des items confisqués
CREATE TABLE IF NOT EXISTS `police_confiscated_items` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizen_id` VARCHAR(50) NOT NULL COMMENT 'Identifiant du citoyen',
    `citizen_name` VARCHAR(100) NOT NULL COMMENT 'Nom du citoyen',
    `officer_id` VARCHAR(50) NOT NULL COMMENT 'Officier ayant confisqué',
    `officer_name` VARCHAR(100) NOT NULL COMMENT 'Nom de l\'officier',
    `item_name` VARCHAR(100) NOT NULL COMMENT 'Nom de l\'item',
    `item_label` VARCHAR(150) NOT NULL COMMENT 'Label de l\'item',
    `quantity` INT DEFAULT 1 COMMENT 'Quantité confisquée',
    `confiscated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_citizen` (`citizen_id`),
    INDEX `idx_officer` (`officer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des alertes/dispatch
CREATE TABLE IF NOT EXISTS `police_alerts` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `alert_code` VARCHAR(20) NOT NULL COMMENT 'Code 10-XX',
    `alert_type` VARCHAR(50) NOT NULL COMMENT 'Type d\'alerte',
    `message` TEXT NOT NULL COMMENT 'Message de l\'alerte',
    `coords_x` FLOAT NOT NULL COMMENT 'Position X',
    `coords_y` FLOAT NOT NULL COMMENT 'Position Y',
    `coords_z` FLOAT NOT NULL COMMENT 'Position Z',
    `street` VARCHAR(255) NULL COMMENT 'Nom de rue',
    `priority` INT DEFAULT 3 COMMENT 'Priorité (1=haute, 3=basse)',
    `responded` TINYINT(1) DEFAULT 0 COMMENT '0 = non traité, 1 = traité',
    `responder_id` VARCHAR(50) NULL COMMENT 'Officier ayant répondu',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `responded_at` TIMESTAMP NULL DEFAULT NULL,
    INDEX `idx_responded` (`responded`),
    INDEX `idx_priority` (`priority`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des radars fixes (optionnel - pour radars statiques)
CREATE TABLE IF NOT EXISTS `police_speed_cameras` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `coords_x` FLOAT NOT NULL,
    `coords_y` FLOAT NOT NULL,
    `coords_z` FLOAT NOT NULL,
    `heading` FLOAT DEFAULT 0.0,
    `speed_limit` INT NOT NULL DEFAULT 80 COMMENT 'Limite en km/h',
    `radius` FLOAT DEFAULT 20.0 COMMENT 'Rayon de détection',
    `enabled` TINYINT(1) DEFAULT 1,
    `location_name` VARCHAR(255) NULL,
    INDEX `idx_enabled` (`enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des logs police (actions importantes)
CREATE TABLE IF NOT EXISTS `police_logs` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `officer_id` VARCHAR(50) NOT NULL,
    `officer_name` VARCHAR(100) NOT NULL,
    `action` VARCHAR(100) NOT NULL COMMENT 'Type d\'action',
    `target_id` VARCHAR(50) NULL COMMENT 'Citoyen cible (si applicable)',
    `target_name` VARCHAR(100) NULL,
    `details` TEXT NULL COMMENT 'Détails de l\'action',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_officer` (`officer_id`),
    INDEX `idx_action` (`action`),
    INDEX `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ═══════════════════════════════════════════════════════════════════════════
-- DONNÉES DE TEST (OPTIONNEL - décommenter si besoin)
-- ═══════════════════════════════════════════════════════════════════════════

/*
-- Exemple de radar fixe
INSERT INTO `police_speed_cameras` (`coords_x`, `coords_y`, `coords_z`, `heading`, `speed_limit`, `location_name`) VALUES
(-529.0, -1776.0, 21.3, 230.0, 80, 'Grove Street'),
(1163.0, -348.0, 68.0, 90.0, 50, 'Vinewood');

-- Exemple d'amende de test
INSERT INTO `police_fines` (`officer_id`, `officer_name`, `citizen_id`, `citizen_name`, `amount`, `reason`, `paid`) VALUES
('license:123456', 'John Cop', 'license:789012', 'Jane Citizen', 350, 'Excès de vitesse (majeur)', 0);
*/

-- ═══════════════════════════════════════════════════════════════════════════
-- INDEX SUPPLÉMENTAIRES POUR PERFORMANCES
-- ═══════════════════════════════════════════════════════════════════════════

-- Amélioration des recherches par date
ALTER TABLE `police_fines` ADD INDEX `idx_created` (`created_at`);
ALTER TABLE `police_criminal_records` ADD INDEX `idx_created` (`created_at`);
ALTER TABLE `police_logs` ADD INDEX `idx_target` (`target_id`);

-- ═══════════════════════════════════════════════════════════════════════════
-- FIN DU SCRIPT SQL
-- ═══════════════════════════════════════════════════════════════════════════

COMMIT;
