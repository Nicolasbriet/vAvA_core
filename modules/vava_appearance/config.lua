--[[
    vava_appearance/config.lua
    Rôle : réglages de l'apparence que lit le seul serveur (servi au seul serveur, jamais téléchargé par les
           joueurs) : version du core, bornes du schéma d'une apparence, débit des créations. Complète la table
           ouverte par config_client.lua (emplacements proposés, apparences de départ) sans en réécrire une clé
           (T-132).
    Dépendances : shared/constants.lua, config_client.lua
]]

local config = VavaAppearance.config

config.coreVersion = '0.3.0'

-- Bornes de validation côté serveur (le client connaît les vraies limites du modèle). Larges pour accepter
-- les packs de vêtements ajoutés plus tard.
config.maxDrawable = 2000
config.maxTexture = 255

config.createRateLimit = { capacity = 2, refillPerSecond = 0.05 }
