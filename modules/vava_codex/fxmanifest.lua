--[[
    vava_codex/fxmanifest.lua
    Rôle : le Codex : toutes les commandes et toutes les touches du serveur, lues dans le registre `core:commands` que
           chaque module remplit, filtrées selon les droits du joueur, classées par chapitre, cherchées, composées par
           un formulaire selon le type de chaque argument (joueur, compétence, zone, nombre…) et lancées ; signets,
           dernières pages et réglage « rester ouvert » par personnage ; onglet des touches. Touche F1 (réglable) et
           /codex. Le serveur décide de ce que chacun voit ; les commandes gardent leurs propres contrôles.
    Dépendances : vAvA_core ≥ 0.7.0 (registre des commandes) ; facultatifs : vava_admin (rangs et droits du
                  Conseil), vava_hud (notifications), vava_chat (dernières pages des commandes tapées)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_codex'
description 'Codex vAvA : toutes les commandes et touches du serveur, classées, cherchées, composées et lancées'
version '1.1.2'

dependency 'vAvA_core'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
    'web/img/*',
    'web/fonts/*.woff2',
}

-- Ordre explicite : chaque fichier ne dépend que de ceux listés avant lui.
shared_scripts {
    'shared/constants.lua',
    'config.lua',
}

server_scripts {
    'server/core.lua',
    'bridge/server.lua',
    'server/catalog.lua',
    'shared/prefs.lua',          -- logique pure, servie au seul serveur (testée hors jeu : tests/spec)
    'server/prefs.lua',
    'server/suggestions.lua',
    'server/commands.lua',
    'server/main.lua',
}

client_scripts {
    'client/core.lua',
    'client/nui.lua',
    'client/keys.lua',
    'client/main.lua',
}
