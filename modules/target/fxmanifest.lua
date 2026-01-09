fx_version 'cerulean'
game 'gta5'

author 'vAvA Team'
description 'vAvA Target - Système de ciblage 3D pour vAvA_core'
version '1.0.0'

-- Chargement des fichiers shared
shared_scripts {
    'shared/locale.lua',      -- Charger en premier
    'locales/*.lua',
    'config/*.lua',
    'shared/*.lua'
}

-- Chargement des fichiers client
client_scripts {
    'client/*.lua'
}

-- Chargement des fichiers serveur
server_scripts {
    'server/*.lua'
}

-- Interface NUI
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js'
}

-- Exports client
exports {
    'AddTargetEntity',
    'AddTargetModel',
    'AddTargetZone',
    'AddTargetBone',
    'RemoveTarget',
    'RemoveTargetModel',
    'RemoveTargetZone',
    'RemoveTargetBone',
    'DisableTarget',
    'IsTargetActive',
    'GetNearbyTargets'
}

-- Exports serveur
server_exports {
    'ValidateInteraction',
    'LogInteraction'
}
