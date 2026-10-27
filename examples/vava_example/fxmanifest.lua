--[[
    vava_example/fxmanifest.lua
    Rôle : module minimal de démonstration (registre, hooks, RPC dans les deux sens, migration).
    À copier dans le dossier resources du serveur, puis : ensure vAvA_core, ensure vava_example.
    Dépendances : vAvA_core
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vava_example'
description "Module d'exemple vAvA"
version '1.1.0'

dependency 'vAvA_core'

-- Migrations appliquées par le core avant setup(), dans l'ordre de leur numéro.
vava_migration 'sql/0001_create_notes.sql'
vava_migration 'sql/0002_add_note_character.sql'

server_scripts {
    'config.lua',
    'server/main.lua',
}

client_script 'client/main.lua'
