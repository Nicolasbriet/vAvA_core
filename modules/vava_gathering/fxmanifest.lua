--[[
    vava_gathering/fxmanifest.lua
    Rôle : la récolte du royaume (zones à vitalité, points à charges, outils en main, qualité, pêche), gardée par
           l'Atelier (atelier « Récolte »). Détail : README.
    Dépendances : vAvA_core ≥ 0.11.0, vava_ui ≥ 1.0.0, vava_inventory ≥ 1.4.0, vava_skills ≥ 1.0.0 ; facultatifs :
                  vava_atelier, vava_hud, vava_admin, vava_chat, vava_health, vava_time
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_gathering'
description 'Récolte vAvA : zones à vitalité sur la carte, nœuds, outils en main, qualité, pêche, pistes de gibier'
version '1.8.0'

dependency 'vAvA_core'
dependency 'vava_ui'
dependency 'vava_inventory'
dependency 'vava_skills'

vava_migration 'sql/0001_gathering.sql'

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
    'config_client.lua',         -- ouvre VavaGathering.config : ce que lit le client
    'shared/geometry.lua',
    'shared/proximity.lua',
    'shared/zonestate.lua',
}

server_scripts {
    'config.lua',                -- complète VavaGathering.config : ce que lit le seul serveur
    'shared/season.lua',         -- logique pure, servie au seul serveur (testée hors jeu : tests/spec)
    'shared/catch.lua',          -- idem
    'shared/zonebuild.lua',      -- idem : état d'une zone construit par le serveur (shared/zonestate.lua : sa lecture)
    'shared/editing.lua',        -- idem : atelier « Récolte » (formulaires, conversions, règles, liste de la carte)
    'server/core.lua',
    'bridge/server.lua',
    'server/journal.lua',
    'server/catalog.lua',
    'server/share.lua',
    'server/zones.lua',
    'server/nodes.lua',
    'server/trials.lua',
    'server/quality.lua',
    'server/harvest.lua',
    'server/fishing.lua',
    'server/admin.lua',
    'server/map.lua',
    'server/atelier.lua',
    'server/api.lua',
    'server/commands.lua',
    'server/main.lua',
}

client_scripts {
    'client/core.lua',
    'client/nui.lua',
    'client/props.lua',
    'client/blips.lua',
    'client/interact.lua',
    'client/fishing.lua',
    'client/main.lua',
}
