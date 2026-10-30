--[[
    vava_characters_ui/fxmanifest.lua
    Rôle : écran de sélection et éditeur de création de personnage (NUI). Ressource cliente uniquement : chaque
           action est une intention envoyée au serveur via l'API du core et de vava_appearance.
    Dépendances : vAvA_core ≥ 0.3.0 (règles de nom du serveur : ≥ 0.8.0), vava_appearance, vava_ui ≥ 1.0.0 (polices,
                  grain et ornements de la page, par nui://vava_ui/…)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_characters_ui'
description 'Sélection et création de personnage vAvA'
version '1.1.0'

dependencies {
    'vAvA_core',
    'vava_ui',
    'vava_appearance',
}

ui_page 'web/index.html'

-- polices, grain et ornements : vava_ui (le blason reste ici) ; les données simulées hors jeu (dossier dev/) ne sont
-- jamais livrées
files {
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
    'web/img/*.svg',
}

client_scripts {
    'config.lua',
    'client/core.lua',
    'client/camera.lua',
    'client/preview.lua',
    'client/nui.lua',
    'client/main.lua',
}
