--[[
    vava_appearance/fxmanifest.lua
    Rôle : apparence des personnages (héritage, visage, cheveux, peau, maquillage, tenue) : stockage dans un champ
           de personnage, validation, application à chaque apparition, et fonctions réutilisables (exports client)
           pour les interfaces de création, coiffeurs, magasins de vêtements…
           T-132 : les joueurs ne téléchargent que les constantes, config_client.lua (emplacements proposés,
           apparences de départ) et shared/appearance.lua ; config.lua (bornes du schéma, débit des créations) est
           servi au seul serveur.
    Dépendances : vAvA_core ≥ 0.3.0
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_appearance'
description 'Apparence des personnages vAvA'
version '1.1.0'

dependency 'vAvA_core'

-- Les joueurs ne téléchargent que les shared_scripts et les client_scripts : config.lua, en tête des server_scripts,
-- n'est jamais servi (T-132).
shared_scripts {
    'shared/constants.lua',
    'config_client.lua',         -- ouvre VavaAppearance.config : ce que lit le client
    'shared/appearance.lua',
}

server_scripts {
    'config.lua',                -- complète VavaAppearance.config : ce que lit le seul serveur
    'server/schema.lua',
    'server/main.lua',
}

client_scripts {
    'client/apply.lua',
    'client/main.lua',
}
