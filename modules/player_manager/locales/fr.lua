--[[
    vAvA_player_manager - Locales FR
    Traduction française
]]

Locales = Locales or {}

Locales['fr'] = {
    -- Sélecteur
    ['selector_title'] = 'Sélection du personnage',
    ['create_character'] = 'Créer un personnage',
    ['delete_character'] = 'Supprimer',
    ['play_character'] = 'Jouer',
    ['confirm_delete'] = 'Êtes-vous sûr de vouloir supprimer ce personnage?',
    ['last_played'] = 'Dernière connexion',
    ['playtime'] = 'Temps de jeu',
    ['job'] = 'Emploi',
    ['no_characters'] = 'Aucun personnage',
    ['create_first'] = 'Créez votre premier personnage',
    ['max_characters'] = 'Personnages: %s/%s',
    
    -- Création
    ['creation_title'] = 'Création de personnage',
    ['firstname'] = 'Prénom',
    ['lastname'] = 'Nom',
    ['dateofbirth'] = 'Date de naissance',
    ['sex'] = 'Sexe',
    ['male'] = 'Homme',
    ['female'] = 'Femme',
    ['nationality'] = 'Nationalité',
    ['story'] = 'Histoire',
    ['background'] = 'Votre profession avant Los Santos',
    ['reason'] = 'Pourquoi êtes-vous venu(e) à Los Santos?',
    ['goal'] = 'Quel est votre objectif principal?',
    ['create_btn'] = 'Créer',
    ['cancel_btn'] = 'Annuler',
    ['required_field'] = 'Champ obligatoire',
    ['invalid_dob'] = 'Date de naissance invalide',
    ['too_young'] = 'Âge minimum: %s ans',
    ['too_old'] = 'Âge maximum: %s ans',
    
    -- Carte ID
    ['id_card'] = 'Carte d\'identité',
    ['show_id'] = 'Montrer carte ID',
    ['citizen_id'] = 'N° Citoyen',
    ['phone_number'] = 'Téléphone',
    ['issued_date'] = 'Date d\'émission',
    ['valid_until'] = 'Valide jusqu\'au',
    ['id_shown_to'] = 'Vous avez montré votre carte à %s',
    ['id_shown_by'] = '%s vous montre sa carte d\'identité',
    
    -- Licences
    ['licenses'] = 'Licences',
    ['no_licenses'] = 'Aucune licence',
    ['obtain_license'] = 'Obtenir',
    ['license_valid'] = 'Valide',
    ['license_expired'] = 'Expirée',
    ['license_suspended'] = 'Suspendue',
    ['exam_required'] = 'Examen requis',
    ['go_to_exam'] = 'Aller passer l\'examen',
    ['cost'] = 'Coût',
    ['validity'] = 'Validité',
    ['days'] = 'jours',
    ['unlimited'] = 'Illimité',
    ['driver_license'] = 'Permis de conduire',
    ['weapon_license'] = 'Permis port d\'arme',
    ['business_license'] = 'Licence commerciale',
    ['hunting_license'] = 'Permis de chasse',
    ['fishing_license'] = 'Permis de pêche',
    ['pilot_license'] = 'Licence de pilote',
    ['boat_license'] = 'Permis bateau',
    
    -- Stats
    ['statistics'] = 'Statistiques',
    ['playtime_hours'] = 'Temps de jeu (heures)',
    ['distance_walked_km'] = 'Distance à pied (km)',
    ['distance_driven_km'] = 'Distance en véhicule (km)',
    ['total_deaths'] = 'Nombre de morts',
    ['total_arrests'] = 'Arrestations',
    ['jobs_completed'] = 'Missions accomplies',
    ['money_earned'] = 'Argent gagné',
    ['money_spent'] = 'Argent dépensé',
    
    -- Historique
    ['history'] = 'Historique',
    ['event_type'] = 'Type',
    ['event_date'] = 'Date',
    ['event_amount'] = 'Montant',
    ['no_history'] = 'Aucun historique',
    ['load_more'] = 'Charger plus',
    
    -- Events
    ['character_login'] = 'Connexion',
    ['character_logout'] = 'Déconnexion',
    ['job_change'] = 'Changement emploi',
    ['name_change'] = 'Changement nom',
    ['bank_deposit'] = 'Dépôt banque',
    ['bank_withdraw'] = 'Retrait banque',
    ['bank_transfer'] = 'Virement',
    ['property_buy'] = 'Achat propriété',
    ['property_sell'] = 'Vente propriété',
    ['vehicle_buy'] = 'Achat véhicule',
    ['vehicle_sell'] = 'Vente véhicule',
    ['arrest'] = 'Arrestation',
    ['fine'] = 'Amende',
    ['jail'] = 'Prison',
    ['death'] = 'Mort',
    ['revive'] = 'Réanimation',
    ['license_obtained'] = 'Licence obtenue',
    ['license_revoked'] = 'Licence révoquée',
    ['license_suspended'] = 'Licence suspendue',
    
    -- Notifications
    ['character_created'] = 'Personnage créé avec succès!',
    ['character_deleted'] = 'Personnage supprimé',
    ['character_selected'] = 'Bienvenue %s %s',
    ['license_obtained_msg'] = 'Vous avez obtenu: %s',
    ['license_revoked_msg'] = 'Votre licence %s a été révoquée',
    ['license_expired_msg'] = 'Votre licence %s a expiré',
    ['insufficient_funds'] = 'Fonds insuffisants',
    ['exam_required_msg'] = 'Vous devez passer un examen pour cette licence',
    
    -- Erreurs
    ['error_occurred'] = 'Une erreur est survenue',
    ['character_not_found'] = 'Personnage introuvable',
    ['access_denied'] = 'Accès refusé',
    ['license_not_found'] = 'Licence introuvable',
    ['max_chars_reached'] = 'Limite de personnages atteinte',
    
    -- Commandes
    ['cmd_characters'] = 'Ouvrir sélecteur personnages',
    ['cmd_deletechar'] = 'Supprimer personnage',
    ['cmd_resetchar'] = 'Réinitialiser personnage',
    ['cmd_givelicense'] = 'Donner licence',
    ['cmd_revokelicense'] = 'Révoquer licence',
    ['cmd_showid'] = 'Montrer carte ID',
    ['cmd_checkid'] = 'Vérifier carte ID',
    ['cmd_showlicenses'] = 'Voir mes licences',
    ['cmd_stats'] = 'Voir statistiques'
}

return Locales['fr']
