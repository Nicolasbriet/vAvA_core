--[[
    vava_atelier/config_client.lua
    Rôle : réglages lus par le client de chaque joueur (et relus par le serveur) : touche, commande, textes de l'amorce
           (refus, chargement des registres, réponses au chat), attentes du chargeur. Ce que lit le seul client du
           Conseil (outil de placement, textes de la séance) : config_conseil.lua, livré dans le paquet (T-157) ; le
           reste : config.lua, servi au seul serveur. Détail : README (Règles).
    Dépendances : shared/constants.lua
]]

VavaAtelier.config = {
    clientFile = true,  -- posé par ce fichier, ne pas changer (sans lui, le serveur signale un config.lua d'avant 1.2.0)

    -- Touche par défaut, réglable par le joueur (Paramètres › Raccourcis › FiveM), et commande du chat.
    keys = { open = 'F9' },
    labels = { open = 'Ouvrir l\'Atelier du Conseil' },
    command = 'atelier',

    -- Textes affichés par le client hors de la page (l'interface a les siens : web/js/strings.js) ; le serveur lit
    -- aussi les refus. Ceux de la séance du Conseil sont dans config_conseil.lua, les autres dans config.lua (texts.*).
    texts = {
        -- refus que l'amorce peut montrer (RPC `code` et transport, client/notice.lua) ; les autres refus, ceux de la
        -- séance du Conseil, sont dans config_conseil.lua (relecture réseau R-3 de T-157)
        refused = {
            not_ready = 'Le Registre du Conseil s\'éveille : réessayez dans un instant.',
            no_character = 'Choisissez d\'abord un personnage.',
            not_allowed = 'L\'Atelier est réservé au Conseil.',
            unavailable = 'L\'Atelier est indisponible pour le moment.',
            rate_limited = 'Doucement : patientez un instant.',
            busy = 'Un instant : la demande précédente n\'est pas finie.',
            bad_request = 'Demande refusée : rouvrez la fiche.',
        },
        -- nom des réponses de /atelier_archives dans le chat du membre (ancien texts.archives.author)
        sayAuthor = 'Atelier',
        -- T-157 : chargeur (160 octets au plus) ; premier envoi d'une version, puis échec d'un fichier ou de la page
        loading = 'On apporte les registres de l\'Atelier : un instant…',
        loadFailed = 'Les registres de l\'Atelier n\'ont pas pu être ouverts : prévenez un développeur.',
    },

    -- T-157 : attentes du chargeur de l'Atelier (client/loader.lua), en millisecondes (1 000 à 30 000)
    delivery = {
        pageWaitMs = 5000,    -- attente au plus de la page vide (« prête ») avant de lui donner ses scripts
        bootWaitMs = 5000,    -- attente au plus du compte rendu de la page après ses scripts
    },
}
