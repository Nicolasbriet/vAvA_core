--[[
    vava_inventory/fxmanifest.lua
    Rôle : inventaire en grille : objets déclarés par les modules, conteneurs (personnage, sacs au sol, coffres créés
           par d'autres modules, ancrés à un lieu), opérations validées par le serveur, poids, métadonnées par pile
           (empilement par égalité, retraits ciblés, écriture partielle), raccourcis, interface glisser-déposer,
           catalogue de développement (désactivé par défaut).
    Dépendances : vAvA_core ≥ 0.3.0, OneSync (sacs au sol en entités réseau, distances lues côté serveur)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_inventory'
description 'Inventaire en grille vAvA'
version '1.6.1'

dependency 'vAvA_core'

vava_migration 'sql/0001_containers.sql'
vava_migration 'sql/0002_items.sql'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
    'web/img/*',
    'web/fonts/*.woff2',
}

shared_scripts {
    'shared/constants.lua',
    'config.lua',
    'shared/grid.lua',
}

server_scripts {
    'server/core.lua',
    'server/positions.lua',
    'server/items.lua',
    'server/persistence.lua',
    'server/containers.lua',
    'server/viewers.lua',
    'server/drops.lua',
    'server/hands.lua',
    'server/operations.lua',
    'server/catalog.lua',
    'server/characters.lua',
    'server/api.lua',
    'server/commands.lua',
    'server/main.lua',
}

client_scripts {
    'client/core.lua',
    'client/drops.lua',
    'client/hands.lua',
    'client/nui.lua',
    'client/main.lua',
}
