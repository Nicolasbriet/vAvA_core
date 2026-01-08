--[[
    vAvA_inventory - Système d'inventaire complet
    Version: 1.0.0
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vAvA_inventory'
author 'vAvA'
description 'Système d\'inventaire moderne avec gestion des armes'
version '1.0.0'

dependencies {
    'vAvA_core'
}

shared_scripts {
    '@vAvA_core/config/config.lua',
    '@vAvA_core/shared/utils.lua',
    'config.lua',
    'shared/*.lua'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
    'html/img/**/*.png',
    'html/img/items/*.png'
}
