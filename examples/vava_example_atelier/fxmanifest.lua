--[[
    vava_example_atelier/fxmanifest.lua
    Rôle : exemple de développement de l'Atelier du Conseil (T-100) : deux ateliers déclarés sans une ligne
           d'interface (panneaux du bourg, proclamations), tous les widgets, des règles propres au module, et une
           commande qui écrit au journal du Conseil. Serveur seulement : ni client, ni page.
    Jamais sur un serveur ouvert au public : sans `set vava_env dev`, le module refuse de démarrer et ne déclare rien.
    Dépendances : vAvA_core ≥ 0.11.0 ; vava_atelier (relu à son démarrage : les ateliers sont redéclarés au hook
                  vava_atelier:editorsReady), volontairement pas en `dependency` : relancer l'Atelier n'arrête pas
                  l'exemple
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vava_example_atelier'
description "Exemple de l'Atelier vAvA (mode développement seulement)"
version '1.0.0'

dependency 'vAvA_core'

server_scripts {
    'config.lua',
    'shared/guard.lua',
    'shared/rules.lua',
    'shared/forms.lua',
    'server/main.lua',
}
