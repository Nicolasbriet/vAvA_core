--[[
    vava_needs/fxmanifest.lua
    Rôle : besoins des personnages (faim, soif) : baisse avec le temps décidée par le serveur, paliers d'effets,
           consommation des objets à effets de l'inventaire, perte de vie d'un besoin épuisé (décidée par le serveur
           avec vava_health), API pour les autres modules.
           T-132 : les joueurs ne téléchargent que les constantes, config_client.lua (besoins, paliers, vie,
           endurance, gestes, jauges) et shared/starvation.lua ; config.lua (boucle, activité, refus d'un objet) est
           servi au seul serveur.
    Dépendances : vAvA_core ≥ 0.3.0 ; facultatives : vava_inventory ≥ 1.1.0 (manger, boire), vava_hud (jauges),
                  vava_health (perte de vie appliquée par le serveur, mise à terre ; 1.3.0 : chaîne de dégâts)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_needs'
description 'Faim et soif vAvA'
version '1.3.0'

dependency 'vAvA_core'

-- icônes des jauges, affichées par vava_hud (nui://vava_needs/web/icons/...)
files {
    'web/icons/*.svg',
}

-- Les joueurs ne téléchargent que les shared_scripts et les client_scripts : config.lua, en tête des server_scripts,
-- n'est jamais servi (T-132).
shared_scripts {
    'shared/constants.lua',
    'config_client.lua',         -- ouvre VavaNeeds.config : ce que lit le client
    'shared/starvation.lua',
}

server_scripts {
    'config.lua',                -- complète VavaNeeds.config : ce que lit le seul serveur
    'server/core.lua',
    'bridge/server.lua',
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
