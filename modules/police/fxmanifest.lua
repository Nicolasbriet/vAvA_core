--[[
    vAvA_police - Système de Police Complet
    Version: 1.0.0 - Module vAvA_core
    
    Fonctionnalités:
    - Service on/duty automatique
    - Menu interaction citoyen (fouille, menottes, amendes)
    - Gestion des casiers judiciaires
    - Système d'amendes et contraventions
    - Prison système avec temps de peine
    - Radar et contrôle de vitesse
    - Véhicules de police avec sirènes
    - Armurerie police avec grades
    - Vestiaire avec tenues par grade
    - Dossier médical suspect
    - Menu tablette (recherche plaques, personnes)
    - Confiscation d'armes/items
    - GPS collègues en service
    - Alarmes cambriolages
    - Système de backup/renfort
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vAvA_police'
author 'vAvA'
description 'Système de police complet avec tablette, amendes, prison et radar'
version '1.0.0'

dependencies {
    'vAvA_core',
    'oxmysql'
}

shared_scripts {
    'config.lua',
    'locales/*.lua'
}

client_scripts {
    'client/main.lua',
    'client/menu.lua',
    'client/tablet.lua',
    'client/radar.lua',
    'client/blips.lua',
    'client/interactions.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/database.lua',
    'server/prison.lua',
    'server/fines.lua',
    'server/dispatch.lua',
    'server/records.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
    'html/img/*.png'
}

-- Exports serveur
server_exports {
    'IsPoliceOnDuty',
    'GetOnDutyPolice',
    'SendPoliceAlert',
    'AddFine',
    'SendToPrison',
    'GetCriminalRecord',
    'AddCriminalRecord'
}

-- Exports client
client_exports {
    'IsHandcuffed',
    'OpenTablet',
    'GetNearbyPlayers'
}
