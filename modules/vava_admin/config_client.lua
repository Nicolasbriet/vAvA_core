--[[
    vava_admin/config_client.lua
    Rôle : réglages de l'administration que lit le client : commandes et touches du Registre et du vol libre, outils
           du client (vol libre, observation, téléportation au repère), durée d'une annonce, textes affichés par le
           client. Téléchargé par chaque joueur ; le serveur le lit aussi. Tout le reste (rangs et droits, bans,
           journal, signalements, débits, textes du serveur) est dans config.lua, servi au seul serveur (T-132).
    Dépendances : shared/constants.lua
]]

VavaAdmin.config = {
    clientFile = true,  -- posé par ce fichier, ne pas changer (sans lui, le serveur signale un config.lua d'avant 1.9.0)

    -- Commande des signalements (/signaler). Délai entre deux signalements et nombre ouvert : config.lua.
    reportCommand = 'signaler',

    -- Client : touches (réglables par le joueur dans Paramètres > Raccourcis > FiveM), outils. Le vol libre se bascule
    -- d'une touche ; le serveur vérifie le droit à chaque appui (sans droit, la touche ne fait rien).
    keys = { open = 'F10', noclip = 'F2' },
    openCommand = 'conseil',
    noclipCommand = 'vava_admin_noclip',
    labels = { open = 'Ouvrir le Registre du Conseil', noclip = 'Vol libre (Conseil)' },
    noclip = { speed = 1.0, fastSpeed = 4.0, slowSpeed = 0.25 },
    spectate = { streamWaitMs = 3000, pollMs = 100, anchorMs = 1000, anchorDepth = 12.0 },
    waypoint = { probeHeights = { 1000.0, 800.0, 600.0, 400.0, 300.0, 200.0, 150.0, 100.0, 50.0, 25.0, 0.0 }, probeWaitMs = 50 },
    announcementMs = 9000,

    -- Textes affichés par le client (le panneau a les siens : web/js/strings.js). Ceux du serveur : config.lua.
    messages = {
        reportUsage = 'usage : /%s <message>',
        noclipOn = 'Vol libre : vous êtes invisible.',
        noclipOff = 'Vol libre terminé.',
        -- 1.11.0 : le rang a perdu un droit d'outil, vol libre, invisibilité, invulnérabilité et observation coupés
        toolsWithdrawn = 'Votre rang ne vous donne plus les outils du Conseil : ils sont rangés.',
    },
}
