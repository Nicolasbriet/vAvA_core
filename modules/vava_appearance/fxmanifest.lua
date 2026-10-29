--[[
    vava_appearance/fxmanifest.lua
    Rôle : apparence des personnages (héritage, visage, cheveux, peau, maquillage, tenue) : stockage dans un champ
           de personnage, validation, application à chaque apparition, et fonctions réutilisables (exports client)
           pour les interfaces de création, coiffeurs, magasins de vêtements…
    Dépendances : vAvA_core ≥ 0.3.0
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_appearance'
description 'Apparence des personnages vAvA'
version '1.0.1'

dependency 'vAvA_core'

shared_scripts {
    'shared/constants.lua',
    'config.lua',
    'shared/appearance.lua',
}

server_scripts {
    'server/schema.lua',
    'server/main.lua',
}

client_scripts {
    'client/apply.lua',
    'client/main.lua',
}
