--[[
    vava_chancellerie/config.lua
    Rôle : configuration du pont (serveur seulement).
    Dépendances : shared/constants.lua
]]

VavaBridge.config = {
    coreVersion = '0.5.0',

    -- Réglages posés par la Chancellerie au lancement de FXServer (+set sur la ligne de commande, jamais dans le
    -- server.cfg) : clé partagée, tirée à chaque lancement, et adresse de la Chancellerie pour la prévenir.
    convars = { token = 'vava_chancellerie_token', url = 'vava_chancellerie_url' },
    -- longueur minimale de la clé : plus courte, le pont reste fermé
    tokenMin = 32,
    -- adresse de la Chancellerie qui reçoit les évènements
    eventPath = '/api/bridge/event',
    -- corps de requête accepté (octets)
    bodyMax = 65536,
    -- évènements perdus (Chancellerie fermée) : signalés au plus une fois par intervalle
    pushWarnEveryMs = 60000,

    -- Caméras (vava_cameras) : droit du Registre pour regarder ; la vue en grand passe par la demande « écran du
    -- joueur » du Registre (cible vérifiée, inscrite au journal), les cases d'un mur par l'ouverture du mur.
    cameras = { permission = 'watch', fullRequest = 'watchScreen' },

    -- Journal du Registre pour les actions faites depuis le web dans d'autres modules (32 caractères au plus).
    messages = {
        logZoneUpdate = 'Zone de voix modifiée',
        logZoneDelete = 'Zone de voix supprimée',
        logWall = 'Mur des caméras ouvert',
    },
}
