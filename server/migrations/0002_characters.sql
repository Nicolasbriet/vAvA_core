-- vAvA_core : personnages. Les champs déclarés par les modules vivent dans `data` (JSON) ;
-- les données volumineuses (inventaire, comptes…) vont dans les tables des modules, qui référencent `id`.
-- Suppression douce (`deleted_at`) : les références des modules restent valides.
CREATE TABLE IF NOT EXISTS `vava_characters` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_id` INT UNSIGNED NOT NULL,
    `first_name` VARCHAR(64) NOT NULL,
    `last_name` VARCHAR(64) NOT NULL,
    `sex` CHAR(1) NOT NULL,
    `position_x` FLOAT NULL DEFAULT NULL,
    `position_y` FLOAT NULL DEFAULT NULL,
    `position_z` FLOAT NULL DEFAULT NULL,
    `heading` FLOAT NULL DEFAULT NULL,
    `data` JSON NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `last_played_at` TIMESTAMP NULL DEFAULT NULL,
    `deleted_at` TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_account_alive` (`account_id`, `deleted_at`),
    KEY `idx_name` (`first_name`, `last_name`),
    CONSTRAINT `fk_characters_account` FOREIGN KEY (`account_id`) REFERENCES `vava_accounts` (`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
