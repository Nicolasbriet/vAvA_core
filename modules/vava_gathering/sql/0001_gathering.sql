-- vava_gathering : état des zones et des nœuds (la donnée — positions, ressources, props — vit dans config.lua) et
-- journal. Les dates sont en secondes (horloge du serveur). Un identifiant absent de la config est ignoré au chargement.

-- Vitalité d'une zone (0 à 100), recalculée à la demande depuis `updated_at` ; cicatrice jusqu'à `scarred_until` ;
-- épuisements récents (réaction de la terre).
CREATE TABLE IF NOT EXISTS `vava_gathering_zones` (
    `zone` VARCHAR(32) NOT NULL,
    `vitality` DECIMAL(5, 2) NOT NULL DEFAULT 100.00,
    `updated_at` INT UNSIGNED NOT NULL DEFAULT 0,
    `scarred_until` INT UNSIGNED NULL DEFAULT NULL,
    `depletions` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `last_depletion_at` INT UNSIGNED NULL DEFAULT NULL,
    PRIMARY KEY (`zone`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- Charges restantes d'un nœud, recalculées à la demande depuis `updated_at`.
CREATE TABLE IF NOT EXISTS `vava_gathering_nodes` (
    `node` VARCHAR(48) NOT NULL,
    `zone` VARCHAR(32) NOT NULL,
    `charges` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `updated_at` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`node`),
    KEY `idx_vava_gathering_nodes_zone` (`zone`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- Journal : épuisements, cicatrices, réactions de la terre, actions du Conseil.
CREATE TABLE IF NOT EXISTS `vava_gathering_log` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `at` INT UNSIGNED NOT NULL,
    `kind` VARCHAR(32) NOT NULL,
    `zone` VARCHAR(32) NULL DEFAULT NULL,
    `node` VARCHAR(48) NULL DEFAULT NULL,
    `character_id` INT UNSIGNED NULL DEFAULT NULL,
    `account_id` INT UNSIGNED NULL DEFAULT NULL,
    `details` JSON NULL,
    PRIMARY KEY (`id`),
    KEY `idx_vava_gathering_log_at` (`at`),
    KEY `idx_vava_gathering_log_zone` (`zone`, `at`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
