--[[
    vava_atelier/fxmanifest.lua
    Rôle : l'Atelier du Conseil : créer et régler le royaume en jeu (fiches gardées en base, essai, publication, retour
           en arrière, outil de placement). Code du Conseil livré à la demande (T-157) : les joueurs ne téléchargent
           qu'une amorce ; le reste part chez les seuls membres (vava_conseil_lua, vava_conseil_web). Détail : README.
    Dépendances : vAvA_core ≥ 0.11.0, vava_ui ≥ 1.0.0 ; vava_admin ≥ 1.8.0 relu à chaque appel (pas en `dependency`) ;
                  facultatifs : vava_inventory, vava_hud
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_atelier'
description 'Atelier du Conseil vAvA : créer et régler le royaume en jeu (socle : accueil, droits, formulaire, journal)'
version '1.4.0'

dependency 'vAvA_core'
dependency 'vava_ui'

vava_migration 'sql/0001_journal.sql'
vava_migration 'sql/0002_definitions.sql'
vava_migration 'sql/0003_parent_index.sql'

ui_page 'web/index.html'

-- polices, grain et ornements : vava_ui ; les données simulées hors jeu (dossier dev/) ne sont jamais livrées ; le
-- dossier des archives (echanges/) n'est jamais servi aux joueurs. T-157 : page vide et son amorce seulement ; la
-- feuille et les scripts partent dans le paquet du Conseil (vava_conseil_web).
files {
    'web/index.html',
    'web/boot.js',
}

-- Ordre explicite : chaque fichier ne dépend que de ceux listés avant lui. Les joueurs ne téléchargent que les
-- shared_scripts et les client_scripts : config.lua, en tête des server_scripts, n'est jamais servi (T-132).
shared_scripts {
    'shared/constants.lua',
    'config_client.lua',         -- ouvre VavaAtelier.config : ce que lit le client de chaque joueur
    'shared/digest.lua',         -- T-157 : empreinte du paquet du Conseil (serveur et chargeur)
    'shared/codepack.lua',       -- T-157 : format du paquet (serveur et chargeur)
}

server_scripts {
    'config_conseil.lua',        -- T-157 : complète VavaAtelier.config : ce que lit le Conseil (aussi au paquet)
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
    'shared/codepack_encode.lua', -- T-157 : écriture du paquet du Conseil (le chargeur ne fait que le lire)
    'shared/placerules.lua',     -- T-102 : règles de placement, mêmes pour l'aperçu (paquet) et la décision (serveur)
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
    'server/delivery.lua',       -- T-157 : paquet du Conseil, RPC code
    'server/history.lua',
    'server/archives.lua',
    'server/providers.lua',
    'server/commands.lua',
    'server/api.lua',
    'server/main.lua',
}

-- Amorce, livrée à tous : touche et commande, notifications, réponse de /atelier_archives, chargeur.
client_scripts {
    'client/core.lua',
    'client/nui.lua',
    'client/notice.lua',
    'client/loader.lua',
    'client/main.lua',
}

-- T-157 : code du seul Conseil, livré à la demande (server/delivery.lua) ; jamais téléchargé par les joueurs. Ordre
-- d'exécution chez le membre : celui de la liste, après les client_scripts.
vava_conseil_lua {
    'config_conseil.lua',
    'shared/placerules.lua',
    'shared/aim.lua',
    'client/session.lua',
    'client/relay.lua',
    'client/drawing.lua',
    'client/ghosts.lua',
    'client/placer.lua',
    'client/keys.lua',
}
-- Ordre d'insertion dans la page : celui de la page de développement, dev/index.html (essai : atelier_delivery_spec).
vava_conseil_web {
    'web/css/style.css',
    'web/js/strings.js', 'web/js/bridge.js', 'web/js/format.js', 'web/js/lifecycle.js', 'web/js/components.js',
    'web/js/widgets.js', 'web/js/form.js', 'web/js/placing.js', 'web/js/view-home.js', 'web/js/view-list.js',
    'web/js/view-entry.js', 'web/js/view-history.js', 'web/js/view-journal.js', 'web/js/app.js',
}
