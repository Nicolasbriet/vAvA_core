-- vava_health : journal des coups (chaîne de dégâts). Dates en secondes (horloge du serveur). Points sur 100.
CREATE TABLE IF NOT EXISTS `vava_health_hits` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `at` INT UNSIGNED NOT NULL,
    `target_id` INT UNSIGNED NOT NULL,              -- personnage touche
    `source_id` INT UNSIGNED NULL DEFAULT NULL,     -- personnage a l'origine ; NULL : le monde, la faim
    `origin` VARCHAR(64) NOT NULL,                  -- ressource qui a appele hit (vava_health : perte native)
    `kind` VARCHAR(16) NOT NULL,
    `ref` VARCHAR(64) NULL DEFAULT NULL,            -- technique ou sort
    `weapon` VARCHAR(64) NULL DEFAULT NULL,
    `amount` DECIMAL(6,1) NOT NULL,                 -- avant modificateurs
    `applied` DECIMAL(6,1) NOT NULL,                -- retire de la vie
    `blocked` DECIMAL(6,1) NOT NULL DEFAULT 0,
    `absorbed` DECIMAL(6,1) NOT NULL DEFAULT 0,
    `resisted` DECIMAL(6,1) NOT NULL DEFAULT 0,
    `cancelled` VARCHAR(32) NULL DEFAULT NULL,      -- raison d'une annulation
    `downed` TINYINT(1) NOT NULL DEFAULT 0,
    `x` FLOAT NULL DEFAULT NULL,
    `y` FLOAT NULL DEFAULT NULL,
    `z` FLOAT NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_vava_health_hits_at` (`at`),
    KEY `idx_vava_health_hits_target` (`target_id`, `at`),
    KEY `idx_vava_health_hits_source` (`source_id`, `at`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
