--[[
    vava_hud/fxmanifest.lua
    Rôle : affichage en jeu : retire l'interface native de GTA (minimap, HUD, notifications) et la remplace par des
           jauges (santé, faim, soif…) et des notifications que les autres modules utilisent par exports.
           Ressource cliente uniquement.
    Dépendances : vAvA_core ≥ 0.3.0 (hooks client du personnage)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_hud'
description 'Affichage en jeu vAvA (jauges, notifications)'
version '1.2.0'

dependency 'vAvA_core'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
    'web/img/*',
    'web/fonts/*.woff2',
}

client_scripts {
    'config.lua',
    'client/core.lua',
    'client/nui.lua',
    'client/gauges.lua',
    'client/native.lua',
    'client/notify.lua',
    'client/main.lua',
}
