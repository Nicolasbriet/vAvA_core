--[[
    vava_arrival/config.lua
    Rôle : tout ce qui est réglable de l'arrivée d'un nouveau personnage : dotation de départ et sa limite par compte,
           objets déclarés à l'inventaire s'ils manquent, attente de l'accueil côté client, chapitre du Codex, commande
           du Conseil, débit de l'accusé, rétention du journal, textes. Lue par le client et le serveur.
    Le point d'arrivée n'est PAS ici : c'est `spawn.defaultPoint` de config/server.lua (core), où le core fait déjà
    apparaître tout personnage sans position enregistrée, donc tout nouveau personnage (une seule source).
    Les textes ont été relus avec ceux de l'écran de chargement (T-021) : `messages.kit` suit `kit.items`,
    `messages.codexHint` cite la touche par défaut de vava_codex (F1).
    Dépendances : shared/constants.lua
]]

VavaArrival.config = {
    coreVersion = '0.10.0',  -- core.net.send (0.10.0) ; playSeconds du hook loaded (0.6.0) ; registre core:commands (0.7.0)
    dependencies = { vava_inventory = '1.4.0' },  -- exchange, registre des objets

    kit = {
        -- Dotation de départ : liste pure, 8 entrées au plus, quantités de 1 à 100, un objet au plus une fois.
        -- `{}` : aucune dotation (l'état passe à « donnée », rien n'est donné). Ne pas remplir en même temps
        -- `startingItems` de vava_inventory (double dotation). À tenir d'accord avec `messages.kit`.
        items = {
            { item = 'pain', quantity = 2 },
            { item = 'eau', quantity = 2 },
        },
        -- Au plus `max` dotations par compte sur `days` jours glissants (réservées, données ou incertaines, personnages
        -- supprimés compris) ; au-delà, l'accueil a lieu sans dotation. `max = 0` : aucune limite.
        perAccount = { max = 3, days = 30 },
    },

    -- Objets déclarés à l'inventaire par ce module S'ILS NE LE SONT PAS DÉJÀ (le premier déclaré l'emporte). Image :
    -- nui://vava_arrival/web/items/<nom>.svg, ajoutée à la déclaration. Mêmes définitions que vava_example_items.
    items = {
        pain = { label = 'Miche de pain', description = 'Croûte épaisse, mie serrée.', width = 2, height = 1,
            weight = 400, stack = 10, category = 'nourriture', effects = { hunger = 35 } },
        eau = { label = 'Outre d\'eau', description = 'De l\'eau fraîche tirée du puits.', width = 1, height = 2,
            weight = 700, stack = 5, category = 'boisson', effects = { thirst = 40 } },
    },

    welcome = {
        delayMs = 4000,      -- attente après la réception de l'accueil (fondu d'ouverture terminé, écran calme)
        retryMs = 1000,      -- intervalle des essais tant que l'écran n'est pas prêt (menu pause, interface ouverte, fondu)
        maxWaitMs = 30000,   -- au-delà, les notifications s'affichent sans ouvrir le Codex (une rappelle la touche)
        maxSends = 3,        -- envois de l'accueil à un personnage sans accusé de lecture (un par session) ; ensuite rien
    },

    codex = {
        -- chapitre ou page où le Codex s'ouvre à la première venue (identifiant, 64 octets au plus) : le chapitre de
        -- lecture « Premiers pas » (vava_codex 1.5.0, T-023), ouvert à sa première page, « Vivre à Eldoria ». Un
        -- identifiant que le Codex ne connaît pas (Codex antérieur à 1.5.0) le laisse s'ouvrir à son index.
        chapter = 'premiers_pas',
    },

    admin = {
        command = 'accueil',            -- /accueil etat | redoter | rejouer <n° de joueur>
        permission = 'give',            -- droit vava_admin (Sénéchal et au-dessus : le droit « Donner » du Registre)
        ace = 'vava_arrival.admin',     -- repli ACE sans vava_admin
        cooldownMs = 2000,              -- entre deux /accueil d'un même membre (console exceptée)
    },

    rateLimits = {
        welcomed = { capacity = 2, refillPerSecond = 0.05 },  -- RPC vava_arrival:welcomed (accusé), par joueur
    },

    logRetentionDays = 90,  -- purge de vava_arrival_log au démarrage

    -- Textes (notifications : 200 octets au plus, texte brut ; libellés du journal du Registre : 32 octets au plus).
    messages = {
        welcome = 'Bienvenue à Eldoria. Nulle pièce ici : on troque, on rend service, on partage. Allez vers les autres, ils vous guideront.',
        kit = 'Dans votre besace : deux miches de pain et deux outres d\'eau. Pour la suite, comptez sur les autres.',
        codexHint = 'Votre Codex (F1) garde ce qu\'il faut savoir pour vos premiers pas : ouvrez-le quand vous le voudrez.',
        admin = {
            usage = 'usage : /%s etat <n°> | redoter <n°> | rejouer <n°>',
            noCharacter = 'Joueur %d : aucun personnage en jeu.',
            wait = 'Patientez un instant.',
            busy = 'Une dotation est en cours pour ce personnage : réessayez dans un instant.',
            unavailable = 'Le livre des arrivées ne répond pas : réessayez dans un instant.',
            state = '%s (joueur %d, personnage n° %d) : dotation %s ; accueil %s.',
            unknown = '%s (joueur %d, personnage n° %d) : arrivé avant l\'accueil, rien à suivre.',
            kitStates = {
                due = 'à donner',
                claimed = 'en cours',
                given = 'donnée le %s',
                withheld = 'retenue le %s (limite du compte)',
                uncertain = 'incertaine depuis le %s (à vérifier)',
                none = 'aucune (arrivé avant l\'accueil)',
            },
            welcomeStates = {
                seen = 'vu le %s',
                pending = 'envoyé %d fois, pas encore vu',
                never = 'jamais envoyé',
            },
            dateFormat = '%d/%m à %H h %M',  -- os.date, heure du serveur
            regiven = 'Dotation redonnée à %s.',
            regiveFailed = 'Dotation non donnée à %s : %s.',
            codes = {
                no_space = 'besace pleine',
                too_heavy = 'besace trop lourde',
                unknown_item = 'objet inconnu de l\'inventaire',
                inventory_unavailable = 'inventaire indisponible',
                changed = 'le joueur a changé de personnage',
            },
            replayed = 'Accueil rejoué pour %s.',
            replayFailed = 'Accueil non rejoué pour %s : %s.',
        },
        journal = {
            regive = 'Dotation redonnée',
            replay = 'Accueil rejoué',
        },
    },
}
