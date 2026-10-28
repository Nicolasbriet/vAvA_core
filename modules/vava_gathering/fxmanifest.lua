--[[
    vava_gathering/fxmanifest.lua
    Rôle : la récolte du royaume : zones à vitalité (plein rendement, réduit, épuisée avec props remplacés, cicatrice),
           nœuds à charges (arbres, filons, buissons, bancs de poissons, pistes de gibier), outils en main qui s'usent,
           qualité de la récolte (compétence, outil, vitalité) en palier et provenance sur les piles, pêche à la barre
           de tension, réaction de la terre, commandes du Conseil. Le serveur décide de tout (distance, outil,
           cooldown, durée, rendement, charges, vitalité) et appelle vava_skills pour l'XP ; le client crée les props à
           portée, montre l'invite, joue le geste et la barre de tension.
    Dépendances : vAvA_core ≥ 0.6.0, vava_inventory ≥ 1.4.0 (objets, mains, métadonnées), vava_skills ≥ 1.0.0 (XP) ;
                  facultatifs : vava_hud (barre de progression, notifications), vava_admin (droit metiers), vava_chat
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_gathering'
description 'Récolte vAvA : zones à vitalité, nœuds, outils en main, qualité, pêche, pistes de gibier'
version '1.0.0'

dependency 'vAvA_core'
dependency 'vava_inventory'
dependency 'vava_skills'

vava_migration 'sql/0001_gathering.sql'

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
    'shared/geometry.lua',
}

server_scripts {
    'server/core.lua',
    'bridge/server.lua',
    'server/journal.lua',
    'server/catalog.lua',
    'server/zones.lua',
    'server/nodes.lua',
    'server/quality.lua',
    'server/harvest.lua',
    'server/fishing.lua',
    'server/admin.lua',
    'server/api.lua',
    'server/main.lua',
}

client_scripts {
    'client/core.lua',
    'client/nui.lua',
    'client/props.lua',
    'client/interact.lua',
    'client/fishing.lua',
    'client/main.lua',
}
