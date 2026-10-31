--[[
    vava_gathering/config.lua
    Rôle : donnée de jeu de la récolte lue par le seul serveur (servi au seul serveur, jamais téléchargé par les
           joueurs) : bandes de vitalité et leurs effets, cicatrice, réaction de la terre, saisons, tolérances des
           gestes, durée et qualité d'une récolte, pêche (barre de tension, touche, prise), battement d'abonnement
           des zones, journal, droits, débits, solidité par défaut d'un outil, objets déclarés à l'inventaire, textes.
           Complète la table ouverte par config_client.lua (invite, streaming, carte, touches, genre des outils, part
           client des ressources, animations) sans en réécrire une clé (T-132). T-102 : zones et nœuds (graine de
           l'Atelier), part serveur des ressources et des outils, apparences, réglages de l'atelier « Récolte », essai
           à blanc. Modifiable sans toucher au code. Durées en millisecondes sauf mention contraire.
    Dépendances : shared/constants.lua, config_client.lua
]]

local config = VavaGathering.config

config.coreVersion = '0.11.0'   -- abonnements de zone (core.zones)
config.dependencies = { vava_inventory = '1.4.0', vava_skills = '1.0.0' }

-- T-102 : un config_client.lua d'avant 1.8.0 (gardé par une mise à jour) porte encore les zones et les nœuds ; ils
-- sont ignorés (ceux d'ici, puis la base de l'Atelier, font foi) et le démarrage le signale en console.
config.legacyClientPlaces = config.zones ~= nil or config.nodes ~= nil

-- Zones et nœuds : la GRAINE de l'Atelier (vava_atelier, atelier « Récolte ») — version 1 au premier démarrage, puis la
-- base fait foi (une zone ou un point changé en jeu l'emporte sur cette liste). Sans l'Atelier, la récolte tourne sur
-- cette graine. EXEMPLES autour du point d'apparition par défaut, à remplacer par les lieux du royaume.
-- Zones : `kind` type de lieu (editor.zoneKinds), `cost` vitalité perdue par récolte réussie, `regenPerHour` points
-- rendus par heure, `scarHours` durée de la cicatrice. Ce que voit le joueur (nom, type, lieu) part dans l'état de zone.
config.zones = {
    { id = 'foret_brume', label = 'Forêt de Brume', kind = 'foret', x = -320.0, y = -880.0, z = 31.0, radius = 120.0, cost = 2.0, regenPerHour = 4.0, scarHours = 48 },   -- PLACEHOLDER
    { id = 'mine_du_val', label = 'Mine du Val', kind = 'mine', x = -180.0, y = -1010.0, z = 29.0, radius = 80.0, cost = 2.5, regenPerHour = 3.0, scarHours = 72 },      -- PLACEHOLDER
    { id = 'prairie_haute', label = 'Prairie Haute', kind = 'prairie', x = -380.0, y = -1060.0, z = 31.0, radius = 100.0, cost = 1.5, regenPerHour = 6.0, scarHours = 24 }, -- PLACEHOLDER
    { id = 'riviere_claire', label = 'Rivière Claire', kind = 'eau', x = -120.0, y = -880.0, z = 29.0, radius = 60.0, cost = 2.0, regenPerHour = 5.0, scarHours = 36 },    -- PLACEHOLDER
}

-- Nœuds (« points » dans l'Atelier) : `label` nom du point, `charges` maximum, `regenMs` par charge rendue. Le modèle est
-- celui de la ressource (config_client.lua, `resources[…].prop`).
config.nodes = {
    { id = 'foret_brume_chene_1', label = 'Chêne 1', zone = 'foret_brume', resource = 'chene', x = -300.0, y = -900.0, z = 31.0, heading = 0.0, charges = 3, regenMs = 600000 },           -- PLACEHOLDER
    { id = 'foret_brume_chene_2', label = 'Chêne 2', zone = 'foret_brume', resource = 'chene', x = -330.0, y = -870.0, z = 31.0, heading = 40.0, charges = 3, regenMs = 600000 },          -- PLACEHOLDER
    { id = 'foret_brume_pin_1', label = 'Pin 1', zone = 'foret_brume', resource = 'pin', x = -350.0, y = -910.0, z = 31.0, heading = 90.0, charges = 4, regenMs = 480000 },                -- PLACEHOLDER
    { id = 'mine_du_val_fer_1', label = 'Filon de fer 1', zone = 'mine_du_val', resource = 'fer', x = -190.0, y = -1000.0, z = 29.0, heading = 0.0, charges = 3, regenMs = 900000 },       -- PLACEHOLDER
    { id = 'mine_du_val_cuivre_1', label = 'Filon de cuivre 1', zone = 'mine_du_val', resource = 'cuivre', x = -170.0, y = -1020.0, z = 29.0, heading = 0.0, charges = 3, regenMs = 900000 }, -- PLACEHOLDER
    { id = 'mine_du_val_pierre_1', label = 'Roche 1', zone = 'mine_du_val', resource = 'pierre', x = -200.0, y = -1030.0, z = 29.0, heading = 0.0, charges = 5, regenMs = 600000 },       -- PLACEHOLDER
    { id = 'prairie_haute_lavande_1', label = 'Lavande 1', zone = 'prairie_haute', resource = 'lavande', x = -370.0, y = -1050.0, z = 31.0, heading = 0.0, charges = 4, regenMs = 420000 }, -- PLACEHOLDER
    { id = 'prairie_haute_sauge_1', label = 'Sauge 1', zone = 'prairie_haute', resource = 'sauge', x = -395.0, y = -1075.0, z = 31.0, heading = 0.0, charges = 3, regenMs = 540000 },      -- PLACEHOLDER
    { id = 'prairie_haute_lievre_1', label = 'Piste de lièvre 1', zone = 'prairie_haute', resource = 'piste_lievre', x = -400.0, y = -1040.0, z = 31.0, heading = 0.0, charges = 2, regenMs = 1200000 }, -- PLACEHOLDER
    { id = 'prairie_haute_cerf_1', label = 'Piste de cerf 1', zone = 'prairie_haute', resource = 'piste_cerf', x = -360.0, y = -1090.0, z = 31.0, heading = 0.0, charges = 1, regenMs = 2400000 },     -- PLACEHOLDER
    { id = 'riviere_claire_truite_1', label = 'Banc de truites 1', zone = 'riviere_claire', resource = 'truite', x = -110.0, y = -870.0, z = 29.0, heading = 0.0, charges = 4, regenMs = 600000 },   -- PLACEHOLDER
    { id = 'riviere_claire_brochet_1', label = 'Banc de brochets 1', zone = 'riviere_claire', resource = 'brochet', x = -130.0, y = -895.0, z = 29.0, heading = 0.0, charges = 2, regenMs = 1200000 }, -- PLACEHOLDER
}

-- Part serveur des ressources (mêmes identifiants que `resources` de config_client.lua, sinon le module refuse de
-- démarrer) : objet produit, compétence, difficulté, XP, rendement { min, max } avant bonus, durée du geste, nœud
-- d'eau (barre de tension), pièce en plus.
config.resourceStats = {
    chene = { item = 'bois_chene', skill = 'bucheronnage', difficulty = 15, xp = 12, yield = { 2, 4 }, durationMs = 5000 },
    pin = { item = 'bois_pin', skill = 'bucheronnage', difficulty = 5, xp = 8, yield = { 2, 4 }, durationMs = 4500 },
    fer = { item = 'minerai_fer', skill = 'minage', difficulty = 25, xp = 14, yield = { 1, 3 }, durationMs = 6000 },
    cuivre = { item = 'minerai_cuivre', skill = 'minage', difficulty = 10, xp = 10, yield = { 1, 3 }, durationMs = 5500 },
    pierre = { item = 'pierre', skill = 'minage', difficulty = 0, xp = 6, yield = { 2, 5 }, durationMs = 4000 },
    lavande = { item = 'lavande', skill = 'herboristerie', difficulty = 5, xp = 8, yield = { 1, 3 }, durationMs = 3500 },
    sauge = { item = 'sauge', skill = 'herboristerie', difficulty = 20, xp = 12, yield = { 1, 3 }, durationMs = 4000 },
    truite = { item = 'truite', skill = 'peche', difficulty = 10, xp = 10, yield = { 1, 2 }, durationMs = 0, fishing = true },
    brochet = { item = 'brochet', skill = 'peche', difficulty = 35, xp = 16, yield = { 1, 1 }, durationMs = 0, fishing = true },
    piste_lievre = { item = 'viande_lievre', skill = 'chasse', difficulty = 10, xp = 10, yield = { 1, 2 }, durationMs = 5000, extra = { item = 'peau_lievre', chance = 0.5 } },
    piste_cerf = { item = 'viande_cerf', skill = 'chasse', difficulty = 40, xp = 18, yield = { 2, 3 }, durationMs = 7000, extra = { item = 'peau_cerf', chance = 0.7 } },
}

-- Part serveur des outils (mêmes objets que `tools` de config_client.lua) : puissance (divise la durée), bonus de
-- rendement (unités) et de qualité (points de score), usure par usage (points de solidité).
config.toolStats = {
    hache_fer = { power = 1.0, yieldBonus = 0, qualityBonus = 0, wear = 2 },
    pioche_fer = { power = 1.0, yieldBonus = 0, qualityBonus = 0, wear = 2 },
    faucille_fer = { power = 1.0, yieldBonus = 0, qualityBonus = 0, wear = 1 },
    couteau_fer = { power = 1.0, yieldBonus = 0, qualityBonus = 0, wear = 1 },
    canne_a_peche = { power = 1.0, yieldBonus = 0, qualityBonus = 0, wear = 1 },
}

-- Apparence d'un point dans l'Atelier (« Apparence : chêne de GTA, modèle provisoire… »), par ressource. Le jour des
-- modèles médiévaux : changer `prop` de la ressource et retirer `provisional`.
config.looks = {
    chene = { label = 'chêne de GTA', provisional = true },            -- PLACEHOLDER
    pin = { label = 'pin de GTA', provisional = true },                -- PLACEHOLDER
    fer = { label = 'rocher de GTA', provisional = true },             -- PLACEHOLDER
    cuivre = { label = 'rocher de GTA', provisional = true },          -- PLACEHOLDER
    pierre = { label = 'rocher de GTA', provisional = true },          -- PLACEHOLDER
    lavande = { label = 'plante de GTA', provisional = true },         -- PLACEHOLDER
    sauge = { label = 'plante de GTA', provisional = true },           -- PLACEHOLDER
    truite = { label = 'flotteur de GTA', provisional = true },        -- PLACEHOLDER
    brochet = { label = 'flotteur de GTA', provisional = true },       -- PLACEHOLDER
    piste_lievre = { label = 'buisson de GTA', provisional = true },   -- PLACEHOLDER
    piste_cerf = { label = 'buisson de GTA', provisional = true },     -- PLACEHOLDER
}

-- Atelier de la récolte (vava_atelier : zones et points créés, déplacés, réglés en jeu par le Conseil).
config.editor = {
    right = 'metiers',                                         -- droit de l'atelier (Sénéchal et au-dessus)
    zoneRadius = { min = 10.0, max = 300.0, default = 60.0 },  -- rayon d'une zone (m) ; défaut au premier tracé
    nodeSlack = 5.0,          -- un point peut déborder de sa zone de 5 m au plus (tronc au bord)
    spacing = 2.0,            -- deux points d'une même zone à 2 m au moins (au sol)
    overlapTolerance = 10.0,  -- deux zones peuvent se chevaucher de 10 m au plus
    maxZones = 256,           -- zones vivantes au plus (le core en permet 1 024 par module)
    maxNodesPerZone = 120,    -- points par zone (deux clés d'état par point, 256 clés au plus par zone du core)
    flushGraceMs = 2000,      -- une diffusion en attente depuis plus de 2 s part au passage suivant de la boucle lente
    zoneKinds = {             -- choix « Type de lieu » (chaque valeur a son icône dans map.kinds, sinon celle par défaut)
        { value = 'foret', label = 'Forêt' }, { value = 'mine', label = 'Mine' },
        { value = 'prairie', label = 'Prairie' }, { value = 'eau', label = 'Eau' },
    },
    -- valeurs de départ d'une zone ou d'un point nouveaux
    defaults = { cost = 2.0, regenPerHour = 4.0, scarHours = 48, charges = 3, regenMs = 600000 },
    texts = {
        label = 'Récolte',
        description = 'Forêts, mines, prairies et coins de pêche, arbres et filons un par un.',
        trial = 'Tester la récolte',
        publish = 'Publier la zone',
        publishHint = 'Publier rend les nouveaux points visibles aux joueurs proches.',
        trialLine = 'Mode essai : vous seul voyez ces points',
        name = 'Une autre zone porte déjà ce nom.',
        noPlaceZone = 'Placez la zone avant de l\'essayer ou de la publier.',
        noPlaceNode = 'Placez le point avant de l\'essayer ou de le publier.',
        radius = 'Le rayon doit aller de %d à %d m.',
        overlap = 'Cette zone empiète sur « %s » de %d m.',
        resource = 'Ressource inconnue.',
        kind = 'Type de lieu inconnu.',
        fishOnly = 'Une zone d\'eau ne porte que des bancs de poissons.',
        waterOnly = 'Les poissons ne se pêchent que dans une zone d\'eau.',
        outside = 'Ce point est hors de « %s ».',
        tooClose = 'Trop près de « %s » (%s m).',
        tooMany = 'Cette zone aurait %d points : %d au plus.',
        tooManyZones = 'Le royaume a déjà %d zones de récolte.',
        tooWide = 'Les points de « %s » s\'étendent à %d m de son centre : %d m au plus.',
        noZone = 'La zone de ce point n\'est pas publiée : essayez ou publiez la zone.',
        hint = '%d points',
        compareTitle = 'Pour comparer',
        compare = '%s — fatigue %s, repos %s pts/h',
    },
}

-- Vitalité d'une zone (0 à 100). Au-dessus de `normal` : plein rendement ; entre `reduced` et `normal` : rendement
-- et qualité réduits, chance d'échec ; sous `reduced` : zone épuisée (props remplacés), rendement effondré ;
-- à 0 : cicatrice, régénération multipliée par `scar.regenFactor` pendant `scarHours` de la zone.
config.bands = {
    normal = 60,
    reduced = 25,
    effects = {
        normal = { yield = 1.0, tierMalus = 0, failure = 0.0 },
        reduced = { yield = 0.6, tierMalus = 1, failure = 0.25 },
        depleted = { yield = 0.2, tierMalus = 2, failure = 0.5 },
    },
}
config.scar = { regenFactor = 0.2 }
-- épuisements répétés (cicatrices) dans la fenêtre → hook vava_gathering:earthReaction (contenu plus tard)
config.earthReaction = { depletions = 3, windowDays = 7 }

-- Saisons du royaume (vava_time, facultatif : sans lui, aucun effet). Facteurs par saison et par compétence de la
-- ressource : `regen` vitesse à laquelle les nœuds rendent leurs charges (0 : rien ne repousse et le temps ne
-- compte pas), `yield` unités récoltées (au moins une). Absent : 1. Le minage ne dépend d'aucune saison.
config.seasons = {
    regen = {
        printemps = { herboristerie = 1.25, chasse = 1.25, peche = 1.25 },
        automne = { herboristerie = 0.75, chasse = 1.25 },
        hiver = { herboristerie = 0.25, peche = 0.5, chasse = 0.5, bucheronnage = 0.75 },
    },
    yield = {
        automne = { chasse = 1.25 },
        hiver = { herboristerie = 0.5 },
    },
}

-- Tolérances des gestes, lues par le seul serveur : ajoutées à `interact` (config_client.lua), dont le client lit la
-- distance d'invite et l'annulation au mouvement (relecture sécurité S-5 de T-132).
config.interact.serverTolerance = 1.5      -- marge ajoutée côté serveur (centre du prop, latence) : distance + tolérance
config.interact.cooldownMs = 1500          -- entre deux récoltes d'un même joueur
config.interact.finishToleranceMs = 400    -- avance tolérée du client sur la durée annoncée (latence)
config.interact.expireMs = 30000           -- une récolte commencée et jamais finie est oubliée

-- Durée d'un geste : base de la ressource × (1 − niveau × skillFactor) ÷ puissance de l'outil, bornée.
config.duration = { skillFactor = 0.004, minMs = 1200 }

-- Qualité : score 0–100 = niveau × skill + qualité de l'outil (0–100, 50 sans qualité connue) × tool
-- + vitalité × vitality ± jitter, puis palier 1 à 5 selon `tiers` (bornes basses des paliers 2 à 5), moins le
-- malus de la bande. `origin` : écrire le nom de la zone dans les métadonnées (les piles ne se mélangent alors
-- pas d'une zone à l'autre).
config.quality = {
    weights = { skill = 0.5, tool = 0.3, vitality = 0.2 },
    jitter = 8,
    tiers = { 20, 40, 60, 85 },
    defaultToolQuality = 50,
    origin = true,
}

-- Pêche : la ligne est lancée (begin) ; le serveur tire le moment de la touche, prévient le client, qui tient la
-- tension dans la zone pendant `durationMs` ; `reel` dit si la tenue a réussi. La barre ne peut que faire rater :
-- ligne tenue, le serveur tire encore la prise (`catch`). Un raté n'use aucune charge. Lu par le seul serveur : la
-- barre (`tension`) part avec la touche, et le client n'en lit que `holdRatio` (borné de 0 à 1 ; à défaut, le repli
-- `FISHING_HOLD_RATIO` de shared/constants.lua).
config.fishing = {
    biteMinMs = 4000,
    biteMaxMs = 14000,
    tension = {
        durationMs = 6000,      -- durée de la barre
        zoneMin = 0.35,         -- zone à tenir (part de la barre)
        zoneMax = 0.65,
        drift = 0.12,           -- dérive aléatoire de la zone par seconde (part de la barre)
        pull = 0.9,             -- montée de l'aiguille par seconde quand on tient
        gravity = 0.7,          -- descente par seconde quand on relâche
        holdRatio = 0.6,        -- part du temps dans la zone pour réussir
    },
    reelToleranceMs = 500,      -- avance tolérée sur la durée de la barre
    reelGraceMs = 4000,         -- retard toléré (au-delà : la prise s'est échappée)
    -- Prise tirée par le serveur quand la ligne a tenu : chance que le poisson se décroche, de `novice` au niveau 0
    -- de Pêche à `master` au niveau `masterLevel` (linéaire entre les deux), plus le supplément de la bande de la
    -- zone (`bands`). Parts de 0 à 1. L'échec de la bande (`bands.effects.failure`) s'applique ensuite, comme à
    -- toute récolte. Décision du 30 octobre 2026 (une seule cause par message) : supplément à 0 partout, le
    -- décrochage ne dépend que du niveau ; l'état de l'eau ne joue que par l'échec de la bande. Réglage gardé pour
    -- pouvoir le remettre (essai d'avant : reduced = 0.05, depleted = 0.10).
    catch = {
        novice = 0.25,
        master = 0.02,
        masterLevel = 100,
        bands = { normal = 0.0, reduced = 0.0, depleted = 0.0 },
    },
}

-- État des zones et des nœuds (bande, cicatrice, charges) : envoyé par le core aux seuls joueurs à moins de
-- `streaming.radius` (config_client.lua) + `subscribeSlack` mètres du cercle qui englobe les nœuds d'une zone
-- (abonnements de zone) : il est là avant que le premier prop puisse apparaître ; seuls les nœuds des zones reçues sont
-- mesurés. Une zone reçue fait aussitôt un passage : `subscribeSlack` ne couvre que l'attente du passage du core, il
-- doit valoir au moins vitesse maximale × `zones.passMs` du core + 5 m (20 m : cavalier au galop, ~15 m/s, avec
-- passMs = 1000 ; à passer à 35 m avec passMs = 2000 ou pour une monture plus rapide). `radius` + `subscribeSlack` :
-- 500 m au plus. Lu par le seul serveur : ajouté à `streaming`.
config.streaming.subscribeSlack = 20.0

config.persistence = { flushMs = 10000 }   -- écriture groupée des zones et nœuds modifiés
config.logRetentionDays = 90

config.admin = {
    permission = 'metiers',         -- droit vava_admin ; sans lui, ACE
    ace = 'metiers.admin',
    command = 'recolte',
}

config.rateLimits = {
    map = { capacity = 2, refillPerSecond = 0.05 },   -- liste de la carte : deux demandes, puis une toutes les 20 s
    begin = { capacity = 4, refillPerSecond = 1 },
    cancel = { capacity = 4, refillPerSecond = 1 },
    finish = { capacity = 4, refillPerSecond = 1 },
    reel = { capacity = 4, refillPerSecond = 1 },
    zones = { capacity = 3, refillPerSecond = 0.5 },
}

-- Un outil sans solidité connue (donné par le Conseil, antérieur à l'artisanat) en reçoit une au premier usage.
config.toolDefaults = { durability = 100 }

-- Objets déclarés à l'inventaire par ce module (matières premières et outils de base). Images : web/items/<nom>.svg.
-- `held` : accessoire tenu en main (os main droite par défaut, décalages à régler modèle par modèle).
config.items = {
    bois_chene = { label = 'Bûche de chêne', description = 'Bois dur et serré, prisé des menuisiers.', width = 1, height = 2, weight = 900, stack = 20, category = 'materiau' },
    bois_pin = { label = 'Bûche de pin', description = 'Bois tendre et résineux.', width = 1, height = 2, weight = 700, stack = 20, category = 'materiau' },
    minerai_fer = { label = 'Minerai de fer', description = 'Roche lourde veinée de rouille.', width = 1, height = 1, weight = 800, stack = 30, category = 'materiau' },
    minerai_cuivre = { label = 'Minerai de cuivre', description = 'Roche aux reflets verts.', width = 1, height = 1, weight = 750, stack = 30, category = 'materiau' },
    pierre = { label = 'Pierre', description = 'Un bloc brut, bon pour les murs.', width = 1, height = 1, weight = 1200, stack = 30, category = 'materiau' },
    lavande = { label = 'Lavande', description = 'Brins violets au parfum entêtant.', width = 1, height = 1, weight = 50, stack = 40, category = 'materiau' },
    sauge = { label = 'Sauge', description = 'Feuilles grises, amères et bienfaisantes.', width = 1, height = 1, weight = 50, stack = 40, category = 'materiau' },
    truite = { label = 'Truite', description = 'Encore frétillante.', width = 2, height = 1, weight = 600, stack = 10, category = 'nourriture' },
    brochet = { label = 'Brochet', description = 'Long, nerveux, aux dents fines.', width = 3, height = 1, weight = 2000, stack = 5, category = 'nourriture' },
    viande_lievre = { label = 'Viande de lièvre', description = 'Maigre et goûteuse.', width = 1, height = 1, weight = 400, stack = 10, category = 'nourriture' },
    viande_cerf = { label = 'Viande de cerf', description = 'Une pièce sombre et ferme.', width = 2, height = 1, weight = 1500, stack = 10, category = 'nourriture' },
    peau_lievre = { label = 'Peau de lièvre', description = 'Fine, à tanner sans attendre.', width = 1, height = 1, weight = 200, stack = 10, category = 'materiau' },
    peau_cerf = { label = 'Peau de cerf', description = 'Épaisse, pour le cuir.', width = 2, height = 2, weight = 1800, stack = 5, category = 'materiau' },
    hache_fer = { label = 'Hache de bûcheron', description = 'Fer large emmanché de frêne.', width = 1, height = 3, weight = 2200, stack = 1, category = 'outil',
        held = { model = 'prop_tool_fireaxe', offset = { 0.1, 0.02, 0.0 }, rotation = { 0.0, 0.0, 0.0 } } },
    pioche_fer = { label = 'Pioche', description = 'Pointe de fer sur un manche court.', width = 1, height = 3, weight = 2500, stack = 1, category = 'outil',
        held = { model = 'prop_tool_pickaxe', offset = { 0.1, 0.02, 0.0 }, rotation = { 0.0, 0.0, 0.0 } } },
    faucille_fer = { label = 'Faucille', description = 'Lame courbe pour les herbes.', width = 1, height = 2, weight = 600, stack = 1, category = 'outil',
        held = { model = 'prop_tool_hammer', offset = { 0.1, 0.0, 0.0 }, rotation = { 0.0, 0.0, 0.0 } } },
    couteau_fer = { label = 'Couteau de chasse', description = 'Pour dépecer et dépouiller.', width = 1, height = 2, weight = 400, stack = 1, category = 'outil',
        held = { model = 'w_me_knife_01', offset = { 0.1, 0.0, 0.0 }, rotation = { 0.0, 0.0, 0.0 } } },
    canne_a_peche = { label = 'Canne à pêche', description = 'Noisetier souple, ligne de crin.', width = 1, height = 4, weight = 800, stack = 1, category = 'outil',
        held = { model = 'prop_fishing_rod_01', offset = { 0.1, 0.0, 0.0 }, rotation = { 0.0, 0.0, 0.0 } } },
}

-- Textes des notifications (serveur → joueur). %s : libellé, %d : nombre.
config.messages = {
    harvested = '%s : %d × %s (%s).',                     -- ressource, quantité, objet, palier
    harvestedExtra = 'Et aussi : %s.',
    failed = 'La récolte échoue : la terre est fatiguée ici.',
    failedWater = 'Ces eaux sont fatiguées : le poisson vous échappe.',     -- zone d'eau (`waterKinds`)
    escaped = 'La prise s\'est échappée.',
    slipped = 'Au dernier moment, le poisson se décroche.',
    noTool = 'Il vous faut %s en main.',                  -- genre d'outil (libellé)
    brokenTool = 'Votre outil est brisé.',
    noCharges = 'Il n\'y a plus rien à prendre ici pour le moment.',
    depleted = '%s est épuisée : la terre a besoin de repos.',
    depletedWater = '%s est épuisée : l\'eau a besoin de repos.',          -- zone d'eau (`waterKinds`)
    scarred = '%s porte une cicatrice : elle mettra longtemps à se remettre.',
    toolWorn = 'Votre %s s\'use (%d).',
    toolBroken = 'Votre %s se brise !',
    noSpace = 'Vous ne pouvez rien porter de plus.',
    tiers = { 'grossier', 'commun', 'soigné', 'excellent', 'chef-d\'œuvre' },
    toolKinds = { hache = 'une hache', pioche = 'une pioche', faucille = 'une faucille', couteau = 'un couteau', canne = 'une canne à pêche' },
    -- T-102 : essai de l'Atelier, récolte à blanc (rien n'est donné)
    trialHarvest = '[Essai] %s : %d × %s (%s). Rien n\'est donné pendant un essai.',
    trialFailed = '[Essai] La récolte aurait échoué : la terre est fatiguée ici.',
}
