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

    -- Journal du Registre pour les actions faites depuis le web dans d'autres modules (32 caractères au plus).
    messages = {
        logZoneUpdate = 'Zone de voix modifiée',
        logZoneDelete = 'Zone de voix supprimée',
        logWall = 'Mur des caméras ouvert',
    },
}
