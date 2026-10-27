--[[
    vava_cameras/shared/constants.lua
    Rôle : table du module (seule globale de la ressource) et constantes de protocole.
    Dépendances : aucune
]]

VavaCameras = {}

-- Événements serveur → client (toujours vers le seul joueur concerné).
VavaCameras.EVENTS = {
    START = 'vava_cameras:start',     -- au joueur filmé : { session, quality = { … }, iceServers }
    ANSWER = 'vava_cameras:answer',   -- au joueur filmé : { session, sdp } réponse de celui qui regarde
    STOP = 'vava_cameras:stop',       -- au joueur filmé : { session }
    OFFER = 'vava_cameras:offer',     -- au membre qui regarde en jeu : { session, sdp }
    ENDED = 'vava_cameras:ended',     -- au membre qui regarde en jeu : { session, reason }
}

-- Intentions des clients (RPC du core).
VavaCameras.RPC = {
    OFFER = 'vava_cameras:sendOffer',     -- joueur filmé : (session, sdp), candidats réseau compris
    FAILED = 'vava_cameras:failed',       -- joueur filmé : (session, raison)
    WALL = 'vava_cameras:wall',           -- membre en jeu : ouvre le mur → joueurs, adresses STUN (inscrit au journal)
    PLAYERS = 'vava_cameras:players',     -- membre en jeu : joueurs connectés (mur ouvert)
    WATCH = 'vava_cameras:watch',         -- membre en jeu : (joueur, qualité) → session ; vue en grand au journal
    ANSWER = 'vava_cameras:sendAnswer',   -- membre en jeu : (session, sdp)
    CLOSE = 'vava_cameras:close',         -- membre en jeu : (session)
    LEAVE = 'vava_cameras:leave',         -- membre en jeu : mur fermé, toutes ses caméras s'éteignent
}

-- Hooks déclenchés par le module.
VavaCameras.HOOKS = {
    WEB = 'vava_cameras:web',   -- after (serveur) : { session, offer? , ended? } pour une caméra regardée depuis le web
}

-- Raisons de fin annoncées par le jeu du joueur filmé.
VavaCameras.FAILURES = { 'capture_failed', 'unsupported', 'connection_failed', 'closed' }

-- Format des identifiants de caméra (24 chiffres hexadécimaux).
VavaCameras.SESSION_PATTERN = '^%x+$'
VavaCameras.SESSION_LENGTH = 24

-- Qualités demandables.
VavaCameras.QUALITIES = { 'tile', 'full' }

-- Liens facultatifs.
VavaCameras.ADMIN = {
    RESOURCE = 'vava_admin',
    REGISTRY = 'vava_admin:tools',
    READY = 'vava_admin:toolsReady',
    OPENED = 'vava_admin:toolOpened',
    TOOL = 'vava_cameras:wall',
}
