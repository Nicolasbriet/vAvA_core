fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'vAvA Core'
description 'Module de gestion des jobs avancé'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/interactions.lua',
    'client/menus.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/database.lua',
    'server/interactions.lua',
    'server/creator.lua',
    'test_improvements.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js'
}

dependencies {
    'vAvA_core',
    'oxmysql'
}
