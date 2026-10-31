--[[
    vava_time/config.lua
    Rôle : donnée de jeu du temps que lit le seul serveur (servi au seul serveur, jamais téléchargé par les joueurs) :
           décalage permis au Conseil, cours des ciels (successeurs, poids, durées, transition), nuits de gel, Conseil,
           outil du Registre, pont du web, boucle lente, débits. Complète la table ouverte par config_client.lua
           (horloge, calendrier et saisons, ciels, commandes, réglages du client, textes) sans en réécrire une clé
           (T-132). Modifiable sans toucher au code. Durées en millisecondes sauf mention contraire.
    Dépendances : shared/constants.lua, config_client.lua
]]

local config = VavaTime.config

config.coreVersion = '0.7.0'          -- registre des commandes core:commands

-- Heure du royaume : décalage permis au Conseil (le rythme de l'horloge est dans config_client.lua).
config.clock.maxShiftMinutes = 720    -- décalage permis : ± 12 h

-- Cours des ciels (les ciels eux-mêmes sont dans config_client.lua, `weather.types`) : ajouté à la table `weather`.
-- Un config_client.lua de 1.4.0 gardé par une mise à jour sert encore ces réglages aux joueurs : relevé avant de les
-- poser, signalé au démarrage ; ceux d'ici font foi (T-146).
VavaTime.legacyClientSky = config.weather.next ~= nil or config.weather.seasons ~= nil or config.weather.snow ~= nil
    or config.weather.durationMinutes ~= nil or config.weather.durations ~= nil or config.weather.fadeSeconds ~= nil
-- Ciels qui peuvent suivre chacun (le même compris : il dure alors une durée de plus). Si aucun n'est de saison, le
-- cycle tire parmi tous les ciels de la saison.
config.weather.next = {
    clair = { 'clair', 'soleil', 'nuages', 'brume', 'brouillard' },
    soleil = { 'soleil', 'clair', 'nuages', 'brume' },
    nuages = { 'nuages', 'clair', 'couvert', 'eclaircies', 'brouillard' },
    couvert = { 'couvert', 'nuages', 'pluie', 'brouillard', 'neige_legere' },
    eclaircies = { 'eclaircies', 'clair', 'nuages' },
    pluie = { 'pluie', 'couvert', 'orage', 'eclaircies' },
    orage = { 'pluie', 'eclaircies', 'couvert' },
    brume = { 'brume', 'clair', 'nuages' },
    brouillard = { 'brouillard', 'nuages', 'clair', 'couvert' },
    neige_legere = { 'neige_legere', 'neige', 'couvert', 'nuages' },
    neige = { 'neige', 'neige_legere', 'tempete', 'couvert' },
    tempete = { 'neige', 'neige_legere' },
    neige_au_sol = { 'neige_au_sol', 'neige_legere', 'couvert' },
}
-- Poids de chaque ciel par saison ; absent ou 0 : jamais tiré par le cycle dans cette saison.
config.weather.seasons = {
    printemps = { clair = 3, soleil = 1, nuages = 3, couvert = 2, eclaircies = 2, pluie = 3, orage = 1, brouillard = 1 },
    ete = { clair = 4, soleil = 4, nuages = 2, couvert = 1, eclaircies = 1, pluie = 1, orage = 1, brume = 1 },
    automne = { clair = 2, nuages = 3, couvert = 3, eclaircies = 1, pluie = 3, orage = 1, brouillard = 2, brume = 1 },
    hiver = { clair = 2, nuages = 2, couvert = 3, pluie = 1, brouillard = 2, neige_legere = 2, neige = 1, tempete = 0.3 },
}
config.weather.snow = true                                  -- false : le cycle ne tire aucun ciel de neige
config.weather.durationMinutes = { 25, 50 }                 -- durée d'un ciel, tirée dans la fourchette
config.weather.durations = { orage = { 10, 20 }, tempete = { 10, 20 } }
config.weather.fadeSeconds = 90                             -- transition d'un ciel à l'autre (cycle)

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
