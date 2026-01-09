-- ══════════════════════════════════════════════════════════════════════════════
-- vAvA_core - Economy SQL Schema
-- Tables pour le système économique
-- ══════════════════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════════════════
-- Table: economy_state
-- État global de l'économie (inflation, multiplicateur, etc.)
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `economy_state` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `inflation` DECIMAL(10,4) NOT NULL DEFAULT 1.0000,
    `base_multiplier` DECIMAL(10,4) NOT NULL DEFAULT 1.0000,
    `profile` VARCHAR(50) NOT NULL DEFAULT 'normal',
    `last_update` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `updated_by` VARCHAR(50) DEFAULT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insertion état par défaut
INSERT INTO `economy_state` (`inflation`, `base_multiplier`, `profile`) 
VALUES (1.0000, 1.0000, 'normal')
ON DUPLICATE KEY UPDATE `id` = `id`;

-- ══════════════════════════════════════════════════════════════════════════════
-- Table: economy_items
-- Prix dynamiques des items
-- ══════════════════════════════════════════════════════════════════════════════

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

-- ══════════════════════════════════════════════════════════════════════════════
-- Table: economy_jobs
-- Salaires dynamiques des jobs
-- ══════════════════════════════════════════════════════════════════════════════

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

-- ══════════════════════════════════════════════════════════════════════════════
-- Table: economy_logs
-- Historique des changements économiques
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `economy_logs` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `log_type` ENUM('price', 'salary', 'tax', 'inflation', 'recalculate', 'override', 'alert') NOT NULL,
    `item_or_job` VARCHAR(100) DEFAULT NULL,
    `old_value` DECIMAL(10,2) DEFAULT NULL,
    `new_value` DECIMAL(10,2) DEFAULT NULL,
    `variation_percent` DECIMAL(10,4) DEFAULT NULL,
    `source` ENUM('auto', 'admin', 'system') NOT NULL DEFAULT 'auto',
    `admin_identifier` VARCHAR(100) DEFAULT NULL,
    `reason` TEXT DEFAULT NULL,
    `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `log_type` (`log_type`),
    KEY `timestamp` (`timestamp`),
    KEY `item_or_job` (`item_or_job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ══════════════════════════════════════════════════════════════════════════════
-- Table: economy_transactions
-- Statistiques des transactions pour auto-ajustement
-- ══════════════════════════════════════════════════════════════════════════════

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

-- ══════════════════════════════════════════════════════════════════════════════
-- Table: economy_shops
-- Multiplicateurs dynamiques des shops
-- ══════════════════════════════════════════════════════════════════════════════

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

-- ══════════════════════════════════════════════════════════════════════════════
-- Table: economy_taxes
-- Configuration dynamique des taxes
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `economy_taxes` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `tax_type` VARCHAR(50) NOT NULL,
    `rate` DECIMAL(10,4) NOT NULL DEFAULT 0.0500,
    `description` VARCHAR(255) DEFAULT NULL,
    `last_update` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `tax_type` (`tax_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insertion taxes par défaut
INSERT INTO `economy_taxes` (`tax_type`, `rate`, `description`) VALUES
('achat', 0.0500, 'Taxe sur les achats'),
('vente', 0.0300, 'Taxe sur les ventes'),
('salaire', 0.0200, 'Taxe sur les salaires'),
('transfert', 0.0100, 'Taxe sur les transferts bancaires'),
('vehicule', 0.1000, 'Taxe sur l\'achat de véhicules'),
('immobilier', 0.1500, 'Taxe sur l\'achat immobilier')
ON DUPLICATE KEY UPDATE `id` = `id`;

-- ══════════════════════════════════════════════════════════════════════════════
-- Migration tracking
-- ══════════════════════════════════════════════════════════════════════════════

INSERT INTO `vcore_migrations` (`migration`, `applied_at`) 
VALUES ('economy_system', NOW())
ON DUPLICATE KEY UPDATE `applied_at` = NOW();
