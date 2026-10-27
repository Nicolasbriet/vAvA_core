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
    },

    -- Exécution des ordres d'apparition côté client (la position est toujours décidée par le serveur).
    spawn = {
        fadeMs = 500,
        modelTimeoutMs = 10000,      -- chargement du modèle de ped
        collisionTimeoutMs = 5000,   -- chargement des collisions autour du point d'apparition
        pollMs = 50,                 -- intervalle de vérification pendant une apparition
        sessionPollMs = 250,         -- attente de la session réseau au démarrage du client
    },
}
