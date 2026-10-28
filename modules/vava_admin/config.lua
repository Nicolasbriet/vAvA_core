--[[
    vava_admin/config.lua
    Rôle : configuration de l'administration (lue par le client et le serveur) : rangs du Conseil et leurs droits,
           durées de bans, outils, textes.
    Dépendances : shared/constants.lua
]]

VavaAdmin.config = {
    coreVersion = '0.5.0',

    -- Rangs du Conseil, du plus bas au plus haut : chacun a les droits des rangs inférieurs, plus les siens.
    -- On n'agit jamais sur un membre de rang égal ou supérieur. Bans (droit 'ban') : maxBanHours = durée maximale ;
    -- permanentBans = sans limite, ban définitif compris. Droit 'watch' (écran des joueurs) : tout le Conseil, sur tout le
    -- monde, sans règle de rang.
    ranks = {
        {
            name = 'gardien', label = 'Gardien', level = 1, maxBanHours = 0,
            permissions = { 'view', 'teleport', 'freeze', 'heal', 'message', 'warn', 'kick', 'reports', 'watch' },
        },
        {
            name = 'senechal', label = 'Sénéchal', level = 2, maxBanHours = 168,
            -- metiers : zones et nœuds de récolte, stations, parcelles, correction d'une compétence (modules métiers) ;
            -- nommer un fondateur reste réservé à `staff`
            permissions = { 'ban', 'inventory', 'give', 'announce', 'tools', 'spectate', 'logs', 'bans', 'metiers' },
        },
        {
            name = 'souverain', label = 'Souverain', level = 3, maxBanHours = 0, permanentBans = true,
            permissions = { 'unban', 'staff' },
        },
    },

    -- Durées proposées dans le panneau (heures ; 0 = définitif), filtrées selon le rang.
    banDurations = { 1, 6, 24, 72, 168, 720, 0 },

    -- Chancellerie (panneau web) : seule ressource admise à agir au nom d'un compte du panneau, et nom de l'acteur
    -- au journal (%s = compte du panneau).
    web = { bridge = 'vava_chancellerie', actorLabel = 'Chancellerie : %s' },

    -- Journal des actions : conservé ce nombre de jours (purgé au démarrage).
    logRetentionDays = 90,
    pageSize = 50,

    -- Signalements (/signaler) : un par joueur et par intervalle ; gardés en mémoire jusqu'à leur clôture.
    reportCommand = 'signaler',
    reportCooldownMs = 60000,
    maxOpenReports = 100,

    -- Déplacements : écart à l'arrivée (m) pour ne pas apparaître dans la personne.
    teleportOffset = 1.2,

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

    rateLimits = {
        read = { capacity = 10, refillPerSecond = 2 },     -- ouverture, listes, fiches
        action = { capacity = 10, refillPerSecond = 2 },   -- actions sur les joueurs
        report = { capacity = 2, refillPerSecond = 0.05 }, -- /signaler (joueurs)
    },

    -- Textes vus par les joueurs (le panneau a les siens : web/js/strings.js).
    messages = {
        console = 'Console',
        kicked = 'Expulsé par le Conseil.\nMotif : %s',
        banned = 'Vous êtes banni de ce royaume.\nMotif : %s\n%s\nBan n° %d',
        bannedUntil = 'Jusqu\'au %s.',
        bannedForever = 'Ban définitif.',
        warned = 'Avertissement du Conseil : %s',
        messageTitle = 'Message du Conseil',
        frozen = 'Le Conseil vous a immobilisé.',
        unfrozen = 'Vous pouvez de nouveau bouger.',
        reportSent = 'Votre signalement a été transmis au Conseil.',
        reportTooSoon = 'Patientez avant d\'envoyer un nouveau signalement.',
        reportClaimed = 'Un membre du Conseil prend en charge votre signalement.',
        reportClosed = 'Votre signalement a été clos.',
        reportNew = 'Signalement n° %d de %s.',
        reportUsage = 'usage : /%s <message>',
        notStaff = 'Vous ne siégez pas au Conseil.',
        noclipOn = 'Vol libre : vous êtes invisible.',
        noclipOff = 'Vol libre terminé.',
    },
}
