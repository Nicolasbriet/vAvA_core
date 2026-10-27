--[[
    vava_health/config.lua
    Rôle : configuration de la santé, de la mise à terre et de la réanimation (lue par le client et le serveur).
           Vie exprimée de 0 à 1 : part de la vie située au-dessus du seuil de mise à terre.
    Dépendances : shared/constants.lua
]]

VavaHealth.config = {
    coreVersion = '0.4.0',

    downThreshold = 100,        -- vie GTA à laquelle un joueur est à terre (seuil « blessé mortellement » du jeu)
    initial = 1.0,              -- vie d'un nouveau personnage
    naturalRegen = false,       -- récupération automatique de GTA : coupée, on se soigne par objets ou réanimation

    -- Serveur : lecture de la vie des joueurs en jeu (une native par joueur) ; le client n'a rien à déclarer.
    pollMs = 500,
    sampleMs = 10000,           -- enregistrement de la vie dans le personnage
    sampleEpsilon = 0.01,       -- écart minimal pour la réécrire
    graceMs = 3000,             -- après une apparition ou une réanimation, la vie lue côté serveur peut être en retard

    downed = {
        giveUpAfterMs = 180000, -- rendre l'âme possible après 3 minutes
        autoRespawnMs = 600000, -- porté d'office au lieu de soins après 10 minutes
        resendMs = 5000,        -- relevé sans l'accord du serveur (désynchronisation, triche) : remis à terre
    },

    assist = {
        distance = 2.0,         -- portée (m) pour relever quelqu'un, lue côté serveur
        tolerance = 1.0,        -- marge (m) acceptée à la fin du geste
        durationMs = 8000,
        health = 0.25,          -- vie après une réanimation
        item = nil,             -- objet requis et consommé (ex. 'bandage') ; nil : aucun, en attendant les métiers
        gesture = { dict = 'amb@medic@standing@tendtodead@base', clip = 'base', flag = 1 },
    },

    respawn = {
        health = 0.5,           -- vie après avoir rendu l'âme
        holdMs = 3000,          -- touche à maintenir : pas de retour par erreur
        -- Lieux de soins, provisoires en attendant la carte médiévale : le plus proche est choisi.
        points = {
            { x = 298.6, y = -584.5, z = 43.26, heading = 70.0 },
            { x = 1839.0, y = 3672.9, z = 34.28, heading = 210.0 },
        },
    },

    healing = { fullAt = 0.98 },  -- au-delà, un objet de soin est refusé (rien n'est gaspillé)

    client = {
        gaugePollMs = 500,      -- lecture locale de la vie pour la jauge (aucun échange réseau)
        animation = { blendIn = 8.0, blendOut = -8.0, loadTimeoutMs = 1000, loadPollMs = 10 },
        postFxDelayMs = 1500,   -- effets de mort de GTA coupés après leur démarrage
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

    rateLimits = {
        assist = { capacity = 3, refillPerSecond = 0.5 },
        giveUp = { capacity = 2, refillPerSecond = 0.2 },
    },

    -- Jauge de vava_hud (facultatif).
    hud = { label = 'Santé', icon = 'nui://vava_health/web/icons/health.svg', order = 5, low = 0.3, critical = 0.1 },
}
