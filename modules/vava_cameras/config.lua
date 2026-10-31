--[[
    vava_cameras/config.lua
    Rôle : réglages des caméras que lit le seul serveur (servi au seul serveur, jamais téléchargé par les joueurs) :
           droit de regarder, capture, budget du débit montant, adresses STUN, bornes des caméras, mur (dispositions,
           durée, outil du Registre), débits, textes du journal. Complète la table ouverte par config_client.lua
           (qualités, spectateurs par joueur, taille d'une offre, commande et rythme du mur) sans en réécrire une clé
           (T-132).
    Dépendances : shared/constants.lua, config_client.lua
]]

local config = VavaCameras.config

config.coreVersion = '0.5.0'

-- droit vava_admin pour regarder (tout le Conseil, sans règle de rang)
config.permission = 'watch'

-- Une seule capture par joueur, à la taille pleine ; chaque spectateur reçoit sa propre qualité (`qualities`,
-- config_client.lua). L'image ne passe jamais par le serveur (de joueur à spectateur) ; ces débits sont pris sur la
-- connexion montante du joueur filmé (qui porte aussi son jeu et sa voix) : bornés ensemble par `budget`.
config.capture = { width = 960, height = 540, fps = 20 }

-- Débit montant total d'un joueur filmé, tous ses spectateurs ensemble (jeu et web). Chacun reçoit son plancher,
-- puis le reste va à la vue en grand jusqu'à son plafond, enfin aux cases à parts égales ; la part de chacun est
-- revue à chaque arrivée ou départ d'un spectateur. Un spectateur de plus qui ne tient pas (deuxième vue en grand,
-- ou planchers au-delà du total) est refusé : « budget ». Avec les valeurs ci-dessous et 6 spectateurs au plus,
-- seul le second regard en grand est refusé ; le total, lui, ne dépasse jamais 1 500 kbit/s (au lieu de 7 200).
-- C'est le débit visé par les encodeurs : sur le fil, compter environ 1,6 Mbit/s (en-têtes RTP, SRTP, UDP et IP :
-- 6 à 10 %, retransmissions, images clés, sondes de débit au démarrage) ; 1 400 ici tient 1,5 Mbit/s sur le fil.
config.budget = {
    uplinkKbps = 1500,
    perQuality = { full = 1 },   -- une seule vue en grand à la fois par joueur filmé
}

-- Adresses STUN données aux deux bouts : sans elles, seuls le jeu et le spectateur d'un même réseau se trouvent.
-- Celle de Google ne coûte rien au serveur ; elle voit passer l'adresse IP des joueurs à la connexion.
config.iceServers = { 'stun:stun.l.google.com:19302' }

-- Bornes des caméras (spectateurs par joueur et taille d'une offre : config_client.lua).
config.limits.sessions = 96                        -- caméras ouvertes en tout
config.limits.sessionMaxMs = 2 * 60 * 60 * 1000    -- au-delà, une caméra oubliée s'éteint
config.limits.answerMs = 30000                     -- sans réponse du spectateur dans ce délai, la caméra s'éteint
-- offre du joueur filmé relayée au membre en jeu en envoi latent, à ce débit (octets par seconde) : une offre de 6 Ko
-- arrive en 0,2 s, une de 20 Ko en 0,6 s, sans jamais occuper la voie fiable du jeu du membre
config.limits.offerBytesPerSecond = 32000

-- Mur en jeu : dispositions proposées (cases par côté). Commande et rythme : config_client.lua.
config.wall.layouts = { 1, 2, 3, 4 }
config.wall.defaultLayout = 3
-- un mur ouvert depuis plus longtemps n'ouvre plus de case : le rouvrir (nouvelle ligne au journal)
config.wall.maxOpenMs = 2 * 60 * 60 * 1000
config.wall.tool = { label = 'Mur des caméras', hint = 'L\'écran de tous les joueurs connectés, en grille ; un clic l\'ouvre en grand.' }

config.rateLimits = {
    capture = { capacity = 8, refillPerSecond = 2 },   -- offre et fin du joueur filmé
    wall = { capacity = 4, refillPerSecond = 0.5 },    -- ouverture du mur
    watch = { capacity = 40, refillPerSecond = 8 },    -- caméras demandées (un mur 4 × 4 en ouvre 16)
    signal = { capacity = 40, refillPerSecond = 8 },   -- réponses et fermetures du membre qui regarde
    players = { capacity = 4, refillPerSecond = 1 },
}

-- Chancellerie (panneau web) : seule ressource admise à ouvrir une caméra en son nom.
config.web = { bridge = 'vava_chancellerie' }

-- Journal du Conseil (32 caractères au plus).
config.messages = {
    logWall = 'Mur des caméras ouvert',
    logWatch = 'Écran regardé',
}
