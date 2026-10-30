--[[
    vava_farming/config.lua
    Rôle : toute la donnée de jeu de l'agriculture (lue par le client et le serveur) : croissance, fertilité, qualité,
           graines, gestes et leurs durées, seau et puits, outils, cultures, objets déclarés, parcelles et grenier, puits,
           composteur ajouté à l'artisanat, animations, droits, touches, textes. Modifiable sans toucher au code.
    Les parcelles, puits et modèles de props sont des EXEMPLES autour du point d'apparition par défaut ; les durées de
    croissance sont courtes pour les essais (minutes) : à rallonger pour le royaume.
    Dépendances : shared/constants.lua
]]

VavaFarming.config = {
    coreVersion = '0.6.0',
    dependencies = { vava_inventory = '1.4.0', vava_skills = '1.0.0', vava_gathering = '1.0.0', vava_crafting = '1.1.0' },

    -- Croissance : la plante pousse tant que l'humidité dépasse le seuil ; sèche, elle marque une pause, flétrit après
    -- wiltAfterHours de sécheresse continue, meurt après dieAfterHours. Arroser une plante flétrie la fait repartir.
    growth = { moistureThreshold = 20, wiltAfterHours = 6, dieAfterHours = 18 },

    -- Saisons du royaume (vava_time, facultatif : sans lui, aucun effet). `growth` multiplie la vitesse de pousse,
    -- `drying` celle à laquelle la terre sèche (1 : sans effet ; 0 : arrêt ; une valeur invalide compte pour 1).
    -- L'hiver, une culture met quatre fois plus longtemps, mais un arrosage tient quatre fois plus ; l'été assoiffe :
    -- il faut arroser plus souvent. Une saison absente de la liste est sans effet.
    seasons = {
        printemps = { growth = 1.25, drying = 1.0 },
        ete = { growth = 1.0, drying = 1.5 },
        automne = { growth = 0.75, drying = 0.75 },
        hiver = { growth = 0.25, drying = 0.25 },
    },

    -- Gel (vava_time, facultatif) : au soir d'une nuit de gel, les cultivateurs concernés sont avertis (propriétaire en
    -- jeu d'une parcelle privée, joueurs à `warnRadius` mètres d'une parcelle) ; à la tombée de la nuit, toute plante ni
    -- couverte ni d'une culture `frostHardy` meurt. Couvrir un emplacement (geste « Couvrir ») consomme `cover` et le
    -- protège jusqu'à la récolte ou l'arrachage. Aucun objet « paille » n'existe encore dans le royaume : le compost en
    -- tient lieu (à changer ici le jour où la paille existe).
    frost = { cover = { item = 'compost', quantity = 1 }, warnRadius = 60.0 },

    -- Fertilité (0–100 par emplacement) : rendue par la jachère (par jour vide), le compost, la rotation (famille
    -- différente de la culture précédente) ; pénalité quand on replante la même famille.
    fertility = { fallowPerDay = 10, compostBonus = 25, rotationBonus = 10, sameFamilyPenalty = 10, initial = 80 },

    -- Qualité d'une récolte = graine × 0,35 + compétence × 0,35 + régularité d'arrosage × 0,15 + fertilité × 0,15 ± jitter.
    quality = {
        weights = { seed = 0.35, skill = 0.35, watering = 0.15, fertility = 0.15 },
        jitter = 5,
        tiers = { 20, 40, 60, 85 },
        tierLabels = { 'Grossier', 'Commun', 'Soigné', 'Excellent', 'Chef-d\'œuvre' },
        materialQuality = { 10, 30, 50, 72, 92 },
        origin = true,              -- écrire le nom de la parcelle (provenance) sur les piles récoltées
        plantXpShare = 0.25,        -- XP de la plantation : part de l'XP de la culture
    },

    -- Graines récupérées à la récolte : chance de base + par niveau d'Agriculture, bornée ; 1 à `max` graines au palier
    -- de la récolte.
    seeds = { baseChance = 0.3, perLevel = 0.005, maxChance = 0.9, count = { 1, 2 } },

    -- Gestes : durée du geste (le serveur applique à la fin) et animation. La faucille en main accélère la récolte.
    actions = {
        plant = { durationMs = 3000, anim = 'plant' },
        water = { durationMs = 2500, anim = 'water' },
        fertilize = { durationMs = 2500, anim = 'plant' },
        harvest = { durationMs = 4500, anim = 'harvest', sickleFactor = 0.6 },
        clear = { durationMs = 3000, anim = 'plant' },
        cover = { durationMs = 3000, anim = 'plant' },
    },

    -- Seau : objet tenu en main, charges en métadonnée `water`, rempli aux puits.
    bucket = { item = 'seau', charges = 5 },
    -- Compost : un par application. Déchets végétaux : rendus par une plante arrachée (flétrie ou morte).
    compost = { item = 'compost', waste = { item = 'dechets_vegetaux', count = { 1, 2 } } },
    -- Outils reconnus en main.
    tools = { seau = { kind = 'seau' }, faucille_fer = { kind = 'faucille' } },

    interact = {
        distance = 2.0,
        serverTolerance = 1.5,
        expireMs = 30000,
        finishToleranceMs = 400,
        moveCancel = 1.5,
    },

    streaming = { radius = 80.0, pollMs = 1000, modelTimeoutMs = 5000 },
    -- écriture groupée ; journal du grenier en attente (lignes par minute) borné à granaryLogMax : plein, il s'écrit
    -- aussitôt, et ce qui ne tient plus pendant une panne de la base est perdu (signalé)
    persistence = { flushMs = 10000, granaryLogMax = 2000 },
    logRetentionDays = 90,
    logTier = 4,

    admin = { permission = 'metiers', ace = 'metiers.admin', command = 'agriculture' },

    keys = { interact = 'E' },
    labels = { interact = 'Cultiver (emplacement, puits ou grenier proche)' },

    rateLimits = {
        open = { capacity = 4, refillPerSecond = 1 },
        begin = { capacity = 4, refillPerSecond = 1 },
        cancel = { capacity = 4, refillPerSecond = 1 },
        finish = { capacity = 4, refillPerSecond = 1 },
        fill = { capacity = 3, refillPerSecond = 0.5 },
        granary = { capacity = 3, refillPerSecond = 0.5 },
    },

    -- Cultures : graine → produit ; durée (minutes), eau consommée par heure (points d'humidité), coût de fertilité par
    -- récolte, famille (rotation), rendement, XP, difficulté, props par stade (du semis au mûr ; le dernier n'apparaît qu'à
    -- maturité), prop flétri, prop mort ; `frostHardy` : résiste aux nuits de gel (vava_time) sans être couverte.
    crops = {
        ble = { label = 'Blé', family = 'cereale', seed = 'graine_ble', product = 'ble', growMinutes = 90, waterPerHour = 20, fertilityCost = 15,
            yield = { 3, 6 }, xp = 14, difficulty = 15,
            stages = { 'prop_plant_01b', 'prop_veg_crop_01', 'prop_veg_crop_tr_01' }, wilted = 'prop_veg_crop_02', dead = 'prop_veg_crop_02' },
        carotte = { label = 'Carotte', family = 'racine', seed = 'graine_carotte', product = 'carotte', growMinutes = 30, waterPerHour = 25, fertilityCost = 10,
            yield = { 2, 5 }, xp = 8, difficulty = 5,
            stages = { 'prop_plant_01b', 'prop_veg_crop_04_leaf' }, wilted = 'prop_veg_crop_02', dead = 'prop_veg_crop_02' },
        chou = { label = 'Chou', family = 'feuille', seed = 'graine_chou', product = 'chou', growMinutes = 45, waterPerHour = 30, fertilityCost = 12,
            yield = { 1, 3 }, xp = 10, difficulty = 10,
            stages = { 'prop_plant_01b', 'prop_veg_crop_03_cab' }, wilted = 'prop_veg_crop_02', dead = 'prop_veg_crop_02',
            frostHardy = true },
        lin = { label = 'Lin', family = 'fibre', seed = 'graine_lin', product = 'lin', growMinutes = 60, waterPerHour = 15, fertilityCost = 20,
            yield = { 2, 4 }, xp = 12, difficulty = 20,
            stages = { 'prop_plant_01b', 'prop_veg_crop_05', 'prop_veg_crop_tr_02' }, wilted = 'prop_veg_crop_02', dead = 'prop_veg_crop_02' },
    },

    -- Objets déclarés à l'inventaire par ce module. Images : web/items/<nom>.svg.
    items = {
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
    },

    -- Parcelles : grille d'emplacements (lignes × colonnes, espacement en m) centrée et orientée ; `owner` nul =
    -- communale ; `granary` : grenier commun (conteneur conservé) et son lieu. EXEMPLES.
    parcels = {
        { id = 'champ_communal', label = 'Champ communal', x = -230.0, y = -890.0, z = 31.2, heading = 0.0, rows = 3, cols = 4, spacing = 1.6,
            granary = { x = -222.0, y = -885.0, z = 31.2, label = 'Grenier commun', width = 10, height = 8, maxWeight = 200000, prop = 'prop_crate_11e' } },
        { id = 'jardin_prive', label = 'Jardin privé', x = -240.0, y = -905.0, z = 31.2, heading = 30.0, rows = 2, cols = 3, spacing = 1.6,
            owner = { kind = 'character', id = 1 } },
    },

    -- Puits : remplissent le seau tenu en main.
    wells = {
        { id = 'puits_bourg', label = 'Puits du bourg', x = -236.0, y = -897.0, z = 31.2, prop = 'prop_barrel_01a' },
    },

    -- Composteur : type de station et recette ajoutés aux registres de vava_crafting, station placée par addStation.
    composter = {
        type = { id = 'composteur', label = 'Composteur', skills = { 'agriculture' }, anim = 'tan', prop = 'prop_rub_binbag_01' },
        recipe = { id = 'compost', label = 'Compost', skill = 'agriculture', level = 0, station = 'composteur', durationMs = 6000, difficulty = 5, xp = 6,
            ingredients = { { item = 'dechets_vegetaux', quantity = 3 } }, output = { item = 'compost', quantity = 1 } },
        station = { id = 'composteur_communal', label = 'Composteur du champ', x = -224.0, y = -895.0, z = 31.2, quality = 50 },
    },

    -- Animations côté client : scénario du jeu, ou dictionnaire + animation en boucle.
    anims = {
        plant = { scenario = 'WORLD_HUMAN_GARDENER_PLANT' },
        water = { scenario = 'WORLD_HUMAN_GARDENER_PLANT' },
        harvest = { scenario = 'WORLD_HUMAN_GARDENER_PLANT' },
        fill = { scenario = 'WORLD_HUMAN_GARDENER_PLANT' },
    },

    -- Textes des notifications (serveur → joueur). %s : libellé, %d : nombre.
    messages = {
        planted = '%s semé.',
        watered = 'Arrosé (%d charge(s) restante(s)).',
        fertilized = 'Compost épandu : fertilité %d %%.',
        harvested = '%s : %d × %s (%s).',                -- culture, quantité, produit, palier
        seedsBack = 'Et %d graine(s) récupérée(s).',
        cleared = 'Emplacement dégagé.',
        clearedWaste = 'Emplacement dégagé : %d déchets végétaux.',
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
        -- gel (vava_time) : couvrir un emplacement, avertissement du soir, plantes perdues ; %s : culture ou parcelle(s)
        covered = 'Emplacement couvert : la plante passera les nuits de gel.',
        alreadyCovered = 'Cette plante est déjà couverte.',
        frostHardy = '%s ne craint pas le gel.',
        noCover = 'Il vous faut du compost pour couvrir la plante.',
        frostWarning = 'Le froid mordra cette nuit (%s) : couvrez les cultures fragiles ou elles gèleront.',
        frostStruck = 'Le gel a pris %d plante(s) : %s.',
    },
}
