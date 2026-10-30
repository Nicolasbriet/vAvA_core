-- vava_chancellerie : comptes de jeu que le pont a vus reliés à un compte du panneau (code juste tapé en jeu, confirmé
-- par la Chancellerie). Seuls ceux-là reçoivent un rang du Conseil du panneau. Les joueurs sont désignés par leur
-- compte (vava_accounts.id) ; `panel_account` : nom du compte du panneau à la dernière liaison, pour mémoire.

CREATE TABLE IF NOT EXISTS `vava_chancellerie_links` (
    `account_id` INT UNSIGNED NOT NULL,
    `panel_account` VARCHAR(64) NOT NULL,
    `linked_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`account_id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
