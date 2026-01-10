-- ═══════════════════════════════════════════════════════════════════════════
-- vAvA_player_manager - Schéma Base de Données
-- ═══════════════════════════════════════════════════════════════════════════

-- Table: Personnages
CREATE TABLE IF NOT EXISTS player_characters (
    id INT AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(50) UNIQUE NOT NULL,
    license VARCHAR(100) NOT NULL,
    firstname VARCHAR(50) NOT NULL,
    lastname VARCHAR(50) NOT NULL,
    dateofbirth VARCHAR(20) NOT NULL,
    sex VARCHAR(1) NOT NULL DEFAULT 'm',
    nationality VARCHAR(50) DEFAULT 'USA',
    phone VARCHAR(20) UNIQUE,
    job VARCHAR(50) DEFAULT 'unemployed',
    job_grade INT DEFAULT 0,
    gang VARCHAR(50) DEFAULT 'none',
    gang_grade INT DEFAULT 0,
    money_cash DECIMAL(10,2) DEFAULT 5000.00,
    money_bank DECIMAL(10,2) DEFAULT 25000.00,
    last_played TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    playtime INT DEFAULT 0,
    is_dead TINYINT(1) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_license (license),
    INDEX idx_citizenid (citizenid),
    INDEX idx_last_played (last_played)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: Apparence personnage
CREATE TABLE IF NOT EXISTS player_appearance (
    id INT AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(50) UNIQUE NOT NULL,
    model VARCHAR(50) DEFAULT 'mp_m_freemode_01',
    skin LONGTEXT,
    tattoos LONGTEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (citizenid) REFERENCES player_characters(citizenid) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: Tenues sauvegardées
CREATE TABLE IF NOT EXISTS player_outfits (
    id INT AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(50) NOT NULL,
    outfit_name VARCHAR(100) NOT NULL,
    outfit_data LONGTEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (citizenid) REFERENCES player_characters(citizenid) ON DELETE CASCADE,
    INDEX idx_citizenid (citizenid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: Licences
CREATE TABLE IF NOT EXISTS player_licenses (
    id INT AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(50) NOT NULL,
    license_type VARCHAR(50) NOT NULL,
    license_label VARCHAR(100) NOT NULL,
    obtained_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL,
    is_suspended TINYINT(1) DEFAULT 0,
    suspended_until TIMESTAMP NULL,
    issued_by VARCHAR(50) DEFAULT NULL,
    UNIQUE KEY unique_license (citizenid, license_type),
    FOREIGN KEY (citizenid) REFERENCES player_characters(citizenid) ON DELETE CASCADE,
    INDEX idx_citizenid (citizenid),
    INDEX idx_license_type (license_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: Statistiques
CREATE TABLE IF NOT EXISTS player_stats (
    id INT AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(50) UNIQUE NOT NULL,
    playtime INT DEFAULT 0,
    distance_walked DECIMAL(12,2) DEFAULT 0.00,
    distance_driven DECIMAL(12,2) DEFAULT 0.00,
    deaths INT DEFAULT 0,
    arrests INT DEFAULT 0,
    jobs_completed INT DEFAULT 0,
    money_earned DECIMAL(15,2) DEFAULT 0.00,
    money_spent DECIMAL(15,2) DEFAULT 0.00,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (citizenid) REFERENCES player_characters(citizenid) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: Historique
CREATE TABLE IF NOT EXISTS player_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(50) NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    event_description TEXT NOT NULL,
    event_data LONGTEXT,
    amount DECIMAL(15,2) DEFAULT NULL,
    related_player VARCHAR(50) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (citizenid) REFERENCES player_characters(citizenid) ON DELETE CASCADE,
    INDEX idx_citizenid (citizenid),
    INDEX idx_event_type (event_type),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table: Histoire du personnage
CREATE TABLE IF NOT EXISTS player_story (
    id INT AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(50) UNIQUE NOT NULL,
    background TEXT,
    reason_for_coming TEXT,
    main_goal TEXT,
    notes LONGTEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (citizenid) REFERENCES player_characters(citizenid) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ═══════════════════════════════════════════════════════════════════════════
-- DONNÉES PAR DÉFAUT
-- ═══════════════════════════════════════════════════════════════════════════

-- Exemples de licences par défaut (optionnel)
-- Ces données peuvent être ajoutées manuellement si besoin
