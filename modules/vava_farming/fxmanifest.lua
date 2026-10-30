--[[
    vava_farming/fxmanifest.lua
    Rôle : l'agriculture du royaume : parcelles communales ou privées à emplacements, croissance par stades calculée
           sur les dates (humidité qui baisse, pause à sec, flétrissement, mort ; saison de vava_time qui accélère ou
           ralentit la pousse et le dessèchement ; nuits de gel d'hiver qui tuent les plantes ni couvertes ni
           résistantes, annoncées sur la fiche des plantes ; couvrir en automne et en hiver, de déchets végétaux ou
           de compost), fertilité (coût par récolte, rotation, compost, jachère), qualité de
           la récolte (graine, compétence, régularité d'arrosage, fertilité) en palier,
           graines récupérées, seau rempli aux puits, grenier commun (conteneur de l'inventaire, ancré, dépôts et
           retraits journalés), composteur ajouté à l'artisanat, commandes du Conseil. Le serveur décide de tout et
           demande l'XP à vava_skills ; chaque parcelle est une zone du core, connue des seuls joueurs proches ; le client
           crée les props des plantes selon leur stade, montre l'invite et le menu, joue les gestes.
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
version '1.7.0'

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

-- Ordre explicite : chaque fichier ne dépend que de ceux listés avant lui.
shared_scripts {
    'shared/constants.lua',
    'config.lua',
    'shared/geometry.lua',
    'shared/parcelzone.lua',
    'shared/proximity.lua',
    'shared/growth.lua',
}

server_scripts {
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
