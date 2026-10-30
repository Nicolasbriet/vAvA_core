--[[
    vava_crafting/config.lua
    Rôle : toute la donnée de jeu de l'artisanat (lue par le client et le serveur) : paliers, formule de qualité,
           chefs-d'œuvre et baptême, poinçons, réparation, durées, interaction, streaming des props, outils, types de
           stations, stations placées, objets déclarés, recettes de départ, animations, droits, touches, textes.
           Modifiable sans toucher au code. Durées en millisecondes.
    Les stations placées et les modèles de props sont des EXEMPLES autour du point d'apparition par défaut : à remplacer
    par les lieux et les props du royaume.
    Dépendances : shared/constants.lua
]]

VavaCrafting.config = {
    coreVersion = '0.11.0',  -- abonnements de zone (core.zones)
    dependencies = { vava_inventory = '1.4.0', vava_skills = '1.0.0', vava_gathering = '1.0.0' },

    -- Paliers de qualité (bornes basses des paliers 2 à 5), libellés, et qualité équivalente d'un palier de matière.
    tiers = {
        thresholds = { 20, 40, 60, 85 },
        labels = { 'Grossier', 'Commun', 'Soigné', 'Excellent', 'Chef-d\'œuvre' },
        materialQuality = { 10, 30, 50, 72, 92 },
    },

    -- Qualité d'une pièce = matériaux × 0,5 + niveau × 0,4 + station × 0,1 ± jitter, plafonnée par le niveau.
    quality = {
        weights = { materials = 0.5, skill = 0.4, station = 0.1 },
        jitter = 5,
        capByLevel = true,
    },

    -- Chef-d'œuvre : palier 5 ; l'artisan peut le baptiser pendant la fenêtre qui suit sa création. Lettres admises
    -- dans un nom (accents compris) et séparateurs (jamais en tête, en fin ni doublés).
    masterpiece = {
        tier = 5, nameWindowMs = 300000, nameMin = 2, nameMax = 32,
        nameLetters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZàâäáãåæçéèêëíìîïñóòôöõøœúùûüýÿÀÂÄÁÃÅÆÇÉÈÊËÍÌÎÏÑÓÒÔÖÕØŒÚÙÛÜÝŸ',
        nameSeparators = " '-",
    },

    -- Poinçon : un glyphe par personnage, choisi dès le rang `minRank` dans une compétence d'artisanat.
    mark = {
        minRank = 'compagnon',
        glyphs = { '✦', '✧', '❖', '☽', '☀', '⚒', '⚔', '⚜', '✠', '☘', '❦', '⚓', '♜', '⚚', '✶', '♆', '⚑', '❂' },
    },

    -- Journal d'un objet : création + les 5 dernières entrées.
    history = { max = 6 },

    -- Garde de la signature (hook des métadonnées, server/guard.lua).
    guard = {
        -- un même refus (même module, même objet, même clé) n'est journalisé et signalé en console qu'une fois par
        -- fenêtre ; les suivants sont comptés et annoncés avec le prochain refus signalé
        windowMs = 60000,
        -- refus distincts suivis à la fois ; au-delà, un refus nouveau n'est ni journalisé ni signalé (seulement
        -- compté) jusqu'à la purge suivante (une fois par fenêtre)
        maxTracked = 500,
        -- plus haute solidité qu'un autre module peut donner à un objet signé qui n'en a pas : celle que pose l'usure
        -- de la récolte (vava_gathering, toolDefaults.durability), ou la solidité de sa recette si elle est plus haute
        bornDurability = 100,
    },

    -- Réparation : part des ingrédients de la recette (arrondie au-dessus), solidité rendue mais maximale réduite,
    -- niveau requis = part du niveau de la recette, XP = part de l'XP de la recette, durée du geste.
    repair = { ingredientShare = 0.25, maxDurabilityLoss = 5, minLevelShare = 0.5, xpShare = 0.25, durationMs = 4000 },

    -- Durée d'une pièce : base de la recette × (1 − niveau × skillFactor), bornée.
    duration = { skillFactor = 0.004, minMs = 1500 },

    interact = {
        distance = 2.5,
        serverTolerance = 1.5,
        expireMs = 120000,          -- une pièce commencée et jamais finie libère la station au bout de ce délai…
        expireMarginMs = 30000,     -- … ou de sa durée + cette marge, si c'est plus long (recette de plus de 90 s)
        finishToleranceMs = 400,
        moveCancel = 1.5,
    },

    lessons = { radius = 10.0 },    -- une recette transmise réalisée devant un élève à cette distance lui vaut une leçon

    -- Client : props des stations créés à portée (`radius`, mètres). Les stations sont groupées par case de `groupCell`
    -- mètres : seules celles d'une case à portée sont mesurées. Un passage toutes les `pollMs` près d'une case, toutes
    -- les `idlePollMs` quand aucune station ne peut être à moins de `radius` + `idleMargin` (la marge couvre le chemin
    -- d'un cavalier rapide pendant `idlePollMs`, pour que les props apparaissent comme avant).
    -- Chaque station est une zone du core de `zoneRadius` mètres : un joueur la reçoit (dessin, combustible, occupation)
    -- à `radius` + `subscribeSlack` mètres de son bord, ses changements tant qu'il ne s'en éloigne pas de plus de 25 m
    -- au-delà (réglage du core), et ne connaît aucune autre station. `subscribeSlack` couvre le chemin d'un cavalier au
    -- galop (~15 m/s) entre deux passages du core (1 s) : la station est connue avant d'arriver à portée des props. La
    -- boucle des props ne tourne que si une station est connue.
    streaming = {
        radius = 80.0, pollMs = 1000, idlePollMs = 2500, idleMargin = 60.0, groupCell = 200.0, modelTimeoutMs = 5000,
        zoneRadius = 2.0, subscribeSlack = 20.0,
    },
    persistence = { flushMs = 10000 },
    logRetentionDays = 180,
    -- journal : pièces de ce palier et au-dessus (Excellent+)
    logTier = 4,

    admin = { permission = 'metiers', ace = 'metiers.admin', command = 'artisanat' },

    keys = { interact = 'E' },
    labels = { interact = 'Utiliser une station d\'artisanat' },

    rateLimits = {
        open = { capacity = 3, refillPerSecond = 0.5 },
        craft = { capacity = 3, refillPerSecond = 0.5 },
        cancel = { capacity = 4, refillPerSecond = 1 },
        finish = { capacity = 4, refillPerSecond = 1 },
        fuel = { capacity = 3, refillPerSecond = 0.5 },
        repair = { capacity = 3, refillPerSecond = 0.5 },
        mark = { capacity = 2, refillPerSecond = 0.2 },
        name = { capacity = 2, refillPerSecond = 0.2 },
    },

    -- Outils d'artisan à tenir en main : objet → genre demandé par les recettes.
    tools = {
        marteau_forge = { kind = 'marteau' },
    },

    -- Types de stations : compétences servies, combustible éventuel (objet, unités par pièce, réserve), animation.
    stationTypes = {
        forge = { label = 'Forge', skills = { 'forge' }, fuel = { item = 'charbon', perCraft = 1, capacity = 20 }, anim = 'hammer', prop = 'prop_tool_bench02' },
        etabli = { label = 'Établi', skills = { 'menuiserie' }, anim = 'hammer', prop = 'prop_tool_bench02_ld' },
        metier_a_tisser = { label = 'Métier à tisser', skills = { 'tissage' }, anim = 'sew', prop = 'prop_table_03' },
        alambic = { label = 'Alambic', skills = { 'alchimie' }, anim = 'brew', prop = 'prop_table_04' },
        tannerie = { label = 'Tannerie', skills = { 'tannerie' }, anim = 'tan', prop = 'prop_rub_table_01' },
        fourneau = { label = 'Fourneau', skills = { 'cuisine' }, fuel = { item = 'bois_pin', perCraft = 1, capacity = 20 }, anim = 'cook', prop = 'prop_bbq_3' },
        table_arcanes = { label = 'Table d\'arcanes', skills = { 'arcanes' }, anim = 'study', prop = 'prop_table_08' },
    },

    -- Stations placées : type, nom, position, qualité (0–100 : bonus de la station), propriétaire (nil : publique ;
    -- { kind = 'character', id = n } : privée). EXEMPLES autour du point d'apparition par défaut.
    stations = {
        { id = 'forge_bourg', type = 'forge', label = 'Forge du bourg', x = -255.0, y = -945.0, z = 31.2, heading = 90.0, quality = 50 },
        { id = 'etabli_bourg', type = 'etabli', label = 'Établi du bourg', x = -262.0, y = -940.0, z = 31.2, heading = 90.0, quality = 50 },
        { id = 'metier_bourg', type = 'metier_a_tisser', label = 'Métier à tisser du bourg', x = -268.0, y = -935.0, z = 31.2, heading = 90.0, quality = 40 },
        { id = 'alambic_bourg', type = 'alambic', label = 'Alambic de l\'herboriste', x = -274.0, y = -930.0, z = 31.2, heading = 90.0, quality = 60 },
        { id = 'tannerie_bourg', type = 'tannerie', label = 'Tannerie du bourg', x = -280.0, y = -925.0, z = 31.2, heading = 90.0, quality = 40 },
        { id = 'fourneau_bourg', type = 'fourneau', label = 'Fourneau de l\'auberge', x = -286.0, y = -920.0, z = 31.2, heading = 90.0, quality = 50 },
        { id = 'table_arcanes_tour', type = 'table_arcanes', label = 'Table d\'arcanes de la tour', x = -292.0, y = -915.0, z = 31.2, heading = 90.0, quality = 70 },
    },

    -- Objets déclarés à l'inventaire par ce module. Images : web/items/<nom>.svg. `effects` rend l'objet utilisable
    -- (vava_needs : hunger, thirst ; vava_health : health).
    items = {
        charbon = { label = 'Charbon de bois', description = 'Noir, léger, prêt pour la forge.', width = 1, height = 1, weight = 300, stack = 40, category = 'materiau' },
        lingot_fer = { label = 'Lingot de fer', description = 'Fondu et martelé en barre.', width = 1, height = 1, weight = 1000, stack = 20, category = 'materiau' },
        lingot_cuivre = { label = 'Lingot de cuivre', description = 'Rougeoyant, tendre sous le marteau.', width = 1, height = 1, weight = 900, stack = 20, category = 'materiau' },
        cuir = { label = 'Cuir tanné', description = 'Souple et solide.', width = 2, height = 1, weight = 500, stack = 20, category = 'materiau' },
        marteau_forge = { label = 'Marteau de forge', description = 'Tête lourde, manche court.', width = 1, height = 2, weight = 1500, stack = 1, category = 'outil',
            held = { model = 'prop_tool_hammer', offset = { 0.1, 0.0, 0.0 }, rotation = { 0.0, 0.0, 0.0 } } },
        epee_courte = { label = 'Épée courte', description = 'Lame d\'acier, garde simple.', width = 1, height = 4, weight = 1800, stack = 1, category = 'arme',
            held = { model = 'w_me_machette_lr', offset = { 0.1, 0.0, 0.0 }, rotation = { 0.0, 0.0, 0.0 } } },
        veste_de_cuir = { label = 'Veste de cuir', description = 'Cousue de pièces épaisses.', width = 2, height = 3, weight = 2500, stack = 1, category = 'armure' },
        potion_de_soin = { label = 'Potion de soin', description = 'Rouge sombre, odeur de sauge.', width = 1, height = 1, weight = 300, stack = 5, category = 'soin', effects = { health = 20 } },
        ragout_de_lievre = { label = 'Ragoût de lièvre', description = 'Mijoté aux herbes.', width = 1, height = 1, weight = 500, stack = 5, category = 'nourriture', effects = { hunger = 40 } },
        anneau_cuivre = { label = 'Anneau de cuivre', description = 'Un anneau simple, poli.', width = 1, height = 1, weight = 50, stack = 1, category = 'valeur' },
        talisman = { label = 'Talisman', description = 'Un disque de cuivre gravé, tiède au toucher.', width = 1, height = 1, weight = 100, stack = 1, category = 'valeur' },
    },

    -- Recettes de départ. `station` : type ; `tool` : genre d'outil en main (nil : aucun) ; `signed` : objet signé
    -- (unique, qualité, solidité, créateur) ; `signedIfQuality` : signé seulement à partir de cette qualité (potions) ;
    -- `durability` : solidité initiale d'un objet signé ; `transmission` : s'apprend par leçon ; `fragments` : savoirs
    -- perdus. Les ingrédients exigent un palier minimal (`minTier`, 1 par défaut).
    recipes = {
        charbon_de_bois = { label = 'Charbon de bois', skill = 'cuisine', level = 0, station = 'fourneau', durationMs = 5000, difficulty = 0, xp = 6,
            ingredients = { { item = 'bois_pin', quantity = 2 } }, output = { item = 'charbon', quantity = 2 } },
        ragout_de_lievre = { label = 'Ragoût de lièvre', skill = 'cuisine', level = 5, station = 'fourneau', durationMs = 8000, difficulty = 10, xp = 12,
            ingredients = { { item = 'viande_lievre', quantity = 1 }, { item = 'sauge', quantity = 1 } }, output = { item = 'ragout_de_lievre', quantity = 1 } },
        lingot_fer = { label = 'Lingot de fer', skill = 'forge', level = 0, station = 'forge', durationMs = 6000, difficulty = 5, xp = 8,
            ingredients = { { item = 'minerai_fer', quantity = 2 } }, output = { item = 'lingot_fer', quantity = 1 } },
        lingot_cuivre = { label = 'Lingot de cuivre', skill = 'forge', level = 0, station = 'forge', durationMs = 5000, difficulty = 0, xp = 6,
            ingredients = { { item = 'minerai_cuivre', quantity = 2 } }, output = { item = 'lingot_cuivre', quantity = 1 } },
        marteau_forge = { label = 'Marteau de forge', skill = 'menuiserie', level = 0, station = 'etabli', durationMs = 7000, difficulty = 5, xp = 10, signed = true, durability = 120,
            ingredients = { { item = 'lingot_fer', quantity = 1 }, { item = 'bois_pin', quantity = 1 } }, output = { item = 'marteau_forge', quantity = 1 } },
        hache_fer = { label = 'Hache de bûcheron', skill = 'forge', level = 10, station = 'forge', tool = 'marteau', durationMs = 9000, difficulty = 15, xp = 16, signed = true, durability = 100,
            ingredients = { { item = 'lingot_fer', quantity = 2 }, { item = 'bois_chene', quantity = 1 } }, output = { item = 'hache_fer', quantity = 1 } },
        pioche_fer = { label = 'Pioche', skill = 'forge', level = 10, station = 'forge', tool = 'marteau', durationMs = 9000, difficulty = 15, xp = 16, signed = true, durability = 100,
            ingredients = { { item = 'lingot_fer', quantity = 2 }, { item = 'bois_chene', quantity = 1 } }, output = { item = 'pioche_fer', quantity = 1 } },
        faucille_fer = { label = 'Faucille', skill = 'forge', level = 5, station = 'forge', tool = 'marteau', durationMs = 7000, difficulty = 10, xp = 12, signed = true, durability = 80,
            ingredients = { { item = 'lingot_fer', quantity = 1 }, { item = 'bois_pin', quantity = 1 } }, output = { item = 'faucille_fer', quantity = 1 } },
        couteau_fer = { label = 'Couteau de chasse', skill = 'forge', level = 5, station = 'forge', tool = 'marteau', durationMs = 6000, difficulty = 10, xp = 12, signed = true, durability = 80,
            ingredients = { { item = 'lingot_fer', quantity = 1 }, { item = 'bois_pin', quantity = 1 } }, output = { item = 'couteau_fer', quantity = 1 } },
        canne_a_peche = { label = 'Canne à pêche', skill = 'menuiserie', level = 5, station = 'etabli', durationMs = 7000, difficulty = 10, xp = 12, signed = true, durability = 80,
            ingredients = { { item = 'bois_pin', quantity = 2 } }, output = { item = 'canne_a_peche', quantity = 1 } },
        epee_courte = { label = 'Épée courte', skill = 'forge', level = 30, station = 'forge', tool = 'marteau', durationMs = 15000, difficulty = 35, xp = 30, signed = true, durability = 150, transmission = true,
            ingredients = { { item = 'lingot_fer', quantity = 3, minTier = 2 }, { item = 'bois_chene', quantity = 1 } }, output = { item = 'epee_courte', quantity = 1 } },
        cuir = { label = 'Cuir tanné', skill = 'tannerie', level = 0, station = 'tannerie', durationMs = 8000, difficulty = 5, xp = 10,
            ingredients = { { item = 'peau_lievre', quantity = 2 } }, output = { item = 'cuir', quantity = 1 } },
        cuir_epais = { label = 'Cuir épais', skill = 'tannerie', level = 15, station = 'tannerie', durationMs = 10000, difficulty = 20, xp = 16,
            ingredients = { { item = 'peau_cerf', quantity = 1 } }, output = { item = 'cuir', quantity = 2 } },
        veste_de_cuir = { label = 'Veste de cuir', skill = 'tissage', level = 15, station = 'metier_a_tisser', durationMs = 12000, difficulty = 20, xp = 20, signed = true, durability = 120,
            ingredients = { { item = 'cuir', quantity = 3 } }, output = { item = 'veste_de_cuir', quantity = 1 } },
        potion_de_soin = { label = 'Potion de soin', skill = 'alchimie', level = 10, station = 'alambic', durationMs = 9000, difficulty = 15, xp = 14, signedIfQuality = 60, durability = 1,
            ingredients = { { item = 'lavande', quantity = 2 }, { item = 'sauge', quantity = 1 } }, output = { item = 'potion_de_soin', quantity = 1 } },
        anneau_cuivre = { label = 'Anneau de cuivre', skill = 'menuiserie', level = 20, station = 'etabli', durationMs = 10000, difficulty = 25, xp = 18, signed = true, durability = 200,
            ingredients = { { item = 'lingot_cuivre', quantity = 1 } }, output = { item = 'anneau_cuivre', quantity = 1 } },
        talisman = { label = 'Talisman', skill = 'arcanes', level = 10, station = 'table_arcanes', durationMs = 12000, difficulty = 20, xp = 20, signed = true, durability = 60, transmission = true,
            fragments = { 'feuillet_un', 'feuillet_deux', 'feuillet_trois' },
            ingredients = { { item = 'lingot_cuivre', quantity = 1 }, { item = 'lavande', quantity = 1 } }, output = { item = 'talisman', quantity = 1 } },
    },

    -- Animations côté client : scénario du jeu, ou dictionnaire + animation en boucle.
    anims = {
        hammer = { scenario = 'WORLD_HUMAN_HAMMERING' },
        sew = { scenario = 'WORLD_HUMAN_SEAT_WALL' },
        brew = { scenario = 'WORLD_HUMAN_STAND_MOBILE' },
        tan = { scenario = 'WORLD_HUMAN_GARDENER_PLANT' },
        cook = { scenario = 'PROP_HUMAN_BBQ' },
        study = { scenario = 'WORLD_HUMAN_CLIPBOARD' },
    },

    -- Textes des notifications (serveur → joueur). %s : libellé, %d : nombre.
    messages = {
        crafted = '%s : %s (%s, qualité %d).',                 -- recette, objet, palier, qualité
        craftedSimple = '%s : %d × %s (%s).',                  -- recette, quantité, objet, palier
        masterpiece = 'Un chef-d\'œuvre ! Vous pouvez le baptiser depuis la station pendant quelques minutes.',
        repaired = '%s réparé : solidité %d / %d.',
        fueled = '%s : combustible %d / %d.',
        noFuel = 'La %s manque de combustible.',
        noTool = 'Il vous faut %s en main.',
        brokenTool = 'Votre outil est brisé.',
        missing = 'Il vous manque des matières.',
        noSpace = 'Vous ne pouvez rien porter de plus.',
        busy = 'Quelqu\'un travaille déjà ici.',
        noAccess = 'Cette station ne vous appartient pas.',
        lessonGiven = 'Vous avez enseigné %s à %s.',
        named = '%s porte désormais le nom « %s ».',
        markSet = 'Votre poinçon est désormais %s.',
        toolKinds = { marteau = 'un marteau de forge' },
    },
}
