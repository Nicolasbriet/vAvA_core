--[[
    vava_atelier/fxmanifest.lua
    Rôle : l'Atelier du Conseil : créer et régler le royaume en jeu (fiches gardées en base, essai, publication, retour
           en arrière, outil de placement). Détail : README.
    Dépendances : vAvA_core ≥ 0.11.0, vava_ui ≥ 1.0.0 ; vava_admin ≥ 1.8.0 relu à chaque appel (pas en `dependency`) ;
                  facultatifs : vava_inventory, vava_hud
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_atelier'
description 'Atelier du Conseil vAvA : créer et régler le royaume en jeu (socle : accueil, droits, formulaire, journal)'
version '1.3.0'

dependency 'vAvA_core'
dependency 'vava_ui'

vava_migration 'sql/0001_journal.sql'
vava_migration 'sql/0002_definitions.sql'
vava_migration 'sql/0003_parent_index.sql'

ui_page 'web/index.html'

-- polices, grain et ornements : vava_ui ; les données simulées hors jeu (dossier dev/) ne sont jamais livrées ; le
-- dossier des archives (echanges/) n'est jamais servi aux joueurs
files {
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
}

-- Ordre explicite : chaque fichier ne dépend que de ceux listés avant lui. Les joueurs ne téléchargent que les
-- shared_scripts et les client_scripts : config.lua, en tête des server_scripts, n'est jamais servi (T-132).
shared_scripts {
    'shared/constants.lua',
    'config_client.lua',         -- ouvre VavaAtelier.config : ce que lit le client
    'shared/placerules.lua',     -- T-102 : règles de placement, les mêmes pour l'aperçu (client) et la décision (serveur)
}

server_scripts {
    'config.lua',                -- complète VavaAtelier.config : ce que lit le seul serveur
    'server/core.lua',
    'shared/bounds.lua',         -- constantes réservées au serveur (jamais envoyées aux joueurs)
    'shared/text.lua',           -- logique pure, servie au seul serveur (testée hors jeu : tests/spec)
    'shared/formvalues.lua',
    'shared/formschema.lua',
    'shared/rights.lua',
    'shared/journaltext.lua',
    'shared/fingerprint.lua',
    'shared/place.lua',
    'shared/slug.lua',
    'shared/changes.lua',
    'shared/stored.lua',
    'shared/lifecycle.lua',
    'shared/exchange.lua',
    'bridge/server.lua',
    'server/editors.lua',
    'server/access.lua',
    'server/journal.lua',
    'server/entries.lua',
    'server/check.lua',
    'server/home.lua',
    'server/store.lua',
    'server/index.lua',
    'server/calls.lua',
    'server/trials.lua',
    'server/sync.lua',
    'server/lifecycle.lua',
    'server/placement.lua',
    'server/history.lua',
    'server/archives.lua',
    'server/providers.lua',
    'server/commands.lua',
    'server/api.lua',
    'server/main.lua',
}

client_scripts {
    'shared/aim.lua',            -- logique pure de la visée, lue par le seul client (testée hors jeu)
    'client/core.lua',
    'client/nui.lua',
    'client/session.lua',
    'client/relay.lua',
    'client/drawing.lua',
    'client/ghosts.lua',
    'client/placer.lua',
    'client/main.lua',
}
