--[[
    vava_chancellerie/fxmanifest.lua
    Rôle : pont entre la Chancellerie (panneau web, programme à part) et le serveur de jeu. Reçoit ses demandes par
           l'adresse HTTP du serveur (machine locale et clé tirée à chaque lancement seulement) et les fait exécuter
           par le Registre du Conseil (vava_admin), les zones de voix (vava_voice) et les caméras (vava_cameras) au
           nom du compte du panneau ; prévient la Chancellerie en direct (signalements, arrivées et départs, caméras).
           Relie un compte du panneau à son joueur (code tapé en jeu) et applique en jeu le rang du compte relié.
           Serveur seulement : le seul message aux joueurs est le résultat de leur liaison (affiché par vava_admin).
    Dépendances : vAvA_core ≥ 0.5.0, vava_admin ≥ 1.3.0 ; facultatives : vava_voice ≥ 1.1.0 (zones de voix),
                  vava_cameras ≥ 1.0.0 (écran des joueurs)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_chancellerie'
description 'Pont de la Chancellerie (panneau web) vAvA'
version '1.2.0'

dependencies { 'vAvA_core', 'vava_admin' }

shared_scripts {
    'shared/constants.lua',
    'config.lua',
}

server_scripts {
    'server/core.lua',
    'server/auth.lua',
    'server/push.lua',
    'server/link.lua',
    'server/routes.lua',
    'server/http.lua',
    'server/main.lua',
}
