--[[
    vava_cameras/fxmanifest.lua
    Rôle : caméras sur l'écran des joueurs, pour le Conseil. Le jeu du joueur filme l'image du jeu seule (ni Windows,
           ni Discord, ni les interfaces) et l'envoie en WebRTC direct à chaque membre qui le regarde : en jeu (mur des
           caméras, ouvert depuis le Registre ou par commande) ou depuis la Chancellerie (par son pont). Une seule
           capture par joueur, réduite pour les cases d'un mur, pleine pour une vue en grand (une seule à la fois) ;
           débit montant total du joueur filmé borné et réparti entre ses spectateurs. Le serveur ne relaie que la
           négociation ; il décide qui regarde qui, et l'inscrit au journal du Conseil.
           T-132 : les joueurs ne téléchargent que les constantes et config_client.lua (qualités, spectateurs par
           joueur, taille d'une offre, commande et rythme du mur) ; config.lua et shared/budget.lua sont servis au
           seul serveur.
    Dépendances : vAvA_core ≥ 0.5.0 ; vava_ui ≥ 1.0.0 (polices, grain, coins et filet du mur, par nui://vava_ui/…) ;
                  facultatives : vava_admin ≥ 1.2.0 (droit « watch », journal, outil du
                  Registre), vava_chancellerie (caméras depuis le web)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_cameras'
description 'Caméras sur l\'écran des joueurs (Conseil) vAvA'
version '1.5.0'

dependency 'vAvA_core'
dependency 'vava_ui'

ui_page 'web/index.html'

-- polices, grain, coins et filet : vava_ui ; les données simulées hors jeu (dossier dev/) ne sont jamais livrées
files {
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
}

-- Les joueurs ne téléchargent que les shared_scripts et les client_scripts : config.lua, en tête des server_scripts,
-- n'est jamais servi (T-132).
shared_scripts {
    'shared/constants.lua',
    'config_client.lua',         -- ouvre VavaCameras.config : ce que lit le client
}

server_scripts {
    'config.lua',                -- complète VavaCameras.config : ce que lit le seul serveur
    'shared/budget.lua',
    'server/core.lua',
    'server/links.lua',
    'server/players.lua',
    'server/sessions.lua',
    'server/api.lua',
    'server/commands.lua',
    'server/main.lua',
}

client_scripts {
    'client/core.lua',
    'client/nui.lua',
    'client/capture.lua',
    'client/wall.lua',
    'client/main.lua',
}
