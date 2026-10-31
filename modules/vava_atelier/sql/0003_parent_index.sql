-- vava_atelier : enfants d'une fiche (lieux du volet et des règles de placement, T-102). Lu par la requête
-- CHILDREN_SQL de server/store.lua (`WHERE editor = ? AND parent = ?`).
ALTER TABLE `vava_atelier_definitions` ADD INDEX `idx_atelier_def_parent` (`editor`, `parent`);
