--[[
    vava_pause/config_client.lua
    Rôle : réglages de la bannière du royaume que lit le client : interception d'Échap et de P, ouverture et veille,
           menus natifs de GTA et de FiveM, manette, rectangle du Codex en panneau, fiche complète, teintes de la
           bannière royale et des tampons de rang, plaque du royaume, réglages du joueur (gardés sur sa machine),
           commande d'essai du ligotage, textes affichés par le client. Téléchargé par chaque joueur ; le serveur le lit
           aussi (meuble par défaut). Tout le reste (débits, fenêtre de combat, plafonds de l'instantané, confréries,
           Conseil, départ, touche déclarée au registre, textes du serveur) est dans config.lua, servi au seul serveur
           (T-132).
    Dépendances : shared/constants.lua
]]

VavaPause.config = {
    clientFile = true,  -- posé par ce fichier, ne pas changer (sans lui, le serveur signale un config.lua remplacé)

    -- Interception d'Échap et de P (contrôles de GTA : 199 = P et Start, 200 = Échap).
    intercept = {
        controls = { 199, 200 },
        idleMs = 500,          -- attente de la boucle hors jeu (sélection, chargement, menu natif ouvert)
        focusWatchMs = 100,    -- guet du focus d'une autre interface
        graceMs = 300,         -- après qu'une interface a rendu le focus : un Échap reçu ne déploie rien
        noticeMs = 3000,       -- même refus non répété avant ce délai
        -- SetPauseMenuActive(false) à chaque image, en plus du blocage d'Échap et de P : empêche le menu de GTA de
        -- s'ouvrir par un autre chemin (manette), mais referme aussi un menu de GTA qu'un autre module ouvrirait. Essai
        -- en jeu sans lui : pause 1-8 (false) ; s'il ne sert à rien, le retirer (relecture réseau R-2 de T-145).
        holdPauseMenu = true,
    },

    open = {
        waitMs = 50,           -- attente de la réponse avant d'afficher (sinon : affichée, données à venir)
        timeoutMs = 4000,      -- attente maximale de la réponse
        reuseMs = 60000,       -- réponse précédente reprise si le serveur refuse pour débit (rate_limited)
        watchMs = 500,         -- bannière ouverte : à terre, ligoté, blessé relus à cet intervalle
        hitDrop = 0.02,        -- baisse de vie (part de 0 à 1) qui replie la bannière
        rollMs = 250,          -- déroulé (envoyé à la page ; 0 = sans animation)
    },

    -- Menus natifs de GTA et de FiveM (noms de menus du jeu, à vérifier en jeu).
    native = {
        map = { menu = 'FE_MENU_VERSION_MP_PAUSE', deeper = true, deeperDelayMs = 150 },
        settings = { menu = 'FE_MENU_VERSION_LANDING_MENU' },
        keymapping = { menu = 'FE_MENU_VERSION_LANDING_KEYMAPPING_MENU' },
        watchMs = 250,         -- fermeture du menu natif guettée à cet intervalle, puis la bannière revient
        returnDelayMs = 150,
        openTimeoutMs = 1500,  -- menu demandé mais jamais ouvert (nom inconnu) : menu suivant, ou retour à la bannière
    },

    quit = { fallbackMs = 1500 },  -- « quit » sans effet après ce délai : le serveur déconnecte avec un message

    gamepad = {
        enabled = true,
        pausedMs = 100,        -- menu natif ou Codex en panneau ouvert : manette relue à cet intervalle, pas par image
        controls = { up = 172, down = 173, left = 174, right = 175, accept = 201, back = 202, prevTab = 205,
                     nextTab = 206, resume = 199 },
    },

    -- Codex en panneau : rectangle du tome (vw, vh), à droite de la bannière.
    codex = { resource = 'vava_codex', rect = { left = 32.6, top = 10.7, width = 58.3, height = 71.1 } },

    -- « Ouvrir la fiche complète » : le livre des compétences.
    sheet = { resource = 'vava_skills', command = 'vava_skills' },

    -- Blasons : meuble par défaut (bannière royale) et teintes royales.
    royal = { cloth = '#6e2116', clothDark = '#4a150d', field = '#273b56', charge = 'croix' },

    -- Teinte des tampons de rang (nom du rang de vava_skills → couleur d'encre).
    rankInks = { novice = '#6b5640', apprenti = '#3f5a33', compagnon = '#7c5d22', artisan = '#7c5d22',
                 maitre = '#8e2c1d', grand_maitre = '#8e2c1d' },

    -- Plaque du royaume (bas à droite) : moment du jour, saison, habitants présents.
    plaque = {
        periods = {            -- heure de début → libellé
            { from = 0, label = 'Nuit' }, { from = 5, label = 'Aube' }, { from = 7, label = 'Matin' },
            { from = 12, label = 'Midi' }, { from = 14, label = 'Après-midi' }, { from = 18, label = 'Soir' },
            { from = 22, label = 'Nuit' },
        },
        timeFormat = '%s, %d h',
        seasons = { printemps = 'Printemps', ete = 'Été', automne = 'Automne', hiver = 'Hiver' },
        people = { one = '1 habitant présent', many = '%d habitants présents' },
    },

    -- Réglages du joueur, gardés sur sa machine (stockage local de FiveM), jamais envoyés au serveur. Un réglage
    -- n'apparaît que si une ressource de `uses` est démarrée ; sa valeur effective est décidée par le module qui
    -- l'applique, dans sa propre config.
    settings = {
        kvp = 'vava_pause:reglages',
        list = {
            { key = 'ui.scale', tab = 'interface', kind = 'choice', default = 100, choices = { 90, 100, 115 },
              labels = { '90 %', '100 %', '115 %' }, uses = { 'vava_pause', 'vava_hud' },
              label = 'Taille de l\'interface', help = 'Plus lisible de loin, sur un grand écran.' },
            { key = 'hud.notifyDuration', tab = 'interface', kind = 'choice', default = 'normale',
              choices = { 'courte', 'normale', 'longue' }, labels = { 'Courte', 'Normale', 'Longue' },
              uses = { 'vava_hud' },
              label = 'Durée des notifications', help = 'Le temps qu\'un message reste à l\'écran.' },
            { key = 'voice.circle', tab = 'voix', kind = 'lever', default = true, uses = { 'vava_voice' },
              label = 'Cercle de portée au sol', help = 'Montre jusqu\'où porte votre voix quand vous en changez.' },
        },
    },

    -- Essai en jeu du ligotage, tant qu'aucun module ne lie : commande locale qui bascule
    -- SetEnableHandcuffs(PlayerPedId(), …) sur son seul ped ('' = commande absente). Laisser '' en service.
    devCuffCommand = '',

    -- Touche rappelée au pied de la bannière (« Échap pour reprendre »).
    closeKey = 'Échap',

    messages = {
        refused = {
            combat = 'Pas de répit au cœur d\'un combat : la bannière attendra.',
            restrained = 'Les mains liées, vous ne pouvez déployer la bannière.',
            blocked = 'La bannière ne peut être déployée pour l\'instant.',
        },
        interrupted = 'Le monde vous rappelle à lui : la bannière se replie.',
        unavailable = 'La bannière du royaume est indisponible pour l\'instant.',
    },
}
