-- vava_magic : tables de la magie. La fiche magie elle-même (mage, sorts, XP, sigils gardés) vit dans le champ
-- `vava_magic:sheet` du personnage (colonne JSON `data` de vava_characters), sauvegardé par le core.

-- Sigil de chaque personnage, mage ou non : unique dans tout le royaume. Brouiller son sigil le remplace.
CREATE TABLE IF NOT EXISTS `vava_magic_sigils` (
    `sigil` VARCHAR(16) NOT NULL,
    `character_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`sigil`),
    UNIQUE KEY `uq_vava_magic_sigils_character` (`character_id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- Registres des murmures : l'objet de l'inventaire ne porte que ce numéro (métadonnée `registre`).
CREATE TABLE IF NOT EXISTS `vava_magic_registers` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `created_at` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- Pages d'un registre : direction 1 = envoyé, 2 = reçu ; date en secondes (horloge du serveur).
CREATE TABLE IF NOT EXISTS `vava_magic_register_pages` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `register_id` INT UNSIGNED NOT NULL,
    `written_at` INT UNSIGNED NOT NULL,
    `direction` TINYINT UNSIGNED NOT NULL,
    `contact` VARCHAR(160) NOT NULL,
    `body` TEXT NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_vava_magic_pages_register` (`register_id`, `id`),
    CONSTRAINT `fk_vava_magic_pages_register` FOREIGN KEY (`register_id`) REFERENCES `vava_magic_registers` (`id`) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- Dégâts infligés par les sorts, pour le Conseil : lanceur et cible (personnages), part de vie, position de la cible.
CREATE TABLE IF NOT EXISTS `vava_magic_damage_log` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `at` INT UNSIGNED NOT NULL,
    `spell` VARCHAR(32) NOT NULL,
    `caster_id` INT UNSIGNED NOT NULL,
    `target_id` INT UNSIGNED NOT NULL,
    `kind` VARCHAR(8) NOT NULL,
    `damage` DECIMAL(6, 3) NOT NULL,
    `x` FLOAT NOT NULL,
    `y` FLOAT NOT NULL,
    `z` FLOAT NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_vava_magic_damage_at` (`at`),
    KEY `idx_vava_magic_damage_target` (`target_id`, `at`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
