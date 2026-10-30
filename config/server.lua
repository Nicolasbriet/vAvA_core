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
        -- Gardes de connexion : modules qui vérifient chaque arrivant par un hook (bans). Tant que l'un d'eux n'est pas
        -- prêt (démarrage, redémarrage, arrêté — y compris par un restart du core, que FiveM ne relance pas — ou en
        -- échec), les connexions sont refusées (guardNotReady) ; seule une ressource absente du serveur n'est pas
        -- attendue (signalée à la console à chaque connexion). Serveur sans Registre, ou ressource renommée : mettre
        -- cette liste à jour.
        connectionGuards = { 'vava_admin' },
        -- Messages affichés au joueur pendant la connexion.
        messages = {
            checking = 'Vérification de votre compte…',
            starting = 'Le serveur démarre, merci de patienter…',
            stillStarting = 'Le serveur démarre, réessayez dans un instant.',  -- attente dépassée (coreWaitTimeoutMs)
            noLicense = 'Licence Rockstar introuvable : relancez FiveM en étant connecté à votre compte.',
            alreadyConnected = 'Ce compte est déjà connecté au serveur.',
            refused = 'Connexion refusée.',
            unavailable = 'Le serveur est momentanément indisponible, réessayez dans un instant.',
            guardNotReady = 'Le royaume s\'éveille : réessayez dans un instant.',  -- un garde de connexion pas prêt
            -- personnage ou ordre d'apparition impossible à envoyer (trop gros…) : déconnexion plutôt qu'un joueur bloqué
            sendFailed = 'Votre personnage n\'a pas pu vous être envoyé : reconnectez-vous ; si cela se répète, prévenez le Conseil.',
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
        publicCompareDepth = 16,   -- tables imbriquées comparées au plus sur cette profondeur (au-delà : différentes) ;
                                   -- un champ public au schéma plus profond est refusé à sa déclaration
        publicFloatTolerance = 1e-6,  -- écart relatif admis entre deux nombres non entiers (aller-retour réseau)
        publicMaxCorrections = 3,     -- remises d'un champ depuis sa dernière publication avant de les espacer
        publicGuardMaxDelayMs = 10000,  -- espacement maximal (doublé à chaque remise au-delà du plafond) : une valeur
                                        -- qui ne reviendrait jamais égale coûte au plus une écriture par 10 s
    },

    -- Envois serveur → client (core.net) : mesure de taille, envoi latent des gros messages, compteur par ressource et
    -- par évènement, commande du Conseil /vava_reseau.
    net = {
        mode = 'auto',          -- auto : mesure exacte (une seule sérialisation) si le runtime l'offre, sinon
                                -- estimation ; estimate : forcer l'estimation (secours si la mesure exacte se conduit
                                -- mal en jeu)
        maxBytes = 262144,      -- 256 Ko : au-delà, envoi refusé (too_large) et erreur en console
        maxArgs = 16,           -- valeurs par envoi
        maxTargets = 256,       -- joueurs dans une liste de cibles
        latent = {
            threshold = 8192,          -- octets : strictement au-delà, envoi latent (option auto)
            bytesPerSecond = 65536,    -- débit de chaque envoi latent (64 Ko/s, environ 0,5 Mbit/s)
            maxInFlightBytes = 524288, -- 512 Ko : volume latent encore en route vers un même joueur au-delà duquel un
                                       -- nouvel envoi latent vers lui est refusé (saturated)
            maxTotalInFlightBytes = 4194304,  -- 4 Mo : volume latent en route tous joueurs confondus au-delà duquel un
                                              -- nouvel envoi latent est refusé (saturated) ; catalogues de l'Atelier
        },
        near = {
            maxRadius = 1000.0,     -- mètres : rayon maximal de sendNear et playersNear
            positionCacheMs = 50,   -- position d'un ped gardée ce temps : un passage des zones et les sendNear qui le
                                    -- suivent ne relisent rien (50 ms à 10 m/s : 0,5 m d'écart au plus)
        },
        counter = {
            bucketMs = 5000,        -- largeur d'une case de la fenêtre glissante
            buckets = 12,           -- cases : fenêtre d'une minute (55 à 60 s)
            maxKeys = 512,          -- couples (ressource, évènement) suivis ; au-delà, cumul sous (*, <autres>)
            maxWatched = 4,         -- joueurs suivis évènement par évènement en même temps
            maxWatchedKeys = 64,    -- évènements distincts par joueur suivi ; au-delà, <autres>
            watchMs = 300000,       -- durée d'un suivi (5 min)
            sweepMs = 60000,        -- ménage des clés sans envoi depuis une fenêtre
        },
        command = {
            name = 'vava_reseau',             -- commande du Conseil
            probeName = 'vava_reseau_essai',  -- commande console d'essai (débit du latent, ordre, proximité)
            permission = 'tools',             -- droit vava_admin (Sénéchal et au-dessus)
            ace = 'vava.reseau',              -- repli sans vava_admin
            adminResource = 'vava_admin',     -- ressource qui tient les droits et le journal
            cooldownMs = 2000,                -- entre deux commandes d'un même membre
            lines = 10,                       -- évènements affichés (1 à 20)
            probeMaxKb = 256,                 -- taille maximale d'un essai
            messages = {
                author = 'Réseau',
                header = 'Dernière minute (%s) : %d envois, %s, dont %d latents.',
                modeExact = 'mesure exacte',
                modeEstimate = 'estimation',
                line = '%d. %s · %s : %d envois, %s, le plus gros %s%s',
                lineLatent = ', %d latents',
                empty = 'Aucun envoi compté dans la dernière minute.',
                player = 'Joueur %d (%s) : %d envois, %s dans la dernière minute.',
                noCharacter = 'sans personnage',
                watchStarted = 'Détail par évènement suivi pendant %d min : relancez la commande dans une minute.',
                watchFull = 'Déjà %d joueurs suivis : détail indisponible pour celui-ci.',
                unknownPlayer = 'Aucun joueur n° %s en jeu.',
                usage = 'usage : /vava_reseau | joueur <n°> | ressource <nom> | zones [n°]',
                -- abonnements de zone (0.11.0) : durées à deux décimales, virgule française
                zones = 'Zones : %d (%s) ; %d abonnements ; passage : dernier %s ms, moyen %s ms, au plus %s ms sur la minute.',
                zonesNone = 'Aucune zone déclarée.',
                zonesPlayer = 'Joueur %d : %d zone(s) suivie(s)%s',
                zonesNoPass = '–',  -- aucun passage encore mesuré
                footer = 'Non comptés : GlobalState, state bags et envois directs des modules.',
                probeUsage = 'usage : vava_reseau_essai <n° du joueur> <Ko 1-256> [rayon]',
                probeSent = 'essai envoyé au joueur %d : %d Ko en latent, %d joueur(s) à %g m',
                probeSentAlone = 'essai envoyé au joueur %d : %d Ko en latent',
                probeRefused = 'essai refusé : %s',
            },
        },
    },

    -- Abonnements de zone (core.zones, 0.11.0) : un module déclare des zones et tient leur état dans le core ; le serveur
    -- abonne les joueurs proches (positions lues par lui) et n'envoie l'état et ses différences qu'à eux.
    zones = {
        passMs = 1000,             -- intervalle entre deux passages (entrées et sorties de zone). Recommandé : garder
                                   -- 1000. Coût mesuré hors jeu (Lua seul, 2 048 zones, rapport T-014) par passage :
                                   -- joueurs immobiles 0,03 ms à 64 joueurs, 0,07 ms à 128 (non recalculés) ; en
                                   -- mouvement, zones éparses 0,23 / 0,46 ms, ville (1,5 × 1,5 km, rayons 2-30 m)
                                   -- 1,7 / 3,3 ms, ville très dense 6,4 / 13,9 ms ; plus quatre natives par joueur.
                                   -- 2000 divise ce coût par deux et reste sûr avec la marge par défaut de 50 m (un
                                   -- cavalier au galop, ~15 m/s, parcourt 30 m entre deux passages) ; au-delà, la zone
                                   -- peut arriver après le joueur
        stillDistance = 1.0,       -- m : un joueur qui a bougé de moins depuis son dernier calcul (même instance, aucune
                                   -- zone déclarée, déplacée ou retirée entre-temps) n'est pas recalculé
        cellSize = 256.0,          -- côté d'une case de la grille (m)
        coordLimit = 50000.0,      -- |x| et |y| d'un centre au plus (la carte tient dans ±10 000)
        maxRadius = 500.0,         -- rayon d'une zone au plus (m, > 0)
        defaultMargin = 50.0,      -- marge par défaut au-delà du bord : la zone est reçue avant d'y entrer
        maxMargin = 500.0,         -- marge au plus (≥ 0)
        exitMargin = 25.0,         -- désabonné seulement au-delà de rayon + marge + exitMargin (pas d'aller-retour)
        maxZones = 2048,           -- zones déclarées en tout
        maxZonesPerOwner = 1024,   -- zones d'un même module
        maxKeys = 256,             -- clés dans l'état d'une zone
        keyMaxLength = 48,         -- octets d'une clé (et d'un identifiant de zone)
        maxChanges = 64,           -- clés changées ou retirées par appel
        maxValueBytes = 4096,      -- taille estimée d'une valeur
        maxStateBytes = 32768,     -- taille estimée de l'état d'une zone (clés + valeurs)
        maxTotalStateBytes = 8388608,  -- 8 Mo : somme des états de toutes les zones
        maxDiffBytes = 8192,       -- différence regroupée d'un tour au-delà de laquelle l'instantané part à sa place
        maxSubscriptionsPerPlayer = 256,  -- zones suivies par un joueur ; au-delà, les plus lointaines attendent
        snapshotBudgetBytes = 32768,      -- instantanés envoyés à un même joueur dans un passage (taille estimée) ; le
                                          -- reste au passage suivant, les plus proches d'abord
        rateLimit = { capacity = 4, refillPerSecond = 0.5 },  -- RPC core:zones:resync, par joueur
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
