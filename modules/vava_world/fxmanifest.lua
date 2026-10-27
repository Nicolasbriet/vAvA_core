--[[
    vava_world/fxmanifest.lua
    Rôle : le monde du royaume. Aujourd'hui : la carte de GTA vidée de sa population (aucun PNJ, véhicule, bateau,
           train, avion, animal, ni police ou secours), décidé par le serveur pour chaque instance, et les sons de la
           ville moderne coupés chez chaque joueur (circulation, foule, véhicules lointains, sirènes, radio de
           police). Plus tard : heure, météo.
    Dépendances : vAvA_core ≥ 0.5.0 (OneSync requis)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_world'
description 'Monde vAvA (carte sans population)'
version '1.1.0'

dependency 'vAvA_core'

shared_scripts {
    'shared/constants.lua',
    'config.lua',
}

server_scripts {
    'server/core.lua',
    'server/population.lua',
    'server/api.lua',
    'server/main.lua',
}

client_scripts {
    'client/core.lua',
    'client/population.lua',
    'client/audio.lua',
    'client/main.lua',
}
