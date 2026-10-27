-- vava_chat : journal du chat pour la modération (genres choisis dans la config : /ooc, /mp, /staff).
-- Effacé au bout de `log.retentionDays` jours. Date en secondes (horloge du serveur). 0 et '' : pas de destinataire
-- désigné (hors-RP, Conseil). Le nom est celui du personnage au moment du message.
CREATE TABLE IF NOT EXISTS `vava_chat_logs` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `at` INT UNSIGNED NOT NULL,
    `kind` VARCHAR(8) NOT NULL,
    `character_id` INT UNSIGNED NOT NULL,
    `author` VARCHAR(96) NOT NULL,
    `target_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `target` VARCHAR(96) NOT NULL DEFAULT '',
    `recipients` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `message` VARCHAR(1100) NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_vava_chat_logs_at` (`at`),
    KEY `idx_vava_chat_logs_character` (`character_id`, `at`),
    KEY `idx_vava_chat_logs_target` (`target_id`, `at`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
