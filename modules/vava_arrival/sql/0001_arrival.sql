-- vava_arrival : accueil des nouveaux personnages. Dates en secondes (horloge du serveur).
-- Une ligne par personnage accueilli (créée à son premier chargement, ou par le Conseil) ; jamais supprimée,
-- même quand le personnage est supprimé : elle compte dans la limite des dotations du compte.
CREATE TABLE IF NOT EXISTS `vava_arrival` (
    `character_id` INT UNSIGNED NOT NULL,
    `account_id` INT UNSIGNED NOT NULL,
    `kit` VARCHAR(12) NOT NULL DEFAULT 'due',            -- due, claimed, given, withheld, uncertain, none
    `kit_at` INT UNSIGNED NULL DEFAULT NULL,              -- reservation, remise, retenue
    `welcomed_at` INT UNSIGNED NULL DEFAULT NULL,         -- accueil vu (accuse du client)
    `welcome_sends` TINYINT UNSIGNED NOT NULL DEFAULT 0,  -- accueils envoyes sans accuse
    `created_at` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`character_id`),
    KEY `idx_vava_arrival_account` (`account_id`, `kit_at`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- Journal : dotations donnees, retenues, incertaines ; actions du Conseil.
CREATE TABLE IF NOT EXISTS `vava_arrival_log` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `at` INT UNSIGNED NOT NULL,
    `kind` VARCHAR(24) NOT NULL,                          -- kit_given, kit_withheld, kit_uncertain, admin_regive, admin_replay
    `character_id` INT UNSIGNED NOT NULL,
    `account_id` INT UNSIGNED NULL DEFAULT NULL,
    `actor_account_id` INT UNSIGNED NULL DEFAULT NULL,    -- membre du Conseil ; NULL : le serveur ou la console
    `details` JSON NULL,
    PRIMARY KEY (`id`),
    KEY `idx_vava_arrival_log_at` (`at`),
    KEY `idx_vava_arrival_log_character` (`character_id`, `at`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
