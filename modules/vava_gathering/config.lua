--[[
    vava_gathering/config.lua
    Rôle : toute la donnée de jeu de la récolte (lue par le client et le serveur) : bandes de vitalité et leurs effets,
           cicatrice, réaction de la terre, interaction, durée et qualité d'une récolte, pêche (barre de tension),
           streaming des props, outils, ressources, objets déclarés à l'inventaire, zones et nœuds, animations, droits,
           touches, textes. Modifiable sans toucher au code. Durées en millisecondes sauf mention contraire.
    Les zones et nœuds ci-dessous sont des EXEMPLES autour du point d'apparition par défaut : à remplacer par les lieux du
    royaume. Les modèles de props et d'accessoires sont ceux du jeu de base : à ajuster avec les packs médiévaux.
    Dépendances : shared/constants.lua
]]

VavaGathering.config = {
    coreVersion = '0.11.0',  -- abonnements de zone (core.zones)
    dependencies = { vava_inventory = '1.4.0', vava_skills = '1.0.0' },

    -- Vitalité d'une zone (0 à 100). Au-dessus de `normal` : plein rendement ; entre `reduced` et `normal` : rendement
    -- et qualité réduits, chance d'échec ; sous `reduced` : zone épuisée (props remplacés), rendement effondré ;
    -- à 0 : cicatrice, régénération multipliée par `scar.regenFactor` pendant `scarHours` de la zone.
    bands = {
        normal = 60,
        reduced = 25,
        effects = {
            normal = { yield = 1.0, tierMalus = 0, failure = 0.0 },
            reduced = { yield = 0.6, tierMalus = 1, failure = 0.25 },
            depleted = { yield = 0.2, tierMalus = 2, failure = 0.5 },
        },
    },
    scar = { regenFactor = 0.2 },
    -- épuisements répétés (cicatrices) dans la fenêtre → hook vava_gathering:earthReaction (contenu plus tard)
    earthReaction = { depletions = 3, windowDays = 7 },

    -- Saisons du royaume (vava_time, facultatif : sans lui, aucun effet). Facteurs par saison et par compétence de la
    -- ressource : `regen` vitesse à laquelle les nœuds rendent leurs charges (0 : rien ne repousse et le temps ne
    -- compte pas), `yield` unités récoltées (au moins une). Absent : 1. Le minage ne dépend d'aucune saison.
    seasons = {
        regen = {
            printemps = { herboristerie = 1.25, chasse = 1.25, peche = 1.25 },
            automne = { herboristerie = 0.75, chasse = 1.25 },
            hiver = { herboristerie = 0.25, peche = 0.5, chasse = 0.5, bucheronnage = 0.75 },
        },
        yield = {
            automne = { chasse = 1.25 },
            hiver = { herboristerie = 0.5 },
        },
    },

    interact = {
        distance = 2.5,             -- distance maximale au nœud (m) pour l'invite côté client
        serverTolerance = 1.5,      -- marge ajoutée côté serveur (centre du prop, latence) : distance + tolérance
        cooldownMs = 1500,          -- entre deux récoltes d'un même joueur
        finishToleranceMs = 400,    -- avance tolérée du client sur la durée annoncée (latence)
        expireMs = 30000,           -- une récolte commencée et jamais finie est oubliée
        moveCancel = 1.5,           -- client : se déplacer de plus de 1,5 m interrompt le geste
    },

    -- Durée d'un geste : base de la ressource × (1 − niveau × skillFactor) ÷ puissance de l'outil, bornée.
    duration = { skillFactor = 0.004, minMs = 1200 },

    -- Qualité : score 0–100 = niveau × skill + qualité de l'outil (0–100, 50 sans qualité connue) × tool
    -- + vitalité × vitality ± jitter, puis palier 1 à 5 selon `tiers` (bornes basses des paliers 2 à 5), moins le
    -- malus de la bande. `origin` : écrire le nom de la zone dans les métadonnées (les piles ne se mélangent alors
    -- pas d'une zone à l'autre).
    quality = {
        weights = { skill = 0.5, tool = 0.3, vitality = 0.2 },
        jitter = 8,
        tiers = { 20, 40, 60, 85 },
        defaultToolQuality = 50,
        origin = true,
    },

    -- Pêche : la ligne est lancée (begin) ; le serveur tire le moment de la touche, prévient le client, qui tient la
    -- tension dans la zone pendant `durationMs` ; `reel` dit si la tenue a réussi. La barre ne peut que faire rater :
    -- ligne tenue, le serveur tire encore la prise (`catch`). Un raté n'use aucune charge.
    fishing = {
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
    },

    -- Client : props des nœuds créés à portée (`radius`, mètres), remplacés par le modèle « épuisé » quand la zone l'est.
    -- Les nœuds sont regroupés par zone : seuls ceux d'une zone à portée sont mesurés. Un passage toutes les `pollMs`
    -- près d'une zone, toutes les `idlePollMs` quand aucun nœud ne peut être à moins de `radius` + `idleMargin` (la
    -- marge couvre le chemin d'un cavalier rapide pendant `idlePollMs`, pour que les props apparaissent comme avant).
    -- État des zones et des nœuds (bande, cicatrice, charges) : envoyé par le core aux seuls joueurs à moins de
    -- `radius` + `subscribeSlack` mètres du cercle qui englobe les nœuds d'une zone (abonnements de zone) : il est là
    -- avant que le premier prop puisse apparaître ; seuls les nœuds des zones reçues sont mesurés.
    streaming = { radius = 80.0, pollMs = 1000, idlePollMs = 2500, idleMargin = 60.0, modelTimeoutMs = 5000, subscribeSlack = 20.0 },

    -- Carte : un blip par zone (icône `sprite` et couleur `colour` du jeu selon le genre, liste sur docs.fivem.net →
    -- Blips), nommé comme elle, à courte portée (petite carte à l'approche, toujours sur la grande), et le cercle
    -- translucide de son rayon (`ring`). Posés par le client depuis cette config : rien ne circule. Le panneau des
    -- zones pose le repère de la carte sur une zone.
    map = {
        blips = true,
        scale = 0.85,
        ring = { show = true, alpha = 64 },         -- cercle du rayon sur la grande carte (alpha 0 à 255)
        kinds = {
            foret = { sprite = 141, colour = 25 },      -- gibier, vert forêt
            mine = { sprite = 319, colour = 40 },       -- foreuse, gris sombre
            prairie = { sprite = 496, colour = 46 },    -- feuille, or
            eau = { sprite = 410, colour = 3 },         -- barque, bleu
        },
        default = { sprite = 1, colour = 0 },           -- genre sans icône : point blanc
    },

    -- Genres de zone d'eau (`zones[].kind`) : leurs textes parlent de l'eau, non de la terre (échec de la bande,
    -- épuisement, invite).
    waterKinds = { eau = true },

    persistence = { flushMs = 10000 },  -- écriture groupée des zones et nœuds modifiés
    logRetentionDays = 90,

    admin = {
        permission = 'metiers',         -- droit vava_admin ; sans lui, ACE
        ace = 'metiers.admin',
        command = 'recolte',
    },

    keys = { interact = 'E', zones = 'O' },
    labels = { interact = 'Récolter (nœud proche)', zones = 'Ouvrir le panneau des zones de récolte' },

    rateLimits = {
        begin = { capacity = 4, refillPerSecond = 1 },
        cancel = { capacity = 4, refillPerSecond = 1 },
        finish = { capacity = 4, refillPerSecond = 1 },
        reel = { capacity = 4, refillPerSecond = 1 },
        zones = { capacity = 3, refillPerSecond = 0.5 },
    },

    -- Un outil sans solidité connue (donné par le Conseil, antérieur à l'artisanat) en reçoit une au premier usage.
    toolDefaults = { durability = 100 },

    -- Outils : objet de l'inventaire → genre (requis par les ressources), puissance (divise la durée), bonus de
    -- rendement (unités) et de qualité (points de score), usure par usage (points de solidité). Ils sont aussi
    -- déclarés comme objets ci-dessous (`items`) et tenus en main (`held`).
    tools = {
        hache_fer = { kind = 'hache', power = 1.0, yieldBonus = 0, qualityBonus = 0, wear = 2 },
        pioche_fer = { kind = 'pioche', power = 1.0, yieldBonus = 0, qualityBonus = 0, wear = 2 },
        faucille_fer = { kind = 'faucille', power = 1.0, yieldBonus = 0, qualityBonus = 0, wear = 1 },
        couteau_fer = { kind = 'couteau', power = 1.0, yieldBonus = 0, qualityBonus = 0, wear = 1 },
        canne_a_peche = { kind = 'canne', power = 1.0, yieldBonus = 0, qualityBonus = 0, wear = 1 },
    },

    -- Ressources : ce qu'un nœud produit. `tool` : genre d'outil requis en main (nil : à la main). `fishing` : nœud
    -- d'eau, mini-jeu de tension. `yield` : { min, max } unités avant bonus. `anim` : clé de `anims`.
    resources = {
        chene = { label = 'Chêne', item = 'bois_chene', skill = 'bucheronnage', tool = 'hache', difficulty = 15, xp = 12, yield = { 2, 4 }, durationMs = 5000, anim = 'chop' },
        pin = { label = 'Pin', item = 'bois_pin', skill = 'bucheronnage', tool = 'hache', difficulty = 5, xp = 8, yield = { 2, 4 }, durationMs = 4500, anim = 'chop' },
        fer = { label = 'Filon de fer', item = 'minerai_fer', skill = 'minage', tool = 'pioche', difficulty = 25, xp = 14, yield = { 1, 3 }, durationMs = 6000, anim = 'mine' },
        cuivre = { label = 'Filon de cuivre', item = 'minerai_cuivre', skill = 'minage', tool = 'pioche', difficulty = 10, xp = 10, yield = { 1, 3 }, durationMs = 5500, anim = 'mine' },
        pierre = { label = 'Roche', item = 'pierre', skill = 'minage', tool = 'pioche', difficulty = 0, xp = 6, yield = { 2, 5 }, durationMs = 4000, anim = 'mine' },
        lavande = { label = 'Lavande', item = 'lavande', skill = 'herboristerie', tool = nil, difficulty = 5, xp = 8, yield = { 1, 3 }, durationMs = 3500, anim = 'pick' },
        sauge = { label = 'Sauge', item = 'sauge', skill = 'herboristerie', tool = 'faucille', difficulty = 20, xp = 12, yield = { 1, 3 }, durationMs = 4000, anim = 'pick' },
        truite = { label = 'Banc de truites', item = 'truite', skill = 'peche', tool = 'canne', difficulty = 10, xp = 10, yield = { 1, 2 }, durationMs = 0, anim = 'fish', fishing = true },
        brochet = { label = 'Banc de brochets', item = 'brochet', skill = 'peche', tool = 'canne', difficulty = 35, xp = 16, yield = { 1, 1 }, durationMs = 0, anim = 'fish', fishing = true },
        piste_lievre = { label = 'Piste de lièvre', item = 'viande_lievre', skill = 'chasse', tool = 'couteau', difficulty = 10, xp = 10, yield = { 1, 2 }, durationMs = 5000, anim = 'skin', extra = { item = 'peau_lievre', chance = 0.5 } },
        piste_cerf = { label = 'Piste de cerf', item = 'viande_cerf', skill = 'chasse', tool = 'couteau', difficulty = 40, xp = 18, yield = { 2, 3 }, durationMs = 7000, anim = 'skin', extra = { item = 'peau_cerf', chance = 0.7 } },
    },

    -- Objets déclarés à l'inventaire par ce module (matières premières et outils de base). Images : web/items/<nom>.svg.
    -- `held` : accessoire tenu en main (os main droite par défaut, décalages à régler modèle par modèle).
    items = {
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
    },

    -- Zones : `cost` vitalité perdue par récolte réussie, `regenPerHour` points rendus par heure, `scarHours` durée
    -- de la cicatrice. EXEMPLES autour du point d'apparition par défaut.
    zones = {
        { id = 'foret_brume', label = 'Forêt de Brume', kind = 'foret', x = -320.0, y = -880.0, z = 31.0, radius = 120.0, cost = 2.0, regenPerHour = 4.0, scarHours = 48 },
        { id = 'mine_du_val', label = 'Mine du Val', kind = 'mine', x = -180.0, y = -1010.0, z = 29.0, radius = 80.0, cost = 2.5, regenPerHour = 3.0, scarHours = 72 },
        { id = 'prairie_haute', label = 'Prairie Haute', kind = 'prairie', x = -380.0, y = -1060.0, z = 31.0, radius = 100.0, cost = 1.5, regenPerHour = 6.0, scarHours = 24 },
        { id = 'riviere_claire', label = 'Rivière Claire', kind = 'eau', x = -120.0, y = -880.0, z = 29.0, radius = 60.0, cost = 2.0, regenPerHour = 5.0, scarHours = 36 },
    },

    -- Nœuds : `charges` maximum, `regenMs` par charge rendue, `prop` modèles normal et épuisé (créés par le client).
    nodes = {
        { id = 'foret_brume_chene_1', zone = 'foret_brume', resource = 'chene', x = -300.0, y = -900.0, z = 31.0, heading = 0.0, charges = 3, regenMs = 600000, prop = { model = 'prop_tree_oak_01', depleted = 'prop_tree_stump_01' } },
        { id = 'foret_brume_chene_2', zone = 'foret_brume', resource = 'chene', x = -330.0, y = -870.0, z = 31.0, heading = 40.0, charges = 3, regenMs = 600000, prop = { model = 'prop_tree_oak_01', depleted = 'prop_tree_stump_01' } },
        { id = 'foret_brume_pin_1', zone = 'foret_brume', resource = 'pin', x = -350.0, y = -910.0, z = 31.0, heading = 90.0, charges = 4, regenMs = 480000, prop = { model = 'prop_tree_pine_01', depleted = 'prop_tree_stump_01' } },
        { id = 'mine_du_val_fer_1', zone = 'mine_du_val', resource = 'fer', x = -190.0, y = -1000.0, z = 29.0, heading = 0.0, charges = 3, regenMs = 900000, prop = { model = 'prop_rock_1_a', depleted = 'prop_rock_1_f' } },
        { id = 'mine_du_val_cuivre_1', zone = 'mine_du_val', resource = 'cuivre', x = -170.0, y = -1020.0, z = 29.0, heading = 0.0, charges = 3, regenMs = 900000, prop = { model = 'prop_rock_1_b', depleted = 'prop_rock_1_f' } },
        { id = 'mine_du_val_pierre_1', zone = 'mine_du_val', resource = 'pierre', x = -200.0, y = -1030.0, z = 29.0, heading = 0.0, charges = 5, regenMs = 600000, prop = { model = 'prop_rock_1_c', depleted = 'prop_rock_1_f' } },
        { id = 'prairie_haute_lavande_1', zone = 'prairie_haute', resource = 'lavande', x = -370.0, y = -1050.0, z = 31.0, heading = 0.0, charges = 4, regenMs = 420000, prop = { model = 'prop_plant_01a', depleted = 'prop_plant_01b' } },
        { id = 'prairie_haute_sauge_1', zone = 'prairie_haute', resource = 'sauge', x = -395.0, y = -1075.0, z = 31.0, heading = 0.0, charges = 3, regenMs = 540000, prop = { model = 'prop_plant_01a', depleted = 'prop_plant_01b' } },
        { id = 'prairie_haute_lievre_1', zone = 'prairie_haute', resource = 'piste_lievre', x = -400.0, y = -1040.0, z = 31.0, heading = 0.0, charges = 2, regenMs = 1200000, prop = { model = 'prop_bush_lrg_02', depleted = 'prop_bush_med_03' } },
        { id = 'prairie_haute_cerf_1', zone = 'prairie_haute', resource = 'piste_cerf', x = -360.0, y = -1090.0, z = 31.0, heading = 0.0, charges = 1, regenMs = 2400000, prop = { model = 'prop_bush_lrg_02', depleted = 'prop_bush_med_03' } },
        { id = 'riviere_claire_truite_1', zone = 'riviere_claire', resource = 'truite', x = -110.0, y = -870.0, z = 29.0, heading = 0.0, charges = 4, regenMs = 600000, prop = { model = 'prop_dock_float_1', depleted = 'prop_dock_float_1b' } },
        { id = 'riviere_claire_brochet_1', zone = 'riviere_claire', resource = 'brochet', x = -130.0, y = -895.0, z = 29.0, heading = 0.0, charges = 2, regenMs = 1200000, prop = { model = 'prop_dock_float_1', depleted = 'prop_dock_float_1b' } },
    },

    -- Animations côté client : scénario du jeu, ou dictionnaire + animation en boucle.
    anims = {
        chop = { dict = 'melee@large_wpn@streamed_core', anim = 'ground_attack_on_spot', flag = 1 },
        mine = { scenario = 'WORLD_HUMAN_HAMMERING' },
        pick = { scenario = 'WORLD_HUMAN_GARDENER_PLANT' },
        fish = { scenario = 'WORLD_HUMAN_STAND_FISHING' },
        skin = { dict = 'amb@medic@standing@kneel@base', anim = 'base', flag = 1 },
    },

    -- Textes des notifications (serveur → joueur). %s : libellé, %d : nombre.
    messages = {
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
    },
}
