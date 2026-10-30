--[[
    config/server.lua
    Rôle : configuration serveur uniquement. Chargé en server_scripts : jamais envoyé aux clients.
    Dépendances : shared/init.lua
]]

vAvA.config.server = {
    log = {
        level = 'info',  -- debug | info | warn | error
    },

    database = {
        slowQueryMs = 200,       -- au-delà, la requête est signalée comme lente
        logSqlMaxLength = 500,   -- longueur maximale du SQL recopié dans les logs
    },

    modules = {
        dependencyTimeoutMs = 30000,  -- attente maximale qu'une dépendance démarrée devienne prête
    },

    -- Bornes injectées dans les schémas d'entrées réseau qui n'en précisent pas.
    schema = {
        maxStringLength = 256,
        maxArrayLength = 64,
        maxMapEntries = 64,
    },

    rpc = {
        defaultTimeoutMs = 10000,     -- appels serveur → client
        minTimeoutMs = 250,
        maxTimeoutMs = 60000,
        maxPending = 4096,            -- appels serveur → client en attente, tous joueurs confondus
        maxInFlightPerPlayer = 8,     -- requêtes client → serveur traitées en même temps pour un joueur
        maxArgs = 16,                 -- arguments déclarables par RPC
        maxReturns = 16,              -- valeurs acceptées dans une réponse client
        logNameMaxLength = 64,        -- longueur maximale d'un nom reçu du client recopiée dans les logs
    },

    players = {
        connectTimeoutMs = 120000,  -- au-delà, une connexion acceptée mais jamais finalisée libère sa session (filet)
        connectCheckMs = 5000,      -- vérification qu'une connexion acceptée existe encore côté FXServer (abandon :
                                    -- licence libérée après deux relevés manquants, sans attendre connectTimeoutMs)
        coreWaitTimeoutMs = 60000,  -- attente maximale du démarrage du core par une connexion (base injoignable…)
        -- Messages affichés au joueur pendant la connexion.
        messages = {
            checking = 'Vérification de votre compte…',
            starting = 'Le serveur démarre, merci de patienter…',
            stillStarting = 'Le serveur démarre, réessayez dans un instant.',  -- attente dépassée (coreWaitTimeoutMs)
            noLicense = 'Licence Rockstar introuvable : relancez FiveM en étant connecté à votre compte.',
            alreadyConnected = 'Ce compte est déjà connecté au serveur.',
            refused = 'Connexion refusée.',
            unavailable = 'Le serveur est momentanément indisponible, réessayez dans un instant.',
        },
    },

    characters = {
        maxPerAccount = 3,
        uniqueNames = false,  -- true : un même prénom + nom ne peut exister qu'une fois (hors supprimés)
        sexes = { 'm', 'f' },
        -- Règles des prénoms et noms. Exception à « jamais envoyé aux clients » : elles partent avec la liste des
        -- personnages, pour que l'interface de création vérifie la saisie comme le serveur (qui revérifie tout).
        name = {
            minLength = 2,    -- en caractères, accents compris
            maxLength = 24,
            letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
                .. 'àâäáãåæçéèêëíìîïñóòôöõøœúùûüýÿÀÂÄÁÃÅÆÇÉÈÊËÍÌÎÏÑÓÒÔÖÕØŒÚÙÛÜÝŸ',
            separators = " '-",  -- autorisés entre deux lettres, jamais en tête, en fin ni doublés
        },
        -- Intentions du joueur sur ses personnages (par joueur).
        rateLimits = {
            list = { capacity = 5, refillPerSecond = 1 },
            create = { capacity = 2, refillPerSecond = 0.05 },
            select = { capacity = 3, refillPerSecond = 0.2 },
            unload = { capacity = 2, refillPerSecond = 0.1 },
            delete = { capacity = 2, refillPerSecond = 0.05 },
            spawned = { capacity = 3, refillPerSecond = 0.5 },
        },
    },

    persistence = {
        positionSampleMs = 15000,  -- lecture serveur des positions des personnages actifs
        positionEpsilon = 1.0,     -- déplacement minimal (m) pour que la position soit à sauvegarder
        saveIntervalMs = 300000,   -- sauvegarde groupée des personnages modifiés
    },

    -- Champs publics (statebag du joueur, répliqué) : un client peut réécrire le sien aux yeux des autres ; le serveur
    -- garde la valeur qu'il a publiée et la remet.
    sync = {
        publicGuardDelayMs = 250,  -- délai avant de remettre la valeur du serveur : les réécritures d'un même joueur
                                   -- pendant ce délai ne coûtent qu'une correction (au plus 4 par seconde et par joueur)
        publicCompareDepth = 16,   -- tables imbriquées comparées au plus sur cette profondeur (au-delà : différentes)
    },

    spawn = {
        models = { m = 'mp_m_freemode_01', f = 'mp_f_freemode_01' },  -- en attendant un module d'apparence
        defaultPoint = { x = -269.4, y = -955.3, z = 31.2, heading = 205.8 },  -- premier spawn d'un personnage
    },

    rateLimit = {
        global = { capacity = 40, refillPerSecond = 20 },     -- par joueur, tous messages RPC confondus
        rpcDefault = { capacity = 10, refillPerSecond = 4 },  -- par joueur et par RPC, si le module n'en précise pas
        bounds = {
            minCapacity = 1,
            maxCapacity = 500,
            minRefillPerSecond = 0.01,
            maxRefillPerSecond = 500,
        },
    },
}
