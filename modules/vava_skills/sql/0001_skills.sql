-- vava_skills : compétences, mentorats, recettes transmises, leçons, fragments et journal. Les dates sont en secondes
-- (horloge du serveur, os.time). Le savoir commun et le budget se calculent sur ces lignes, jamais stockés.

-- Une ligne par compétence pratiquée (absence = niveau 0, mode keep). `xp` : XP dans le niveau courant.
-- Renommée du maître : total, jour UTC du dernier gain (jours depuis l'époque) et gain de ce jour (plafond).
CREATE TABLE IF NOT EXISTS `vava_skills_skills` (
    `character_id` INT UNSIGNED NOT NULL,
    `skill` VARCHAR(32) NOT NULL,
    `level` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `xp` INT UNSIGNED NOT NULL DEFAULT 0,
    `mode` CHAR(4) NOT NULL DEFAULT 'keep',
    `renown` INT UNSIGNED NOT NULL DEFAULT 0,
    `renown_day` INT UNSIGNED NOT NULL DEFAULT 0,
    `renown_day_gained` INT UNSIGNED NOT NULL DEFAULT 0,
    `practiced_at` INT UNSIGNED NOT NULL DEFAULT 0,
    `updated_at` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`character_id`, `skill`),
    KEY `idx_vava_skills_skill_level` (`skill`, `level`),
    CONSTRAINT `fk_vava_skills_skills_character` FOREIGN KEY (`character_id`) REFERENCES `vava_characters` (`id`) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- Mentorats : en cours quand `ended_at` est NULL ; les terminés restent (histoire, rendement décroissant de la
-- Renommée sur un même apprenti). `ended_by` : master | apprentice | system.
CREATE TABLE IF NOT EXISTS `vava_skills_mentorships` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `skill` VARCHAR(32) NOT NULL,
    `master_id` INT UNSIGNED NOT NULL,
    `apprentice_id` INT UNSIGNED NOT NULL,
    `started_at` INT UNSIGNED NOT NULL,
    `ended_at` INT UNSIGNED NULL DEFAULT NULL,
    `ended_by` VARCHAR(16) NULL DEFAULT NULL,
    `xp_granted` INT UNSIGNED NOT NULL DEFAULT 0,
    `renown_granted` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_vava_skills_mentor_apprentice` (`apprentice_id`, `skill`, `ended_at`),
    KEY `idx_vava_skills_mentor_master` (`master_id`, `skill`, `ended_at`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- Recettes transmises connues (les recettes libres ne sont pas stockées : le niveau suffit).
-- `source` : lesson | founder | fragments | admin ; `taught_by` : professeur de la leçon qui a achevé l'apprentissage.
CREATE TABLE IF NOT EXISTS `vava_skills_recipes` (
    `character_id` INT UNSIGNED NOT NULL,
    `recipe` VARCHAR(64) NOT NULL,
    `learned_at` INT UNSIGNED NOT NULL,
    `source` VARCHAR(16) NOT NULL,
    `taught_by` INT UNSIGNED NULL DEFAULT NULL,
    PRIMARY KEY (`character_id`, `recipe`),
    KEY `idx_vava_skills_recipe_teacher` (`recipe`, `taught_by`),
    CONSTRAINT `fk_vava_skills_recipes_character` FOREIGN KEY (`character_id`) REFERENCES `vava_characters` (`id`) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- Une ligne par leçon reçue : compte, délai minimal entre deux leçons, histoire complète (les professeurs peuvent
-- différer d'une leçon à l'autre). `number` : rang de la leçon pour cet élève et cette recette.
CREATE TABLE IF NOT EXISTS `vava_skills_lessons` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `recipe` VARCHAR(64) NOT NULL,
    `student_id` INT UNSIGNED NOT NULL,
    `teacher_id` INT UNSIGNED NOT NULL,
    `at` INT UNSIGNED NOT NULL,
    `number` TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_vava_skills_lessons_student` (`student_id`, `recipe`, `at`),
    KEY `idx_vava_skills_lessons_teacher` (`teacher_id`, `at`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- Fragments de savoirs perdus réunis par un personnage ; la recette est apprise quand tous ceux qu'elle déclare y sont.
CREATE TABLE IF NOT EXISTS `vava_skills_fragments` (
    `character_id` INT UNSIGNED NOT NULL,
    `recipe` VARCHAR(64) NOT NULL,
    `fragment` VARCHAR(32) NOT NULL,
    `found_at` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`character_id`, `recipe`, `fragment`),
    CONSTRAINT `fk_vava_skills_fragments_character` FOREIGN KEY (`character_id`) REFERENCES `vava_characters` (`id`) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- Journal des actions sensibles : leçons, mentorats, fondateurs, corrections du Conseil, rouille, savoirs appris.
-- `actor_id` : personnage à l'origine (NULL : console, système) ; `account_id` : compte de l'acteur (Conseil).
CREATE TABLE IF NOT EXISTS `vava_skills_log` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `at` INT UNSIGNED NOT NULL,
    `kind` VARCHAR(32) NOT NULL,
    `actor_id` INT UNSIGNED NULL DEFAULT NULL,
    `account_id` INT UNSIGNED NULL DEFAULT NULL,
    `target_id` INT UNSIGNED NULL DEFAULT NULL,
    `skill` VARCHAR(32) NULL DEFAULT NULL,
    `recipe` VARCHAR(64) NULL DEFAULT NULL,
    `details` JSON NULL,
    PRIMARY KEY (`id`),
    KEY `idx_vava_skills_log_at` (`at`),
    KEY `idx_vava_skills_log_target` (`target_id`, `at`),
    KEY `idx_vava_skills_log_kind` (`kind`, `at`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
