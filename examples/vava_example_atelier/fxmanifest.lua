--[[
    vava_example_atelier/fxmanifest.lua
    Rôle : exemple de développement de l'Atelier du Conseil (T-100, T-101) : deux ateliers déclarés sans une ligne
           d'interface (panneaux du bourg, proclamations), tous les widgets, des règles propres au module, une
           commande qui écrit au journal du Conseil ; T-101 : ateliers gardés (la base fait foi), essai chez l'auteur
           seul, panneaux diffusés par zone du core à leurs seuls abonnés, /atelier_exemple lire. Serveur seulement :
           ni client, ni page.
    Jamais sur un serveur ouvert au public : sans `set vava_env dev`, le module refuse de démarrer et ne déclare rien.
    Dépendances : vAvA_core ≥ 0.11.0 ; vava_atelier ≥ 1.1.0 (relu à son démarrage : les ateliers sont redéclarés au hook
                  vava_atelier:editorsReady), volontairement pas en `dependency` : relancer l'Atelier n'arrête pas
                  l'exemple
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vava_example_atelier'
description "Exemple de l'Atelier vAvA (mode développement seulement)"
version '1.1.0'

dependency 'vAvA_core'

server_scripts {
    'config.lua',
    'shared/guard.lua',
    'shared/rules.lua',
    'shared/forms.lua',
    'shared/store.lua',
    'server/main.lua',
}
