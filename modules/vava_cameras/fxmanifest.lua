--[[
    vava_cameras/fxmanifest.lua
    Rôle : caméras sur l'écran des joueurs, pour le Conseil. Le jeu du joueur filme l'image du jeu seule (ni Windows,
           ni Discord, ni les interfaces) et l'envoie en WebRTC direct à chaque membre qui le regarde : en jeu (mur des
           caméras, ouvert depuis le Registre ou par commande) ou depuis la Chancellerie (par son pont). Une seule
           capture par joueur, réduite pour les cases d'un mur, pleine pour une vue en grand. Le serveur ne relaie
           que la négociation ; il décide qui regarde qui, et l'inscrit au journal du Conseil.
    Dépendances : vAvA_core ≥ 0.5.0 ; facultatives : vava_admin ≥ 1.2.0 (droit « watch », journal, outil du
                  Registre), vava_chancellerie (caméras depuis le web)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_cameras'
description 'Caméras sur l\'écran des joueurs (Conseil) vAvA'
version '1.0.0'

dependency 'vAvA_core'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
    'web/img/*',
    'web/fonts/*.woff2',
}

shared_scripts {
    'shared/constants.lua',
    'config.lua',
}

server_scripts {
    'server/core.lua',
    'server/links.lua',
    'server/players.lua',
    'server/sessions.lua',
    'server/api.lua',
    'server/main.lua',
}

client_scripts {
    'client/core.lua',
    'client/nui.lua',
    'client/capture.lua',
    'client/wall.lua',
    'client/main.lua',
}
