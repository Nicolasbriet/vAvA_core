-- vava_example : notes publiées par les joueurs (démonstration).
-- Idempotent (IF NOT EXISTS) : rejouable sans danger si une instruction suivante venait à échouer.
CREATE TABLE IF NOT EXISTS `vava_example_notes` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `note_type` VARCHAR(64) NOT NULL,
    `author` VARCHAR(64) NOT NULL,
    `content` VARCHAR(500) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_note_type` (`note_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
