--[[
    vava_skills/fxmanifest.lua
    Rôle : compétences du royaume, fondation des métiers : treize compétences de 0 à 100 et six rangs, savoir commun et
           budget de points, rouille (↑ = ↓), rendements décroissants, métiers en pénurie, mentorat (bonus de l'apprenti,
           Renommée du maître), Arcanes transmises de maître à apprenti, recettes transmises par leçons et leur lignée,
           savoirs perdus reconstitués par fragments, fondateurs, journal. Les modules métiers (récolte, artisanat,
           agriculture) ne calculent jamais l'XP : ils l'appellent avec un contexte. Le serveur décide de tout ; le
           client affiche le livre des compétences (touche K) et demande.
           T-132 : les joueurs ne téléchargent que les constantes et config_client.lua (touche, texte du livre
           indisponible) ; config.lua et shared/progression.lua sont servis au seul serveur.
    Dépendances : vAvA_core ≥ 0.6.0 (temps de jeu), vava_ui ≥ 1.0.0 (polices, grain, papier et coins de la page, par
                  nui://vava_ui/…), vava_inventory ≥ 1.4.0 (fragments) ; facultatifs : vava_hud
                  (notifications), vava_admin (droits `metiers` et `staff`, journal du Conseil)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_skills'
description 'Compétences vAvA : niveaux, rangs, rouille, pénurie, mentorat, Renommée, recettes transmises, lignées'
version '1.3.0'

dependency 'vAvA_core'
dependency 'vava_ui'
dependency 'vava_inventory'

vava_migration 'sql/0001_skills.sql'

ui_page 'web/index.html'

-- polices, grain, papier et coins : vava_ui ; les données simulées hors jeu (dossier dev/) ne sont jamais livrées
files {
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
}

-- Ordre explicite : chaque fichier ne dépend que de ceux listés avant lui. Les joueurs ne téléchargent que les
-- shared_scripts et les client_scripts : config.lua, en tête des server_scripts, n'est jamais servi (T-132).
shared_scripts {
    'shared/constants.lua',
    'config_client.lua',         -- ouvre VavaSkills.config : ce que lit le client
}

server_scripts {
    'config.lua',                -- complète VavaSkills.config : ce que lit le seul serveur
    'shared/progression.lua',    -- logique pure, servie au seul serveur (testée hors jeu : tests/spec)
    'server/core.lua',
    'bridge/server.lua',
    'server/journal.lua',
    'server/registries.lua',
    'server/sheets.lua',
    'server/shortages.lua',
    'server/progression.lua',
    'server/mentoring.lua',
    'server/lessons.lua',
    'server/admin.lua',
    'server/api.lua',
    'server/commands.lua',
    'server/main.lua',
}

client_scripts {
    'client/core.lua',
    'client/nui.lua',
    'client/main.lua',
}
