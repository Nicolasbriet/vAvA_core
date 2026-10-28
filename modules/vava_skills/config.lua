--[[
    vava_skills/config.lua
    Rôle : toute la donnée de jeu des compétences (lue par le client et le serveur) : compétences et catégories, rangs,
           courbe d'XP, savoir commun et budget, rouille, rendements décroissants, pénurie, mentorat et Renommée,
           Arcanes, leçons et savoirs perdus, journal, droits du Conseil, touches, textes. Modifiable sans toucher au
           code. Les durées sont en millisecondes sauf mention contraire.
    Dépendances : shared/constants.lua
]]

VavaSkills.config = {
    coreVersion = '0.6.0',                           -- temps de jeu des personnages (playSeconds)
    dependencies = { vava_inventory = '1.4.0' },     -- fragments de savoirs perdus (objets utilisables)

    -- Compétences, dans l'ordre d'affichage. `mentoredOnly` : ne progresse qu'en présence de son mentor (Arcanes).
    skills = {
        { id = 'bucheronnage', label = 'Bûcheronnage', category = 'recolte' },
        { id = 'minage', label = 'Minage', category = 'recolte' },
        { id = 'herboristerie', label = 'Herboristerie', category = 'recolte' },
        { id = 'peche', label = 'Pêche', category = 'recolte' },
        { id = 'chasse', label = 'Chasse', category = 'recolte' },
        { id = 'agriculture', label = 'Agriculture', category = 'terre' },
        { id = 'forge', label = 'Forge', category = 'transformation' },
        { id = 'menuiserie', label = 'Menuiserie', category = 'transformation' },
        { id = 'tissage', label = 'Tissage et couture', category = 'transformation' },
        { id = 'tannerie', label = 'Tannerie', category = 'transformation' },
        { id = 'alchimie', label = 'Alchimie', category = 'transformation' },
        { id = 'cuisine', label = 'Cuisine', category = 'transformation' },
        { id = 'arcanes', label = 'Arcanes', category = 'savoir', mentoredOnly = true },
    },
    categories = {
        { id = 'recolte', label = 'Récolte' },
        { id = 'terre', label = 'Terre' },
        { id = 'transformation', label = 'Transformation' },
        { id = 'savoir', label = 'Savoir' },
    },

    -- Rangs, par niveau minimal croissant.
    ranks = {
        { name = 'novice', label = 'Novice', min = 0 },
        { name = 'apprenti', label = 'Apprenti', min = 20 },
        { name = 'compagnon', label = 'Compagnon', min = 40 },
        { name = 'artisan', label = 'Artisan', min = 60 },
        { name = 'maitre', label = 'Maître', min = 80 },
        { name = 'grand_maitre', label = 'Grand Maître', min = 95 },
    },

    levels = {
        max = 100,
        commonKnowledge = 20,      -- points libres par compétence (« savoir commun »), hors budget et hors rouille
        budget = 200,              -- points au-delà du savoir commun, toutes compétences confondues ; à augmenter, jamais baisser
    },

    xp = {
        -- XP pour passer du niveau n au suivant : floor(base + square × n²) → 50 au niveau 0, 3 800 au niveau 50,
        -- 14 751 au niveau 99 ; ~500 000 XP pour atteindre 100.
        base = 50,
        square = 1.5,
        defaultAmount = 10,        -- XP de base d'une action quand le module appelant n'en donne pas
        maxPerAction = 500,        -- XP de base acceptée par action (après multiplicateurs : bornée à maxGainPerAction)
        maxGainPerAction = 1000,
        -- rendements décroissants : une action de difficulté très inférieure au niveau rapporte de moins en moins.
        -- Plein tant que niveau − difficulté ≤ margin ; décroît linéairement jusqu'à floor à margin + span ; floor au-delà.
        diminishing = { margin = 10, span = 30, floor = 0.1 },
    },

    -- Rouille : au plafond, un point gagné en `up` retire un point à une compétence `down` au-dessus du savoir commun.
    -- pick : highest (la plus haute), recent (la dernière pratiquée), random (au hasard).
    rust = { pick = 'highest' },

    -- Métiers en pénurie : compétence où moins de minPlayers personnages actifs (joués depuis activeDays jours)
    -- atteignent minRank → l'XP y est multipliée. Aucune pénurie tant que le royaume compte moins de minActivePlayers
    -- personnages actifs (lancement du serveur : tout serait en pénurie). Recalcul au démarrage puis toutes les refreshMs.
    shortages = { minPlayers = 2, minActivePlayers = 10, activeDays = 14, minRank = 'compagnon', multiplier = 1.5, refreshMs = 1800000 },

    mentoring = {
        minRank = 'maitre',            -- rang pour proposer un mentorat (et pour enseigner une leçon)
        maxApprentices = 3,            -- par maître et par compétence
        bonus = 0.5,                   -- +50 % d'XP pour l'apprenti…
        radius = 20.0,                 -- …à moins de 20 m de son maître…
        recentMs = 600000,             -- …qui a lui-même pratiqué cette compétence depuis moins de 10 min
        proposalTtlMs = 60000,         -- une proposition non acceptée expire
        proposalRadius = 10.0,         -- distance maximale entre maître et apprenti au moment de proposer
        minTeachPlaySeconds = 36000,   -- temps de jeu (10 h) pour proposer un mentorat ou donner une leçon
        renown = {
            share = 0.10,              -- Renommée du maître = 10 % de l'XP bonifiée gagnée par l'apprenti…
            dailyCap = 100,            -- …plafonnée par jour UTC et par compétence…
            halfEvery = 200,           -- …et divisée par 2 tous les 200 points déjà rapportés par ce même apprenti
        },
    },

    -- Arcanes (et toute compétence `mentoredOnly`) : aucune progression sans son mentor dans cette compétence à portée.
    arcanes = { masterRadius = 30.0 },

    lessons = {
        required = 3,                  -- leçons pour apprendre une recette transmise
        minIntervalMs = 3600000,       -- délai minimal entre deux leçons d'une même recette (1 h)
        radius = 10.0,                 -- l'élève assiste à la réalisation : à moins de 10 m
    },

    persistence = { flushMs = 10000 }, -- écriture groupée des fiches modifiées
    logRetentionDays = 180,            -- journal vava_skills_log, purgé au démarrage

    admin = {
        permission = 'metiers',        -- droit vava_admin : corriger une compétence, donner une recette, voir une fiche
        founderPermission = 'staff',   -- droit vava_admin : nommer un fondateur (rang et recettes initiaux)
        ace = 'metiers.admin',         -- sans vava_admin : permission ACE (la console l'a toujours)
        commands = { metiers = 'metiers', founder = 'vava_fondateur' },
    },

    -- Touche par défaut, réglable par le joueur (Paramètres > Raccourcis > FiveM).
    keys = { open = 'K' },
    labels = { open = 'Ouvrir le livre des compétences' },

    rateLimits = {
        sheet = { capacity = 3, refillPerSecond = 0.5 },
        mode = { capacity = 6, refillPerSecond = 2 },
        mentor = { capacity = 3, refillPerSecond = 0.2 },
        lineage = { capacity = 4, refillPerSecond = 0.5 },
        shortages = { capacity = 3, refillPerSecond = 0.5 },
    },

    -- Textes des notifications (serveur → joueur). %s : compétence, rang, nom ; %d : niveau.
    messages = {
        levelUp = '%s : niveau %d.',
        rankUp = '%s : vous êtes désormais %s.',
        capReached = 'Vous avez atteint votre plafond : marquez une compétence à oublier (↓) pour progresser encore.',
        rusted = '%s : niveau %d (oubli).',
        locked = '%s : compétence verrouillée (=), aucune progression.',
        noMaster = '%s : ce savoir ne progresse qu\'auprès de votre maître.',
        proposalReceived = '%s vous propose de devenir votre maître en %s. Ouvrez le livre (%s) pour répondre.',
        proposalSent = 'Proposition de mentorat envoyée à %s.',
        proposalExpired = 'La proposition de mentorat de %s a expiré.',
        mentorshipStarted = '%s est désormais votre %s en %s.',   -- nom, maître | apprenti, compétence
        mentorshipEnded = 'Votre mentorat en %s avec %s a pris fin.',
        lessonGiven = 'Leçon donnée à %s : %s (%d/%d).',
        lessonReceived = 'Leçon de %s : %s (%d/%d).',
        recipeLearned = 'Vous maîtrisez désormais : %s.',
        fragmentFound = 'Fragment réuni : %s (%d/%d).',
        unavailable = 'Le livre des compétences est indisponible pour le moment.',
        roles = { master = 'maître', apprentice = 'apprenti' },
    },
}
