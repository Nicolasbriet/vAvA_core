--[[
    vava_crafting/fxmanifest.lua
    Rôle : l'artisanat du royaume : stations (forge, établi, métier à tisser, alambic, tannerie, fourneau, table
           d'arcanes) publiques ou privées avec leur qualité et leur combustible, recettes à ingrédients par palier
           choisi, qualité d'une pièce (matériaux, niveau, station, aléa, plafonnée par le niveau), objets signés
           (qualité, solidité, créateur figé, poinçon, baptême d'un chef-d'œuvre, histoire), réparation qui marque
           l'objet, leçons données en réalisant une recette transmise devant un élève, commandes du Conseil. Le serveur
           décide de tout ; le client crée les props des stations, montre l'invite et le menu, joue le geste. Chaque
           station est une zone du core : seuls les joueurs proches la connaissent et reçoivent ses changements.
           T-132 : les joueurs ne téléchargent que les constantes, config_client.lua (nom d'un chef-d'œuvre, geste de
           réparation, interaction, streaming, touche, types de stations, animations) et la logique lue par le client
           (proximité, carnet des stations) ; config.lua et shared/quality.lua sont servis au seul serveur.
    Dépendances : vAvA_core ≥ 0.11.0 (abonnements de zone), vava_ui ≥ 1.0.0 (polices, grain, papier et coins de la page, par
                  nui://vava_ui/…), vava_inventory ≥ 1.4.0 (échange atomique, mains, métadonnées), vava_skills ≥ 1.0.0
                  (recettes, XP, leçons), vava_gathering ≥ 1.0.0 (matières et outils de base) ; facultatifs : vava_hud,
                  vava_admin (droit metiers), vava_chat, vava_health (aucun artisanat à terre)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_crafting'
description 'Artisanat vAvA : stations, recettes, qualité, objets signés, réparation, leçons'
version '1.6.0'

dependency 'vAvA_core'
dependency 'vava_ui'
dependency 'vava_inventory'
dependency 'vava_skills'
dependency 'vava_gathering'

vava_migration 'sql/0001_crafting.sql'

ui_page 'web/index.html'

-- polices, grain, papier et coins : vava_ui ; les données simulées hors jeu (dossier dev/) ne sont jamais livrées
files {
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
    'web/items/*.svg',
}

-- Ordre explicite : chaque fichier ne dépend que de ceux listés avant lui. Les joueurs ne téléchargent que les
-- shared_scripts et les client_scripts : config.lua, en tête des server_scripts, n'est jamais servi (T-132).
shared_scripts {
    'shared/constants.lua',
    'config_client.lua',         -- ouvre VavaCrafting.config : ce que lit le client
    'shared/proximity.lua',
    'shared/stationzone.lua',
}

server_scripts {
    'config.lua',                -- complète VavaCrafting.config : ce que lit le seul serveur
    'shared/quality.lua',        -- logique pure, servie au seul serveur (testée hors jeu : tests/spec)
    'server/core.lua',
    'bridge/server.lua',
    'server/journal.lua',
    'server/guard.lua',
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
