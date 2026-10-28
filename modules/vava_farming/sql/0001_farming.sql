-- vava_farming : état des emplacements (la donnée — parcelles, cultures, puits — vit dans config.lua), greniers
-- communs (conteneurs de l'inventaire), journaux. Dates en secondes (horloge du serveur). Un identifiant de parcelle
-- absent de la config est ignoré au chargement.

-- Emplacement d'une parcelle : culture plantée (NULL : vide), palier de la graine, croissance effective (secondes),
-- humidité et fertilité (0–100), sécheresse (depuis quand, heures cumulées), arrosages, flétri, mort, famille de la
-- dernière culture (rotation), date du dernier calcul.
CREATE TABLE IF NOT EXISTS `vava_farming_slots` (
    `parcel` VARCHAR(32) NOT NULL,
    `slot` TINYINT UNSIGNED NOT NULL,
    `crop` VARCHAR(32) NULL DEFAULT NULL,
    `seed_tier` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `planted_at` INT UNSIGNED NOT NULL DEFAULT 0,
    `growth` INT UNSIGNED NOT NULL DEFAULT 0,
    `moisture` DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
    `fertility` DECIMAL(5, 2) NOT NULL DEFAULT 80.00,
    `dry_since` INT UNSIGNED NULL DEFAULT NULL,
    `dry_hours` DECIMAL(8, 3) NOT NULL DEFAULT 0.000,
    `waterings` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `wilted` TINYINT(1) NOT NULL DEFAULT 0,
    `dead` TINYINT(1) NOT NULL DEFAULT 0,
    `last_family` VARCHAR(32) NULL DEFAULT NULL,
    `updated_at` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`parcel`, `slot`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- Grenier commun d'une parcelle : conteneur conservé de vava_inventory.
CREATE TABLE IF NOT EXISTS `vava_farming_granaries` (
    `parcel` VARCHAR(32) NOT NULL,
    `container_id` INT UNSIGNED NOT NULL,
    `created_at` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`parcel`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- Dépôts et retraits au grenier (gestes des joueurs vus par les hooks de l'inventaire). `action` : deposit | withdraw.
CREATE TABLE IF NOT EXISTS `vava_farming_granary_log` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `at` INT UNSIGNED NOT NULL,
    `parcel` VARCHAR(32) NOT NULL,
    `character_id` INT UNSIGNED NULL DEFAULT NULL,
    `action` VARCHAR(16) NOT NULL,
    `item` VARCHAR(64) NOT NULL,
    `quantity` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_vava_farming_granary_parcel` (`parcel`, `at`),
    KEY `idx_vava_farming_granary_character` (`character_id`, `at`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- Journal : plantations, récoltes Excellent et au-dessus, arrachages, actions du Conseil.
CREATE TABLE IF NOT EXISTS `vava_farming_log` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `at` INT UNSIGNED NOT NULL,
    `kind` VARCHAR(32) NOT NULL,
    `parcel` VARCHAR(32) NULL DEFAULT NULL,
    `slot` TINYINT UNSIGNED NULL DEFAULT NULL,
    `character_id` INT UNSIGNED NULL DEFAULT NULL,
    `account_id` INT UNSIGNED NULL DEFAULT NULL,
    `item` VARCHAR(64) NULL DEFAULT NULL,
    `quality` TINYINT UNSIGNED NULL DEFAULT NULL,
    `details` JSON NULL,
    PRIMARY KEY (`id`),
    KEY `idx_vava_farming_log_at` (`at`),
    KEY `idx_vava_farming_log_parcel` (`parcel`, `at`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
