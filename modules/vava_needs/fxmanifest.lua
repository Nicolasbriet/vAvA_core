--[[
    vava_needs/fxmanifest.lua
    Rôle : besoins des personnages (faim, soif) : baisse avec le temps décidée par le serveur, paliers d'effets,
           consommation des objets à effets de l'inventaire, API pour les autres modules.
    Dépendances : vAvA_core ≥ 0.3.0 ; facultatives : vava_inventory ≥ 1.1.0 (manger, boire), vava_hud (jauges)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_needs'
description 'Faim et soif vAvA'
version '1.1.1'

dependency 'vAvA_core'

-- icônes des jauges, affichées par vava_hud (nui://vava_needs/web/icons/...)
files {
    'web/icons/*.svg',
}

shared_scripts {
    'shared/constants.lua',
    'config.lua',
}

server_scripts {
    'server/core.lua',
    'server/state.lua',
    'server/decay.lua',
    'server/consume.lua',
    'server/api.lua',
    'server/main.lua',
}

client_scripts {
    'client/core.lua',
    'client/effects.lua',
    'client/hud.lua',
    'client/main.lua',
}
