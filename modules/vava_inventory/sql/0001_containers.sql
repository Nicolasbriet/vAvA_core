-- vava_inventory : conteneurs persistants (inventaire d'un personnage, coffres créés par d'autres modules).
-- Les sacs au sol ne sont pas conservés : ils n'ont pas de ligne ici.
CREATE TABLE IF NOT EXISTS `vava_inventory_containers` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `kind` VARCHAR(32) NOT NULL,
    `owner_type` VARCHAR(32) NOT NULL DEFAULT '',
    `owner_id` VARCHAR(64) NOT NULL DEFAULT '',
    `width` TINYINT UNSIGNED NOT NULL,
    `height` TINYINT UNSIGNED NOT NULL,
    `max_weight` INT UNSIGNED NOT NULL DEFAULT 0,
    `label` VARCHAR(64) NOT NULL DEFAULT '',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_owner` (`owner_type`, `owner_id`, `kind`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
