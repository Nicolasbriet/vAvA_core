--[[
    vava_skills/fxmanifest.lua
    Rôle : compétences du royaume, fondation des métiers : treize compétences de 0 à 100 et six rangs, savoir commun et
           budget de points, rouille (↑ = ↓), rendements décroissants, métiers en pénurie, mentorat (bonus de l'apprenti,
           Renommée du maître), Arcanes transmises de maître à apprenti, recettes transmises par leçons et leur lignée,
           savoirs perdus reconstitués par fragments, fondateurs, journal. Les modules métiers (récolte, artisanat,
           agriculture) ne calculent jamais l'XP : ils l'appellent avec un contexte. Le serveur décide de tout ; le
           client affiche le livre des compétences (touche K) et demande.
    Dépendances : vAvA_core ≥ 0.6.0 (temps de jeu), vava_inventory ≥ 1.4.0 (fragments) ; facultatifs : vava_hud
                  (notifications), vava_admin (droits `metiers` et `staff`, journal du Conseil)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_skills'
description 'Compétences vAvA : niveaux, rangs, rouille, pénurie, mentorat, Renommée, recettes transmises, lignées'
version '1.1.1'

dependency 'vAvA_core'
dependency 'vava_inventory'

vava_migration 'sql/0001_skills.sql'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
    'web/img/*',
    'web/fonts/*.woff2',
}

-- Ordre explicite : chaque fichier ne dépend que de ceux listés avant lui.
shared_scripts {
    'shared/constants.lua',
    'config.lua',
    'shared/progression.lua',
}

server_scripts {
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
