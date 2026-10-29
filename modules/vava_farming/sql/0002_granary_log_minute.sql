-- vava_farming : journal du grenier regroupé par minute. Une ligne par minute, grenier, personnage, objet et sens
-- (deposit | withdraw), quantités additionnées, au lieu d'une ligne par geste. `minute` (début de la minute, en
-- secondes, horloge du serveur) est égal à `at` sur ces lignes ; il vaut NULL sur les lignes d'avant, une par geste,
-- qui restent lisibles telles quelles (`at` à la seconde) et n'entrent pas dans la clé unique (un NULL n'y est jamais
-- en double). La purge par `at` vaut pour les deux.
-- Une migration = un changement. ALTER TABLE n'étant pas idempotent sous MySQL, il est seul dans son fichier, en une
-- seule instruction : la colonne et la clé viennent ensemble ou pas du tout, et la migration est rejouée telle quelle
-- après correction.
ALTER TABLE `vava_farming_granary_log`
    ADD COLUMN `minute` INT UNSIGNED NULL DEFAULT NULL AFTER `at`,
    ADD UNIQUE KEY `uq_vava_farming_granary_minute` (`minute`, `parcel`, `character_id`, `item`, `action`);
