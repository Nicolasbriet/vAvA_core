--[[
    vava_admin/config.lua
    Rôle : réglages de l'administration que lit le seul serveur (servi au seul serveur, jamais téléchargé par les
           joueurs) : rangs du Conseil et leurs droits, durées de bans, pont du web, journal, relecture des bans,
           signalements et demandes au Conseil (1.10.0), invulnérabilité (1.11.0), déplacements, débits, textes
           envoyés par le serveur. Complète la table ouverte par
           config_client.lua (commandes, touches, outils du client, textes du client) sans en réécrire une clé
           (T-132).
    Dépendances : shared/constants.lua, config_client.lua
]]

local config = VavaAdmin.config

config.coreVersion = '0.5.0'

-- Rangs du Conseil, du plus bas au plus haut : chacun a les droits des rangs inférieurs, plus les siens.
-- On n'agit jamais sur un membre de rang égal ou supérieur. Bans (droit 'ban') : maxBanHours = durée maximale ;
-- permanentBans = sans limite, ban définitif compris. Droit 'watch' (écran des joueurs) : tout le Conseil, sur tout le
-- monde, sans règle de rang.
config.ranks = {
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
}

-- Durées proposées dans le panneau (heures ; 0 = définitif), filtrées selon le rang.
config.banDurations = { 1, 6, 24, 72, 168, 720, 0 }

-- Chancellerie (panneau web) : seule ressource admise à agir au nom d'un compte du panneau, et nom de l'acteur
-- au journal (%s = compte du panneau).
config.web = { bridge = 'vava_chancellerie', actorLabel = 'Chancellerie : %s' }

-- Journal des actions : conservé ce nombre de jours (purgé au démarrage).
config.logRetentionDays = 90
config.pageSize = 50

-- Bans relus en jeu (arrivée d'un joueur, démarrage du Registre) quand la base ne répond pas : seconde lecture
-- après retryMs ; si elle échoue encore, onError = 'keep' (défaut : gardé en jeu, « bans illisibles, joueur
-- gardé » à la console ; à l'arrivée, la lecture de la connexion avait réussi) ou 'kick' (expulsé, message
-- banCheckUnavailable ; un hoquet de base au démarrage du Registre expulserait tout le serveur). La connexion,
-- elle, est toujours refusée quand la lecture des bans échoue. Au démarrage, un joueur que le core n'a pas encore
-- repris est relu jusqu'à sweepAttempts fois, à sweepRetryMs d'écart.
config.banRecheck = { retryMs = 5000, onError = 'keep', sweepAttempts = 6, sweepRetryMs = 5000 }

-- Signalements (/signaler, commande dans config_client.lua) : un par joueur et par intervalle ; gardés en mémoire jusqu'à
-- leur clôture.
config.reportCooldownMs = 60000
config.maxOpenReports = 100

-- Demandes au Conseil (1.10.0) : la bannière du royaume (vava_pause) en crée par l'export submitRequest, réservé aux
-- ressources de `callers` ; natures acceptées (`kinds`) ; demandes ouvertes par compte au plus (aussi pour
-- /signaler) ; témoins d'un signalement de joueur : joueurs à `witnessRadius` mètres de l'auteur, même instance,
-- `maxWitnesses` au plus ; dernière demande close d'un compte gardée `closedMemoryMs` pour son suivi ; texte d'une
-- demande (/signaler compris) : `minChars` caractères au moins, `maxLines` lignes au plus (500 octets : MAX_TEXT).
config.requests = {
    callers = { 'vava_pause' },
    maxOpenPerAccount = 2,
    witnessRadius = 30.0,
    maxWitnesses = 8,
    closedMemoryMs = 900000,
    minChars = 10,
    maxLines = 12,
    kinds = { 'question', 'player', 'bug', 'other' },
}

-- Invulnérabilité tenue par le serveur (1.11.0) : l'outil « Invulnérabilité », le vol libre et l'observation d'un
-- membre du Conseil annulent tout coup et tout sort qui l'atteint par la chaîne de dégâts de vava_health (modificateur
-- vava_admin:invulnerabilite, étape « annulation »). `priority` : rang dans l'étape (0 à 99, plus petit = plus tôt) ;
-- `label` : nom montré dans la liste des modificateurs de la chaîne (48 octets au plus).
config.invulnerability = {
    priority = 10,
    label = 'Invulnérabilité du Conseil',
}

-- Déplacements : écart à l'arrivée (m) pour ne pas apparaître dans la personne.
config.teleportOffset = 1.2

config.rateLimits = {
    read = { capacity = 10, refillPerSecond = 2 },     -- ouverture, listes, fiches
    action = { capacity = 10, refillPerSecond = 2 },   -- actions sur les joueurs
    report = { capacity = 2, refillPerSecond = 0.05 }, -- /signaler (joueurs)
}

-- Textes vus par les joueurs, envoyés par le serveur (le panneau a les siens : web/js/strings.js ; ceux qu'affiche le
-- client, vol libre et usage de /signaler : config_client.lua).
local messages = config.messages
messages.console = 'Console'
messages.kicked = 'Expulsé par le Conseil.\nMotif : %s'
messages.banned = 'Vous êtes banni de ce royaume.\nMotif : %s\n%s\nBan n° %d'
messages.bannedUntil = 'Jusqu\'au %s.'
messages.bannedForever = 'Ban définitif.'
-- base qui ne répond pas à la vérification des bans : connexion refusée (jamais accordée sans vérification)
messages.banCheckUnavailable = 'Le registre des bans ne peut être consulté pour l\'instant : réessayez dans une minute.'
-- journal (32 caractères au plus) : compte banni trouvé en jeu (banni pendant son chargement, ou pendant que le Registre
-- était absent), expulsé ; moment inscrit dans les détails
messages.logBanEnforced = 'Banni écarté par le Registre'
messages.whenJoined = 'à son arrivée'
messages.whenSwept = 'au démarrage du Registre'
messages.warned = 'Avertissement du Conseil : %s'
messages.messageTitle = 'Message du Conseil'
messages.frozen = 'Le Conseil vous a immobilisé.'
messages.unfrozen = 'Vous pouvez de nouveau bouger.'
messages.reportSent = 'Votre signalement a été transmis au Conseil.'
messages.reportTooSoon = 'Patientez avant d\'envoyer un nouveau signalement.'
messages.reportClaimed = 'Un membre du Conseil prend en charge votre signalement.'
messages.reportClosed = 'Votre signalement a été clos.'
messages.reportNew = 'Signalement n° %d de %s.'
-- 1.10.0 : alerte au Conseil (nature, numéro, auteur), nature de chaque demande, refus d'une demande de trop
messages.requestNew = '%s : demande n° %d de %s.'
messages.requestKinds = { question = 'Question', player = 'Signalement', bug = 'Anomalie', other = 'Autre' }
messages.reportTooShort = 'Quelques mots de plus, s\'il vous plaît.'
messages.reportInvalid = 'Ce message contient des caractères que le Registre ne peut garder.'
messages.reportTooMany = 'Vos demandes attendent déjà le Conseil : patientez qu\'il y réponde.'
messages.notStaff = 'Vous ne siégez pas au Conseil.'
