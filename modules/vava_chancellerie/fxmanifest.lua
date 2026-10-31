--[[
    vava_chancellerie/fxmanifest.lua
    Rôle : pont entre la Chancellerie (panneau web, programme à part) et le serveur de jeu. Reçoit ses demandes par
           l'adresse HTTP du serveur (machine locale et clé tirée à chaque lancement seulement, donnée par la console
           du serveur et gardée en mémoire, jamais sur la ligne de commande) et les fait exécuter
           par le Registre du Conseil (vava_admin), les zones de voix (vava_voice), les caméras (vava_cameras) et le
           ciel et l'heure (vava_time) au nom du compte du panneau ; lit le compteur réseau du core (page Réseau,
           lecture seule) ; prévient la Chancellerie en direct (signalements,
           arrivées et départs, caméras).
           Relie un compte du panneau à son joueur (code tapé en jeu) et applique en jeu le rang du compte relié,
           seulement à un compte vu relié en jeu ; liste blanche Discord à la connexion des joueurs.
           Serveur seulement : le seul message aux joueurs est le résultat de leur liaison (affiché par vava_admin).
    Dépendances : vAvA_core ≥ 0.5.0, vava_admin ≥ 1.3.0 ; facultatives : vava_voice ≥ 1.1.0 (zones de voix),
                  vava_cameras ≥ 1.3.0 (écran des joueurs), vava_time ≥ 1.0.0 (ciel et heure) ;
                  vAvA_core ≥ 0.12.0 pour la page Réseau (core.net, joueurs suivis d'office)
    T-132 : aucun fichier servi aux joueurs (ni shared_scripts, ni client_scripts) : constantes, config et logique
            pure sont en server_scripts.
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_chancellerie'
description 'Pont de la Chancellerie (panneau web) vAvA'
version '1.7.1'

dependencies { 'vAvA_core', 'vava_admin' }

vava_migration 'sql/0001_chancellerie.sql'

-- Serveur seulement : le pont n'a pas de partie client, les joueurs ne téléchargent rien de cette ressource (T-132).
server_scripts {
    'shared/constants.lua',
    'config.lua',
    'shared/rules.lua',          -- logique pure (tests/spec), servie au seul serveur
    'server/core.lua',
    'server/auth.lua',
    'server/push.lua',
    'server/links.lua',
    'server/link.lua',
    'server/whitelist.lua',
    'server/routes.lua',
    'server/time.lua',
    'server/network.lua',
    'server/http.lua',
    'server/commands.lua',
    'server/main.lua',
}
