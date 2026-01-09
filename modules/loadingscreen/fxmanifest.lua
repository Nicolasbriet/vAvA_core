--[[
    vava_loadingscreen - Écran de chargement immersif
    Version: 1.0.0
    Auteur: Briet
    Framework: vAvA_core
]]

fx_version 'cerulean'
game 'gta5'

name 'vava_loadingscreen'
description 'Écran de chargement immersif avec image de fond pour vAvA_core'
author 'Briet'
version '1.0.0'

-- Configuration du loadscreen
loadscreen 'ui/index.html'
loadscreen_manual_shutdown 'yes'
loadscreen_cursor 'yes'

-- Fichiers partagés
shared_scripts {
    '@vAvA_core/config/config.lua',
    'config.lua',
    'locales/*.lua'
}

-- Fichiers client
client_scripts {
    'client/main.lua'
}

-- Fichiers UI
files {
    'ui/index.html',
    'ui/style.css',
    'ui/app.js',
    'ui/assets/*.png',
    'ui/assets/*.jpg',
    'ui/assets/*.webp',
    'ui/assets/*.mp3',
    'ui/assets/*.ogg'
}

-- Dépendances
dependencies {
    'vAvA_core'
}

lua54 'yes'
