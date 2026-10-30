--[[
    config/shared.lua
    Rôle : configuration lue par le client ET le serveur.
    Ce fichier est téléchargé par chaque client : n'y mettre aucune donnée sensible ni aucune limite de sécurité serveur.
    Dépendances : shared/init.lua
]]

vAvA.config.shared = {
    log = {
        prefix = 'vAvA',
        clientLevel = 'info',  -- niveau minimum côté client (le serveur a le sien dans config/server.lua)
        throttleMs = 10000,    -- intervalle minimum entre deux logs répétitifs d'une même source (erreur en boucle, abus)
        colors = { debug = '^5', info = '^2', warn = '^3', error = '^1', reset = '^7' },
    },

    -- Noms de hooks, RPC, registres et clés de registre.
    identifiers = {
        pattern = '^[%w_%-%.:]+$',
        maxLength = 64,
    },

    hooks = {
        defaultPriority = 100,  -- plus petit = exécuté plus tôt
        minPriority = 0,
        maxPriority = 1000,
        slowHandlerMs = 25,     -- au-delà, le handler est signalé comme lent
    },

    -- Appels client → serveur, côté client. Les limites qui protègent le serveur sont dans config/server.lua.
    rpc = {
        defaultTimeoutMs = 10000,
        minTimeoutMs = 250,
        maxTimeoutMs = 60000,
        maxPending = 32,        -- appels simultanés en attente de réponse sur un client
        -- Réponse trop grosse envoyée en latent (core.net) : le serveur prévient avant (octets, débit) et l'attente
        -- de l'appel est repoussée du temps de transfert plus cette marge, au plus de maxLatentExtendMs. Le serveur
        -- applique la même règle à ses appels serveur → client partis en latent.
        latentMarginMs = 3000,
        maxLatentExtendMs = 30000,
    },

    -- Essai du réseau lancé depuis la console du serveur (vava_reseau_essai) : au-delà, le client écrit en console F8
    -- ce qui est arrivé.
    net = {
        probeTimeoutMs = 60000,
    },

    -- Abonnements de zone, côté client (0.11.0) : les zones suivies sont décidées par le serveur ; le client garde une
    -- réplique de chacune et redemande l'instantané s'il manque une révision.
    zones = {
        maxBuffered = 64,          -- différences gardées par zone en attendant un instantané (latent derrière une file)
        awaitMarginMs = 3000,      -- marge ajoutée au délai annoncé d'un instantané latent avant de le redemander
        maxAwaitMs = 30000,        -- attente maximale d'un instantané annoncé
        resyncRetryMs = 5000,      -- premier délai avant de réessayer une demande d'instantané en échec (doublé)
        resyncMaxRetryMs = 60000,  -- délai maximal entre deux essais
        staleSnapshotMs = 60000,   -- instantané latent doublé par une sortie (ou un déchargement) : ignoré s'il arrive
                                   -- dans ce délai (aucun latent n'est en route plus longtemps)
    },

    -- Exécution des ordres d'apparition côté client (la position est toujours décidée par le serveur).
    spawn = {
        fadeMs = 500,
        modelTimeoutMs = 10000,      -- chargement du modèle de ped
        collisionTimeoutMs = 5000,   -- chargement des collisions autour du point d'apparition
        pollMs = 50,                 -- intervalle de vérification pendant une apparition
        sessionPollMs = 250,         -- attente de la session réseau au démarrage du client
        -- Écran de chargement (0.13.0) : si cette ressource tourne à la première mise en attente, elle ferme elle-même
        -- l'écran quand la sélection est affichée (passage sans écran noir) ; '' : le core le ferme à la mise en
        -- attente (comportement de 0.12.0). Filet : le core le ferme au plus tard maxHoldMs (ms) après.
        loadingScreen = { resource = 'vava_loading', maxHoldMs = 30000 },
    },
}
