--[[
    vava_provisions/config_client.lua
    Rôle : réglages des vivres que lit le client : sortes de points d'eau (modèle, invite, texte d'un point à sec),
           portée de l'invite, streaming des props, gestes, touche, textes. Téléchargé par chaque joueur ; le serveur
           le lit aussi. Tout le reste (objets déclarés, remplissage, contenants, recette de l'outre, gorgées, délai,
           points d'eau, marge du serveur, zone des points, commande du Conseil, débit) est dans config.lua, servi au
           seul serveur (T-132).
    Les modèles et les gestes sont des EXEMPLES (-- PLACEHOLDER) : à remplacer par les props du royaume.
    Dépendances : shared/constants.lua
]]

VavaProvisions.config = {
    clientFile = true,  -- posé par ce fichier, ne pas changer (sans lui, le serveur signale un config.lua d'avant 1.1.0)

    -- Sortes de points d'eau. reserve.capacity = 0 : sans fond (jamais à sec). refillSeconds : un puisage rendu toutes
    -- les N secondes. `drink` : on peut y boire sans outre. `dry` : texte quand il n'y a plus de quoi remplir une outre
    -- (%d : minutes d'attente, arrondies au-dessus ; au plus un %d). Entières ici : le client les lit par sorte (modèle,
    -- invite, texte d'un point à sec) et les passe à shared/pointzone.lua.
    kinds = {
        puits = { label = 'Puits', model = 'prop_barrel_01a', -- PLACEHOLDER : modèle de puits médiéval
            reserve = { capacity = 40, refillSeconds = 60 }, drink = true,
            dry = 'Le seau racle le fond : le puits doit se remplir (environ %d min).' },
        fontaine = { label = 'Fontaine', model = 'prop_barrel_01a', -- PLACEHOLDER : modèle de fontaine
            reserve = { capacity = 0 }, drink = true,
            dry = 'La fontaine est tarie : revenez dans environ %d min.' },
        source = { label = 'Source', model = 'prop_rock_1_a', -- PLACEHOLDER : rocher d'où sourd l'eau
            reserve = { capacity = 15, refillSeconds = 180 }, drink = true,
            dry = 'La source ne coule plus qu\'en filet : revenez dans environ %d min.' },
    },

    -- La marge du serveur (`serverTolerance`) est dans config.lua.
    interact = {
        distance = 2.0,          -- portée de l'invite et de l'usage (client), en mètres
    },

    -- Client : props des points créés à portée (`radius`, mètres), groupés par case de `groupCell` mètres ; un passage
    -- toutes les `pollMs` près d'une case, toutes les `idlePollMs` quand aucun point ne peut être à moins de `radius` +
    -- `idleMargin`. La boucle ne tourne que si un point est connu. La zone de chaque point et son battement d'abonnement
    -- (`zoneRadius`, `subscribeSlack`) sont dans config.lua.
    streaming = {
        radius = 80.0, pollMs = 1000, idlePollMs = 2500, idleMargin = 60.0, groupCell = 200.0, modelTimeoutMs = 5000,
    },

    -- Gestes joués par le client après la réponse du serveur : scénario du jeu, ou dictionnaire + animation (haut du corps).
    anims = {
        fill = { scenario = 'WORLD_HUMAN_GARDENER_PLANT', durationMs = 2500 },                       -- PLACEHOLDER (animation vanilla)
        drink = { dict = 'mp_player_intdrink', clip = 'loop_bottle', flag = 49, durationMs = 2500 },  -- PLACEHOLDER (animation vanilla)
    },

    keys = { interact = 'E' },
    labels = { interact = 'Puiser ou boire (point d\'eau proche)' },

    -- Textes (notifications : 200 octets au plus, texte brut ; libellés du journal du Registre : 32 octets au plus).
    -- Formatés par le client d'après le code rendu par le serveur. Entiers ici : le client passe la table à
    -- shared/rules.lua (textes du Conseil compris, jusqu'à la coupe de rules.lua prévue par T-143).
    messages = {
        filledOne = 'Vous remplissez une outre.',
        filledMany = 'Vous remplissez %d outres.',
        drank = 'Vous buvez quelques gorgées d\'eau fraîche.',
        drankDry = 'Trop peu d\'eau pour remplir une outre, mais assez pour boire quelques gorgées.',
        -- rendu seulement sans outre vide en besace (rules.decide, ligne 4) : la seconde phrase guide le nouveau venu
        notThirsty = 'Vous n\'avez pas soif. Pour emporter de l\'eau, il vous faut une outre vide.',
        noContainer = 'Il vous faut une outre vide pour emporter de l\'eau.',
        noSpace = 'Votre besace est pleine.',
        tooHeavy = 'Votre besace serait trop lourde.',
        wait = 'Patientez un instant.',
        tooFar = 'Approchez-vous davantage.',
        unavailable = 'Impossible pour l\'instant : réessayez dans un moment.',
        torn = 'La couture cède : l\'outre se fend entre vos mains. Il vous en faudra une neuve, de la main d\'un tanneur.',
        lost = 'Votre besace est pleine : l\'outre vide est perdue.',
        prompt = {
            both = 'Puiser ou boire',   -- sorte où l'on peut boire
            fill = 'Puiser',            -- sorte où l'on ne boit pas
        },
        admin = {
            usage = 'usage : /%s points | reserve <point> <nombre>',
            line = '%s (%s, %s) : %s.',          -- nom, identifiant, sorte, réserve
            level = '%d / %d puisages',
            bottomless = 'sans fond',
            set = 'Réserve de %s : %d / %d.',
            unknown = 'Point d\'eau inconnu : %s.',
            range = 'La réserve de %s va de 0 à %d.',
            noReserve = '%s est sans fond : rien à régler.',
            wait = 'Patientez un instant.',
            more = '… et %d autres points d\'eau.',
        },
        journal = {
            reserve = 'Réserve d\'eau fixée',     -- journal du Registre
        },
    },
}
