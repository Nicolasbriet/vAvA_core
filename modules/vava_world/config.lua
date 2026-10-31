--[[
    vava_world/config.lua
    Rôle : réglages du monde que lit le seul serveur (servi au seul serveur, jamais téléchargé par les joueurs) :
           version du core, instances préparées au démarrage, nettoyage de la carte. Complète la table ouverte par
           config_client.lua (population, avis de recherche, sons) sans en réécrire une clé (T-132).
    Dépendances : shared/constants.lua, config_client.lua
]]

local config = VavaWorld.config

config.coreVersion = '0.5.0'

-- instances à préparer au démarrage (0 = le monde commun) ; les modules qui créent des instances appellent l'export
-- prepareBucket pour les leurs
config.population.buckets = { 0 }
-- au démarrage, retire ce que le jeu aurait déjà fait apparaître (module redémarré en cours de partie)
config.population.cleanupOnStart = true
