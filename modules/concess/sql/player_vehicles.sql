-- Table pour stocker les véhicules des joueurs (module concessionnaire)
CREATE TABLE IF NOT EXISTS `player_vehicles` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `owner` INT(11) NOT NULL COMMENT 'ID du propriétaire (characters.id)',
    `plate` VARCHAR(10) NOT NULL UNIQUE COMMENT 'Plaque d\'immatriculation',
    `vehicle` VARCHAR(50) NOT NULL COMMENT 'Modèle du véhicule',
    `mods` TEXT DEFAULT NULL COMMENT 'Modifications du véhicule (JSON)',
    `stored` TINYINT(1) DEFAULT 1 COMMENT '1 = en garage, 0 = sorti',
    `garage` VARCHAR(50) DEFAULT NULL COMMENT 'Nom du garage où est stocké le véhicule',
    `impounded` TINYINT(1) DEFAULT 0 COMMENT '1 = en fourrière',
    `fuel` INT(11) DEFAULT 100 COMMENT 'Niveau de carburant (0-100)',
    `engine` INT(11) DEFAULT 1000 COMMENT 'État du moteur (0-1000)',
    `body` INT(11) DEFAULT 1000 COMMENT 'État de la carrosserie (0-1000)',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `owner` (`owner`),
    KEY `plate` (`plate`),
    FOREIGN KEY (`owner`) REFERENCES `characters`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
