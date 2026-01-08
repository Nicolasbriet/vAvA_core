--[[
    vAvA_core - Traductions Français
]]

Locales = Locales or {}

Locales['fr'] = {
    -- ═══════════════════════════════════════════════════════════════════════
    -- GÉNÉRAL
    -- ═══════════════════════════════════════════════════════════════════════
    ['welcome'] = 'Bienvenue sur %s !',
    ['goodbye'] = 'À bientôt !',
    ['loading'] = 'Chargement...',
    ['error'] = 'Une erreur est survenue',
    ['success'] = 'Succès !',
    ['cancelled'] = 'Annulé',
    ['confirm'] = 'Confirmer',
    ['cancel'] = 'Annuler',
    ['yes'] = 'Oui',
    ['no'] = 'Non',
    ['close'] = 'Fermer',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- JOUEUR
    -- ═══════════════════════════════════════════════════════════════════════
    ['player_loaded'] = 'Données chargées avec succès',
    ['player_saved'] = 'Données sauvegardées',
    ['player_not_found'] = 'Joueur introuvable',
    ['character_created'] = 'Personnage créé avec succès',
    ['character_deleted'] = 'Personnage supprimé',
    ['character_select'] = 'Sélection du personnage',
    ['character_limit'] = 'Vous avez atteint la limite de personnages',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- ARGENT
    -- ═══════════════════════════════════════════════════════════════════════
    ['money_received'] = 'Vous avez reçu $%s',
    ['money_removed'] = 'Vous avez perdu $%s',
    ['money_set'] = 'Votre argent a été défini à $%s',
    ['money_not_enough'] = 'Vous n\'avez pas assez d\'argent',
    ['money_bank_received'] = 'Vous avez reçu $%s sur votre compte bancaire',
    ['money_bank_removed'] = '$%s ont été retirés de votre compte bancaire',
    ['money_cash'] = 'Liquide',
    ['money_bank'] = 'Banque',
    ['money_black'] = 'Argent sale',
    ['money_transfer'] = 'Transfert effectué',
    ['money_transfer_received'] = 'Vous avez reçu un transfert de $%s',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- JOB
    -- ═══════════════════════════════════════════════════════════════════════
    ['job_changed'] = 'Vous êtes maintenant %s (%s)',
    ['job_not_authorized'] = 'Vous n\'êtes pas autorisé à faire cela',
    ['job_on_duty'] = 'Vous êtes maintenant en service',
    ['job_off_duty'] = 'Vous n\'êtes plus en service',
    ['job_salary_received'] = 'Vous avez reçu votre salaire : $%s',
    ['job_hired'] = 'Vous avez été embauché comme %s',
    ['job_fired'] = 'Vous avez été licencié',
    ['job_promoted'] = 'Vous avez été promu à %s',
    ['job_demoted'] = 'Vous avez été rétrogradé à %s',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- INVENTAIRE
    -- ═══════════════════════════════════════════════════════════════════════
    ['inventory'] = 'Inventaire',
    ['inventory_full'] = 'Votre inventaire est plein',
    ['inventory_weight'] = 'Poids : %s / %s',
    ['item_received'] = 'Vous avez reçu %sx %s',
    ['item_removed'] = 'Vous avez perdu %sx %s',
    ['item_used'] = 'Vous avez utilisé %s',
    ['item_not_found'] = 'Item introuvable',
    ['item_not_enough'] = 'Vous n\'avez pas assez de %s',
    ['item_dropped'] = 'Vous avez jeté %sx %s',
    ['item_picked_up'] = 'Vous avez ramassé %sx %s',
    ['item_cannot_use'] = 'Vous ne pouvez pas utiliser cet item',
    ['item_give'] = 'Vous avez donné %sx %s',
    ['item_give_received'] = 'Vous avez reçu %sx %s de %s',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- STATUS
    -- ═══════════════════════════════════════════════════════════════════════
    ['status_hunger'] = 'Faim',
    ['status_thirst'] = 'Soif',
    ['status_stress'] = 'Stress',
    ['status_health'] = 'Santé',
    ['status_armor'] = 'Armure',
    ['status_hungry'] = 'Vous avez faim !',
    ['status_thirsty'] = 'Vous avez soif !',
    ['status_stressed'] = 'Vous êtes stressé !',
    ['status_dying'] = 'Vous êtes en train de mourir !',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- VÉHICULES
    -- ═══════════════════════════════════════════════════════════════════════
    ['vehicle'] = 'Véhicule',
    ['vehicle_spawned'] = 'Véhicule sorti du garage',
    ['vehicle_stored'] = 'Véhicule rangé',
    ['vehicle_not_owned'] = 'Ce véhicule ne vous appartient pas',
    ['vehicle_no_keys'] = 'Vous n\'avez pas les clés',
    ['vehicle_locked'] = 'Véhicule verrouillé',
    ['vehicle_unlocked'] = 'Véhicule déverrouillé',
    ['vehicle_impounded'] = 'Votre véhicule a été mis en fourrière',
    ['vehicle_insurance'] = 'Assurance véhicule',
    ['vehicle_no_insurance'] = 'Ce véhicule n\'est pas assuré',
    ['vehicle_repaired'] = 'Véhicule réparé',
    ['vehicle_no_garage'] = 'Aucun garage à proximité',
    ['vehicle_already_out'] = 'Ce véhicule est déjà sorti',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- ADMIN
    -- ═══════════════════════════════════════════════════════════════════════
    ['admin_no_permission'] = 'Vous n\'avez pas la permission',
    ['admin_player_teleported'] = 'Joueur téléporté',
    ['admin_player_healed'] = 'Joueur soigné',
    ['admin_player_revived'] = 'Joueur réanimé',
    ['admin_player_kicked'] = 'Joueur expulsé',
    ['admin_player_banned'] = 'Joueur banni',
    ['admin_player_unbanned'] = 'Joueur débanni',
    ['admin_money_given'] = 'Argent donné',
    ['admin_money_removed'] = 'Argent retiré',
    ['admin_item_given'] = 'Item donné',
    ['admin_item_removed'] = 'Item retiré',
    ['admin_job_set'] = 'Job défini',
    ['admin_vehicle_spawned'] = 'Véhicule spawn',
    ['admin_vehicle_deleted'] = 'Véhicule supprimé',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- SÉCURITÉ
    -- ═══════════════════════════════════════════════════════════════════════
    ['security_banned'] = 'Vous êtes banni de ce serveur',
    ['security_ban_reason'] = 'Raison : %s',
    ['security_ban_expire'] = 'Expire le : %s',
    ['security_ban_permanent'] = 'Ban permanent',
    ['security_kicked'] = 'Vous avez été expulsé',
    ['security_kick_reason'] = 'Raison : %s',
    ['security_rate_limit'] = 'Trop de requêtes, veuillez patienter',
    ['security_suspicious'] = 'Activité suspecte détectée',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- UI / NOTIFICATIONS
    -- ═══════════════════════════════════════════════════════════════════════
    ['notify_info'] = 'Information',
    ['notify_success'] = 'Succès',
    ['notify_warning'] = 'Attention',
    ['notify_error'] = 'Erreur',
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- COMMANDES
    -- ═══════════════════════════════════════════════════════════════════════
    ['cmd_help'] = 'Affiche l\'aide',
    ['cmd_me'] = 'Action RP',
    ['cmd_do'] = 'Description RP',
    ['cmd_ooc'] = 'Message hors-jeu'
}
