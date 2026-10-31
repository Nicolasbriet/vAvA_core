--[[
    vava_dev_characters/fxmanifest.lua
    Rôle : outils de TEST : commandes /perso, /respawn, /objet, /besoins, /vie et /aterre.
    Jamais sur un serveur ouvert au public. Inoffensif par construction : sans `set vava_env dev`, le module refuse
    de démarrer et n'offre rien ; avec, chaque commande est réservée au droit `staff` de vava_admin ou à l'ACE
    `vava.dev`, et chaque changement est inscrit au journal du Registre (voir README.md).
    Dépendances : vAvA_core, vava_inventory, vava_needs, vava_health ; facultatif : vava_admin
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vava_dev_characters'
description 'Commandes de test des personnages vAvA (mode développement et Conseil seulement)'
version '1.4.0'

dependencies {
    'vAvA_core',
    'vava_inventory',
    'vava_needs',
    'vava_health',
}

-- config_client.lua : ce que lit le client ; config.lua, en tête des server_scripts, n'est jamais servi (T-132)
shared_script 'config_client.lua'
server_scripts {
    'config.lua',
    'shared/guard.lua',
    'server/main.lua',
}
client_script 'client/main.lua'
