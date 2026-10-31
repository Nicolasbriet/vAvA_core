--[[
    vava_combat/config.lua
    Rôle : tout ce qui est réglable des armes de corps à corps (lu par le client et le serveur) : catégories, familles et
           types de dégâts, fiches des armes, objets déclarés à l'inventaire, recettes déclarées à l'artisanat, qualité
           et usure, filet de la brique `strike`, bouclier accroché (positions, garde du statebag), contrôles natifs
           coupés, commandes du Conseil, textes.
    Les modèles et placements sont des remplaçants vanilla (-- PLACEHOLDER, docs/plan/ASSETS_PLACEHOLDERS.md) : le jour
    où les armes médiévales arrivent, seuls `items[…].held.model`, `shields[…]` et `provisional` changent.
    Les chiffres (dégâts, solidité, usure) sont des valeurs de départ, à régler à la porte T-119.
    Dépendances : shared/constants.lua
]]

VavaCombat.config = {
    coreVersion = '0.10.0',  -- core.net.send (0.10.0), registre core:commands (0.7.0)
    -- statebag de la main de l'inventaire (1.7.0) ; chaîne de dégâts `hit` (1.3.0)
    dependencies = { vava_inventory = '1.7.0', vava_health = '1.3.0' },
    -- versions minimales pour déclarer les recettes ; plus anciennes ou absentes : armes sans recette (console)
    optional = { vava_crafting = '1.5.0', vava_skills = '1.0.0' },

    -- Types de dégâts admis pour une arme (recoupés au démarrage avec vava_health:vocabulary().kinds).
    kinds = { 'tranchant', 'contondant', 'percant' },
    -- Libellés des catégories ; les clés sont exactement VavaCombat.CATEGORIES (règle de COMBAT_V1.md).
    categories = {
        une_main = { label = 'Arme à une main', order = 1 },
        deux_mains = { label = 'Arme à deux mains', order = 2 },
        dague = { label = 'Dague', order = 3 },
        baton = { label = 'Bâton', order = 4 },
        bouclier = { label = 'Bouclier', order = 5 },
    },
    -- Familles d'armes (T-115 : techniques de hache, de masse… ; style = famille + catégorie).
    families = {
        epee = { label = 'Épée' }, hache = { label = 'Hache' }, masse = { label = 'Masse' },
        dague = { label = 'Dague' }, baton = { label = 'Bâton' }, bouclier = { label = 'Bouclier' },
    },
    kindLabels = { tranchant = 'tranchant', contondant = 'contondant', percant = 'perçant' },

    -- Fiches des armes (clé = nom de l'objet d'inventaire). `damage` : points de vie (sur 100) d'un coup de
    -- multiplicateur 1,0, qualité 50, arme non émoussée ; `reachBonus` : mètres ajoutés à la portée de la technique
    -- (T-112) ; `durability` : solidité d'une pièce neuve (recette déclarée ici, pile sans métadonnées) ; `block` : part
    -- arrêtée en bloquant (lue par T-113) ; `provisional` : modèle provisoire, signalé par l'éditeur (T-121).
    weapons = {
        -- adoptée : objet et recette de vava_crafting (forge 30, transmise, solidité 150)
        epee_courte = { category = 'une_main', family = 'epee', kind = 'tranchant', damage = 12, reachBonus = 0,
            durability = 150, block = 0.40, provisional = true },
        epee_longue = { category = 'deux_mains', family = 'epee', kind = 'tranchant', damage = 17, reachBonus = 0.4,
            durability = 160, block = 0.50, provisional = true },
        hache_d_armes = { category = 'une_main', family = 'hache', kind = 'tranchant', damage = 14, reachBonus = -0.1,
            durability = 140, block = 0.30, provisional = true },
        masse_d_armes = { category = 'une_main', family = 'masse', kind = 'contondant', damage = 13, reachBonus = -0.1,
            durability = 180, block = 0.30, provisional = true },
        dague = { category = 'dague', family = 'dague', kind = 'percant', damage = 8, reachBonus = -0.5,
            durability = 100, block = 0.15, provisional = true },
        baton_ferre = { category = 'baton', family = 'baton', kind = 'contondant', damage = 9, reachBonus = 0.6,
            durability = 120, block = 0.45, provisional = true },
        bouclier_rond = { category = 'bouclier', family = 'bouclier', kind = 'contondant', damage = 5, reachBonus = -0.6,
            durability = 150, block = 0.70, provisional = true },
    },

    -- Objets déclarés à l'inventaire par ce module (forme de vava_inventory:items). Image posée par le code :
    -- nui://vava_combat/web/items/<nom>.svg. Le bouclier n'a pas de `held` : il s'accroche (`onUse` posé par le code).
    -- `bone` absent : main droite de l'inventaire.
    items = {
        epee_longue = { label = 'Épée longue', description = 'Une lame qu\'on tient à deux mains, longue d\'un bras tendu.',
            width = 1, height = 5, weight = 2600, stack = 1, category = 'arme',
            held = { model = 'w_me_machette_lr', offset = { 0.1, 0.0, 0.0 }, rotation = { 0.0, 0.0, 0.0 } } }, -- PLACEHOLDER : machette de GTA, placement à régler
        hache_d_armes = { label = 'Hache d\'armes', description = 'Un fer étroit et tranchant, emmanché court pour la mêlée.',
            width = 1, height = 3, weight = 2000, stack = 1, category = 'arme',
            held = { model = 'w_me_hatchet', offset = { 0.1, 0.0, 0.0 }, rotation = { 0.0, 0.0, 0.0 } } }, -- PLACEHOLDER : hachette de GTA
        masse_d_armes = { label = 'Masse d\'armes', description = 'Une tête de fer à ailettes au bout d\'un manche de chêne.',
            width = 1, height = 3, weight = 2400, stack = 1, category = 'arme',
            held = { model = 'w_me_bat', offset = { 0.1, 0.0, 0.0 }, rotation = { 0.0, 0.0, 0.0 } } }, -- PLACEHOLDER : batte de GTA
        dague = { label = 'Dague', description = 'Lame courte à double tranchant, pointe effilée.',
            width = 1, height = 2, weight = 500, stack = 1, category = 'arme',
            held = { model = 'w_me_dagger', offset = { 0.1, 0.0, 0.0 }, rotation = { 0.0, 0.0, 0.0 } } }, -- PLACEHOLDER : dague de GTA
        baton_ferre = { label = 'Bâton ferré', description = 'Du chêne dur, chaussé de fer aux deux bouts.',
            width = 1, height = 5, weight = 1800, stack = 1, category = 'arme',
            held = { model = 'w_me_poolcue', offset = { 0.1, 0.0, 0.0 }, rotation = { 0.0, 0.0, 0.0 } } }, -- PLACEHOLDER : queue de billard de GTA
        bouclier_rond = { label = 'Bouclier rond', description = 'Planches de pin cerclées de fer, bosse de métal au centre.',
            width = 3, height = 3, weight = 4500, stack = 1, category = 'arme' },
    },

    -- Recettes (forme de vava_crafting:recipes, clé = identifiant = objet produit), SANS `signed` ni `durability` : le
    -- code pose `signed = true` et `durability = weapons[objet].durability`. Chacune est aussi déclarée à
    -- vava_skills:recipes. L'Épée courte reste la recette de vava_crafting. Réparation : celle de vava_crafting.
    recipes = {
        dague = { label = 'Dague', skill = 'forge', level = 15, station = 'forge', tool = 'marteau', durationMs = 8000,
            difficulty = 20, xp = 14,
            ingredients = { { item = 'lingot_fer', quantity = 1 }, { item = 'cuir', quantity = 1 } },
            output = { item = 'dague', quantity = 1 } },
        hache_d_armes = { label = 'Hache d\'armes', skill = 'forge', level = 25, station = 'forge', tool = 'marteau',
            durationMs = 10000, difficulty = 30, xp = 22,
            ingredients = { { item = 'lingot_fer', quantity = 2, minTier = 2 }, { item = 'bois_chene', quantity = 1 } },
            output = { item = 'hache_d_armes', quantity = 1 } },
        masse_d_armes = { label = 'Masse d\'armes', skill = 'forge', level = 25, station = 'forge', tool = 'marteau',
            durationMs = 11000, difficulty = 30, xp = 22,
            ingredients = { { item = 'lingot_fer', quantity = 3 }, { item = 'bois_chene', quantity = 1 } },
            output = { item = 'masse_d_armes', quantity = 1 } },
        epee_longue = { label = 'Épée longue', skill = 'forge', level = 50, station = 'forge', tool = 'marteau',
            durationMs = 20000, difficulty = 55, xp = 40, transmission = true,
            ingredients = { { item = 'lingot_fer', quantity = 4, minTier = 3 }, { item = 'bois_chene', quantity = 1 }, { item = 'cuir', quantity = 1 } },
            output = { item = 'epee_longue', quantity = 1 } },
        baton_ferre = { label = 'Bâton ferré', skill = 'menuiserie', level = 10, station = 'etabli', durationMs = 8000,
            difficulty = 15, xp = 12,
            ingredients = { { item = 'bois_chene', quantity = 2 }, { item = 'lingot_fer', quantity = 1 } },
            output = { item = 'baton_ferre', quantity = 1 } },
        bouclier_rond = { label = 'Bouclier rond', skill = 'menuiserie', level = 20, station = 'etabli', durationMs = 12000,
            difficulty = 25, xp = 20,
            ingredients = { { item = 'bois_pin', quantity = 3 }, { item = 'lingot_fer', quantity = 1 }, { item = 'cuir', quantity = 1 } },
            output = { item = 'bouclier_rond', quantity = 1 } },
    },

    -- Qualité de forge → dégâts : linéaire de `minFactor` (qualité 0) à `maxFactor` (qualité 100) ; qualité 50 → 1,00.
    -- `default` : qualité d'une pile qui n'en porte pas (catalogue, don du Conseil).
    quality = { minFactor = 0.85, maxFactor = 1.15, default = 50 },

    -- Usure par coup qui a touché (arrivé, paré, bloqué ou absorbé ; jamais une esquive ni un coup refusé).
    wear = {
        perHit = 1,                  -- solidité perdue par coup qui use
        qualitySave = 0.4,           -- chance de NE PAS user = qualitySave × qualité / 100 (0 % à 40 %)
        dullFactor = 0.5,            -- dégâts d'une arme émoussée (solidité 0, ou `broken` posé ailleurs)
        warnRatio = 0.25,            -- porteur prévenu quand la solidité passe sous ce quart de la maximale
        -- coup annulé à ces étapes : l'arme a touché du fer ou du bois, elle s'use quand même
        cancelledStages = { 'parade', 'blocage', 'bouclier' },
    },

    -- Brique serveur `strike` (filet ; la vraie portée et l'angle sont jugés par T-112).
    strike = {
        maxDistance = 6.0,           -- mètres entre les positions serveur de l'attaquant et de la cible
        minMultiplier = 0.1,         -- bornes du multiplicateur de technique
        maxMultiplier = 3.0,
        minAmount = 0.5,             -- plancher d'un coup (un paquet `hit` exige amount > 0)
        tags = { 'parryable', 'unblockable', 'undodgeable' },  -- étiquettes qu'un appelant peut ajouter (`melee` toujours posé)
        callers = { 'vava_example_combat' },                   -- ressources admises à appeler l'export `strike`
    },

    -- Bouclier accroché.
    shield = {
        armWith = { 'une_main', 'dague' },  -- catégories de l'arme en main qui font porter le bouclier au bras
        armWithEmptyHand = false,           -- mains vides : au bras (true) ou dans le dos (false)
        toggleMs = 1000,                    -- délai entre deux gestes d'accroche d'un même joueur
        verifyMs = 5000,                    -- relevé de possession des boucliers accrochés (filet des hooks)
        missesToDrop = 2,                   -- relevés manquants d'affilée avant de décrocher
        pedCheckMs = 1000,                  -- serveur : nouveau ped d'un porteur → statebag réécrit
        guardDelayMs = 250,                 -- garde du statebag (mêmes valeurs que vava_inventory.hands)
        guardMaxCorrections = 3,
        guardMaxDelayMs = 1000,
        guardWarnMs = 10000,
        pollMs = 1000,                      -- client : boucle lente, seulement tant qu'un bouclier est suivi
        showRadius = 120.0,                 -- client : mètres au-delà desquels un bouclier suivi n'est pas montré
        awaitPedMs = 10000,                 -- client : attente bornée d'un ped annoncé par son statebag
        modelTimeoutMs = 5000,              -- client : attente maximale du chargement d'un modèle
    },
    -- Placement des boucliers (clé = objet) : avant-bras gauche (SKEL_L_Forearm, 61163) et haut du dos (SKEL_Spine3,
    -- 24818). Lu par chaque client dans SA config, jamais dans le statebag.
    shields = {
        bouclier_rond = { model = 'prop_ballistic_shield', -- PLACEHOLDER : bouclier balistique de GTA, placements à régler en jeu
            arm = { bone = 61163, offset = { 0.05, 0.05, 0.0 }, rotation = { 0.0, 90.0, 0.0 } },
            back = { bone = 24818, offset = { -0.1, -0.18, 0.0 }, rotation = { 0.0, 90.0, 180.0 } } },
    },

    -- Contrôles natifs coupés côté client, sans boucle par image (bascules réappliquées à 1 Hz).
    natives = {
        disableMelee = true,         -- drapeau de ped « corps à corps désactivé »
        meleeFlag = 122,             -- CPED_CONFIG_FLAG_DisableMelee
        blockSwitch = true,          -- SetPedCanSwitchWeapon(ped, false)
        stripWeapons = true,         -- arme GTA en main (autre que les poings) → toutes retirées
        pollMs = 1000,               -- cadence du contrôle
        restoreOnStop = true,        -- arrêt du module : drapeau et changement d'arme rendus à GTA
    },

    -- Commandes du Conseil : droit vava_admin `permission` (sans lui : ACE `ace`) ; `maxWear` : points de /armes user.
    admin = { command = 'armes', permission = 'metiers', ace = 'combat.admin', maxWear = 1000 },
    -- Libellés du journal du Registre (32 signes au plus).
    journal = { inspect = 'Combat : armes consultées', wear = 'Combat : arme usée' },

    -- Textes (%s : libellé, %d : nombre).
    messages = {
        shieldHung = '%s accroché, prêt à servir.',
        shieldUnhung = '%s décroché.',
        shieldDowned = 'Vous ne pouvez pas faire cela à terre.',
        tooSoon = 'Un instant…',
        worn = '%s : solidité %d / %d, l\'arme s\'émousse.',
        dull = '%s : l\'arme est émoussée, ses coups ne portent plus qu\'à moitié. Un artisan peut la remettre en état.',
        adminUsage = 'Usage : /armes liste | voir <n° du joueur> | user <n° du joueur> <points 1 à %d>',
        adminNoPlayer = 'Aucun personnage en jeu sous ce numéro.',
        adminNoWeapon = 'Ce personnage ne tient aucune arme du royaume en main.',
        adminDenied = 'Ce registre est réservé au Conseil.',
        adminNothing = '%s : l\'arme est déjà émoussée, il n\'y a plus rien à user.',
        adminFailed = '%s : la solidité n\'a pas pu être changée (l\'arme a quitté la besace, ou l\'artisanat refuse).',
        -- libellé, catégorie, type, dégâts, solidité, « modèle provisoire »
        list = '%s — %s, %s, coup %s, solidité %d%s',
        provisional = ', modèle provisoire',
        listHeader = 'Armes du royaume (%d) :',
        -- n°, libellé, qualité, palier, solidité, maximale, coup de base, coup effectif, émoussée
        inspect = 'Joueur %d — en main : %s, qualité %d, palier %s, solidité %d / %d, coup %s → %s%s',
        inspectNone = 'Joueur %d — rien en main qui soit une arme.',
        dullSuffix = ', émoussée',
        -- libellé, position, solidité, maximale
        inspectShield = 'Bouclier accroché : %s, %s, solidité %d / %d',
        positions = { arm = 'au bras', back = 'dans le dos' },
        -- libellé, avant, après, n°
        wornByCouncil = '%s : solidité %d → %d (joueur %d).',
    },
}
