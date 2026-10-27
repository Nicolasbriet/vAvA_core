--[[
    vava_characters_ui/fxmanifest.lua
    Rôle : écran de sélection et éditeur de création de personnage (NUI). Ressource cliente uniquement : chaque
           action est une intention envoyée au serveur via l'API du core et de vava_appearance.
    Dépendances : vAvA_core ≥ 0.3.0, vava_appearance
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_characters_ui'
description 'Sélection et création de personnage vAvA'
version '1.0.0'

dependencies {
    'vAvA_core',
    'vava_appearance',
}

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
    'client/camera.lua',
    'client/preview.lua',
    'client/nui.lua',
    'client/main.lua',
}
