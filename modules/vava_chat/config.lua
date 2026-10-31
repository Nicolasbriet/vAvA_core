--[[
    vava_chat/config.lua
    Rôle : réglages du chat que lit le seul serveur (servi au seul serveur, jamais téléchargé par les joueurs) :
           portées, droit du canal du Conseil sans vava_admin, journal de modération, débits. Complète la table
           ouverte par config_client.lua (bornes d'un message, texte au-dessus de la tête, interface, touche,
           commandes, textes) sans en réécrire une clé (T-132).
    Dépendances : shared/constants.lua, config_client.lua
]]

local config = VavaChat.config

config.coreVersion = '0.5.0'

-- Portées (mètres, positions lues côté serveur, même monde de routage). Un texte tapé sans commande dans l'onglet
-- Général part en /ooc.
config.ranges = { ooc = 20.0, me = 15.0, ['do'] = 15.0 }

-- Sans vava_admin : permission ACE qui ouvre le canal du Conseil (/staff).
config.staff = { ace = 'vava_chat.staff' }

-- Journal pour la modération : genres gardés, durée, écriture par lots, effacement par tranches.
-- À mentionner dans le règlement du serveur.
config.log = {
    kinds = { ooc = true, mp = true, staff = true },
    retentionDays = 7,
    flushMs = 10000,
    batch = 50,
    maxQueued = 2000,   -- messages gardés en mémoire si la base ne répond plus (au-delà, les plus anciens sont perdus)
    purgeEveryMs = 3600000,
    purgeBatch = 5000,
    purgePauseMs = 200,
}

config.rateLimits = {
    send = { capacity = 6, refillPerSecond = 1 },
    profile = { capacity = 4, refillPerSecond = 0.2 },
    fallback = { capacity = 3, refillPerSecond = 0.5 },  -- réponses « commande inconnue »
}
