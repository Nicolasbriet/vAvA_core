--[[
    vava_hud/fxmanifest.lua
    Rôle : affichage en jeu : retire l'interface native de GTA (minimap, HUD, notifications) et la remplace par des
           jauges (santé, faim, soif…), des notifications et une barre de progression des actions longues que les
           autres modules utilisent par exports. Ressource cliente uniquement.
    Dépendances : vAvA_core ≥ 0.3.0 (hooks client du personnage) ; vava_ui ≥ 1.0.0 (polices et grain de la page, par
                  nui://vava_ui/…)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_hud'
description 'Affichage en jeu vAvA (jauges, notifications, progression)'
version '1.5.0'

dependency 'vAvA_core'
dependency 'vava_ui'

ui_page 'web/index.html'

-- polices et grain : vava_ui ; les données simulées hors jeu (dossier dev/) ne sont jamais livrées
files {
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
}

client_scripts {
    'config_client.lua',
    'client/core.lua',
    'client/nui.lua',
    'client/gauges.lua',
    'client/native.lua',
    'client/notify.lua',
    'client/progress.lua',
    'client/main.lua',
}
