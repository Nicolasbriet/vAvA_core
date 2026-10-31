--[[
    vava_health/fxmanifest.lua
    Rôle : santé des personnages : vie tenue par le serveur, chaîne de dégâts commune (export hit, registre
           vava_health:modifiers, journal des coups), dégâts natifs entre joueurs annulés, mise à terre décidée par le
           serveur, réanimation par un autre joueur, retour au lieu de soins, soins par objets, écran « à terre », API
           pour les autres modules.
    Dépendances : vAvA_core ≥ 0.10.0 (core.net.send) ; vava_ui ≥ 1.0.0 (polices, grain et ornements de
                  la page, par nui://vava_ui/…) ; facultatives : vava_inventory (soins, objets bloqués à terre),
                  vava_needs (pas de faim à terre), vava_hud (jauge, notifications)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_health'
description 'Santé, mise à terre et réanimation vAvA'
version '1.5.0'

dependency 'vAvA_core'
dependency 'vava_ui'

ui_page 'web/index.html'

-- journal des coups, appliqué par le core avant setup()
vava_migration 'sql/0001_hits.sql'

-- polices, grain et ornements : vava_ui ; les données simulées hors jeu (dossier dev/) ne sont jamais livrées
files {
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
    'web/icons/*.svg',
}

-- Les joueurs ne téléchargent que les shared_scripts et les client_scripts : config.lua, en tête des server_scripts,
-- n'est jamais servi (T-132).
shared_scripts {
    'shared/constants.lua',
    'config_client.lua',         -- ouvre VavaHealth.config : ce que lit le client
    'shared/vitality.lua',
}

-- logique pure servie au seul serveur (paquet, chaîne, lecture du ped) : le client n'en télécharge rien
server_scripts {
    'config.lua',                -- complète VavaHealth.config : ce que lit le seul serveur
    'shared/packet.lua',
    'shared/chain.lua',
    'shared/sync.lua',
    'server/core.lua',
    'server/state.lua',
    'server/journal.lua',
    'server/life.lua',
    'server/modifiers.lua',
    'server/chain.lua',
    'server/natives.lua',
    'server/assist.lua',
    'server/links.lua',
    'server/api.lua',
    'server/commands.lua',
    'server/main.lua',
}

client_scripts {
    'client/core.lua',
    'client/body.lua',
    'client/screen.lua',
    'client/hud.lua',
    'client/keys.lua',
    'client/main.lua',
}
