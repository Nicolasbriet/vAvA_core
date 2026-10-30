--[[
    vava_admin/fxmanifest.lua
    Rôle : administration du royaume : Conseil (rangs et droits), panneau « Registre du Conseil » (joueurs,
           signalements, sanctions, journal, outils, annonces), bans à la connexion, journal des actions, commandes de
           la console, API pour les autres modules et le futur panneau web.
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
version '1.8.0'

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

shared_scripts {
    'shared/constants.lua',
    'config.lua',
}

server_scripts {
    'server/core.lua',
    'server/ranks.lua',
    'server/store.lua',
    'server/staff.lua',
    'server/extensions.lua',
    'server/audit.lua',
    'server/bans.lua',
    'server/reports.lua',
    'server/players.lua',
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
