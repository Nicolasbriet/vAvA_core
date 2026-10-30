-- vava_atelier : journal du Conseil (changements faits dans l'Atelier). Une ligne par changement ; jamais modifiée.
CREATE TABLE IF NOT EXISTS `vava_atelier_journal` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `editor` VARCHAR(64) NOT NULL,              -- vava_gathering:zones
    `kind` VARCHAR(32) NOT NULL,                -- zone
    `def_id` VARCHAR(48) NULL,                  -- foret_brume (NULL : l'atelier entier, ex. réimport)
    `action` VARCHAR(16) NOT NULL,              -- created | saved | trial | published | archived | restored | removed
                                                -- | imported | placed | moved | note
    `title` VARCHAR(64) NOT NULL,               -- nom affiché : « Forge du bourg »
    `summary` VARCHAR(160) NULL,                -- « 2 points ajoutés, 1 retiré », « de 4 m »
    `version` INT UNSIGNED NULL,
    `required_right` VARCHAR(16) NOT NULL,      -- droit effectif de l'éditeur au moment de l'écriture (filtre de lecture)
    `actor_account_id` INT UNSIGNED NULL,       -- NULL : console
    `actor_label` VARCHAR(80) NOT NULL,         -- « Sénéchal Aldric Morn »
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_atelier_journal_created` (`created_at`),
    KEY `idx_atelier_journal_right` (`required_right`, `id`),
    KEY `idx_atelier_journal_editor` (`editor`, `id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
