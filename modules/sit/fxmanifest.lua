--[[
    vAvA Core - Module Sit
    Système de points d'assise avec animations personnalisables
    
    Exports Client:
    - OpenSitMenu(): Ouvrir le menu principal
    - ToggleEditMode(): Basculer le mode édition
    - SitDown(pointId): S'asseoir à un point
    - StandUp(): Se lever
    - GetSitPoints(): Récupérer tous les points
    
    Exports Serveur:
    - CreateSitPoint(coords, heading): Créer un point
    - DeleteSitPoint(pointId): Supprimer un point
    - GetSitPoints(): Récupérer tous les points
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vAvA_core_sit'
description 'Module Sit - Points d\'assise avec animations personnalisables'
version '1.0.0'
author 'vAvA'

-- Dépendances
dependencies {
    'vAvA_core'
}

-- Scripts partagés
shared_scripts {
    'config.lua'
}

-- Scripts client
client_scripts {
    'client/main.lua'
}

-- Scripts serveur
server_scripts {
    'server/main.lua'
}

-- Fichiers de données
files {
    'sit_points.json'
}
