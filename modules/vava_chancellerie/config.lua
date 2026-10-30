--[[
    vava_chancellerie/config.lua
    Rôle : configuration du pont (serveur seulement).
    Dépendances : shared/constants.lua
]]

VavaBridge.config = {
    coreVersion = '0.5.0',

    -- Réglage posé par la Chancellerie au lancement de FXServer (+set sur la ligne de commande, jamais dans le
    -- server.cfg) : son adresse, pour la prévenir ; présente, elle dit aussi que le serveur a été lancé par elle. Lue
    -- une seule fois, au setup, et seulement de la forme http://127.0.0.1:<port> (sinon refusée : pont fermé).
    -- `legacyToken` : ancienne façon de passer la clé (Chancellerie d'avant 1.6.0), ignorée et signalée.
    convars = { url = 'vava_chancellerie_url', legacyToken = 'vava_chancellerie_token' },
    -- longueur minimale de la clé : plus courte, elle est refusée et le pont reste fermé
    tokenMin = 32,
    -- Clé du pont, tirée à chaque lancement : jamais sur la ligne de commande (lisible par tout utilisateur de la
    -- machine) ni dans une convar (lisible par toute ressource). Le pont la demande dans la console (ligne
    -- VavaBridge.KEY_ASK_LINE, fixée par le protocole) toutes les `askEveryMs`, pendant `waitMs` au plus ; elle arrive
    -- par la console du serveur et ne vit qu'en mémoire. `max` : longueur au plus (la Chancellerie en envoie 64 signes).
    key = {
        askEveryMs = 5000,
        waitMs = 120000,
        max = 128,
    },
    -- Comptes de jeu vus reliés en jeu : seuls ceux-là reçoivent un rang du panneau. Une liaison en cours (réponse de
    -- la Chancellerie pas encore arrivée) est attendue au plus ce délai (ms) par requête /staff/sync, toutes liaisons
    -- confondues. Doit rester sous le délai d'une demande de la Chancellerie au pont (TIMEOUT_MS = 8000 dans
    -- chancellerie/lib/bridge.js) : au-delà, elle a déjà abandonné la requête.
    links = { waitMs = 5000 },
    -- adresse de la Chancellerie qui reçoit les évènements
    eventPath = '/api/bridge/event',
    -- corps de requête accepté (octets)
    bodyMax = 65536,
    -- évènements perdus (Chancellerie fermée) : signalés au plus une fois par intervalle
    pushWarnEveryMs = 60000,

    -- Caméras (vava_cameras) : droit du Registre pour regarder ; la vue en grand passe par la demande « écran du
    -- joueur » du Registre (cible vérifiée, inscrite au journal), les cases d'un mur par l'ouverture du mur ; une case
    -- demandée par un compte qui n'a ouvert aucun mur depuis tileLogMs (2 h, la durée maximale d'une caméra) inscrit
    -- sa propre ligne « Cases du mur regardées ».
    cameras = { permission = 'watch', fullRequest = 'watchScreen', tileLogMs = 2 * 60 * 60 * 1000 },

    -- Liaison d'un compte du panneau à son joueur : commande à taper en jeu avec le code affiché par le panneau,
    -- essais permis par minute, messages au joueur (clés = codes d'erreur renvoyés par la Chancellerie).
    link = {
        command = 'chancellerie',
        attemptsPerMinute = 5,
        title = 'Chancellerie',
        messages = {
            usage = 'Tapez « %s » suivi du code à 6 chiffres affiché dans la Chancellerie.',
            tooMany = 'Trop d\'essais : patientez une minute.',
            notReady = 'Votre compte n\'est pas encore chargé : réessayez dans un instant.',
            unreachable = 'La Chancellerie ne répond pas : réessayez plus tard.',
            linked = 'Ce joueur est relié au compte « %s » de la Chancellerie ; son rang du Conseil s\'applique.',
            refused = 'Liaison refusée.',
            unknown_code = 'Code inconnu ou expiré : demandez-en un nouveau dans la Chancellerie.',
            too_many_attempts = 'Trop de codes faux : patientez quelques minutes.',
        },
    },

    -- Liste blanche Discord (réglée dans la Chancellerie) : délai de sa réponse à la connexion d'un joueur (ms),
    -- messages quand elle ne répond pas.
    whitelist = {
        timeoutMs = 8000,
        messages = {
            -- serveur lancé par la Chancellerie dont la clé n'est pas encore arrivée : la liste ne peut pas être lue
            opening = 'Le registre des portes s\'ouvre : réessayez dans un instant.',
            unreachable = 'La liste blanche ne peut pas être vérifiée pour l\'instant : réessayez dans une minute.',
            refused = 'Ce serveur est réservé aux membres de son Discord.',
        },
    },

    -- Journal du Registre pour les actions faites depuis le web dans d'autres modules (32 caractères au plus).
    messages = {
        logZoneUpdate = 'Zone de voix modifiée',
        logZoneDelete = 'Zone de voix supprimée',
        logWall = 'Mur des caméras ouvert',
        logTiles = 'Cases du mur regardées',
    },
}
