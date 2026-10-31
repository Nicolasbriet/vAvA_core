--[[
    vava_farming/config.lua
    Rôle : donnée de jeu de l'agriculture lue par le seul serveur (servi au seul serveur, jamais téléchargé par les
           joueurs) : croissance, saisons, gel, fertilité, qualité, graines, seau, compost, outils, tolérances des
           gestes, battement d'abonnement des parcelles, journal, droits, débits, objets déclarés, parcelles et grenier,
           composteur ajouté à l'artisanat, textes. Complète la table ouverte par config_client.lua (gestes, distance
           d'interaction, streaming, touche, cultures, puits, animations) sans en réécrire une clé (T-132). Modifiable
           sans toucher au code.
    Les parcelles sont des EXEMPLES autour du point d'apparition par défaut ; les durées de croissance (cultures,
    config_client.lua) sont courtes pour les essais (minutes) : à rallonger pour le royaume.
    Dépendances : shared/constants.lua, config_client.lua
]]

local config = VavaFarming.config

config.coreVersion = '0.11.0'   -- abonnements de zone (core.zones) : chaque parcelle est une zone du core
config.dependencies = { vava_inventory = '1.4.0', vava_skills = '1.0.0', vava_gathering = '1.0.0', vava_crafting = '1.1.0' }

-- Croissance : la plante pousse tant que l'humidité dépasse le seuil ; sèche, elle marque une pause, flétrit après
-- wiltAfterHours de sécheresse continue, meurt après dieAfterHours. Arroser une plante flétrie la fait repartir.
config.growth = { moistureThreshold = 20, wiltAfterHours = 6, dieAfterHours = 18 }

-- Saisons du royaume (vava_time, facultatif : sans lui, aucun effet). `growth` multiplie la vitesse de pousse,
-- `drying` celle à laquelle la terre sèche (1 : sans effet ; 0 : arrêt ; une valeur invalide compte pour 1).
-- L'hiver, une culture met quatre fois plus longtemps, mais un arrosage tient quatre fois plus ; l'été assoiffe :
-- il faut arroser plus souvent. Une saison absente de la liste est sans effet.
config.seasons = {
    printemps = { growth = 1.25, drying = 1.0 },
    ete = { growth = 1.0, drying = 1.5 },
    automne = { growth = 0.75, drying = 0.75 },
    hiver = { growth = 0.25, drying = 0.25 },
}

-- Gel (vava_time, facultatif ; règles décidées par le porteur du projet le 30 octobre 2026). L'hiver, certaines
-- nuits gèlent (la probabilité est réglée dans vava_time). Dès que la nuit est tirée, le monde l'annonce : une ligne
-- de /date (vava_time) et `messages.frostTonight` sur la fiche des plantes. Au soir d'une nuit de gel, les
-- cultivateurs concernés sont avertis : le propriétaire en jeu d'une parcelle privée, les joueurs à moins de
-- `warnRadius` mètres d'une parcelle commune (rien n'est envoyé aux autres) ; à la tombée de la nuit, toute plante
-- vivante ni couverte ni d'une culture `frostHardy` meurt (le chou seul y résiste).
-- Couvrir un emplacement (geste « Couvrir ») consomme UN des objets de `cover`, le premier dans l'ordre de la liste
-- que le cultivateur a en quantité suffisante, et protège la plante jusqu'à sa récolte ou son arrachage : d'abord un
-- paillis de déchets végétaux (deux par plante), le compost (un) en secours. On ne couvre qu'en `coverSeasons`
-- (l'automne pour se préparer, l'hiver) : hors de ces saisons, ou sans vava_time, aucun gel n'est à craindre.
config.frost = {
    cover = {
        { item = 'dechets_vegetaux', quantity = 2 },
        { item = 'compost', quantity = 1 },
    },
    coverSeasons = { 'automne', 'hiver' },
    warnRadius = 60.0,
}

-- Fertilité (0–100 par emplacement) : rendue par la jachère (par jour vide), le compost, la rotation (famille
-- différente de la culture précédente) ; pénalité quand on replante la même famille.
config.fertility = { fallowPerDay = 10, compostBonus = 25, rotationBonus = 10, sameFamilyPenalty = 10, initial = 80 }

-- Qualité d'une récolte = graine × 0,35 + compétence × 0,35 + régularité d'arrosage × 0,15 + fertilité × 0,15 ± jitter.
config.quality = {
    weights = { seed = 0.35, skill = 0.35, watering = 0.15, fertility = 0.15 },
    jitter = 5,
    tiers = { 20, 40, 60, 85 },
    tierLabels = { 'Grossier', 'Commun', 'Soigné', 'Excellent', 'Chef-d\'œuvre' },
    materialQuality = { 10, 30, 50, 72, 92 },
    origin = true,              -- écrire le nom de la parcelle (provenance) sur les piles récoltées
    plantXpShare = 0.25,        -- XP de la plantation : part de l'XP de la culture
}

-- Graines récupérées à la récolte : chance de base + par niveau d'Agriculture, bornée ; 1 à `max` graines au palier
-- de la récolte.
config.seeds = { baseChance = 0.3, perLevel = 0.005, maxChance = 0.9, count = { 1, 2 } }

-- Seau : objet tenu en main, charges en métadonnée `water`, rempli aux puits.
config.bucket = { item = 'seau', charges = 5 }
-- Compost : un par application. Déchets végétaux : rendus par une plante arrachée (flétrie ou morte).
config.compost = { item = 'compost', waste = { item = 'dechets_vegetaux', count = { 1, 2 } } }
-- Outils reconnus en main.
config.tools = { seau = { kind = 'seau' }, faucille_fer = { kind = 'faucille' } }

-- Tolérances des gestes, lues par le seul serveur : ajoutées à `interact` (config_client.lua), dont le client lit la
-- distance et l'annulation au mouvement (relecture sécurité S-5 de T-132).
config.interact.serverTolerance = 1.5
config.interact.expireMs = 30000
config.interact.finishToleranceMs = 400

-- Une parcelle (emplacements, état des plantes, grenier) n'est connue que des joueurs à moins de son rayon +
-- `streaming.radius` (config_client.lua) + `subscribeSlack` mètres (abonnements de zone du core, positions lues par le
-- serveur une fois par seconde) : le battement couvre le chemin d'un cavalier au galop entre deux passages, pour que la
-- parcelle soit connue avant que ses props doivent apparaître (une parcelle reçue fait aussitôt un passage du client :
-- seule l'attente du core compte). Il doit valoir au moins vitesse maximale × `zones.passMs` du core + 5 m (20 m :
-- cavalier au galop, ~15 m/s, avec passMs = 1000 ; 35 m avec passMs = 2000 ou pour une monture plus rapide). Le
-- joueur l'oublie 25 m plus loin (`zones.exitMargin` du core). Lu par le seul serveur : ajouté à `streaming`.
config.streaming.subscribeSlack = 20.0

-- écriture groupée ; journal du grenier en attente (lignes par minute) borné à granaryLogMax : plein, il s'écrit
-- aussitôt, et ce qui ne tient plus pendant une panne de la base est perdu (signalé)
config.persistence = { flushMs = 10000, granaryLogMax = 2000 }
config.logRetentionDays = 90
config.logTier = 4

config.admin = { permission = 'metiers', ace = 'metiers.admin', command = 'agriculture' }

config.rateLimits = {
    open = { capacity = 4, refillPerSecond = 1 },
    begin = { capacity = 4, refillPerSecond = 1 },
    cancel = { capacity = 4, refillPerSecond = 1 },
    finish = { capacity = 4, refillPerSecond = 1 },
    fill = { capacity = 3, refillPerSecond = 0.5 },
    granary = { capacity = 3, refillPerSecond = 0.5 },
}

-- Objets déclarés à l'inventaire par ce module. Images : web/items/<nom>.svg.
config.items = {
    graine_ble = { label = 'Graines de blé', description = 'Une poignée de grains à semer.', width = 1, height = 1, weight = 50, stack = 40, category = 'materiau' },
    graine_carotte = { label = 'Graines de carotte', description = 'Minuscules, dans un sachet de toile.', width = 1, height = 1, weight = 20, stack = 40, category = 'materiau' },
    graine_chou = { label = 'Graines de chou', description = 'Rondes et noires.', width = 1, height = 1, weight = 20, stack = 40, category = 'materiau' },
    graine_lin = { label = 'Graines de lin', description = 'Brunes et luisantes.', width = 1, height = 1, weight = 30, stack = 40, category = 'materiau' },
    ble = { label = 'Gerbe de blé', description = 'Épis dorés liés d\'un brin.', width = 1, height = 2, weight = 600, stack = 20, category = 'materiau' },
    carotte = { label = 'Carotte', description = 'Croquante, encore terreuse.', width = 1, height = 1, weight = 120, stack = 20, category = 'nourriture', effects = { hunger = 8 } },
    chou = { label = 'Chou', description = 'Une pomme serrée et lourde.', width = 2, height = 2, weight = 1200, stack = 10, category = 'nourriture', effects = { hunger = 15 } },
    lin = { label = 'Lin', description = 'Tiges à rouir pour la fibre.', width = 1, height = 2, weight = 400, stack = 20, category = 'materiau' },
    seau = { label = 'Seau', description = 'Bois cerclé de fer, pour puiser l\'eau.', width = 2, height = 2, weight = 1500, stack = 1, category = 'outil',
        held = { model = 'prop_bucket_01a', offset = { 0.05, 0.0, -0.1 }, rotation = { 0.0, 0.0, 0.0 } } },
    compost = { label = 'Compost', description = 'Noir, gras, odorant : la terre en redemande.', width = 1, height = 1, weight = 800, stack = 20, category = 'materiau' },
    dechets_vegetaux = { label = 'Déchets végétaux', description = 'Tiges flétries et feuilles mortes.', width = 1, height = 1, weight = 300, stack = 30, category = 'materiau' },
}

-- Parcelles : grille d'emplacements (lignes × colonnes, espacement en m) centrée et orientée ; `owner` nul =
-- communale ; `granary` : grenier commun (conteneur conservé) et son lieu. EXEMPLES. Le nom (`label`) d'une
-- parcelle et celui de son grenier sont publics : envoyés à tout joueur proche avec sa définition (jamais le
-- propriétaire ni le contenu du grenier).
config.parcels = {
    { id = 'champ_communal', label = 'Champ communal', x = -230.0, y = -890.0, z = 31.2, heading = 0.0, rows = 3, cols = 4, spacing = 1.6,
        granary = { x = -222.0, y = -885.0, z = 31.2, label = 'Grenier commun', width = 10, height = 8, maxWeight = 200000, prop = 'prop_crate_11e' } },
    { id = 'jardin_prive', label = 'Jardin privé', x = -240.0, y = -905.0, z = 31.2, heading = 30.0, rows = 2, cols = 3, spacing = 1.6,
        owner = { kind = 'character', id = 1 } },
}

-- Composteur : type de station et recette ajoutés aux registres de vava_crafting, station placée par addStation.
config.composter = {
    type = { id = 'composteur', label = 'Composteur', skills = { 'agriculture' }, anim = 'tan', prop = 'prop_rub_binbag_01' },
    recipe = { id = 'compost', label = 'Compost', skill = 'agriculture', level = 0, station = 'composteur', durationMs = 6000, difficulty = 5, xp = 6,
        ingredients = { { item = 'dechets_vegetaux', quantity = 3 } }, output = { item = 'compost', quantity = 1 } },
    station = { id = 'composteur_communal', label = 'Composteur du champ', x = -224.0, y = -895.0, z = 31.2, quality = 50 },
}

-- Textes des notifications (serveur → joueur). %s : libellé, %d : nombre.
config.messages = {
    planted = '%s semé.',
    watered = 'Arrosé (%d charge(s) restante(s)).',
    fertilized = 'Compost épandu : fertilité %d %%.',
    harvested = '%s : %d × %s (%s).',                -- culture, quantité, produit, palier
    seedsBack = 'Et %d graine(s) récupérée(s).',
    cleared = 'Emplacement dégagé.',
    clearedWaste = 'Emplacement dégagé : %d déchets végétaux.',
    clearedLost = 'Emplacement dégagé. Besace pleine : les déchets végétaux sont perdus.',
    filled = 'Seau rempli (%d charges).',
    bucketEmpty = 'Votre seau est vide : remplissez-le à un puits.',
    noBucket = 'Il vous faut un seau en main.',
    noCompost = 'Il vous faut du compost.',
    noSeed = 'Il vous manque des graines.',
    occupied = 'Cet emplacement est déjà planté.',
    empty = 'Rien ne pousse ici.',
    notRipe = '%s n\'est pas mûr (%d %%).',
    dead = 'La plante est morte : arrachez-la.',
    noAccess = 'Cette parcelle ne vous appartient pas.',
    noSpace = 'Vous ne pouvez rien porter de plus.',
    granaryOpened = 'Grenier commun ouvert.',
    -- gel (vava_time) : couvrir une plante, gel annoncé sur la fiche, avertissement du soir, plantes perdues ;
    -- %s : objets qui couvrent (chacun écrit par `coverItem`, joints par `coverOr`), parcelle(s) (jointes par
    -- `parcelSeparator`)
    covered = 'Plante couverte : elle passera les nuits de gel.',
    alreadyCovered = 'Cette plante est déjà couverte.',
    frostHardy = 'Cette culture ne craint pas le gel : inutile de la couvrir.',
    offSeason = 'Aucun gel à craindre en cette saison.',
    noCover = 'Il vous faut de quoi couvrir la plante (%s).',
    coverItem = '%d × %s',
    coverOr = ' ou ',
    frostTonight = 'gel annoncé cette nuit',
    parcelSeparator = ', ',
    frostWarning = 'Le froid mordra cette nuit (%s) : couvrez les cultures fragiles ou elles gèleront.',
    frostStruck = 'Le gel a pris %d plante(s) cette nuit (%s).',
}
