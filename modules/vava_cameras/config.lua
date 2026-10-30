--[[
    vava_cameras/config.lua
    Rôle : configuration des caméras (lue par le client et le serveur) : qualités, limites, adresses STUN, mur,
           textes du journal.
    Dépendances : shared/constants.lua
]]

VavaCameras.config = {
    coreVersion = '0.5.0',

    -- droit vava_admin pour regarder (tout le Conseil, sans règle de rang)
    permission = 'watch',

    -- Une seule capture par joueur, à la taille pleine ; chaque spectateur reçoit sa propre qualité. L'image ne
    -- passe jamais par le serveur (de joueur à spectateur) ; ces débits sont pris sur la connexion montante du joueur
    -- filmé (qui porte aussi son jeu et sa voix) : bornés ensemble par `budget`. bitrateKbps : plafond, atteint quand
    -- le budget le permet ; minKbps : plancher, garanti à chaque spectateur admis.
    capture = { width = 960, height = 540, fps = 20 },
    qualities = {
        tile = { scale = 2, fps = 10, bitrateKbps = 250, minKbps = 120 },    -- case d'un mur : 480 × 270
        full = { scale = 1, fps = 20, bitrateKbps = 1200, minKbps = 600 },   -- vue en grand : 960 × 540
    },

    -- Débit montant total d'un joueur filmé, tous ses spectateurs ensemble (jeu et web). Chacun reçoit son plancher,
    -- puis le reste va à la vue en grand jusqu'à son plafond, enfin aux cases à parts égales ; la part de chacun est
    -- revue à chaque arrivée ou départ d'un spectateur. Un spectateur de plus qui ne tient pas (deuxième vue en grand,
    -- ou planchers au-delà du total) est refusé : « budget ». Avec les valeurs ci-dessous et 6 spectateurs au plus,
    -- seul le second regard en grand est refusé ; le total, lui, ne dépasse jamais 1 500 kbit/s (au lieu de 7 200).
    budget = {
        uplinkKbps = 1500,
        perQuality = { full = 1 },   -- une seule vue en grand à la fois par joueur filmé
    },

    -- Adresses STUN données aux deux bouts : sans elles, seuls le jeu et le spectateur d'un même réseau se trouvent.
    -- Celle de Google ne coûte rien au serveur ; elle voit passer l'adresse IP des joueurs à la connexion.
    iceServers = { 'stun:stun.l.google.com:19302' },

    limits = {
        viewersPerPlayer = 6,      -- membres du Conseil regardant le même joueur en même temps
        sessions = 96,             -- caméras ouvertes en tout
        sessionMaxMs = 2 * 60 * 60 * 1000,   -- au-delà, une caméra oubliée s'éteint
        answerMs = 30000,          -- sans réponse du spectateur dans ce délai, la caméra s'éteint
        sdpMax = 20000,
        -- offre du joueur filmé relayée au membre en jeu en envoi latent, à ce débit (octets par seconde) : une offre
        -- de 6 Ko arrive en 0,2 s, une de 20 Ko en 0,6 s, sans jamais occuper la voie fiable du jeu du membre
        offerBytesPerSecond = 32000,
    },

    -- Mur en jeu : dispositions proposées (cases par côté), joueurs relus à intervalle.
    wall = {
        command = 'cameras',
        layouts = { 1, 2, 3, 4 },
        defaultLayout = 3,
        refreshMs = 5000,
        -- cases ouvertes l'une après l'autre : un mur 4 × 4 reste sous la limite de messages du core (20 par seconde)
        staggerMs = 150,
        -- un mur ouvert depuis plus longtemps n'ouvre plus de case : le rouvrir (nouvelle ligne au journal)
        maxOpenMs = 2 * 60 * 60 * 1000,
        tool = { label = 'Mur des caméras', hint = 'L\'écran de tous les joueurs connectés, en grille ; un clic l\'ouvre en grand.' },
    },

    rateLimits = {
        capture = { capacity = 8, refillPerSecond = 2 },   -- offre et fin du joueur filmé
        wall = { capacity = 4, refillPerSecond = 0.5 },    -- ouverture du mur
        watch = { capacity = 40, refillPerSecond = 8 },    -- caméras demandées (un mur 4 × 4 en ouvre 16)
        signal = { capacity = 40, refillPerSecond = 8 },   -- réponses et fermetures du membre qui regarde
        players = { capacity = 4, refillPerSecond = 1 },
    },

    -- Chancellerie (panneau web) : seule ressource admise à ouvrir une caméra en son nom.
    web = { bridge = 'vava_chancellerie' },

    -- Journal du Conseil (32 caractères au plus).
    messages = {
        logWall = 'Mur des caméras ouvert',
        logWatch = 'Écran regardé',
    },
}
