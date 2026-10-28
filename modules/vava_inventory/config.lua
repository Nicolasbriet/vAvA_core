--[[
    vava_inventory/config.lua
    Rôle : configuration de l'inventaire (lue par le client et le serveur). Poids en grammes.
    Dépendances : shared/constants.lua
]]

VavaInventory.config = {
    coreVersion = '0.3.0',

    -- Inventaire porté par chaque personnage. Agrandir la grille s'applique aussi aux personnages existants.
    character = { label = 'Besace', width = 10, height = 6, maxWeight = 25000 },

    -- Sacs au sol : conteneurs temporaires (non conservés au redémarrage du serveur), entités réseau visibles des
    -- joueurs proches.
    drop = {
        label = 'Sac au sol',
        width = 6, height = 4, maxWeight = 60000,
        model = 'prop_money_bag_01',
        lifetimeMs = 600000,       -- disparition après 10 minutes
        interactDistance = 2.5,    -- distance maximale (m), vérifiée côté serveur à chaque opération
        groundOffset = 0.98,       -- hauteur du centre du ped au-dessus du sol
        reuseDistance = 1.5,       -- jeter près d'un sac existant le remplit plutôt que d'en créer un autre
        stateWaitMs = 2000,        -- client : attente maximale de l'entité locale d'un sac signalé par statebag
        statePollMs = 100,
    },

    maxItemSize = 8,               -- taille maximale d'un objet (cases), en largeur comme en hauteur
    -- Effets déclarés par un objet (`effects = { hunger = 35 }`), appliqués par les modules qui les lisent.
    effects = { maxEntries = 8, maxValue = 1000 },
    -- Métadonnées portées par une pile (toujours un objet JSON) : bornes vérifiées à chaque écriture par un module.
    -- maxEntries s'applique à chaque table (racine comme imbriquée), maxDepth compte la racine.
    metadata = { maxEntries = 32, maxDepth = 4, maxStringLength = 256 },
    -- Conteneurs ouverts par un module avec un ancrage (coffre, grenier, station…) : rayon maximal (m) et cadence
    -- de la vérification d'éloignement, active seulement tant qu'un conteneur ancré est ouvert par quelqu'un.
    anchor = { maxRadius = 25.0, sweepMs = 2000 },
    -- Objet tenu en main (objets déclarant `held = { model, bone?, offset?, rotation? }`).
    hands = {
        defaultBone = 57005,       -- main droite (SKEL_R_Hand)
        pollMs = 1000,             -- client : cadence de la boucle lente, active seulement tant qu'un accessoire est affiché
        modelTimeoutMs = 5000,     -- client : attente maximale du chargement d'un modèle d'accessoire
    },
    flushIntervalMs = 3000,        -- écriture groupée du journal des modifications
    hotbarSize = 5,

    -- Catalogue de développement (1.5.0) : un conteneur temporaire garni d'une pile pleine de chaque objet connu,
    -- par catégorie, découpé en pages à la taille de sa grille. `/catalogue [catégorie] [page]` en jeu (droit
    -- `permission` de vava_admin ; sans lui, ACE `ace`), `catalogue <joueur> [catégorie] [page]` en console. Ce qu'on
    -- en prend est regarni, ce qu'on y dépose disparaît, rien n'est écrit en base. À n'activer que sur un serveur
    -- de test : tout y est gratuit.
    catalog = {
        enabled = true,
        command = 'catalogue',
        label = 'Catalogue (développement)',
        width = 16, height = 10,
        permission = 'staff', ace = 'vava_inventory.catalogue',
    },

    -- Touches par défaut, modifiables par chaque joueur (Paramètres > Raccourcis > FiveM).
    keys = { open = 'I', hotbar = { '1', '2', '3', '4', '5' } },
    labels = { open = 'Ouvrir l\'inventaire', slot = 'Raccourci d\'inventaire %d' },

    -- Objets donnés à la création d'un personnage : { { item = 'nom', quantity = 1 }, ... }.
    startingItems = {},

    rateLimits = {
        open = { capacity = 4, refillPerSecond = 1 },
        action = { capacity = 20, refillPerSecond = 10 },  -- déplacer, diviser, fusionner, jeter, raccourcis
        use = { capacity = 4, refillPerSecond = 1 },
    },
}
