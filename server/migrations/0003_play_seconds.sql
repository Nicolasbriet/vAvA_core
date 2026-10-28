-- vAvA_core : temps de jeu d'un personnage, en secondes, compté côté serveur entre l'apparition confirmée et le
-- déchargement (la sélection ne compte pas), écrit avec le personnage.
-- Une migration = un changement. ALTER TABLE n'étant pas idempotent sous MySQL, il est seul dans son fichier :
-- en cas d'échec, rien n'est enregistré et la migration est rejouée telle quelle après correction.
ALTER TABLE `vava_characters`
    ADD COLUMN `play_seconds` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `heading`;
