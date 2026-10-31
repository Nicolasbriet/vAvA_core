--[[
    vava_needs/config.lua
    Rôle : réglages des besoins que lit le seul serveur (servi au seul serveur, jamais téléchargé par les joueurs) :
           version du core, boucle de baisse, activité, consommation (refus d'un objet, textes, geste par
           catégorie). Complète la table ouverte par config_client.lua (besoins, paliers, vie, endurance, gestes,
           jauges) sans en réécrire une clé (T-132).
    Dépendances : shared/constants.lua, config_client.lua
]]

local config = VavaNeeds.config

config.coreVersion = '0.3.0'

-- Boucle serveur : un seul passage pour tous les personnages actifs. La baisse n'a lieu qu'en jeu : ni hors
-- connexion, ni pendant la sélection du personnage.
config.tickMs = 60000

-- Activité lue côté serveur entre deux passages : la part du temps passé à courir accélère la baisse.
-- En véhicule, la vitesse est celle du véhicule : elle ne compte pas.
config.activity = { sampleMs = 15000, runningSpeed = 4.0, runningMultiplier = 1.5 }

-- Manger et boire : la durée du geste (`consumption.cooldownMs`) est dans config_client.lua.
config.consumption.fullAt = 95                          -- au-delà, l'objet est refusé : rien n'est gaspillé
config.consumption.fullMessage = 'Vous êtes rassasié.'  -- objet qui nourrit et désaltère, les deux déjà pleins
config.consumption.busyMessage = 'Vous n\'avez pas encore fini.'
config.consumption.gestureByCategory = { nourriture = 'eat', boisson = 'drink' }
config.consumption.defaultGesture = 'eat'
