-- vava_voice : zones où la voix porte plus ou moins loin, créées en jeu par le Conseil.
-- Cylindre : centre (pieds du membre du Conseil à la création), rayon et hauteur en mètres ; la zone commence un peu
-- sous le centre (config.zones.baseOffset). multiplier : effet sur toutes les portées (0,5 à 3).

CREATE TABLE IF NOT EXISTS `vava_voice_zones` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `label` VARCHAR(40) NOT NULL,
    `x` DOUBLE NOT NULL,
    `y` DOUBLE NOT NULL,
    `z` DOUBLE NOT NULL,
    `radius` DECIMAL(6, 2) NOT NULL,
    `height` DECIMAL(6, 2) NOT NULL,
    `multiplier` DECIMAL(4, 2) NOT NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
