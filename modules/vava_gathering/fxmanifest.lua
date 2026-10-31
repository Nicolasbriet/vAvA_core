--[[
    vava_gathering/fxmanifest.lua
    Rôle : la récolte du royaume : zones à vitalité (plein rendement, réduit, épuisée avec props remplacés, cicatrice),
           nœuds à charges (arbres, filons, buissons, bancs de poissons, pistes de gibier), outils en main qui s'usent,
           qualité de la récolte (compétence, outil, vitalité) en palier et provenance sur les piles, pêche à la barre
           de tension, réaction de la terre, commandes du Conseil. Le serveur décide de tout (distance, outil,
           cooldown, durée, rendement, charges, vitalité, prise d'un poisson quand la ligne a tenu) et appelle vava_skills pour l'XP ; le client crée les props à
           portée, pose les blips des zones sur la carte, montre l'invite, joue le geste et la barre de tension.
           État des zones et des nœuds (bande, cicatrice, charges) envoyé aux seuls joueurs proches, par les
           abonnements de zone du core (1.6.0).
           T-132 : les joueurs ne téléchargent que les constantes, config_client.lua (invite, streaming, carte,
           touches, outils, ressources, zones et nœuds, animations) et la logique lue par le client (distances,
           proximité, état des zones) ; config.lua (pêche comprise), shared/season.lua et shared/catch.lua sont servis
           au seul serveur.
    Dépendances : vAvA_core ≥ 0.11.0 (abonnements de zone), vava_ui ≥ 1.0.0 (polices, grain, papier et coins de la page, par
                  nui://vava_ui/…), vava_inventory ≥ 1.4.0 (objets, mains, métadonnées), vava_skills ≥ 1.0.0 (XP) ;
                  facultatifs : vava_hud (barre de progression, notifications), vava_admin (droit metiers), vava_chat,
                  vava_health (aucune récolte à terre), vava_time (saisons : repousse des nœuds, quantité récoltée)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_gathering'
description 'Récolte vAvA : zones à vitalité sur la carte, nœuds, outils en main, qualité, pêche, pistes de gibier'
version '1.7.0'

dependency 'vAvA_core'
dependency 'vava_ui'
dependency 'vava_inventory'
dependency 'vava_skills'

vava_migration 'sql/0001_gathering.sql'

ui_page 'web/index.html'

-- polices, grain, papier et coins : vava_ui ; les données simulées hors jeu (dossier dev/) ne sont jamais livrées
files {
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
    'web/items/*.svg',
}

-- Ordre explicite : chaque fichier ne dépend que de ceux listés avant lui. Les joueurs ne téléchargent que les
-- shared_scripts et les client_scripts : config.lua, en tête des server_scripts, n'est jamais servi (T-132).
shared_scripts {
    'shared/constants.lua',
    'config_client.lua',         -- ouvre VavaGathering.config : ce que lit le client
    'shared/geometry.lua',
    'shared/proximity.lua',
    'shared/zonestate.lua',
}

server_scripts {
    'config.lua',                -- complète VavaGathering.config : ce que lit le seul serveur
    'shared/season.lua',         -- logique pure, servie au seul serveur (testée hors jeu : tests/spec)
    'shared/catch.lua',          -- idem
    'server/core.lua',
    'bridge/server.lua',
    'server/journal.lua',
    'server/catalog.lua',
    'server/share.lua',
    'server/zones.lua',
    'server/nodes.lua',
    'server/quality.lua',
    'server/harvest.lua',
    'server/fishing.lua',
    'server/admin.lua',
    'server/api.lua',
    'server/commands.lua',
    'server/main.lua',
}

client_scripts {
    'client/core.lua',
    'client/nui.lua',
    'client/props.lua',
    'client/blips.lua',
    'client/interact.lua',
    'client/fishing.lua',
    'client/main.lua',
}
