--[[
    vava_dev_characters/fxmanifest.lua
    Rôle : outils de TEST : commandes /perso, /respawn, /objet, /besoins, /vie et /aterre.
    À ne pas déployer en production : aucun contrôle d'administration.
    Dépendances : vAvA_core, vava_inventory, vava_needs, vava_health
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vava_dev_characters'
description 'Commandes de test des personnages vAvA'
version '1.2.0'

dependencies {
    'vAvA_core',
    'vava_inventory',
    'vava_needs',
    'vava_health',
}

shared_script 'config.lua'
server_script 'server/main.lua'
client_script 'client/main.lua'
