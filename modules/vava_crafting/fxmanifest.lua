--[[
    vava_crafting/fxmanifest.lua
    Rôle : l'artisanat du royaume : stations (forge, établi, métier à tisser, alambic, tannerie, fourneau, table
           d'arcanes) publiques ou privées avec leur qualité et leur combustible, recettes à ingrédients par palier
           choisi, qualité d'une pièce (matériaux, niveau, station, aléa, plafonnée par le niveau), objets signés
           (qualité, solidité, créateur figé, poinçon, baptême d'un chef-d'œuvre, histoire), réparation qui marque
           l'objet, leçons données en réalisant une recette transmise devant un élève, commandes du Conseil. Le serveur
           décide de tout ; le client crée les props des stations, montre l'invite et le menu, joue le geste.
    Dépendances : vAvA_core ≥ 0.6.0, vava_inventory ≥ 1.4.0 (échange atomique, mains, métadonnées), vava_skills ≥ 1.0.0
                  (recettes, XP, leçons), vava_gathering ≥ 1.0.0 (matières et outils de base) ; facultatifs : vava_hud,
                  vava_admin (droit metiers), vava_chat
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_crafting'
description 'Artisanat vAvA : stations, recettes, qualité, objets signés, réparation, leçons'
version '1.2.0'

dependency 'vAvA_core'
dependency 'vava_inventory'
dependency 'vava_skills'
dependency 'vava_gathering'

vava_migration 'sql/0001_crafting.sql'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
    'web/img/*',
    'web/items/*.svg',
    'web/fonts/*.woff2',
}

-- Ordre explicite : chaque fichier ne dépend que de ceux listés avant lui.
shared_scripts {
    'shared/constants.lua',
    'config.lua',
    'shared/quality.lua',
}

server_scripts {
    'server/core.lua',
    'bridge/server.lua',
    'server/journal.lua',
    'server/catalog.lua',
    'server/stations.lua',
    'server/signature.lua',
    'server/crafting.lua',
    'server/repair.lua',
    'server/admin.lua',
    'server/api.lua',
    'server/commands.lua',
    'server/main.lua',
}

client_scripts {
    'client/core.lua',
    'client/nui.lua',
    'client/props.lua',
    'client/interact.lua',
    'client/main.lua',
}
