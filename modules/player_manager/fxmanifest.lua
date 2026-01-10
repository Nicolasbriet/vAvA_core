--[[
    vAvA_player_manager - Gestion Complète des Joueurs et Personnages
    Version: 1.0.0 - Module vAvA_core
    
    Fonctionnalités:
    - Multi-personnages (jusqu'à 5 par compte)
    - Sélection personnage au login
    - Profils détaillés (nom, DOB, genre, nationalité, background)
    - Statistiques joueur (temps de jeu, argent total, jobs, achievements)
    - Historique complet (amendes, prison, achats, propriétés)
    - Système de licences (conduite, armes, chasse, pêche, bateau, avion)
    - Carte d'identité visuelle moderne (NUI)
    - Permis de conduire visuel
    - Casier judiciaire intégré
    - Fiche médicale
    - Notes personnelles par personnage
    - API complète pour intégration
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vAvA_player_manager'
author 'vAvA'
description 'Système de gestion complète des joueurs et personnages - Multi-char, profils, stats, licences'
version '1.0.0'

dependencies {
    'vAvA_core',
    'oxmysql'
}

shared_scripts {
    'config.lua',
    'locales/*.lua'
}

client_scripts {
    'client/main.lua',
    'client/ui.lua',
    'client/selector.lua',
    'client/identity.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/database.lua',
    'server/characters.lua',
    'server/licenses.lua',
    'server/stats.lua',
    'server/history.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
    'html/img/*.png',
    'html/img/*.jpg'
}

-- Exports serveur
server_exports {
    'GetPlayerCharacters',
    'GetCharacterData',
    'CreateCharacter',
    'DeleteCharacter',
    'SelectCharacter',
    'GetLicense',
    'AddLicense',
    'RemoveLicense',
    'GetPlayerStats',
    'UpdatePlayerStat',
    'AddHistoryEntry',
    'GetCharacterHistory'
}

-- Exports client
client_exports {
    'OpenCharacterSelector',
    'OpenIdentityCard',
    'OpenDriverLicense',
    'GetCurrentCharacter'
}
