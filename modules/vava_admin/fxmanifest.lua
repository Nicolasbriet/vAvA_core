--[[
    vava_admin/fxmanifest.lua
    Rôle : administration du royaume : Conseil (rangs et droits), panneau « Registre du Conseil » (joueurs,
           signalements, sanctions, journal, outils, annonces), bans à la connexion, journal des actions, commandes de
           la console, API pour les autres modules et le futur panneau web.
           T-132 : les joueurs ne téléchargent que les constantes et config_client.lua (commandes, touches, outils du
           client, textes du client) ; config.lua (rangs, bans, journal, signalements, débits, textes du serveur) est
           servi au seul serveur.
           Demandes au Conseil (1.10.0) : nature, position lue par le serveur, témoins d'un signalement de joueur,
           demandes ouvertes par compte, exports submitRequest et requestOf pour la bannière de vava_pause.
           Invulnérabilité tenue par le serveur (1.11.0) : l'outil, le vol libre et l'observation protègent de la
           chaîne de dégâts de vava_health (modificateur d'annulation vava_admin:invulnerabilite).
    Dépendances : vAvA_core ≥ 0.5.0 ; vava_ui ≥ 1.0.0 (polices, grain, papier et coins du Registre, par
                  nui://vava_ui/…) ; facultatives : vava_health, vava_needs, vava_inventory (actions sur les joueurs),
                  vava_hud (notifications)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_admin'
description 'Administration vAvA (Registre du Conseil)'
version '1.11.0'

dependency 'vAvA_core'
dependency 'vava_ui'

vava_migration 'sql/0001_admin.sql'

ui_page 'web/index.html'

-- polices, grain, papier et coins : vava_ui ; les données simulées hors jeu (dossier dev/) ne sont jamais livrées
files {
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
}

-- Les joueurs ne téléchargent que les shared_scripts et les client_scripts : config.lua, en tête des server_scripts,
-- n'est jamais servi (T-132).
shared_scripts {
    'shared/constants.lua',
    'config_client.lua',         -- ouvre VavaAdmin.config : ce que lit le client
}

server_scripts {
    'config.lua',                -- complète VavaAdmin.config : ce que lit le seul serveur
    'shared/requests.lua',       -- 1.10.0 : logique pure des demandes, servie au seul serveur (tests/spec)
    'shared/invulnerability.lua', -- 1.11.0 : règles pures de l'invulnérabilité, servies au seul serveur (tests/spec)
    'server/core.lua',
    'server/ranks.lua',
    'server/store.lua',
    'server/staff.lua',
    'server/extensions.lua',
    'server/audit.lua',
    'server/bans.lua',
    'server/reports.lua',
    'server/players.lua',
    'server/invulnerability.lua',
    'server/spectate.lua',
    'server/actions.lua',
    'server/requests.lua',
    'server/rpc.lua',
    'server/web.lua',
    'server/console.lua',
    'server/api.lua',
    'server/commands.lua',
    'server/main.lua',
}

client_scripts {
    'client/core.lua',
    'client/nui.lua',
    'client/notify.lua',
    'client/tools.lua',
    'client/panel.lua',
    'client/main.lua',
}
