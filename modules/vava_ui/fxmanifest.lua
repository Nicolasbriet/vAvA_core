--[[
    vava_ui/fxmanifest.lua
    Rôle : polices, textures et ornements communs des interfaces vAvA, servis aux pages des autres ressources par
           nui://vava_ui/web/… (feuille web/css/vava_ui.css). Aucun script : rien à régler ni à exécuter.
    Dépendances : aucune. Démarre juste après vAvA_core ; les ressources à page déclarent `dependency 'vava_ui'`.
                  Ne jamais l'arrêter sur un serveur ouvert (FXServer arrêterait aussi ces ressources).
]]

fx_version 'cerulean'
game 'gta5'

name 'vava_ui'
description 'Polices, textures et ornements communs des interfaces vAvA'
version '1.0.0'

-- servis aux pages des autres ressources par nui://vava_ui/web/… ; outils hors jeu (dossier dev/) jamais livrés
files {
    'web/css/vava_ui.css',
    'web/fonts/*.woff2',
    'web/img/*.webp',
    'web/img/*.svg',
}
