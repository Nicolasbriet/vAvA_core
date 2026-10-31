--[[
    vava_provisions/fxmanifest.lua
    Rôle : les vivres du royaume (« Vivres ») : objets `eau` (Outre d'eau) et `outre` (Outre vide) ; points d'eau
           (puits, fontaines, sources) où l'on remplit ses outres vides et où l'on boit quelques gorgées, chacun une
           zone du core connue des seuls joueurs proches ; réserve par point en mémoire (la fontaine est sans fond) ;
           outre vide rendue quand on boit une outre d'eau, qui se fend parfois ; recette de l'outre à la tannerie
           (vava_crafting) ; commande du Conseil /eau. Le serveur décide de tout ; le client crée les props des points
           à portée, montre l'invite et joue le geste.
           T-132 : les joueurs ne téléchargent que les constantes, config_client.lua (sortes de points d'eau, portée,
           streaming, gestes, touche, textes montrés au joueur) et la logique lue par le client (textes, carnet des
           points, proximité) ; config.lua et les règles (shared/rules.lua) sont servis au seul serveur (T-143).
    Dépendances : vAvA_core ≥ 0.11.0 (abonnements de zone, core.net), vava_ui ≥ 1.0.0 (polices et grain de l'invite, par
                  nui://vava_ui/…), vava_inventory ≥ 1.8.0 (échange atomique, hook use avec `consumed`, piles gardées
                  à part) ; facultatifs : vava_needs (boire au point d'eau), vava_crafting et vava_skills (recette de
                  l'outre), vava_health (rien à terre), vava_hud (notifications), vava_admin (droit metiers, journal du
                  Registre), vava_chat (réponses de /eau)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_provisions'
description 'Vivres vAvA : points d\'eau, outres, eau potable'
version '1.2.0'

dependency 'vAvA_core'
dependency 'vava_ui'
dependency 'vava_inventory'

ui_page 'web/index.html'

-- polices et grain : vava_ui ; les données simulées hors jeu (dossier dev/) ne sont jamais livrées
files {
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
    'web/items/*.svg',
}

-- Ordre explicite : chaque fichier ne dépend que de ceux listés avant lui. Les joueurs ne téléchargent que les
-- shared_scripts et les client_scripts : config.lua, en tête des server_scripts, n'est jamais servi (T-132).
shared_scripts {
    'shared/constants.lua',
    'config_client.lua',         -- ouvre VavaProvisions.config : ce que lit le client
    'shared/texts.lua',
    'shared/pointzone.lua',
    'shared/proximity.lua',
}

server_scripts {
    'config.lua',                -- complète VavaProvisions.config : ce que lit le seul serveur
    'shared/rules.lua',
    'server/core.lua',
    'bridge/server.lua',
    'server/items.lua',
    'server/points.lua',
    'server/draw.lua',
    'server/containers.lua',
    'server/admin.lua',
    'server/commands.lua',
    'server/api.lua',
    'server/main.lua',
}

client_scripts {
    'client/core.lua',
    'client/nui.lua',
    'client/points.lua',
    'client/interact.lua',
    'client/main.lua',
}
