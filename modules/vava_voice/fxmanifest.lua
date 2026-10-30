--[[
    vava_voice/fxmanifest.lua
    Rôle : chat vocal de proximité, sur la voix intégrée à FiveM (Mumble de FXServer, son 3D du jeu) : quatre portées
           (Chuchoter, Parler, Crier, Déclamer) changées d'une touche, médaillon dans le HUD, cercle au sol au
           changement de portée, silence hors du jeu (sélection du personnage), portée réduite à terre, zones où la
           voix porte plus ou moins loin, créées en jeu par le Conseil.
    Dépendances : vAvA_core ≥ 0.5.0 ; vava_ui ≥ 1.0.0 (polices, grain, papier et coins de l'éditeur, par
                  nui://vava_ui/…) ; facultatives : vava_hud ≥ 1.2.0 (médaillon), vava_health (portée à terre),
                  vava_admin ≥ 1.1.0 (droits et outil « Zones de voix » du Registre, journal)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_voice'
description 'Chat vocal de proximité vAvA'
version '1.3.0'

dependency 'vAvA_core'
dependency 'vava_ui'

vava_migration 'sql/0001_voice_zones.sql'

ui_page 'web/index.html'

-- polices, grain, papier et coins : vava_ui ; les données simulées hors jeu (dossier dev/) ne sont jamais livrées
files {
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
    'web/icons/*.svg',
}

shared_scripts {
    'shared/constants.lua',
    'config.lua',
    'shared/label.lua',
}

server_scripts {
    'server/core.lua',
    'server/store.lua',
    'server/presence.lua',
    'server/links.lua',
    'server/zones.lua',
    'server/api.lua',
    'server/commands.lua',
    'server/main.lua',
}

client_scripts {
    'client/core.lua',
    'client/nui.lua',
    'client/hud.lua',
    'client/mumble.lua',
    'client/ring.lua',
    'client/zones.lua',
    'client/range.lua',
    'client/editor.lua',
    'client/main.lua',
}
