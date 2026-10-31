--[[
    vava_time/fxmanifest.lua
    Rôle : le temps du royaume, le même pour tous les joueurs : heure de Paris (heure d'été comprise) au rythme réel,
           saisons de quatorze jours (ou vrai calendrier), ciel pondéré par saison avec transitions douces, aucune neige
           hors de l'hiver, nuits de gel en hiver (annoncées dès leur tirage : une ligne de /date). Le Conseil décale ou fige l'heure et impose ou fige un ciel, depuis
           l'outil « Ciel et heure » du Registre, /ciel ou la Chancellerie, avec un débit commun ; état gardé en base.
           Les saisons et le gel sont lus par l'agriculture et la récolte (export, hooks). Le serveur décide de tout et
           publie trois petites valeurs par GlobalState ; le client fait avancer l'horloge du jeu seul et suit les
           transitions du ciel.
           T-132 : les joueurs ne téléchargent que les constantes, config_client.lua (horloge, calendrier, ciels,
           commandes, textes), shared/calendar.lua et shared/weather.lua ; config.lua (décalage permis, nuits de gel,
           Conseil, débits) et shared/frost.lua sont servis au seul serveur.
    Dépendances : vAvA_core ≥ 0.7.0 ; vava_ui ≥ 1.0.0 (polices, grain et coins de la page, par nui://vava_ui/…) ;
                  facultatives : vava_admin (droits, outil du Registre, journal), vava_hud
                  (notifications), vava_chancellerie (actions depuis le web)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_time'
description 'Temps du royaume vAvA : heure de Paris, saisons, météo, ciel et heure du Conseil'
version '1.4.0'

dependency 'vAvA_core'
dependency 'vava_ui'

vava_migration 'sql/0001_time.sql'

ui_page 'web/index.html'

-- polices, grain et coins : vava_ui ; les données simulées hors jeu (dossier dev/) ne sont jamais livrées
files {
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
}

-- Ordre explicite : chaque fichier ne dépend que de ceux listés avant lui. Les joueurs ne téléchargent que les
-- shared_scripts et les client_scripts : config.lua, en tête des server_scripts, n'est jamais servi (T-132).
shared_scripts {
    'shared/constants.lua',
    'config_client.lua',         -- ouvre VavaTime.config : ce que lit le client
    'shared/calendar.lua',
    'shared/weather.lua',
}

server_scripts {
    'config.lua',                -- complète VavaTime.config : ce que lit le seul serveur
    'shared/frost.lua',          -- logique pure, servie au seul serveur (testée hors jeu : tests/spec)
    'server/core.lua',
    'bridge/server.lua',
    'server/store.lua',
    'server/clock.lua',
    'server/seasons.lua',
    'server/sky.lua',
    'server/frost.lua',
    'server/council.lua',
    'server/api.lua',
    'server/commands.lua',
    'server/main.lua',
}

client_scripts {
    'client/core.lua',
    'client/nui.lua',
    'client/world.lua',
    'client/tool.lua',
    'client/main.lua',
}
