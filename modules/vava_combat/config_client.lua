--[[
    vava_combat/config_client.lua
    Rôle : réglages des armes que lit le client (le serveur les lit aussi) : fiches des armes (catégorie, famille de
           l'arme en main), bouclier accroché (position au bras ou dans le dos, cadences du client) et placement de
           chaque bouclier, contrôles natifs coupés. Téléchargé par chaque joueur. `weapons` et `shield` y sont
           entiers : le client les passe à shared/shield.lua. Tout le reste (catégories, familles, types, objets,
           recettes, qualité, usure, `strike`, commandes du Conseil, journal, textes) est dans config.lua, servi au
           seul serveur (T-132).
    Les modèles et placements sont des remplaçants vanilla (-- PLACEHOLDER, docs/plan/ASSETS_PLACEHOLDERS.md) : le jour
    où les boucliers médiévaux arrivent, seuls `shields[…]` et `provisional` changent ici (`items[…].held.model` dans
    config.lua).
    Les chiffres (dégâts, solidité, part bloquée) sont des valeurs de départ, à régler à la porte T-119.
    Dépendances : shared/constants.lua
]]

VavaCombat.config = {
    clientFile = true,  -- posé par ce fichier, ne pas changer (sans lui, le serveur signale un config.lua d'avant 1.1.0)

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
}
