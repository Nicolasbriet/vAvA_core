--[[
    vava_example_items/fxmanifest.lua
    Rôle : objets d'exemple pour l'inventaire (nourriture, boissons, épée, bourse, corde) avec leurs icônes.
           Montre comment un module déclare des objets, sert leurs images et leur donne des effets.
    Dépendances : vAvA_core, vava_inventory
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vava_example_items'
description 'Objets d\'exemple vAvA'
version '1.1.0'

dependencies {
    'vAvA_core',
    'vava_inventory',
}

-- images lues par l'interface de l'inventaire (nui://vava_example_items/web/items/…)
files {
    'web/items/*.svg',
}

server_script 'server/main.lua'
