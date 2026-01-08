--[[
    vAvA Core - Module Concessionnaire
    Système de vente de véhicules (voitures, bateaux, hélicoptères, avions)
    Version: 1.0.0
]]

fx_version 'cerulean'
game 'gta5'

name 'vAvA_core - Concessionnaire'
author 'vAvA Team'
description 'Module concessionnaire intégré au core vAvA'
version '1.0.0'

-- Dépendances
dependencies {
    'vAvA_core'
}

-- Fichiers partagés
shared_scripts {
    '@vAvA_core/shared/*.lua',
    '@vAvA_core/config/config.lua',
    'config.lua'
}

-- Scripts serveur
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

-- Scripts client
client_scripts {
    'client/main.lua'
}

-- Interface NUI
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    'html/img/**/*',
    'vehicles.json'
}

-- Exports client
exports {
    'OpenDealership',
    'CloseDealership',
    'IsNUIOpen'
}

-- Exports serveur
server_exports {
    'GetVehicles',
    'AddVehicle',
    'RemoveVehicle',
    'UpdateVehicle'
}

lua54 'yes'
