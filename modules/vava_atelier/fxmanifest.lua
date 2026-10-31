--[[
    vava_atelier/fxmanifest.lua
    Rôle : l'Atelier du Conseil (T-100, socle) : une touche (F9, réglable) ou /atelier ouvre un livre de travail où
           chaque membre ne voit que les ateliers que son rang lui ouvre (le monde pour un Sénéchal, tout pour un
           Souverain), ses brouillons et le journal des derniers changements. Les modules y déclarent leurs éditeurs
           (registre vava_atelier:editors) sans une ligne d'interface : un formulaire générique à huit widgets les
           dessine, et « Vérifier » contrôle une fiche (forme ici, règles chez le module) sans rien changer. Droits
           revérifiés à chaque appel ; journal propre (365 jours) recopié au Registre.
           T-101 : les définitions sont gardées en base (une ligne par version) : brouillon, essai chez l'auteur seul,
           publication groupée d'une fiche et de ses enfants, retour à une version, retrait, reprise d'un brouillon,
           historique ; la config est la graine, la base fait foi (synchronisation à chaque déclaration d'un module) ;
           archives JSON et retour à l'original par /atelier_archives (Souverain, console).
           T-132 : config_client.lua (touche, commande, textes affichés par le client) est seul téléchargé par les
           joueurs avec les constantes ; config.lua (tout le reste) est servi au seul serveur.
           T-102 : outil de placement en jeu (point, orienté, cercle, tracé ; visée sans curseur, aperçu vert ou rouge
           par les règles déclarées du type, les mêmes au serveur ; fantômes locaux ; Ctrl+Z) ; RPC place et children ;
           essai joué (la page se met de côté, F9 pour revenir) ; index des enfants (sql/0003_parent_index.sql).
    Dépendances : vAvA_core ≥ 0.11.0 ; vava_ui ≥ 1.0.0 (polices et textures, par nui://vava_ui/…) ; vava_admin ≥ 1.8.0
                  relu à chaque appel (sans lui, l'Atelier refuse de s'ouvrir : « Le Registre du Conseil s'éveille »),
                  volontairement pas en `dependency` : arrêter ou relancer le Registre n'arrête pas l'Atelier ;
                  facultatifs : vava_inventory (objets du widget `item`), vava_hud (notifications)
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
    'shared/aim.lua',            -- T-102 : visée de l'outil de placement (lue par le client)
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
    'client/core.lua',
    'client/nui.lua',
    'client/session.lua',
    'client/relay.lua',
    'client/drawing.lua',
    'client/ghosts.lua',
    'client/placer.lua',
    'client/main.lua',
}
