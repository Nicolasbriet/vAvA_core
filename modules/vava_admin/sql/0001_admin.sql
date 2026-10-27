-- vava_admin : membres du Conseil, sanctions, avertissements et journal des actions.
-- Les joueurs sont désignés par leur compte (vava_accounts.id) : aucun autre identifiant n'est conservé.

CREATE TABLE IF NOT EXISTS `vava_admin_staff` (
    `account_id` INT UNSIGNED NOT NULL,
    `rank` VARCHAR(32) NOT NULL,
    `granted_by` INT UNSIGNED NULL,
    `granted_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`account_id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vava_admin_bans` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_id` INT UNSIGNED NOT NULL,
    `target_label` VARCHAR(80) NOT NULL,
    `reason` VARCHAR(500) NOT NULL,
    `actor_account_id` INT UNSIGNED NULL,
    `actor_label` VARCHAR(80) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `expires_at` DATETIME NULL,
    `revoked_at` DATETIME NULL,
    `revoked_by` VARCHAR(80) NULL,
    PRIMARY KEY (`id`),
    KEY `idx_bans_account` (`account_id`, `revoked_at`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vava_admin_warnings` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_id` INT UNSIGNED NOT NULL,
    `reason` VARCHAR(500) NOT NULL,
    `actor_label` VARCHAR(80) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_warnings_account` (`account_id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vava_admin_logs` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `actor_account_id` INT UNSIGNED NULL,
    `actor_label` VARCHAR(80) NOT NULL,
    `action` VARCHAR(32) NOT NULL,
    `target_account_id` INT UNSIGNED NULL,
    `target_label` VARCHAR(80) NULL,
    `details` VARCHAR(1000) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_logs_created` (`created_at`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
