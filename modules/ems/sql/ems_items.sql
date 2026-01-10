-- ========================================
-- ITEMS EMS - vAvA_core Inventory
-- ========================================

-- Ajouter ces items à votre table 'items' dans la base de données
-- Ou importer ce fichier SQL directement

-- ÉQUIPEMENT BASIQUE
INSERT INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`, `useable`) VALUES
('medical_gloves', 'Gants médicaux', 0.1, 0, 1, 1),
('bandage', 'Bandage', 0.2, 0, 1, 1),
('splint', 'Attelle', 0.5, 0, 1, 1),
('antiseptic', 'Antiseptique', 0.3, 0, 1, 1),
('oxygen_portable', 'Oxygène portable', 2.0, 0, 1, 1),
('compress', 'Pansement compressif', 0.4, 0, 1, 1);

-- ÉQUIPEMENT AVANCÉ
INSERT INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`, `useable`) VALUES
('defibrillator', 'Défibrillateur', 5.0, 1, 1, 1),
('iv_nacl', 'Perfusion NaCl', 1.0, 0, 1, 1),
('iv_plasma', 'Perfusion Plasma', 1.5, 1, 1, 1),
('iv_ringer', 'Ringer Lactate', 1.5, 1, 1, 1),
('morphine', 'Morphine', 0.5, 1, 1, 1),
('adrenaline', 'Adrénaline', 0.3, 1, 1, 1),
('suture_kit', 'Kit de suture', 1.0, 1, 1, 1),
('chest_kit', 'Kit thoracique', 2.0, 1, 1, 1),
('backboard', 'Planche dorsale', 3.0, 0, 1, 1);

-- ÉQUIPEMENT CRITIQUE
INSERT INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`, `useable`) VALUES
('intubation_kit', 'Kit d\'intubation', 2.0, 1, 1, 1),
('ventilator', 'Ventilateur mécanique', 10.0, 1, 1, 1),
('surgery_kit', 'Kit chirurgie d\'urgence', 5.0, 1, 1, 1),
('resuscitation_kit', 'Kit réanimation avancée', 4.0, 1, 1, 1),
('ultrasound', 'Échographie portable', 3.0, 1, 1, 1),
('transfusion_kit', 'Kit transfusion', 2.0, 1, 1, 1);

-- MÉDICAMENTS
INSERT INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`, `useable`) VALUES
('painkiller', 'Antidouleur', 0.2, 0, 1, 1),
('antibiotic', 'Antibiotique', 0.2, 0, 1, 1),
('blood_bag_o_neg', 'Poche de sang O-', 0.5, 1, 1, 0),
('blood_bag_o_pos', 'Poche de sang O+', 0.5, 1, 1, 0),
('blood_bag_a_neg', 'Poche de sang A-', 0.5, 1, 1, 0),
('blood_bag_a_pos', 'Poche de sang A+', 0.5, 1, 1, 0),
('blood_bag_b_neg', 'Poche de sang B-', 0.5, 1, 1, 0),
('blood_bag_b_pos', 'Poche de sang B+', 0.5, 1, 1, 0),
('blood_bag_ab_neg', 'Poche de sang AB-', 0.5, 1, 1, 0),
('blood_bag_ab_pos', 'Poche de sang AB+', 0.5, 1, 1, 0);

-- DIVERS
INSERT INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`, `useable`) VALUES
('medical_card', 'Carte médicale', 0.1, 0, 1, 1),
('diagnostic_scanner', 'Scanner de diagnostic', 1.0, 1, 1, 1),
('stretcher', 'Brancard', 5.0, 0, 1, 1);
