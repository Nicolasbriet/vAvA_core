--[[
    vava_arrival/fxmanifest.lua
    Rôle : l'arrivée d'un nouveau personnage : première venue reconnue par le serveur (temps de jeu mesuré par le core
           et ligne en base), dotation de départ donnée une seule fois par l'échange atomique de vava_inventory (limite
           par compte, réservation conditionnelle en base, journal), mot d'accueil en notifications puis Codex ouvert à
           la page des premiers pas, accusé de lecture, commande du Conseil /accueil (état, redoter, rejouer). Le point
           d'arrivée est `spawn.defaultPoint` du core. Aucune boucle, aucun envoi à d'autres joueurs que le nouveau venu.
           T-132 : les joueurs ne téléchargent que les constantes, config_client.lua (attente de l'accueil, chapitre du
           Codex, textes du nouveau venu) et shared/screen.lua ; config.lua et shared/rules.lua sont servis au seul
           serveur.
    Dépendances : vAvA_core ≥ 0.10.0 (core.net, temps de jeu, registre des commandes), vava_inventory ≥ 1.4.0 (exchange,
                  registre des objets) ; facultatifs : vava_codex ≥ 1.4.0 (openAt), vava_hud (notifications),
                  vava_admin (droit give, journal du Registre), vava_chat (réponses de /accueil)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_arrival'
description 'Arrivée vAvA : première venue, dotation de départ unique, accueil et Codex, /accueil du Conseil'
version '1.2.0'

dependency 'vAvA_core'
dependency 'vava_inventory'

vava_migration 'sql/0001_arrival.sql'

-- dessins des objets déclarés par le module (aucune page : l'accueil passe par le HUD et le Codex)
files {
    'web/items/*.svg',
}

-- Ordre explicite : chaque fichier ne dépend que de ceux listés avant lui. Les joueurs ne téléchargent que les
-- shared_scripts et les client_scripts : config.lua, en tête des server_scripts, n'est jamais servi (T-132).
shared_scripts {
    'shared/constants.lua',
    'config_client.lua',         -- ouvre VavaArrival.config : ce que lit le client
    'shared/screen.lua',         -- écran prêt pour l'accueil (logique pure lue par le client)
}

server_scripts {
    'config.lua',                -- complète VavaArrival.config : ce que lit le seul serveur
    'shared/rules.lua',          -- logique pure, servie au seul serveur (testée hors jeu : tests/spec)
    'server/core.lua',
    'bridge/server.lua',
    'server/journal.lua',
    'server/store.lua',
    'server/kit.lua',
    'server/welcome.lua',
    'server/admin.lua',
    'server/commands.lua',
    'server/main.lua',
}

client_scripts {
    'client/core.lua',
    'client/main.lua',
}
