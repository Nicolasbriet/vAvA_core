--[[
    vava_pause/fxmanifest.lua
    Rôle : la bannière du royaume, à la place du menu pause de GTA (Échap, P, Start) : personnage et savoir-faire,
           Codex en panneau, carte, réglages du joueur (gardés sur sa machine), demande au Conseil, paramètres du jeu,
           quitter Eldoria ; plaque du royaume (heure, saison, habitants). Une seule demande au serveur à l'ouverture,
           aucun envoi en continu. Refusée en combat (10 s après un coup), ligoté, dans une autre interface ; réduite à
           terre (Paramètres du jeu, Quitter). La seule boucle par image permanente bloque Échap et P (exception
           décidée par le porteur du projet, T-145).
    Dépendances : vAvA_core ≥ 0.10.0 (core.net, registre core:commands) ; vava_ui ≥ 1.0.0 (polices, grain et
                  ornements de la page, par nui://vava_ui/…) ; facultatifs : vava_skills (savoir-faire, fiche),
                  vava_health (à terre, vie, fenêtre de combat), vava_needs, vava_time, vava_voice, vava_hud,
                  vava_codex ≥ 1.7.0 (panneau), vava_admin ≥ 1.10.0 (demandes au Conseil), vava_guilds (couleurs)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_pause'
description 'Bannière du royaume vAvA : menu pause d\'Eldoria'
version '1.0.0'

dependency 'vAvA_core'
dependency 'vava_ui'

ui_page 'web/index.html'

-- polices, grain et ornements : vava_ui ; les données simulées hors jeu (dossier dev/) ne sont jamais livrées
files {
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
    'web/img/*.svg',
}

-- Ordre explicite : chaque fichier ne dépend que de ceux listés avant lui. Les joueurs ne téléchargent que les
-- shared_scripts et les client_scripts : config.lua, en tête des server_scripts, n'est jamais servi (T-132).
shared_scripts {
    'shared/constants.lua',
    'config_client.lua',         -- ouvre VavaPause.config : ce que lit le client
    'shared/gate.lua',           -- logique pure lue par le client (testée : tests/spec)
    'shared/settings.lua',
    'shared/plaque.lua',
}

server_scripts {
    'config.lua',                -- complète VavaPause.config : ce que lit le seul serveur
    'shared/snapshot.lua',       -- logique pure servie au seul serveur (testée : tests/spec)
    'shared/council.lua',
    'shared/combat.lua',
    'server/core.lua',
    'bridge/server.lua',
    'server/combat.lua',
    'server/keys.lua',
    'server/snapshot.lua',
    'server/rpc.lua',
    'server/api.lua',
    'server/commands.lua',
    'server/main.lua',
}

client_scripts {
    'client/core.lua',
    'client/nui.lua',
    'client/sources.lua',
    'client/settings.lua',
    'client/native.lua',
    'client/intercept.lua',
    'client/gamepad.lua',
    'client/main.lua',
}
