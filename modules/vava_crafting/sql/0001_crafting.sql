-- vava_crafting : état des stations (la donnée — types, positions, recettes — vit dans config.lua) et journal. Les
-- objets créés vivent dans l'inventaire (métadonnées) ; le poinçon d'un artisan dans le champ de personnage
-- `vava_crafting:mark`. Dates en secondes (horloge du serveur).

-- Réserve de combustible d'une station.
CREATE TABLE IF NOT EXISTS `vava_crafting_stations` (
    `station` VARCHAR(32) NOT NULL,
    `fuel` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `updated_at` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`station`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- Journal : pièces Excellent et au-dessus, réparations, baptêmes, leçons données, actions du Conseil.
CREATE TABLE IF NOT EXISTS `vava_crafting_log` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `at` INT UNSIGNED NOT NULL,
    `kind` VARCHAR(32) NOT NULL,
    `station` VARCHAR(32) NULL DEFAULT NULL,
    `recipe` VARCHAR(64) NULL DEFAULT NULL,
    `character_id` INT UNSIGNED NULL DEFAULT NULL,
    `account_id` INT UNSIGNED NULL DEFAULT NULL,
    `item` VARCHAR(64) NULL DEFAULT NULL,
    `quality` TINYINT UNSIGNED NULL DEFAULT NULL,
    `details` JSON NULL,
    PRIMARY KEY (`id`),
    KEY `idx_vava_crafting_log_at` (`at`),
    KEY `idx_vava_crafting_log_character` (`character_id`, `at`),
    KEY `idx_vava_crafting_log_kind` (`kind`, `at`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
