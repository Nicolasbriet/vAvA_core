--[[
    vAvA_testbench - Module de test complet et adaptatif
    Version: 1.0.0
    Auteur: vAvA
    Description: Environnement de test automatique pour vAvA_core
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vAvA_testbench'
author 'vAvA'
description 'Module de test automatique, adaptatif et complet pour vAvA_core'
version '1.0.0'

-- ⚠️ MODULE DE DÉVELOPPEMENT UNIQUEMENT - NE PAS UTILISER EN PRODUCTION ⚠️

dependencies {
    'vAvA_core',
    'oxmysql'
}

shared_scripts {
    'config/config.lua'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/scanner.lua',
    'server/runner.lua',
    'server/logger.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/css/*.css',
    'ui/js/*.js',
    'ui/assets/**/*'
}
