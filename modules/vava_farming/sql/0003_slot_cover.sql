-- vava_farming : emplacement couvert contre le gel des nuits d'hiver (vava_time). Couvrir (geste du cultivateur)
-- protège la plante jusqu'à sa récolte ou son arrachage ; 0 sur toutes les lignes existantes.
-- Une migration = un changement. ALTER TABLE n'étant pas idempotent sous MySQL, il est seul dans son fichier, en une
-- seule instruction.
ALTER TABLE `vava_farming_slots`
    ADD COLUMN `covered` TINYINT(1) NOT NULL DEFAULT 0 AFTER `dead`;
