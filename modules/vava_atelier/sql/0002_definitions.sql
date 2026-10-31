-- vava_atelier : définitions de l'Atelier, une ligne par version. Brouillon et essai : version NULL (numérotés à la
-- publication). Publié : une seule ligne par fiche. Archivé : ancienne version, ou retrait (removal = 1).
CREATE TABLE IF NOT EXISTS `vava_atelier_definitions` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `editor` VARCHAR(64) NOT NULL,                  -- vava_gathering:zones
    `kind` VARCHAR(32) NOT NULL,                    -- zone
    `def_id` VARCHAR(48) NOT NULL,                  -- foret_brume
    `version` INT UNSIGNED NULL,                    -- 1, 2, 3 ; NULL tant que brouillon ou essai
    `status` ENUM('draft', 'trial', 'published', 'archived') NOT NULL,
    `removal` TINYINT(1) NOT NULL DEFAULT 0,        -- 1 : brouillon de retrait, puis version de retrait archivée
    `origin` ENUM('seed', 'atelier', 'restore', 'import') NOT NULL,
    `format` SMALLINT UNSIGNED NOT NULL DEFAULT 1,  -- format des données du module au moment de l'écriture
    `title` VARCHAR(64) NOT NULL,                   -- valeur du titleField (listes, recherche, journal)
    `parent` VARCHAR(48) NULL,                      -- identifiant d'une fiche du type parent
    `data` TEXT NOT NULL,                           -- JSON : table plate champ → valeur (format de T-100)
    `place` TEXT NULL,                              -- JSON : lieu, NULL si le type n'en a pas
    `fingerprint` CHAR(16) NOT NULL,                -- empreinte de data + place + parent (comparaisons)
    `base_version` INT UNSIGNED NULL,               -- version publiée quand le brouillon a été commencé
    `restored_from` INT UNSIGNED NULL,              -- version d'origine d'une version rétablie
    `batch` INT UNSIGNED NULL,                      -- lot de publication : id de la ligne principale
    `rev` INT UNSIGNED NOT NULL DEFAULT 1,          -- révision d'un brouillon (+1 à chaque écriture)
    `summary` VARCHAR(160) NULL,                    -- résumé du changement (brouillon : vis-à-vis du publié)
    `author_account_id` INT UNSIGNED NULL,          -- qui tient ou a tenu le brouillon ; NULL : console
    `author_label` VARCHAR(80) NOT NULL,            -- Sénéchal Aldric Morn
    `published_by` VARCHAR(80) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `published_at` TIMESTAMP NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_atelier_def_version` (`editor`, `kind`, `def_id`, `version`),
    KEY `idx_atelier_def_live` (`editor`, `status`),
    KEY `idx_atelier_def_author` (`author_account_id`, `status`),
    KEY `idx_atelier_def_batch` (`editor`, `batch`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
