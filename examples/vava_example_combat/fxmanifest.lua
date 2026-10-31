--[[
    vava_example_combat/fxmanifest.lua
    Rôle : ressource d'essai de la chaîne de dégâts (T-110) : /frapper (export hit), trois modificateurs d'essai
           (esquive, bouclier, résistance) déclarés au registre vava_health:modifiers, /chaine, et des armes et une
           explosion vanilla pour vérifier que les dégâts natifs entre joueurs sont annulés ; /frapper_arme (1.1.0,
           T-111) : coup de l'arme tenue en main par exports.vava_combat:strike.
    Jamais sur un serveur ouvert au public : sans `set vava_env dev`, le module refuse de démarrer et n'offre rien ;
    avec, chaque commande est réservée au droit `staff` de vava_admin ou à l'ACE `vava.dev`, et chaque coup ou
    protection posée est inscrit au journal du Registre (voir README.md).
    Dépendances : vAvA_core ≥ 0.10.0 ; vava_health ≥ 1.3.0 (relu à son démarrage : les modificateurs sont redéclarés
                  au hook core:module:ready), volontairement pas en `dependency` : relancer vava_health n'arrête pas
                  l'essai ; facultatifs : vava_admin (droit et journal), vava_combat ≥ 1.0.0
                  (/frapper_arme ; pas en `dependency` non plus : l'essai de la chaîne tourne sans lui)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vava_example_combat'
description 'Essai de la chaîne de dégâts vAvA (mode développement seulement)'
version '1.1.0'

dependency 'vAvA_core'

shared_script 'config.lua'

server_scripts {
    'shared/guard.lua',
    'server/main.lua',
}

client_script 'client/main.lua'
