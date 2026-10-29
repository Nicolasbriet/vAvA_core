-- vava_time : état du ciel et de l'heure décidé par le Conseil, gardé d'un démarrage à l'autre. Une seule ligne
-- (`id` = 1). Dates en secondes UTC (horloge du serveur). L'heure de Paris, le calendrier et les ciels vivent dans
-- config.lua : un ciel absent de la config est ignoré au chargement.

-- `clock_shift` : secondes ajoutées à l'heure de Paris (± 43 200) ; `clock_frozen` : seconde du jour où l'heure est
-- figée (−1 : elle court) ; `weather` : ciel courant ; `weather_until` : fin prévue par le cycle ; `weather_forced` :
-- imposé par le Conseil ; `weather_frozen` : figé par le Conseil. Aucune colonne NULL : les paramètres d'une écriture
-- forment une liste sans trou.
CREATE TABLE IF NOT EXISTS `vava_time_state` (
    `id` TINYINT UNSIGNED NOT NULL,
    `clock_shift` INT NOT NULL DEFAULT 0,
    `clock_frozen` INT NOT NULL DEFAULT -1,
    `weather` VARCHAR(24) NOT NULL DEFAULT '',
    `weather_until` INT UNSIGNED NOT NULL DEFAULT 0,
    `weather_forced` TINYINT(1) NOT NULL DEFAULT 0,
    `weather_frozen` TINYINT(1) NOT NULL DEFAULT 0,
    `updated_at` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
