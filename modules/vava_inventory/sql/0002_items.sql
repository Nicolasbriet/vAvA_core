-- vava_inventory : objets (une ligne par pile). L'identifiant est attribué par le serveur en mémoire, pour que
-- chaque opération s'exécute d'un bloc sans attendre la base. `metadata` vaut toujours un objet JSON ('{}' si vide).
CREATE TABLE IF NOT EXISTS `vava_inventory_items` (
    `id` BIGINT UNSIGNED NOT NULL,
    `container_id` INT UNSIGNED NOT NULL,
    `item` VARCHAR(64) NOT NULL,
    `x` TINYINT UNSIGNED NOT NULL,
    `y` TINYINT UNSIGNED NOT NULL,
    `rotated` TINYINT(1) NOT NULL DEFAULT 0,
    `quantity` INT UNSIGNED NOT NULL,
    `metadata` JSON NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_container` (`container_id`),
    CONSTRAINT `fk_items_container` FOREIGN KEY (`container_id`) REFERENCES `vava_inventory_containers` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
