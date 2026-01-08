--[[
    vAvA_inventory - Système d'inventaire 
    Version: 2.0.0 - Items en BDD, sans threads
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vAvA_inventory'
author 'vAvA'
description 'Système d\'inventaire - Items en base de données'
version '2.0.0'

dependencies {
    'oxmysql'
}

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
    'html/img/items/*.png'
}
