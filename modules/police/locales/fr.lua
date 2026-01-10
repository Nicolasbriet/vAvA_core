--[[
    vAvA_police - Traduction Française
]]

Locale = Locale or {}

Locale['fr'] = {
    -- Général
    ['police'] = 'Police',
    ['open_menu'] = 'Appuyez sur ~INPUT_CONTEXT~ pour ouvrir le menu',
    ['no_players_nearby'] = 'Aucun joueur à proximité',
    ['player_not_online'] = 'Le joueur n\'est plus en ligne',
    ['action_cancelled'] = 'Action annulée',
    
    -- Menu interactions
    ['citizen_interaction'] = 'Interaction Citoyen',
    ['handcuff'] = 'Menotter / Démenotter',
    ['search'] = 'Fouiller',
    ['escort'] = 'Escorter',
    ['put_in_vehicle'] = 'Mettre dans véhicule',
    ['remove_from_vehicle'] = 'Sortir du véhicule',
    ['fine'] = 'Donner une amende',
    ['jail'] = 'Envoyer en prison',
    ['identity_check'] = 'Contrôle d\'identité',
    ['check_licenses'] = 'Vérifier licences',
    ['confiscate_items'] = 'Confisquer items',
    
    -- Menottes
    ['handcuffed'] = 'Vous êtes menotté(e)',
    ['unhandcuffed'] = 'Vous avez été démenotté(e)',
    ['handcuffed_target'] = 'Vous avez menotté ~y~%s~s~',
    ['unhandcuffed_target'] = 'Vous avez démenotté ~y~%s~s~',
    
    -- Fouille
    ['search_in_progress'] = 'Fouille en cours...',
    ['searched_target'] = 'Vous avez fouillé ~y~%s~s~',
    ['being_searched'] = 'Vous êtes en train d\'être fouillé(e)',
    ['found_items'] = 'Items trouvés : %s',
    ['no_items_found'] = 'Aucun item trouvé',
    ['illegal_items_confiscated'] = 'Items illégaux confisqués : %s',
    
    -- Escorte
    ['escorting'] = 'Vous escortez ~y~%s~s~',
    ['being_escorted'] = 'Vous êtes escorté(e)',
    ['escort_stopped'] = 'Escorte terminée',
    
    -- Véhicule
    ['put_in_vehicle_success'] = 'Citoyen placé dans le véhicule',
    ['remove_from_vehicle_success'] = 'Citoyen sorti du véhicule',
    ['no_vehicle_nearby'] = 'Aucun véhicule à proximité',
    ['vehicle_full'] = 'Le véhicule est plein',
    
    -- Amendes
    ['fine_issued'] = 'Amende émise : ~g~$%s~s~ pour ~y~%s~s~',
    ['fine_received'] = 'Vous avez reçu une amende de ~r~$%s~s~\nMotif : ~y~%s~s~',
    ['fine_paid'] = 'Amende payée : ~g~$%s~s~',
    ['fine_not_enough_money'] = 'Vous n\'avez pas assez d\'argent',
    ['select_fine_type'] = 'Sélectionner le type d\'amende',
    ['traffic_violations'] = 'Infractions routières',
    ['admin_violations'] = 'Infractions administratives',
    ['criminal_violations'] = 'Infractions pénales',
    ['custom_fine'] = 'Amende personnalisée',
    ['enter_custom_amount'] = 'Entrez le montant de l\'amende',
    ['enter_fine_reason'] = 'Entrez le motif de l\'amende',
    
    -- Prison
    ['jail_time'] = 'Temps de prison : ~y~%s~s~ minutes',
    ['sent_to_jail'] = 'Vous avez envoyé ~y~%s~s~ en prison pour ~r~%s~s~ minutes',
    ['jailed'] = 'Vous avez été emprisonné(e) pour ~r~%s~s~ minutes\nMotif : ~y~%s~s~',
    ['time_remaining'] = 'Temps restant : ~r~%s~s~ minutes',
    ['released_from_jail'] = 'Vous avez été libéré(e) de prison',
    ['work_to_reduce'] = 'Travaillez pour réduire votre peine',
    ['work_point'] = 'Appuyez sur ~INPUT_CONTEXT~ pour travailler',
    ['working'] = 'Travail en cours... (~y~-%s~s~ secondes)',
    ['time_reduced'] = 'Temps réduit de ~g~%s~s~ minutes',
    ['enter_jail_time'] = 'Entrez le temps de prison (minutes)',
    ['enter_jail_reason'] = 'Entrez la raison de l\'emprisonnement',
    
    -- Casier judiciaire
    ['criminal_record'] = 'Casier Judiciaire',
    ['no_criminal_record'] = 'Casier judiciaire vierge',
    ['record_added'] = 'Enregistrement ajouté au casier judiciaire',
    ['view_record'] = 'Consulter le casier',
    ['offense'] = 'Délit',
    ['fine_amount'] = 'Montant amende',
    ['jail_time_served'] = 'Temps prison',
    ['date'] = 'Date',
    ['officer'] = 'Officier',
    
    -- Tablette
    ['tablet'] = 'Tablette Police',
    ['open_tablet'] = 'Ouvrir la tablette',
    ['search_person'] = 'Rechercher une personne',
    ['search_vehicle'] = 'Rechercher un véhicule',
    ['search_plate'] = 'Rechercher par plaque',
    ['recent_alerts'] = 'Alertes récentes',
    ['active_units'] = 'Unités actives',
    ['enter_name'] = 'Entrez le nom',
    ['enter_plate'] = 'Entrez la plaque',
    ['person_info'] = 'Informations Personne',
    ['vehicle_info'] = 'Informations Véhicule',
    ['no_results'] = 'Aucun résultat',
    ['name'] = 'Nom',
    ['dob'] = 'Date de naissance',
    ['gender'] = 'Sexe',
    ['phone'] = 'Téléphone',
    ['job'] = 'Métier',
    ['owner'] = 'Propriétaire',
    ['model'] = 'Modèle',
    ['plate'] = 'Plaque',
    ['color'] = 'Couleur',
    
    -- Vestiaire
    ['cloakroom'] = 'Vestiaire',
    ['civilian_outfit'] = 'Tenue civile',
    ['police_outfit'] = 'Tenue de police',
    ['outfit_changed'] = 'Tenue changée',
    
    -- Armurerie
    ['armory'] = 'Armurerie',
    ['take_weapon'] = 'Prendre une arme',
    ['deposit_weapon'] = 'Déposer une arme',
    ['weapon_taken'] = 'Arme prise : ~y~%s~s~',
    ['weapon_deposited'] = 'Arme déposée : ~y~%s~s~',
    ['insufficient_grade'] = 'Grade insuffisant',
    ['ammo'] = 'Munitions',
    ['ammo_taken'] = 'Munitions prises : ~y~%s~s~',
    
    -- Garage
    ['vehicle_garage'] = 'Garage Police',
    ['spawn_vehicle'] = 'Sortir un véhicule',
    ['store_vehicle'] = 'Ranger le véhicule',
    ['vehicle_spawned'] = 'Véhicule sorti : ~y~%s~s~',
    ['vehicle_stored'] = 'Véhicule rangé',
    ['no_vehicle_nearby_to_store'] = 'Aucun véhicule à proximité',
    ['spawn_point_blocked'] = 'Point de sortie bloqué',
    
    -- Radar
    ['radar_on'] = 'Radar ~g~ACTIVÉ~s~',
    ['radar_off'] = 'Radar ~r~DÉSACTIVÉ~s~',
    ['radar_speed'] = 'Vitesse détectée : ~y~%s~s~ km/h',
    ['radar_limit'] = 'Limite : ~y~%s~s~ km/h',
    ['radar_speeding'] = '~r~EXCÈS DE VITESSE~s~',
    ['radar_target'] = 'Véhicule : ~y~%s~s~',
    ['radar_no_target'] = 'Aucun véhicule détecté',
    
    -- Dispatch / Alertes
    ['dispatch_alert'] = 'ALERTE DISPATCH',
    ['alert_code'] = 'Code',
    ['alert_location'] = 'Localisation',
    ['alert_set_waypoint'] = 'Appuyez sur ~INPUT_CONTEXT~ pour GPS',
    ['alert_respond'] = 'Appuyez sur ~INPUT_PICKUP~ pour répondre',
    ['alert_responded'] = 'Alerte prise en charge par ~y~%s~s~',
    ['backup_requested'] = 'RENFORT DEMANDÉ par ~y~%s~s~',
    ['request_backup'] = 'Demander un renfort',
    ['backup_sent'] = 'Demande de renfort envoyée',
    
    -- Service
    ['on_duty'] = 'Vous êtes maintenant ~g~en service~s~',
    ['off_duty'] = 'Vous êtes maintenant ~r~hors service~s~',
    ['duty_toggle'] = 'Prise/Fin de service',
    
    -- Permissions
    ['no_permission'] = 'Vous n\'avez pas la permission',
    ['insufficient_rank'] = 'Grade insuffisant',
    
    -- Divers
    ['press_to_interact'] = 'Appuyez sur ~INPUT_CONTEXT~ pour interagir',
    ['cancelled'] = 'Annulé',
    ['confirm'] = 'Confirmer',
    ['cancel'] = 'Annuler',
    ['yes'] = 'Oui',
    ['no'] = 'Non',
    ['close'] = 'Fermer',
    ['back'] = 'Retour',
    ['submit'] = 'Valider'
}
