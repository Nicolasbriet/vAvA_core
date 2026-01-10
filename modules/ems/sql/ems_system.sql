-- ═══════════════════════════════════════════════════════════════════════════
-- vAvA_ems - Tables Base de Données
-- Système EMS/Ambulancier Complet
-- ═══════════════════════════════════════════════════════════════════════════

-- Table: Stock de sang à l'hôpital
CREATE TABLE IF NOT EXISTS `hospital_blood_stock` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `blood_type` VARCHAR(5) NOT NULL UNIQUE COMMENT 'Type sanguin (O+, O-, A+, A-, etc.)',
    `units` INT NOT NULL DEFAULT 0 COMMENT 'Nombre d\'unités disponibles',
    `last_update` INT NOT NULL COMMENT 'Timestamp de dernière mise à jour',
    INDEX `idx_blood_type` (`blood_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Initialisation du stock de sang par défaut
INSERT INTO `hospital_blood_stock` (`blood_type`, `units`, `last_update`) VALUES
('O+', 15, UNIX_TIMESTAMP()),
('O-', 15, UNIX_TIMESTAMP()),
('A+', 15, UNIX_TIMESTAMP()),
('A-', 15, UNIX_TIMESTAMP()),
('B+', 15, UNIX_TIMESTAMP()),
('B-', 15, UNIX_TIMESTAMP()),
('AB+', 15, UNIX_TIMESTAMP()),
('AB-', 15, UNIX_TIMESTAMP())
ON DUPLICATE KEY UPDATE units = units;

-- Table: Historique médical des patients
CREATE TABLE IF NOT EXISTS `ems_medical_history` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL COMMENT 'Identifiant du patient',
    `patient_name` VARCHAR(100) NOT NULL COMMENT 'Nom du patient',
    `medic_id` VARCHAR(50) NOT NULL COMMENT 'Identifiant du médecin',
    `medic_name` VARCHAR(100) NOT NULL COMMENT 'Nom du médecin',
    `diagnosis` VARCHAR(255) NOT NULL COMMENT 'Diagnostic',
    `treatment` TEXT NOT NULL COMMENT 'Traitement administré',
    `medication` TEXT NULL COMMENT 'Médicaments prescrits',
    `notes` TEXT NULL COMMENT 'Notes médicales',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_citizenid` (`citizenid`),
    INDEX `idx_medic` (`medic_id`),
    INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: Factures médicales
CREATE TABLE IF NOT EXISTS `ems_invoices` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL COMMENT 'Identifiant du patient',
    `patient_name` VARCHAR(100) NOT NULL COMMENT 'Nom du patient',
    `medic_id` VARCHAR(50) NOT NULL COMMENT 'Identifiant du médecin',
    `medic_name` VARCHAR(100) NOT NULL COMMENT 'Nom du médecin',
    `amount` INT NOT NULL COMMENT 'Montant de la facture',
    `reason` TEXT NOT NULL COMMENT 'Motif de la facture',
    `paid` TINYINT(1) DEFAULT 0 COMMENT '0 = non payée, 1 = payée',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `paid_at` TIMESTAMP NULL DEFAULT NULL,
    INDEX `idx_citizenid` (`citizenid`),
    INDEX `idx_paid` (`paid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: Ambulances en service
CREATE TABLE IF NOT EXISTS `ems_active_units` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL UNIQUE COMMENT 'Identifiant du médecin',
    `medic_name` VARCHAR(100) NOT NULL COMMENT 'Nom du médecin',
    `unit_number` VARCHAR(20) NOT NULL COMMENT 'Numéro d\'unité (ex: EMS-1)',
    `vehicle_plate` VARCHAR(20) NULL COMMENT 'Plaque du véhicule',
    `coords_x` FLOAT NOT NULL COMMENT 'Position X',
    `coords_y` FLOAT NOT NULL COMMENT 'Position Y',
    `coords_z` FLOAT NOT NULL COMMENT 'Position Z',
    `status` VARCHAR(50) DEFAULT 'available' COMMENT 'Statut (available, busy, on_call)',
    `last_update` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_citizenid` (`citizenid`),
    INDEX `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: Appels d'urgence médicaux
CREATE TABLE IF NOT EXISTS `ems_calls` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `caller_id` VARCHAR(50) NOT NULL COMMENT 'Identifiant de l\'appelant',
    `caller_name` VARCHAR(100) NOT NULL COMMENT 'Nom de l\'appelant',
    `call_type` VARCHAR(50) NOT NULL COMMENT 'Type d\'appel (injury, accident, emergency)',
    `description` TEXT NOT NULL COMMENT 'Description de l\'urgence',
    `coords_x` FLOAT NOT NULL COMMENT 'Position X',
    `coords_y` FLOAT NOT NULL COMMENT 'Position Y',
    `coords_z` FLOAT NOT NULL COMMENT 'Position Z',
    `street` VARCHAR(255) NULL COMMENT 'Nom de rue',
    `priority` INT DEFAULT 3 COMMENT 'Priorité (1=critique, 3=basse)',
    `responded` TINYINT(1) DEFAULT 0 COMMENT '0 = non traité, 1 = traité',
    `responder_id` VARCHAR(50) NULL COMMENT 'Médecin ayant répondu',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `responded_at` TIMESTAMP NULL DEFAULT NULL,
    INDEX `idx_responded` (`responded`),
    INDEX `idx_priority` (`priority`),
    INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: Statistiques EMS
CREATE TABLE IF NOT EXISTS `ems_stats` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL UNIQUE COMMENT 'Identifiant du médecin',
    `medic_name` VARCHAR(100) NOT NULL COMMENT 'Nom du médecin',
    `patients_treated` INT DEFAULT 0 COMMENT 'Patients soignés',
    `revives` INT DEFAULT 0 COMMENT 'Réanimations',
    `calls_answered` INT DEFAULT 0 COMMENT 'Appels répondus',
    `distance_driven` DECIMAL(12,2) DEFAULT 0.00 COMMENT 'Distance parcourue en ambulance',
    `time_on_duty` INT DEFAULT 0 COMMENT 'Temps en service (secondes)',
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: Ordonnances médicales
CREATE TABLE IF NOT EXISTS `ems_prescriptions` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL COMMENT 'Identifiant du patient',
    `patient_name` VARCHAR(100) NOT NULL COMMENT 'Nom du patient',
    `medic_id` VARCHAR(50) NOT NULL COMMENT 'Identifiant du médecin prescripteur',
    `medic_name` VARCHAR(100) NOT NULL COMMENT 'Nom du médecin',
    `medication` VARCHAR(100) NOT NULL COMMENT 'Médicament prescrit',
    `dosage` VARCHAR(50) NOT NULL COMMENT 'Dosage',
    `instructions` TEXT NOT NULL COMMENT 'Instructions d\'utilisation',
    `duration` INT NOT NULL COMMENT 'Durée du traitement (jours)',
    `filled` TINYINT(1) DEFAULT 0 COMMENT '0 = non récupérée, 1 = récupérée',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `filled_at` TIMESTAMP NULL DEFAULT NULL,
    INDEX `idx_citizenid` (`citizenid`),
    INDEX `idx_filled` (`filled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
