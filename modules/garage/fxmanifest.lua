--[[
    vAvA Core - Module Garage
    Système de garage et fourrière
    Version: 1.1.1
]]

fx_version 'cerulean'
game 'gta5'

name 'vAvA_core - Garage'
author 'vAvA Team'
description 'Module garage et fourrière intégré au core vAvA'
version '1.1.1'

-- Dépendances
dependencies {
    'vAvA_core'
}

-- Fichiers partagés
shared_scripts {
    '@vAvA_core/shared/enums.lua',
    '@vAvA_core/shared/utils.lua',
    '@vAvA_core/shared/classes.lua',
    '@vAvA_core/config/config.lua',
    'config.lua',
    'locales/*.lua'
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
    'garages.json'
}

-- Exports client
exports {
    'OpenGarage',
    'OpenImpound',
    'StoreVehicle',
    'SpawnVehicle'
}

-- Exports serveur
server_exports {
    'GetPlayerVehicles',
    'ImpoundVehicle',
    'ReleaseFromImpound',
    'GetGarages',
    'AddGarage'
}

lua54 'yes'
