--[[
    vava_time/fxmanifest.lua
    Rôle : le temps du royaume, le même pour tous les joueurs : heure de Paris (heure d'été comprise) au rythme réel,
           saisons de quatorze jours (ou vrai calendrier), ciel pondéré par saison avec transitions douces, aucune neige
           hors de l'hiver, nuits de gel en hiver. Le Conseil décale ou fige l'heure et impose ou fige un ciel, depuis
           l'outil « Ciel et heure » du Registre, /ciel ou la Chancellerie, avec un débit commun ; état gardé en base.
           Les saisons et le gel sont lus par l'agriculture et la récolte (export, hooks). Le serveur décide de tout et
           publie trois petites valeurs par GlobalState ; le client fait avancer l'horloge du jeu seul et suit les
           transitions du ciel.
    Dépendances : vAvA_core ≥ 0.7.0 ; facultatives : vava_admin (droits, outil du Registre, journal), vava_hud
                  (notifications), vava_chancellerie (actions depuis le web)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_time'
description 'Temps du royaume vAvA : heure de Paris, saisons, météo, ciel et heure du Conseil'
version '1.0.0'

dependency 'vAvA_core'

vava_migration 'sql/0001_time.sql'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
    'web/img/*',
    'web/fonts/*.woff2',
}

-- Ordre explicite : chaque fichier ne dépend que de ceux listés avant lui.
shared_scripts {
    'shared/constants.lua',
    'config.lua',
    'shared/calendar.lua',
    'shared/weather.lua',
    'shared/frost.lua',
}

server_scripts {
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
