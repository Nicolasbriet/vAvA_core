-- vava_example : une note est désormais signée par un personnage.
-- Une migration = un changement. ALTER TABLE n'étant pas idempotent sous MySQL, il est seul dans son fichier :
-- en cas d'échec, rien n'est enregistré et la migration est rejouée telle quelle après correction.
ALTER TABLE `vava_example_notes`
    ADD COLUMN `character_id` INT UNSIGNED NULL DEFAULT NULL AFTER `author`,
    ADD KEY `idx_character` (`character_id`);
