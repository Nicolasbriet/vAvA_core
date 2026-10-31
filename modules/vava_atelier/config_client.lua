--[[
    vava_atelier/config_client.lua
    Rôle : réglages de l'Atelier que lit le client : touche, commande, textes affichés hors de la page (refus, bandeaux
           du volet, fin d'essai, auteur des réponses au chat). Téléchargé par chaque joueur ; le serveur le lit aussi.
           Tout le reste est dans config.lua, servi au seul serveur (T-132).
    Dépendances : shared/constants.lua
]]

VavaAtelier.config = {
    clientFile = true,  -- posé par ce fichier, ne pas changer (sans lui, le serveur signale un config.lua d'avant 1.2.0)

    -- Touche par défaut, réglable par le joueur (Paramètres › Raccourcis › FiveM), et commande du chat.
    keys = { open = 'F9' },
    labels = { open = 'Ouvrir l\'Atelier du Conseil' },
    command = 'atelier',

    -- Textes affichés par le client hors de la page (l'interface a les siens : web/js/strings.js) ; le serveur lit
    -- aussi les refus. Les autres textes sont dans config.lua (texts.*).
    texts = {
        modeLine = 'Mode édition : visible par vous seul',      -- bandeau du volet (message `mode`)
        revoked = 'Votre place au Conseil a changé : l\'Atelier se ferme.',
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
        },
        -- bandeau du volet pendant un essai, si l'éditeur n'a pas de texts.trialLine
        trialLineDefault = 'Mode essai : vous seul voyez ce changement en jeu',
        trialEndedFeed = 'L\'essai de « %s » a pris fin.',
        -- nom des réponses de /atelier_archives dans le chat du membre (ancien texts.archives.author)
        sayAuthor = 'Atelier',
    },
}
