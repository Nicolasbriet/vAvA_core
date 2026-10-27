--[[
    vava_world/shared/constants.lua
    Rôle : table du module (seule globale de la ressource) et constantes du jeu.
    Dépendances : aucune
]]

VavaWorld = {}

-- Types de population de GTA (ePopulationType) créés par le jeu lui-même : passants, véhicules garés, patrouilles,
-- PNJ de scénario, circulation. Ceux des scripts (mission) et les joueurs n'en font pas partie.
VavaWorld.AMBIENT_TYPES = {
    [1] = true,   -- random permanent
    [2] = true,   -- random parked
    [3] = true,   -- random patrol
    [4] = true,   -- random scenario
    [5] = true,   -- random ambient
}

-- Services d'intervention de GTA (police, pompiers, ambulances, hélicoptères…), numérotés de 1 à 15.
VavaWorld.DISPATCH_SERVICES = 15
