--[[
    vAvA_keys - Système de Gestion des Clés
    Version: 2.0.0 - Module vAvA_core
    Adapté de vAvA_keys standalone
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vAvA_keys'
author 'vAvA'
description 'Système de gestion des clés de véhicules - Verrouillage, partage, carjack'
version '2.1.0'

shared_scripts {
    'config.lua',
    'locales/*.lua'
}

client_scripts {
    'client/main.lua',
    'client/keys.lua',
    'client/engine.lua',
    'client/carjack.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/main.lua',
    'server/keys.lua',
    'server/share.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

-- Exports serveur
server_exports {
    'GiveKeys',
    'RemoveKeys',
    'HasKeys',
    'ShareKeys',
    'GetPlayerKeys'
}

-- Exports client
client_exports {
    'HasKeys',
    'ToggleLock',
    'ToggleEngine',
    'GetClosestVehicle'
}

dependencies {
    'oxmysql'
}
