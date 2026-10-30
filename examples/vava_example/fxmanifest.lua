--[[
    vava_example/fxmanifest.lua
    Rôle : module minimal de démonstration (registre, hooks, RPC dans les deux sens, migration).
    Jamais sur un serveur ouvert au public : sans `set vava_env dev`, le module refuse de démarrer (seule sa table
    vide est créée par la migration) ; avec, /note est réservé au droit `staff` de vava_admin ou à l'ACE `vava.dev`,
    plafonné par personnage et purgé au démarrage (voir README.md).
    Dépendances : vAvA_core ; facultatif : vava_admin
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vava_example'
description "Module d'exemple vAvA (mode développement seulement)"
version '1.2.0'

dependency 'vAvA_core'

-- Migrations appliquées par le core avant setup(), dans l'ordre de leur numéro.
vava_migration 'sql/0001_create_notes.sql'
vava_migration 'sql/0002_add_note_character.sql'

server_scripts {
    'config.lua',
    'shared/guard.lua',
    'shared/limits.lua',
    'server/main.lua',
}

client_script 'client/main.lua'
