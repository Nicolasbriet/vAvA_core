--[[
    vava_time/config.lua
    Rôle : donnée de jeu du temps que lit le seul serveur (servi au seul serveur, jamais téléchargé par les joueurs) :
           décalage permis au Conseil, nuits de gel, Conseil, outil du Registre, pont du web, boucle lente, débits.
           Complète la table ouverte par config_client.lua (horloge, calendrier et saisons, ciels, commandes,
           réglages du client, textes) sans en réécrire une clé (T-132). Modifiable sans toucher au code. Durées en
           millisecondes sauf mention contraire.
    Dépendances : shared/constants.lua, config_client.lua
]]

local config = VavaTime.config

config.coreVersion = '0.7.0'          -- registre des commandes core:commands

-- Heure du royaume : décalage permis au Conseil (le rythme de l'horloge est dans config_client.lua).
config.clock.maxShiftMinutes = 720    -- décalage permis : ± 12 h

-- Nuits de gel. Chaque jour d'une saison listée, la nuit gèle avec cette probabilité (tirée une fois par jour, au
-- premier passage de la boucle). Au soir (`warnHour`, heure du royaume), les modules sont prévenus (hook
-- vava_time:frostWarning : l'agriculture avertit les cultivateurs concernés) ; à la tombée de la nuit (`hour`), le gel
-- frappe (hook vava_time:frost : l'agriculture perd les cultures ni couvertes ni résistantes). Une heure déjà passée
-- au démarrage du module ne déclenche rien. Du tirage jusqu'au gel, la nuit est annoncée à tous par le monde : une
-- ligne de /date (`messages.frostTonight`) et la fiche des plantes de l'agriculture.
-- Réglages décidés par le porteur du projet (30 octobre 2026) : hiver seulement, 0,4, soir à 17 h, gel à 21 h.
config.frost = { seasons = { hiver = 0.4 }, warnHour = 17, hour = 21 }

-- Conseil : droit vava_admin de l'outil, de /ciel et des décisions prises depuis la Chancellerie (la lecture y
-- demande `view`, vérifié par le pont) ; transition d'un ciel imposé (s) ; débit commun à toutes les décisions, en
-- jeu comme depuis la Chancellerie (au-delà : « Doucement… »).
config.council = { permission = 'tools', fadeSeconds = 20, rate = { capacity = 6, refillPerSecond = 0.5 } }
config.tool = {
    label = 'Ciel et heure',
    hint = 'Heure, saison et ciel du royaume : décaler ou figer l\'heure, imposer un ciel, rendre la main.',
}

-- Chancellerie (panneau web) : seule ressource admise aux exports web*.
config.web = { bridge = 'vava_chancellerie' }

config.server = { tickMs = 15000 }    -- boucle lente : fin d'un ciel, changement de jour ou de saison

config.rateLimits = {
    sync = { capacity = 6, refillPerSecond = 0.1 },
    open = { capacity = 5, refillPerSecond = 1 },
    clock = { capacity = 6, refillPerSecond = 0.5 },
    weather = { capacity = 6, refillPerSecond = 0.5 },
}
