--[[
    vava_combat/fxmanifest.lua
    Rôle : combat de corps à corps d'Eldoria : armes, usure, bouclier accroché, techniques jugées par le serveur (voir
           README.md). Aucune NUI, aucune table SQL.
    Dépendances : vAvA_core ≥ 0.10.0, vava_inventory ≥ 1.7.0, vava_health ≥ 1.3.0 ; facultatifs : voir README.md
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_combat'
description 'Combat vAvA : armes de corps à corps, techniques, usure, bouclier accroché'
version '1.2.0'

dependency 'vAvA_core'
dependency 'vava_inventory'
dependency 'vava_health'

files {
    'web/items/*.svg',
}

-- Ordre explicite. Les joueurs ne téléchargent que shared_scripts et client_scripts (T-132).
shared_scripts {
    'shared/constants.lua',
    'config_client.lua',
    'shared/shield.lua',
    'shared/heading.lua',
    'shared/techniques.lua',
}

server_scripts {
    'config.lua',                -- complète VavaCombat.config : ce que lit le seul serveur
    -- logique pure servie au seul serveur
    'shared/geometry.lua',
    'shared/admission.lua',
    'shared/weapons.lua',
    'shared/guard.lua',
    'server/core.lua',
    'bridge/server.lua',
    'server/catalog.lua',
    'server/pedstate.lua',
    'server/wear.lua',
    'server/shields.lua',
    'server/strike.lua',
    'server/hands.lua',
    'server/reactions.lua',
    'server/swings.lua',
    'server/api.lua',
    'server/commands.lua',
    'server/main.lua',
}

client_scripts {
    'client/core.lua',
    'bridge/client.lua',
    'client/natives.lua',
    'client/shields.lua',
    'client/hands.lua',
    'client/keys.lua',
    'client/targeting.lua',
    'client/attack.lua',
    'client/mode.lua',
    'client/reactions.lua',
    'client/main.lua',
}
