--[[
    vava_chat/config_client.lua
    Rôle : réglages du chat que lit le client (le serveur les lit aussi) : bornes d'un message, texte au-dessus de la
           tête, interface, profil, touche, commandes, suggestions, et tous les textes vus par les joueurs.
           Téléchargé par chaque joueur. Ce que lit le seul serveur (portées, droit sans vava_admin, journal, débits)
           est dans config.lua, servi au seul serveur (T-132).
    Dépendances : shared/constants.lua
]]

VavaChat.config = {
    clientFile = true,  -- posé par ce fichier, ne pas changer (sans lui, le serveur signale un config.lua d'avant 1.4.0)

    maxLength = 250,        -- signes d'un message de joueur (un « é » compte pour un)
    maxBytes = 1100,        -- borne réseau d'un message de joueur (octets)
    systemMaxLength = 500,  -- signes d'un message d'une autre ressource (chat:addMessage)

    -- /me et /do au-dessus de la tête, vus des joueurs à portée : dessinés seulement tant qu'il y en a un à l'écran.
    overhead = {
        durationMs = 8000,
        distance = 15.0,
        maxLines = 3,
        maxChars = 90,       -- au-delà, le texte est coupé (« … ») : le chat garde le message entier
        headBone = 31086,    -- SKEL_Head
        headOffset = 0.42,
        lineHeight = 0.024,  -- part de la hauteur de l'écran entre deux lignes
        font = 4,
        scale = 0.36,
        minScale = 0.6,      -- part de la taille gardée au bout de la distance
        sightMs = 300,       -- ligne de vue relue à cet intervalle (pas à chaque image)
        me = { r = 240, g = 198, b = 116, a = 235 },
        ['do'] = { r = 176, g = 196, b = 214, a = 235 },
    },

    -- Interface : messages gardés par onglet, effacement du fil quand le chat est fermé, place par défaut (part de
    -- l'écran : gauche, haut, largeur, hauteur). Chaque joueur déplace et agrandit son chat ; c'est gardé chez lui.
    ui = {
        maxMessages = 200,
        historyMax = 30,
        fadeMs = 12000,
        suggestionsMax = 6,
        defaultLayout = { x = 0.015, y = 0.22, w = 0.3, h = 0.34 },
        minSize = { w = 300, h = 180 },  -- pixels
    },

    -- Visibilité (menu pause, écran noir) relue à cet intervalle : aucune boucle par image.
    visibilityMs = 300,

    -- Demande du profil (numéro de conversation, Conseil, commandes du serveur) : essais si le serveur n'est pas prêt.
    profile = { attempts = 4, retryMs = 3000 },

    -- Touche d'ouverture (réglable dans Paramètres > Raccourcis > FiveM), à la même place en AZERTY et en QWERTY.
    -- Le chat s'ouvre au relâchement : la lettre n'est pas tapée dans la saisie.
    key = { command = 'vava_chat_ouvrir', key = 'T', label = 'Chat : écrire' },

    commands = {
        ooc = 'ooc', mp = 'mp', reply = 'r', me = 'me', ['do'] = 'do', staff = 'staff', chat = 'chat', reset = 'reinit',
    },

    -- Commandes proposées dans les suggestions : celles des autres ressources permises au joueur, sauf ces motifs.
    commandList = { max = 200, hidden = { '^vava_', '^[%+%-_]' } },

    texts = {
        -- avis montrés dans le chat (codes des refus du serveur et du client)
        errors = {
            not_ready = 'Le chat n\'est pas encore prêt.',
            empty = 'Votre message est vide.',
            invalid = 'Message refusé.',
            offline = 'Ce joueur n\'est plus là.',
            self = 'Vous ne pouvez pas vous écrire.',
            unknown_player = 'Aucun joueur en jeu sous ce numéro.',
            not_staff = 'Ce canal est réservé au Conseil.',
            refused = 'Votre message est refusé.',
            rate_limited = 'Doucement : vous écrivez trop vite.',
            unknown_command = 'Commande inconnue : /%s',
            no_reply = 'Personne à qui répondre.',
            actions_hint = 'Ici, commencez par /me (une action) ou /do (une description).',
            unknown = 'Le message ne part pas (%s).',
        },
        usage = {
            ooc = 'Usage : /ooc <message>',
            mp = 'Usage : /mp <n°> <message>',
            reply = 'Usage : /r <message>',
            me = 'Usage : /me <action>',
            ['do'] = 'Usage : /do <description>',
            staff = 'Usage : /staff <message>',
            chat = 'Usage : /chat reinit (remet le chat à sa place)',
        },
        reset = 'Le chat est revenu à sa place.',
        suggestions = {
            ooc = { help = 'Hors-RP, aux joueurs proches', params = { { name = 'message', help = 'le message' } } },
            mp = { help = 'Message privé à un joueur', params = { { name = 'n°', help = 'numéro du joueur' }, { name = 'message', help = 'le message' } } },
            reply = { help = 'Répondre au dernier message privé', params = { { name = 'message', help = 'le message' } } },
            me = { help = 'Une action de votre personnage', params = { { name = 'action', help = 'ex. : tire son épée' } } },
            ['do'] = { help = 'Une description de la scène', params = { { name = 'description', help = 'ex. : la porte est verrouillée' } } },
            staff = { help = 'Canal du Conseil', params = { { name = 'message', help = 'le message' } } },
            chat = { help = 'Réglages du chat', params = { { name = 'reinit', help = 'remettre le chat à sa place' } } },
        },
        -- textes de l'interface (envoyés à la page une fois prête)
        ui = {
            tabs = { general = 'Général', actions = 'Actions', staff = 'Conseil' },
            tags = { ooc = 'HRP', mp = 'MP', staff = 'Conseil', system = 'Royaume' },
            me = '* %s %s *',       -- nom, action
            ['do'] = '* %s * (%s)', -- description, nom
            mpFrom = 'De %s',
            mpTo = 'À %s',
            you = 'Vous',
            staffBadge = 'Conseil',
            placeholder = {
                general = 'Hors-RP… ou /me, /do, /mp',
                actions = '/me une action, /do une description',
                mp = 'Écrire à %s…',
                gone = '%s est parti.',
                staff = 'Au Conseil…',
            },
            closeTab = 'Fermer la conversation',
            moveHint = 'Saisir pour déplacer',
            resizeHint = 'Tirer pour agrandir',
            counter = '%d / %d',
            hint = 'Entrée : envoyer · Échap : fermer · ↑ ↓ : historique · Tab : compléter',
        },
        -- au-dessus de la tête
        overhead = { me = '* %s *', ['do'] = '* %s *', ellipsis = '…' },
    },
}
