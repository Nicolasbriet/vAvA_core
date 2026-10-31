--[[
    vava_health/config_client.lua
    Rôle : réglages de la santé que lit le client (le serveur les lit aussi). Vie exprimée de 0 à 1 : part de la vie
           située au-dessus du seuil de mise à terre. Seuil, vie de départ, récupération de GTA, délais à terre, geste
           de réanimation, touche à maintenir pour rendre l'âme, réglages du client, touches, messages, jauge.
           Téléchargé par chaque joueur. Ce que lit le seul serveur (relevés de la vie, chaîne de dégâts, envoi,
           apparition, contrôles natifs, journal, portée et vie de la réanimation, lieux de soins, soins, débits) est
           dans config.lua, servi au seul serveur (T-132).
    Dépendances : shared/constants.lua
]]

VavaHealth.config = {
    clientFile = true,  -- posé par ce fichier, ne pas changer (sans lui, le serveur signale un config.lua d'avant 1.5.0)

    downThreshold = 100,        -- vie GTA à laquelle un joueur est à terre (seuil « blessé mortellement » du jeu)
    initial = 1.0,              -- vie d'un nouveau personnage
    naturalRegen = false,       -- récupération automatique de GTA : coupée, on se soigne par objets ou réanimation

    downed = {
        giveUpAfterMs = 180000, -- rendre l'âme possible après 3 minutes
        autoRespawnMs = 600000, -- porté d'office au lieu de soins après 10 minutes
        resendMs = 5000,        -- relevé sans l'accord du serveur (désynchronisation, triche) : remis à terre
    },

    -- Relever quelqu'un : geste joué par le client. Portée, durée, vie rendue et objet requis : config.lua.
    assist = {
        gesture = { dict = 'amb@medic@standing@tendtodead@base', clip = 'base', flag = 1 },
    },

    -- Rendre l'âme : touche à maintenir. Vie rendue et lieux de soins : config.lua.
    respawn = {
        holdMs = 3000,          -- touche à maintenir : pas de retour par erreur
    },

    client = {
        gaugePollMs = 500,      -- lecture locale de la vie pour la jauge (aucun échange réseau)
        animation = { blendIn = 8.0, blendOut = -8.0, loadTimeoutMs = 1000, loadPollMs = 10 },
        postFxDelayMs = 1500,   -- effets de mort de GTA coupés après leur démarrage
        -- à chaque apparition : tir ami coupé (confort ; la garantie est l'annulation des coups natifs par le serveur)
        protect = true,
    },

    keys = { assist = 'G', giveUp = 'E' },
    labels = { assist = 'Relever une personne à terre', giveUp = 'Rendre l\'âme (à terre, maintenir)' },

    -- Messages au joueur (clé → texte) ; les refus du serveur arrivent sous forme de clé.
    messages = {
        downed_inventory = 'Vous êtes à terre.',
        not_injured = 'Vous n\'êtes pas blessé.',
        nobody = 'Personne n\'est à terre près de vous.',
        busy = 'Quelqu\'un s\'en occupe déjà.',
        missing_item = 'Il vous faut de quoi panser ses plaies.',
        downed = 'Vous êtes à terre.',
        cancelled = 'Le geste a été interrompu.',
        revived = 'Vous reprenez vos esprits.',
        helped = 'Vous avez relevé quelqu\'un.',
        too_early = 'Pas encore : tenez bon.',
        respawned = 'On vous a porté jusqu\'au lieu de soins.',
        rate_limited = 'Doucement…',
        default = 'Action impossible.',
    },

    -- Jauge de vava_hud (facultatif).
    hud = { label = 'Santé', icon = 'nui://vava_health/web/icons/health.svg', order = 5, low = 0.3, critical = 0.1 },
}
