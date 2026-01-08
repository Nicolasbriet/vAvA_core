--[[
    vAvA Core - Module Persist
    Système de persistance des véhicules
    
    Exports Client:
    - SaveVehiclePosition(plate): Sauvegarder la position d'un véhicule
    - GetPersistentVehicles(): Récupérer les véhicules persistants
    - LocateVehicle(plate): Localiser un véhicule sur la carte
    
    Exports Serveur:
    - SaveVehicle(plate, data): Sauvegarder un véhicule
    - GetSpawnedVehicles(): Récupérer les véhicules spawnés
    - RegisterPlayerVehicle(plate, netId, citizenid): Enregistrer un véhicule joueur
    - UnregisterPlayerVehicle(plate): Désenregistrer un véhicule
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vAvA_core_persist'
description 'Module Persist - Persistance des véhicules sur la carte'
version '1.0.0'
author 'vAvA'

-- Dépendances
dependencies {
    'vAvA_core',
    'oxmysql'
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
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}
