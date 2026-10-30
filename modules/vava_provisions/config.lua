--[[
    vava_provisions/config.lua
    Rôle : tout ce qui est réglable des vivres du royaume (lu par le client et le serveur) : objets déclarés s'ils
           manquent (eau, outre), remplissage, contenants rendus et usés, recette de l'outre à la tannerie, gorgées au
           point d'eau, délai entre deux actions, sortes de points d'eau et leurs réserves, points d'eau, portée,
           streaming des props, gestes, touche, commande du Conseil, débit du RPC, textes.
    Les points d'eau et les modèles sont des EXEMPLES autour du point d'apparition par défaut (-- PLACEHOLDER) : à
    remplacer par les lieux et les props du royaume. La config est la graine : l'Atelier les reprendra (T-130 § 10.4).
    Dépendances : shared/constants.lua
]]

VavaProvisions.config = {
    coreVersion = '0.11.0',  -- core.zones (0.11.0), core.net.send (0.10.0), registre core:commands (0.7.0)
    dependencies = { vava_inventory = '1.8.0' },  -- count, exchange, add, hook use avec `consumed`, piles gardées à part

    -- Objets déclarés à l'inventaire S'ILS NE LE SONT PAS DÉJÀ (le premier déclaré l'emporte : avertissement en
    -- console). Image : nui://vava_provisions/web/items/<nom>.svg, ajoutée à la déclaration. La définition de `eau` est
    -- celle de vava_arrival 1.0.0 (taille, pile, poids, soif) : les piles déjà en jeu se relisent telles quelles.
    items = {
        eau = { label = 'Outre d\'eau', description = 'De l\'eau fraîche et claire. Une fois bue, l\'outre vide vous reste, si la couture tient.',
            width = 1, height = 2, weight = 700, stack = 5, category = 'boisson', effects = { thirst = 40 } },
        outre = { label = 'Outre vide', description = 'Cuir cousu et poissé. Elle se remplit à un puits, une fontaine ou une source.',
            width = 1, height = 2, weight = 150, stack = 5, category = 'divers' },
    },

    -- Un appui au point d'eau remplit au plus `maxPerDraw` outres vides (1 à 20) : `from` retirés, `to` donnés, tout ou
    -- rien. Les outres sont retirées sans filtre (palier ignoré, les plus anciennes d'abord).
    fill = { from = 'outre', to = 'eau', maxPerDraw = 5 },

    -- Boire un objet de la liste rend `empty`, sauf une fois sur dix (`tearChance`, 0 à 1) où l'outre se fend. Une
    -- recette future qui consomme `eau` doit rendre `outre` dans sa sortie, sinon l'outre est perdue.
    containers = {
        eau = { empty = 'outre', tearChance = 0.1 },
    },

    -- Tannerie (vava_crafting) : un cuir donne deux outres. Ni signée ni transmise : savoir commun du tanneur. Ajoutée
    -- au registre des recettes si l'artisanat tourne et que la station `tannerie` y est déclarée.
    recipe = { id = 'outre', label = 'Outre', skill = 'tannerie', level = 0, station = 'tannerie', durationMs = 6000,
        difficulty = 5, xp = 8, ingredients = { { item = 'cuir', quantity = 1 } }, output = { item = 'outre', quantity = 2 } },

    -- Boire au point d'eau (vava_needs) : soif + `thirst` (1 à 100) ; refusé si la soif est à `fullAt` ou plus (même
    -- seuil que vava_needs). La réserve n'est pas touchée.
    drink = { thirst = 20, fullAt = 95 },

    -- Délai entre deux actions d'un même joueur (puiser ou boire), tenu par le serveur ; au moins la durée des gestes.
    cooldownMs = 3000,

    -- Sortes de points d'eau. reserve.capacity = 0 : sans fond (jamais à sec). refillSeconds : un puisage rendu toutes
    -- les N secondes. `drink` : on peut y boire sans outre. `dry` : texte quand il n'y a plus de quoi remplir une outre
    -- (%d : minutes d'attente, arrondies au-dessus ; au plus un %d).
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

    -- Points d'eau : EXEMPLES autour du point d'apparition par défaut. `model` facultatif : celui de la sorte sinon ;
    -- '' : aucun prop (point posé sur un décor de la carte). Jamais à moins de 5 m d'un puits de vava_farming, ni d'une
    -- autre cible de la touche E (stations, nœuds de récolte) : deux invites sur la même touche.
    points = {
        { id = 'fontaine_bourg', kind = 'fontaine', label = 'Fontaine du bourg', x = -250.0, y = -960.0, z = 31.2, heading = 0.0 },  -- PLACEHOLDER
        { id = 'puits_lavoir', kind = 'puits', label = 'Puits du lavoir', x = -300.0, y = -985.0, z = 31.2, heading = 0.0 },         -- PLACEHOLDER
        { id = 'source_claire', kind = 'source', label = 'Source de la Rivière Claire', x = -118.0, y = -876.0, z = 29.0, heading = 0.0 }, -- PLACEHOLDER
    },

    -- Au plus ce nombre de points (config et ajouts) ; au-delà, refus `too_many`.
    maxPoints = 256,

    interact = {
        distance = 2.0,          -- portée de l'invite et de l'usage (client), en mètres
        serverTolerance = 1.5,   -- marge du serveur (latence) : refus au-delà de distance + serverTolerance (3,5 m)
    },

    -- Client : props des points créés à portée (`radius`, mètres), groupés par case de `groupCell` mètres ; un passage
    -- toutes les `pollMs` près d'une case, toutes les `idlePollMs` quand aucun point ne peut être à moins de `radius` +
    -- `idleMargin`. Chaque point est une zone du core de `zoneRadius` mètres, connue à `radius` + `subscribeSlack` de
    -- son bord (même sens et mêmes valeurs que vava_crafting). La boucle ne tourne que si un point est connu.
    streaming = {
        radius = 80.0, pollMs = 1000, idlePollMs = 2500, idleMargin = 60.0, groupCell = 200.0, modelTimeoutMs = 5000,
        zoneRadius = 2.0, subscribeSlack = 20.0,
    },

    -- Gestes joués par le client après la réponse du serveur : scénario du jeu, ou dictionnaire + animation (haut du corps).
    anims = {
        fill = { scenario = 'WORLD_HUMAN_GARDENER_PLANT', durationMs = 2500 },                       -- PLACEHOLDER (animation vanilla)
        drink = { dict = 'mp_player_intdrink', clip = 'loop_bottle', flag = 49, durationMs = 2500 },  -- PLACEHOLDER (animation vanilla)
    },

    keys = { interact = 'E' },
    labels = { interact = 'Puiser ou boire (point d\'eau proche)' },

    admin = {
        command = 'eau',            -- /eau points | reserve <point> <nombre>
        permission = 'metiers',     -- droit vava_admin (Sénéchal et au-dessus, comme /agriculture)
        ace = 'metiers.admin',      -- repli ACE sans vava_admin
        cooldownMs = 1000,          -- entre deux /eau d'un même membre (console exceptée)
    },

    rateLimits = {
        draw = { capacity = 3, refillPerSecond = 0.5 },  -- RPC vava_provisions:draw, par joueur
    },

    -- Textes (notifications : 200 octets au plus, texte brut ; libellés du journal du Registre : 32 octets au plus).
    -- Formatés par le client d'après le code rendu par le serveur.
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
        },
        journal = {
            reserve = 'Réserve d\'eau fixée',     -- journal du Registre
        },
    },
}
