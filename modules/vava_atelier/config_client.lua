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
        -- refus d'un RPC (codes du § 6.2 de la spec), montrés hors de l'interface quand elle ne peut pas s'ouvrir
        refused = {
            not_ready = 'Le Registre du Conseil s\'éveille : réessayez dans un instant.',
            no_character = 'Choisissez d\'abord un personnage.',
            not_allowed = 'L\'Atelier est réservé au Conseil.',
            not_open = 'L\'Atelier s\'est refermé : rouvrez-le.',
            unknown_editor = 'Cet atelier n\'existe plus.',
            unknown_kind = 'Ce genre de fiche n\'existe plus dans cet atelier.',
            unknown_entry = 'Cette fiche n\'existe plus.',
            unknown_field = 'Ce réglage n\'existe pas dans cette fiche.',
            busy = 'Un instant : la demande précédente n\'est pas finie.',
            editor_error = 'Cet atelier ne répond pas : prévenez un développeur.',
            db_error = 'Les registres de l\'Atelier ne répondent pas : réessayez dans un instant.',
            rate_limited = 'Doucement : patientez un instant.',
            unavailable = 'L\'Atelier est indisponible pour le moment.',
            stale = 'Cette fiche a changé depuis que vous l\'avez ouverte : rouvrez-la pour voir la dernière version.',
            draft_taken = 'Un autre membre du Conseil tient déjà un brouillon de cette fiche : ouvrez-le pour le lire '
                .. 'ou le reprendre.',
            draft_open = 'Vous avez déjà un brouillon de cette fiche : abandonnez-le d\'abord.',
            not_holder = 'Ce brouillon est tenu par un autre membre du Conseil.',
            no_draft = 'Cette fiche n\'a pas de brouillon en cours.',
            not_stored = 'Cet atelier ne garde encore rien : on peut seulement y vérifier une fiche.',
            too_large = 'Cette fiche est trop lourde pour être gardée : raccourcissez ses textes.',
            full = 'Trop de fiches ou de brouillons : publiez ou abandonnez-en d\'abord.',
            parent_missing = 'Cette fiche dépend d\'une autre qui n\'est pas publiée : publiez-la ou rétablissez-la '
                .. 'd\'abord.',
            trial_busy = 'Vous avez déjà un essai en cours : arrêtez-le d\'abord.',
            no_trial = 'Cet atelier ne propose pas d\'essai.',
            syncing = 'L\'atelier se met à jour : réessayez dans un instant.',
            unknown_version = 'Cette version n\'existe plus.',
            not_archived = 'Seule une ancienne version peut être rétablie.',
            unchanged = 'Rien n\'a changé depuis la version publiée.',
            unreadable = 'Cette version ne peut plus être lue par cet atelier.',
            -- T-102 (outil de placement)
            not_placeable = 'Cette fiche ne se place pas en jeu.',
            instance = 'Vous êtes hors du monde commun (intérieur, cachot…) : revenez-y pour placer.',
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
