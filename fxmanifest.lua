--[[
    vAvA_core - Framework FiveM modulaire, sécurisé et multilingue
    Version: 1.0.0
    Auteur: vAvA
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vAvA_core'
author 'vAvA'
description 'Framework FiveM modulaire, sécurisé et multilingue'
version '1.0.0'

-- Dépendances
dependencies {
    'oxmysql'
}

-- Fichiers partagés
shared_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config/config.lua',
    'locales/*.lua',
    'shared/enums.lua',
    'shared/utils.lua',
    'shared/classes.lua'
}

-- Fichiers serveur
server_scripts {
    'database/dal.lua',
    'database/cache.lua',
    'database/migrations.lua',
    'database/auto_update.lua',
    'server/main.lua',
    'server/callbacks.lua',
    'server/players.lua',
    'server/economy.lua',
    'server/jobs.lua',
    'server/inventory.lua',
    'server/vehicles.lua',
    'server/security.lua',
    'server/logs.lua',
    'server/bans.lua',
    'server/commands.lua'
}

-- Fichiers client
client_scripts {
    'client/main.lua',
    'client/callbacks.lua',
    'client/player.lua',
    'client/hud.lua',
    'client/status.lua',
    'client/vehicles.lua',
    'client/notifications.lua'
}

-- Fichiers UI
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js'
}

-- Exports serveur
server_exports {
    -- Players
    'GetPlayer',
    'GetPlayers',
    'GetPlayerByIdentifier',
    
    -- Economy
    'AddMoney',
    'RemoveMoney',
    'SetMoney',
    'GetMoney',
    
    -- Jobs
    'GetJob',
    'SetJob',
    'GetJobGrade',
    
    -- Inventory
    'AddItem',
    'RemoveItem',
    'GetItem',
    'HasItem',
    'GetInventory',
    
    -- Vehicles
    'GetPlayerVehicles',
    'GiveVehicle',
    
    -- Security
    'BanPlayer',
    'UnbanPlayer',
    'IsPlayerBanned',
    
    -- Utils
    'Log'
}

-- Exports client
client_exports {
    'GetPlayerData',
    'Notify',
    'ShowHUD',
    'HideHUD'
}
