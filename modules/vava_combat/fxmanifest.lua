--[[
    vava_combat/fxmanifest.lua
    Rôle : combat de corps à corps d'Eldoria. Armes (T-111) : catalogue (classes et fiches en config), six objets
           déclarés à l'inventaire et l'Épée courte de vava_crafting adoptée, recettes déclarées à l'artisanat et aux
           compétences, dégâts selon la qualité de forge et l'usure, usure par coup qui touche, brique serveur `strike`,
           bouclier accroché (statebag de ped écrit et gardé par le serveur), combat natif de GTA coupé, commandes du
           Conseil /armes. Techniques (T-112) : techniques en données (COMBAT_V1.md § 3), RPC `vava_combat:use` à
           fenêtre de frappe tenue par le serveur (positions et cap lus par lui, tolérances bornées, enchaînement,
           chancellement), réactions aux seuls proches, mode combat éveillé et borné, dégainer et rengainer, verrou.
           Aucune NUI, aucune table SQL.
    Dépendances : vAvA_core ≥ 0.10.0 (core.net), vava_inventory ≥ 1.7.0 (objet tenu, statebag de la main),
                  vava_health ≥ 1.3.0 (chaîne de dégâts) ; facultatifs : vava_crafting ≥ 1.5.0 et vava_skills ≥ 1.0.0
                  (recettes), vava_hud (notifications), vava_admin (droit metiers, journal du Registre), vava_chat
                  (réponses de /armes), vava_magic (contrôle dur, export hardControl s'il existe)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_combat'
description 'Combat vAvA : armes de corps à corps, techniques, usure, bouclier accroché'
version '1.2.0'

dependency 'vAvA_core'
dependency 'vava_inventory'
dependency 'vava_health'

files {
    'web/items/*.svg',
}

-- Ordre explicite : chaque fichier ne dépend que de ceux listés avant lui. Les joueurs ne téléchargent que les
-- shared_scripts et les client_scripts : config.lua, en tête des server_scripts, n'est jamais servi (T-132).
shared_scripts {
    'shared/constants.lua',
    'config_client.lua',         -- ouvre VavaCombat.config : ce que lit le client
    'shared/shield.lua',
    'shared/geometry.lua',
    'shared/techniques.lua',
}

server_scripts {
    'config.lua',                -- complète VavaCombat.config : ce que lit le seul serveur
    -- logique pure servie au seul serveur
    'shared/weapons.lua',
    'shared/guard.lua',
    'server/core.lua',
    'bridge/server.lua',
    'server/catalog.lua',
    'server/pedstate.lua',
    'server/wear.lua',
    'server/shields.lua',
    'server/strike.lua',
    'server/hands.lua',
    'server/reactions.lua',
    'server/swings.lua',
    'server/api.lua',
    'server/commands.lua',
    'server/main.lua',
}

client_scripts {
    'client/core.lua',
    'bridge/client.lua',
    'client/natives.lua',
    'client/shields.lua',
    'client/hands.lua',
    'client/keys.lua',
    'client/targeting.lua',
    'client/attack.lua',
    'client/mode.lua',
    'client/reactions.lua',
    'client/main.lua',
}
