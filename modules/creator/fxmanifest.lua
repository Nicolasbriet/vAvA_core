--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                                                                           ║
    ║   ██╗   ██╗ █████╗ ██╗   ██╗ █████╗      ██████╗ ██████╗ ██████╗ ███████╗ ║
    ║   ██║   ██║██╔══██╗██║   ██║██╔══██╗    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ║
    ║   ██║   ██║███████║██║   ██║███████║    ██║     ██║   ██║██████╔╝█████╗   ║
    ║   ╚██╗ ██╔╝██╔══██║╚██╗ ██╔╝██╔══██║    ██║     ██║   ██║██╔══██╗██╔══╝   ║
    ║    ╚████╔╝ ██║  ██║ ╚████╔╝ ██║  ██║    ╚██████╗╚██████╔╝██║  ██║███████╗ ║
    ║     ╚═══╝  ╚═╝  ╚═╝  ╚═══╝  ╚═╝  ╚═╝     ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝ ║
    ║                                                                           ║
    ║                   vAvA Creator - Character Creation System                ║
    ║                              Version 1.0.0                                ║
    ║                                                                           ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
]]--

fx_version 'cerulean'
game 'gta5'

name 'vava_creator'
author 'vAvA'
description 'Système complet de création de personnage pour vAvA_core'
version '1.0.0'
lua54 'yes'

dependencies {
    'vAvA_core'
}

shared_scripts {
    '@vAvA_core/shared/enums.lua',
    '@vAvA_core/shared/utils.lua',
    '@vAvA_core/shared/classes.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/shop.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/shop.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    'locales/*.lua'
}
