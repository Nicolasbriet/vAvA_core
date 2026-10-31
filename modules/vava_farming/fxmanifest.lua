--[[
    vava_farming/fxmanifest.lua
    Rôle : l'agriculture du royaume : parcelles communales ou privées à emplacements, croissance par stades calculée
           sur les dates (humidité qui baisse, pause à sec, flétrissement, mort ; saison de vava_time qui accélère ou
           ralentit la pousse et le dessèchement ; nuits de gel d'hiver qui tuent les plantes ni couvertes ni
           résistantes, annoncées sur la fiche des plantes ; couvrir en automne et en hiver, de déchets végétaux ou
           de compost), fertilité (coût par récolte, rotation, compost, jachère), qualité de
           la récolte (graine, compétence, régularité d'arrosage, fertilité) en palier,
           graines récupérées, seau rempli aux puits, grenier commun (conteneur de l'inventaire, ancré, dépôts et
           retraits journalés), composteur ajouté à l'artisanat et sa recette aux compétences (T-136), commandes du
           Conseil. Le serveur décide de tout et demande l'XP à vava_skills ; chaque parcelle est une zone du core,
           connue des seuls joueurs proches ; le client crée les props des plantes selon leur stade, montre l'invite et le menu, joue les gestes.
           T-132 : les joueurs ne téléchargent que les constantes, config_client.lua (gestes, streaming, touche,
           cultures, puits, animations) et la logique lue par le client (géométrie, parcelles, proximité) ;
           config.lua et shared/growth.lua sont servis au seul serveur.
    Dépendances : vAvA_core ≥ 0.11.0 (abonnements de zone), vava_ui ≥ 1.0.0 (polices, grain, papier et coins de la
                  page, par nui://vava_ui/…), vava_inventory ≥ 1.4.0, vava_skills ≥ 1.0.0, vava_gathering ≥ 1.0.0 (faucille),
                  vava_crafting ≥ 1.1.0 (composteur) ; facultatifs : vava_hud, vava_admin (droit metiers), vava_chat,
                  vava_health (aucun geste à terre), vava_time (saisons, nuits de gel)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_farming'
description 'Agriculture vAvA : parcelles, croissance par dates, humidité et fertilité, qualité, grenier commun'
version '1.9.0'

dependency 'vAvA_core'
dependency 'vava_ui'
dependency 'vava_inventory'
dependency 'vava_skills'
dependency 'vava_gathering'
dependency 'vava_crafting'

vava_migration 'sql/0001_farming.sql'
vava_migration 'sql/0002_granary_log_minute.sql'
vava_migration 'sql/0003_slot_cover.sql'

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
    'config_client.lua',         -- ouvre VavaFarming.config : ce que lit le client
    'shared/geometry.lua',
    'shared/parcelzone.lua',
    'shared/proximity.lua',
}

server_scripts {
    'config.lua',                -- complète VavaFarming.config : ce que lit le seul serveur
    'shared/growth.lua',         -- logique pure, servie au seul serveur (testée hors jeu : tests/spec)
    'server/core.lua',
    'bridge/server.lua',
    'server/journal.lua',
    'server/catalog.lua',
    'server/zones.lua',
    'server/slots.lua',
    'server/frost.lua',
    'server/granary.lua',
    'server/actions.lua',
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
