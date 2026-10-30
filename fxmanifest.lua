--[[
    fxmanifest.lua
    Rôle : déclaration de la ressource vAvA_core, de ses migrations et ordre de chargement explicite de chaque fichier.
    Dépendances : oxmysql. OneSync obligatoire (positions lues côté serveur).
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
-- Appels de natives plus rapides (Lua FXv2) : utile pour les natives appelées à chaque requête (GetGameTimer…).
use_experimental_fxv2_oal 'yes'

name 'vAvA_core'
description 'Core RP médiéval vAvA - fondations, joueurs et personnages'
version '0.13.1'

dependency 'oxmysql'

-- Migrations du core, appliquées au démarrage dans l'ordre de leur numéro.
vava_migration 'server/migrations/0001_accounts.sql'
vava_migration 'server/migrations/0002_characters.sql'
vava_migration 'server/migrations/0003_play_seconds.sql'

-- Ordre explicite (pas de glob) : chaque fichier dépend uniquement de ceux listés avant lui.
shared_scripts {
    'shared/init.lua',
    'config/shared.lua',
    'shared/lib/table.lua',
    'shared/lib/string.lua',
    'shared/lib/semver.lua',
    'shared/lib/schema.lua',
    'shared/lib/pending.lua',
    'shared/lib/zonereplica.lua',
    'shared/core/logger.lua',
    'shared/core/hooks.lua',
    'shared/core/api.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config/server.lua',
    'server/core/database.lua',
    'server/core/migrations.lua',
    'server/core/ratelimit.lua',
    'server/core/netsize.lua',
    'server/core/netstats.lua',
    'server/core/net.lua',
    'server/core/rpc.lua',
    'server/core/zonegrid.lua',
    'server/core/zonestate.lua',
    'server/core/zones.lua',
    'server/core/registry.lua',
    'server/core/commands.lua',
    'server/core/netcommand.lua',
    'server/core/modules.lua',
    'server/core/api.lua',
    'server/players/accounts.lua',
    'server/players/fields.lua',
    'server/players/sync.lua',
    'server/players/persistence.lua',
    'server/players/playtime.lua',
    'server/players/positions.lua',
    'server/players/spawn.lua',
    'server/players/characters.lua',
    'server/players/api.lua',
    'server/init.lua',
}

client_scripts {
    'client/core/rpc.lua',
    'client/core/net.lua',
    'client/core/zones.lua',
    'client/core/api.lua',
    'client/players/session.lua',
    'client/players/spawn.lua',
    'client/players/api.lua',
    'client/init.lua',
}
