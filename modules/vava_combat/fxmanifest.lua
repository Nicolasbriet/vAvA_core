--[[
    vava_combat/fxmanifest.lua
    Rôle : armes de corps à corps d'Eldoria (T-111, squelette que T-112 complétera) : catalogue des armes (fiches en
           config), six objets déclarés à l'inventaire et l'Épée courte de vava_crafting adoptée, recettes déclarées à
           l'artisanat et aux compétences, dégâts selon la qualité de forge et l'usure, usure par coup qui touche
           (arme émoussée à 0), brique serveur `strike` (paquet, vava_health:hit, usure), bouclier accroché au bras ou
           au dos (statebag de ped écrit et gardé par le serveur), combat natif de GTA coupé sans boucle par image,
           commandes du Conseil /armes. Aucun RPC, aucune NUI, aucune table SQL.
    Dépendances : vAvA_core ≥ 0.10.0 (core.net.send), vava_inventory ≥ 1.7.0 (objet tenu, statebag de la main),
                  vava_health ≥ 1.3.0 (chaîne de dégâts) ; facultatifs : vava_crafting ≥ 1.5.0 et vava_skills ≥ 1.0.0
                  (recettes), vava_hud (notifications), vava_admin (droit metiers, journal du Registre), vava_chat
                  (réponses de /armes)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_combat'
description 'Combat vAvA : armes de corps à corps, usure, bouclier accroché'
version '1.0.0'

dependency 'vAvA_core'
dependency 'vava_inventory'
dependency 'vava_health'

files {
    'web/items/*.svg',
}

-- Ordre explicite : chaque fichier ne dépend que de ceux listés avant lui.
shared_scripts {
    'shared/constants.lua',
    'config.lua',
    'shared/shield.lua',
}

server_scripts {
    -- logique pure servie au seul serveur
    'shared/weapons.lua',
    'server/core.lua',
    'bridge/server.lua',
    'server/catalog.lua',
    'server/pedstate.lua',
    'server/wear.lua',
    'server/shields.lua',
    'server/strike.lua',
    'server/api.lua',
    'server/commands.lua',
    'server/main.lua',
}

client_scripts {
    'client/core.lua',
    'bridge/client.lua',
    'client/natives.lua',
    'client/shields.lua',
    'client/main.lua',
}
