--[[
    vava_anim_test/fxmanifest.lua
    Rôle : outil de TEST des animations personnalisées : les fichiers .ycd posés dans stream/ sont diffusés aux
           clients (le nom du fichier est le nom du dictionnaire) ; commandes /anim, /animstop, /animprop, /animflags
           et les raccourcis de la config (/epee) pour charger, trouver les clips, jouer, arrêter et juger la pose
           avec un accessoire en main.
           Jamais sur un serveur ouvert au public (le .ycd est téléchargé par chaque joueur tant qu'elle tourne).
           Inoffensif par construction : sans `set vava_env dev`, aucune commande ne répond ; avec, elles sont
           réservées au droit `staff` de vava_admin ou à l'ACE `vava.dev`, et n'apparaissent qu'au Codex du Conseil.
    Dépendances : vAvA_core ≥ 0.7.0 ; facultatif : vava_admin
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vava_anim_test'
description 'Test des animations personnalisées vAvA (.ycd dans stream/, mode développement et Conseil seulement)'
version '1.2.0'

dependency 'vAvA_core'

-- config.lua n'est jamais servi aux joueurs (T-132)
shared_script 'config_client.lua'
server_scripts {
    'config.lua',
    'shared/guard.lua',
    'server/main.lua',
}
client_script 'client/main.lua'
