--[[
    vava_health/fxmanifest.lua
    Rôle : santé des personnages : vie conservée, mise à terre décidée par le serveur, réanimation par un autre joueur,
           retour au lieu de soins, soins par objets, écran « à terre », API pour les autres modules.
    Dépendances : vAvA_core ≥ 0.4.0 (hook core:character:spawned) ; facultatives : vava_inventory (soins, objets
                  bloqués à terre), vava_needs (pas de faim à terre), vava_hud (jauge, notifications)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_health'
description 'Santé, mise à terre et réanimation vAvA'
version '1.1.4'

dependency 'vAvA_core'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
    'web/img/*',
    'web/fonts/*.woff2',
    'web/icons/*.svg',
}

shared_scripts {
    'shared/constants.lua',
    'config.lua',
    'shared/vitality.lua',
}

server_scripts {
    'server/core.lua',
    'server/state.lua',
    'server/life.lua',
    'server/assist.lua',
    'server/links.lua',
    'server/api.lua',
    'server/commands.lua',
    'server/main.lua',
}

client_scripts {
    'client/core.lua',
    'client/body.lua',
    'client/screen.lua',
    'client/hud.lua',
    'client/keys.lua',
    'client/main.lua',
}
