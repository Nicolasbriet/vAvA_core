fx_version 'cerulean'
game 'gta5'

author 'vAvA Development Team'
description 'vAvA Status System - Hunger & Thirst Management'
version '1.0.0'

shared_scripts {
    'config/config.lua',
    'shared/api.lua',
    '@vAvA_core/locales/locale.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}

dependencies {
    'vAvA_core',
    'oxmysql'
}

lua54 'yes'
