--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                   vAvA Creator - Français                                 ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
]]--

Locales = Locales or {}

Locales['fr'] = {
    -- Général
    ['loading'] = 'Chargement...',
    ['error'] = 'Erreur',
    ['success'] = 'Succès',
    ['cancel'] = 'Annuler',
    ['confirm'] = 'Confirmer',
    ['save'] = 'Sauvegarder',
    ['close'] = 'Fermer',
    ['next'] = 'Suivant',
    ['previous'] = 'Précédent',
    ['reset'] = 'Réinitialiser',
    ['random'] = 'Aléatoire',
    
    -- Sélection de personnages
    ['select_character'] = 'Sélection du personnage',
    ['new_character'] = 'Nouveau personnage',
    ['play'] = 'Jouer',
    ['delete'] = 'Supprimer',
    ['delete_confirm'] = 'Êtes-vous sûr de vouloir supprimer ce personnage ?',
    ['slot_empty'] = 'Emplacement vide',
    ['create_character'] = 'Créer un personnage',
    
    -- Créateur - Étapes
    ['step_gender'] = 'Sexe',
    ['step_morphology'] = 'Morphologie',
    ['step_face'] = 'Visage',
    ['step_hair'] = 'Cheveux',
    ['step_skin'] = 'Peau',
    ['step_clothes'] = 'Vêtements',
    ['step_identity'] = 'Identité',
    ['step_summary'] = 'Résumé',
    
    -- Créateur - Genre
    ['choose_gender'] = 'Choisissez le sexe de votre personnage',
    ['male'] = 'Homme',
    ['female'] = 'Femme',
    
    -- Créateur - Morphologie
    ['heritage'] = 'Héritage génétique',
    ['mother'] = 'Mère',
    ['father'] = 'Père',
    ['resemblance'] = 'Ressemblance',
    ['skin_tone'] = 'Teint',
    
    -- Créateur - Visage
    ['face_features'] = 'Traits du visage',
    ['nose_width'] = 'Largeur du nez',
    ['nose_height'] = 'Hauteur du nez',
    ['nose_length'] = 'Longueur du nez',
    ['nose_bridge'] = 'Pont nasal',
    ['nose_tip'] = 'Pointe du nez',
    ['eyebrow_height'] = 'Hauteur des sourcils',
    ['eyebrow_length'] = 'Longueur des sourcils',
    ['cheekbone_height'] = 'Hauteur des pommettes',
    ['cheekbone_width'] = 'Largeur des pommettes',
    ['cheek_width'] = 'Largeur des joues',
    ['eye_opening'] = 'Ouverture des yeux',
    ['lip_thickness'] = 'Épaisseur des lèvres',
    ['jaw_width'] = 'Largeur de la mâchoire',
    ['jaw_length'] = 'Longueur de la mâchoire',
    ['chin_height'] = 'Hauteur du menton',
    ['chin_length'] = 'Longueur du menton',
    ['chin_width'] = 'Largeur du menton',
    ['chin_dimple'] = 'Fossette du menton',
    ['neck_thickness'] = 'Épaisseur du cou',
    
    -- Créateur - Cheveux
    ['hair_style'] = 'Coupe de cheveux',
    ['hair_color'] = 'Couleur principale',
    ['hair_highlight'] = 'Mèches / Reflets',
    ['beard_style'] = 'Style de barbe',
    ['beard_color'] = 'Couleur de barbe',
    ['eyebrows_style'] = 'Style de sourcils',
    ['eyebrows_color'] = 'Couleur des sourcils',
    
    -- Créateur - Peau
    ['blemishes'] = 'Imperfections',
    ['ageing'] = 'Vieillissement',
    ['complexion'] = 'Teint',
    ['sun_damage'] = 'Dégâts solaires',
    ['moles'] = 'Grains de beauté',
    ['makeup'] = 'Maquillage',
    ['lipstick'] = 'Rouge à lèvres',
    ['blush'] = 'Blush',
    ['eye_color'] = 'Couleur des yeux',
    ['opacity'] = 'Opacité',
    
    -- Créateur - Vêtements
    ['top'] = 'Haut',
    ['undershirt'] = 'Sous-vêtement',
    ['pants'] = 'Pantalon',
    ['shoes'] = 'Chaussures',
    ['texture'] = 'Texture',
    
    -- Créateur - Identité
    ['firstname'] = 'Prénom',
    ['lastname'] = 'Nom de famille',
    ['age'] = 'Âge',
    ['nationality'] = 'Nationalité',
    ['story'] = 'Histoire',
    ['story_placeholder'] = 'Racontez l\'histoire de votre personnage...',
    
    -- Nationalités
    ['nationality_american'] = 'Américain',
    ['nationality_french'] = 'Français',
    ['nationality_english'] = 'Anglais',
    ['nationality_spanish'] = 'Espagnol',
    ['nationality_italian'] = 'Italien',
    ['nationality_german'] = 'Allemand',
    ['nationality_mexican'] = 'Mexicain',
    ['nationality_canadian'] = 'Canadien',
    ['nationality_other'] = 'Autre',
    
    -- Créateur - Résumé
    ['summary'] = 'Résumé',
    ['full_name'] = 'Nom complet',
    ['create_btn'] = 'CRÉER LE PERSONNAGE',
    
    -- Validation
    ['invalid_firstname'] = 'Prénom invalide',
    ['invalid_lastname'] = 'Nom invalide',
    ['invalid_age'] = 'Âge invalide',
    ['min_characters'] = 'Minimum %d caractères',
    ['character_created'] = 'Personnage créé avec succès!',
    ['character_deleted'] = 'Personnage supprimé',
    ['welcome'] = 'Bienvenue %s!',
    
    -- Shops
    ['clothing_shop'] = 'Magasin de vêtements',
    ['barber_shop'] = 'Coiffeur',
    ['tattoo_shop'] = 'Tatoueur',
    ['surgery_shop'] = 'Chirurgie esthétique',
    ['press_to_open'] = '[E] %s',
    
    -- Catégories vêtements
    ['category_tops'] = 'Hauts',
    ['category_pants'] = 'Pantalons',
    ['category_shoes'] = 'Chaussures',
    ['category_accessories'] = 'Accessoires',
    ['category_hats'] = 'Chapeaux',
    ['category_glasses'] = 'Lunettes',
    ['category_masks'] = 'Masques',
    ['category_bags'] = 'Sacs',
    ['category_ears'] = 'Boucles d\'oreilles',
    ['category_watches'] = 'Montres',
    ['category_bracelets'] = 'Bracelets',
    
    -- Shops - Actions
    ['buy'] = 'Acheter',
    ['try'] = 'Essayer',
    ['price'] = 'Prix',
    ['total'] = 'Total',
    ['cash'] = 'Espèces',
    ['bank'] = 'Banque',
    ['style'] = 'Style',
    ['not_enough_money'] = 'Pas assez d\'argent',
    ['purchase_success'] = 'Achat effectué!',
    ['purchase_failed'] = 'Échec de l\'achat',
    
    -- Coiffeur
    ['hair'] = 'Cheveux',
    ['beard'] = 'Barbe',
    ['eyebrows'] = 'Sourcils',
    
    -- Chirurgie
    ['heritage_tab'] = 'Héritage',
    ['face_tab'] = 'Visage',
    ['eyes_tab'] = 'Yeux',
    ['surgery_price'] = 'Prix de l\'opération'
}
