--[[
    vAvA_keys - Locales Français
    Traductions françaises pour le module keys
]]

Locale = Locale or {}

Locale['fr'] = {
    -- Messages de notification
    ['vehicle_locked'] = 'Véhicule ~r~verrouillé~s~',
    ['vehicle_unlocked'] = 'Véhicule ~g~déverrouillé~s~',
    ['engine_on'] = 'Moteur ~g~démarré~s~',
    ['engine_off'] = 'Moteur ~r~éteint~s~',
    ['no_keys'] = 'Vous n\'avez pas les clés de ce véhicule',
    ['no_vehicle_nearby'] = 'Aucun véhicule à proximité',
    ['keys_received'] = 'Vous avez reçu les clés du véhicule',
    ['keys_given'] = 'Vous avez donné les clés du véhicule',
    ['keys_removed'] = 'Les clés ont été retirées',
    ['already_has_keys'] = 'Cette personne a déjà les clés',
    ['player_not_found'] = 'Joueur introuvable',
    ['carjack_success'] = 'Crochetage ~g~réussi~s~',
    ['carjack_failed'] = 'Crochetage ~r~échoué~s~',
    ['carjacking'] = 'Crochetage en cours...',
    
    -- Interface ox_lib
    ['give_keys_title'] = 'Donner les clés',
    ['give_keys_desc'] = 'Sélectionnez un joueur à proximité',
    ['player_id'] = 'ID Joueur',
    ['confirm'] = 'Confirmer',
    ['cancel'] = 'Annuler',
    
    -- Commandes
    ['command_givekeys'] = 'Donner les clés d\'un véhicule',
    ['command_removekeys'] = 'Retirer les clés d\'un véhicule',
}
