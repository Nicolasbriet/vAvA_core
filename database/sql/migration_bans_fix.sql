-- ═══════════════════════════════════════════════════════════════════════════
-- vAvA_core - Migration de la Table Bans
-- ═══════════════════════════════════════════════════════════════════════════
-- Ce script migre la structure de la table `bans` pour corriger l'incohérence
-- entre les fichiers SQL et le code Lua.
-- 
-- Changements:
-- 1. Renommer la colonne `expire` en `expire_at`
-- 2. Ajouter les colonnes manquantes (license, steam, discord, ip) si nécessaire
-- 
-- IMPORTANT: Faites une sauvegarde de votre base de données avant d'exécuter !
-- ═══════════════════════════════════════════════════════════════════════════

-- Vérifier si la colonne 'expire' existe et la renommer en 'expire_at'
SET @column_exists = (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'bans'
    AND COLUMN_NAME = 'expire'
);

-- Renommer 'expire' en 'expire_at' si nécessaire
SET @sql = IF(@column_exists > 0,
    'ALTER TABLE `bans` CHANGE COLUMN `expire` `expire_at` DATETIME DEFAULT NULL',
    'SELECT "Column expire does not exist, skipping rename" AS status'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Ajouter la colonne 'license' si elle n'existe pas
SET @column_exists_license = (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'bans'
    AND COLUMN_NAME = 'license'
);

SET @sql_license = IF(@column_exists_license = 0,
    'ALTER TABLE `bans` ADD COLUMN `license` VARCHAR(60) DEFAULT NULL AFTER `identifier`, ADD INDEX `idx_license` (`license`)',
    'SELECT "Column license already exists" AS status'
);
PREPARE stmt_license FROM @sql_license;
EXECUTE stmt_license;
DEALLOCATE PREPARE stmt_license;

-- Ajouter la colonne 'steam' si elle n'existe pas
SET @column_exists_steam = (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'bans'
    AND COLUMN_NAME = 'steam'
);

SET @sql_steam = IF(@column_exists_steam = 0,
    'ALTER TABLE `bans` ADD COLUMN `steam` VARCHAR(60) DEFAULT NULL AFTER `license`, ADD INDEX `idx_steam` (`steam`)',
    'SELECT "Column steam already exists" AS status'
);
PREPARE stmt_steam FROM @sql_steam;
EXECUTE stmt_steam;
DEALLOCATE PREPARE stmt_steam;

-- Ajouter la colonne 'discord' si elle n'existe pas
SET @column_exists_discord = (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'bans'
    AND COLUMN_NAME = 'discord'
);

SET @sql_discord = IF(@column_exists_discord = 0,
    'ALTER TABLE `bans` ADD COLUMN `discord` VARCHAR(60) DEFAULT NULL AFTER `steam`, ADD INDEX `idx_discord` (`discord`)',
    'SELECT "Column discord already exists" AS status'
);
PREPARE stmt_discord FROM @sql_discord;
EXECUTE stmt_discord;
DEALLOCATE PREPARE stmt_discord;

-- Ajouter la colonne 'ip' si elle n'existe pas
SET @column_exists_ip = (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'bans'
    AND COLUMN_NAME = 'ip'
);

SET @sql_ip = IF(@column_exists_ip = 0,
    'ALTER TABLE `bans` ADD COLUMN `ip` VARCHAR(50) DEFAULT NULL AFTER `discord`',
    'SELECT "Column ip already exists" AS status'
);
PREPARE stmt_ip FROM @sql_ip;
EXECUTE stmt_ip;
DEALLOCATE PREPARE stmt_ip;

-- Message de confirmation
SELECT 'Migration de la table bans terminée avec succès!' AS status;
