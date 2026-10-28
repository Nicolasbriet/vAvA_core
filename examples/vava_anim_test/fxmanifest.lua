--[[
    vava_anim_test/fxmanifest.lua
    Rôle : outil de TEST des animations personnalisées : les fichiers .ycd posés dans stream/ sont diffusés aux
           clients (le nom du fichier est le nom du dictionnaire) ; commandes /anim, /animstop, /animprop, /animflags
           et les raccourcis de la config (/epee) pour charger, trouver les clips, jouer, arrêter et juger la pose
           avec un accessoire en main. Déclarées au Codex quand vAvA_core est là.
           À ne pas déployer en production : aucun contrôle d'administration, tout joueur peut s'en servir.
    Dépendances : aucune (commandes côté client) ; facultatif : vAvA_core ≥ 0.7.0 pour le Codex
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vava_anim_test'
description 'Test des animations personnalisées vAvA (.ycd dans stream/)'
version '1.0.0'

shared_script 'config.lua'
server_script 'server/main.lua'
client_script 'client/main.lua'
