--[[
    vava_combat/config.lua
    Rôle : réglages des armes de corps à corps que lit le seul serveur (servi au seul serveur, jamais téléchargé par
           les joueurs) : catégories, familles et types de dégâts, objets déclarés à l'inventaire, recettes déclarées à
           l'artisanat, qualité et usure, filet de la brique `strike`, commandes du Conseil, journal, textes. Complète
           la table ouverte par config_client.lua (fiches des armes, bouclier accroché, placement des boucliers,
           contrôles natifs) sans en réécrire une clé (T-132).
    Les modèles sont des remplaçants vanilla (-- PLACEHOLDER, docs/plan/ASSETS_PLACEHOLDERS.md) : le jour où les armes
    médiévales arrivent, seuls `items[…].held.model` (ici), `shields[…]` et `provisional` (config_client.lua) changent.
    Les chiffres (solidité, usure) sont des valeurs de départ, à régler à la porte T-119.
    Dépendances : shared/constants.lua, config_client.lua
]]

local config = VavaCombat.config

config.coreVersion = '0.10.0'  -- core.net.send (0.10.0), registre core:commands (0.7.0)
-- statebag de la main de l'inventaire (1.7.0) ; chaîne de dégâts `hit` (1.3.0)
config.dependencies = { vava_inventory = '1.7.0', vava_health = '1.3.0' }
-- versions minimales pour déclarer les recettes ; plus anciennes ou absentes : armes sans recette (console)
config.optional = { vava_crafting = '1.5.0', vava_skills = '1.0.0' }

-- Types de dégâts admis pour une arme (recoupés au démarrage avec vava_health:vocabulary().kinds).
config.kinds = { 'tranchant', 'contondant', 'percant' }
-- Libellés des catégories ; les clés sont exactement VavaCombat.CATEGORIES (règle de COMBAT_V1.md).
config.categories = {
    une_main = { label = 'Arme à une main', order = 1 },
    deux_mains = { label = 'Arme à deux mains', order = 2 },
    dague = { label = 'Dague', order = 3 },
    baton = { label = 'Bâton', order = 4 },
    bouclier = { label = 'Bouclier', order = 5 },
}
-- Familles d'armes (T-115 : techniques de hache, de masse… ; style = famille + catégorie).
config.families = {
    epee = { label = 'Épée' }, hache = { label = 'Hache' }, masse = { label = 'Masse' },
    dague = { label = 'Dague' }, baton = { label = 'Bâton' }, bouclier = { label = 'Bouclier' },
}
config.kindLabels = { tranchant = 'tranchant', contondant = 'contondant', percant = 'perçant' }

-- Objets déclarés à l'inventaire par ce module (forme de vava_inventory:items). Image posée par le code :
-- nui://vava_combat/web/items/<nom>.svg. Le bouclier n'a pas de `held` : il s'accroche (`onUse` posé par le code).
-- `bone` absent : main droite de l'inventaire.
config.items = {
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
}

-- Recettes (forme de vava_crafting:recipes, clé = identifiant = objet produit), SANS `signed` ni `durability` : le
-- code pose `signed = true` et `durability = weapons[objet].durability`. Chacune est aussi déclarée à
-- vava_skills:recipes. L'Épée courte reste la recette de vava_crafting. Réparation : celle de vava_crafting.
config.recipes = {
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
}

-- Qualité de forge → dégâts : linéaire de `minFactor` (qualité 0) à `maxFactor` (qualité 100) ; qualité 50 → 1,00.
-- `default` : qualité d'une pile qui n'en porte pas (catalogue, don du Conseil).
config.quality = { minFactor = 0.85, maxFactor = 1.15, default = 50 }

-- Usure par coup qui a touché (arrivé, paré, bloqué ou absorbé ; jamais une esquive ni un coup refusé).
config.wear = {
    perHit = 1,                  -- solidité perdue par coup qui use
    qualitySave = 0.4,           -- chance de NE PAS user = qualitySave × qualité / 100 (0 % à 40 %)
    dullFactor = 0.5,            -- dégâts d'une arme émoussée (solidité 0, ou `broken` posé ailleurs)
    warnRatio = 0.25,            -- porteur prévenu quand la solidité passe sous ce quart de la maximale
    -- coup annulé à ces étapes : l'arme a touché du fer ou du bois, elle s'use quand même
    cancelledStages = { 'parade', 'blocage', 'bouclier' },
}

-- Brique serveur `strike` (filet ; la vraie portée et l'angle sont jugés par T-112).
config.strike = {
    maxDistance = 6.0,           -- mètres entre les positions serveur de l'attaquant et de la cible
    minMultiplier = 0.1,         -- bornes du multiplicateur de technique
    maxMultiplier = 3.0,
    minAmount = 0.5,             -- plancher d'un coup (un paquet `hit` exige amount > 0)
    tags = { 'parryable', 'unblockable', 'undodgeable' },  -- étiquettes qu'un appelant peut ajouter (`melee` toujours posé)
    callers = { 'vava_example_combat' },                   -- ressources admises à appeler l'export `strike`
}

-- Commandes du Conseil : droit vava_admin `permission` (sans lui : ACE `ace`) ; `maxWear` : points de /armes user.
config.admin = { command = 'armes', permission = 'metiers', ace = 'combat.admin', maxWear = 1000 }
-- Libellés du journal du Registre (32 signes au plus).
config.journal = { inspect = 'Combat : armes consultées', wear = 'Combat : arme usée' }

-- Textes (%s : libellé, %d : nombre).
config.messages = {
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
}
