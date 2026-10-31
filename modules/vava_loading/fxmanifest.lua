--[[
    vava_loading/fxmanifest.lua
    Rôle : écran de chargement d'Eldoria (page loadscreen) : progression réelle sur six feux, puis passage sans écran
           noir à la sélection du personnage. Ressource cliente uniquement : aucun RPC, aucun évènement, aucune donnée.
    Dépendances : vAvA_core ≥ 0.13.0 (spawn.loadingScreen : le core lui laisse la fermeture de l'écran) ; facultatif :
                  vava_characters_ui ≥ 1.2.0 (hook vava_characters_ui:shown, export isShown). Démarre juste après
                  vava_ui. Polices embarquées (pas de vava_ui : la page s'affiche avant les autres ressources).
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_loading'
description "Écran de chargement d'Eldoria"
version '1.2.0'

dependency 'vAvA_core'

loadscreen 'web/index.html'
loadscreen_manual_shutdown 'yes'   -- fermé par client/main.lua quand la sélection est affichée
loadscreen_cursor 'yes'            -- souris : passer l'ouverture, musique, parallaxe

-- tout ce que la page charge ; web/dev/ (données simulées, essais) n'est jamais livré : aucun joker de dossier
files {
    'web/index.html',
    'web/css/style.css',
    'web/js/*.js',
    'web/fonts/*.woff2',
}

client_scripts {
    'shared/constants.lua',
    'config_client.lua',
    'client/core.lua',
    'client/main.lua',
}
