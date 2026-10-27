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
    flushIntervalMs = 3000,        -- écriture groupée du journal des modifications
    hotbarSize = 5,

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
