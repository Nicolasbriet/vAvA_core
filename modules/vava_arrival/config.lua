--[[
    vava_arrival/config.lua
    Rôle : réglages de l'arrivée d'un nouveau personnage lus par le seul serveur (servi au seul serveur, jamais
           téléchargé par les joueurs) : dotation de départ, sa limite par compte et les modules qui en déclarent des
           objets, objets déclarés à l'inventaire s'ils manquent, commande du Conseil, débit de l'accusé, rétention du
           journal, textes du Conseil. Complète la table ouverte par config_client.lua (attente de l'accueil côté
           client, chapitre du Codex, textes du nouveau venu) sans en réécrire une clé (T-132).
    Le point d'arrivée n'est PAS ici : c'est `spawn.defaultPoint` de config/server.lua (core), où le core fait déjà
    apparaître tout personnage sans position enregistrée, donc tout nouveau personnage (une seule source).
    Les textes ont été relus avec ceux de l'écran de chargement (T-021) : `messages.kit` (config_client.lua) suit
    `kit.items` (config.lua) : les tenir d'accord.
    Dépendances : shared/constants.lua, config_client.lua
]]

local config = VavaArrival.config

config.coreVersion = '0.10.0'  -- core.net.send (0.10.0) ; playSeconds du hook loaded (0.6.0) ; registre core:commands (0.7.0)
config.dependencies = { vava_inventory = '1.4.0' }  -- exchange, registre des objets

config.kit = {
    -- Dotation de départ : liste pure, 8 entrées au plus, quantités de 1 à 100, un objet au plus une fois.
    -- `{}` : aucune dotation (l'état passe à « donnée », rien n'est donné). Ne pas remplir en même temps
    -- `startingItems` de vava_inventory (double dotation). À tenir d'accord avec `messages.kit` (config_client.lua).
    items = {
        { item = 'pain', quantity = 2 },
        { item = 'eau', quantity = 2 },
    },
    -- Au plus `max` dotations par compte sur `days` jours glissants (réservées, données ou incertaines, personnages
    -- supprimés compris) ; au-delà, l'accueil a lieu sans dotation. `max = 0` : aucune limite.
    perAccount = { max = 3, days = 30 },
    -- Modules qui déclarent des objets de la dotation (l'eau : vava_provisions). À leur annonce `core:module:ready`,
    -- les dotations dues des personnages apparus sont reprises, comme au retour de l'inventaire, sans second
    -- accueil : l'ordre de démarrage ne fait perdre aucune dotation. Liste pure de noms de ressources (8 au plus,
    -- 64 octets chacun).
    providers = { 'vava_provisions' },
}

-- Objets déclarés à l'inventaire par ce module S'ILS NE LE SONT PAS DÉJÀ (le premier déclaré l'emporte). Image :
-- nui://vava_arrival/web/items/<nom>.svg, ajoutée à la déclaration. Même définition que vava_example_items.
-- `eau` n'est plus ici : déclarée par vava_provisions (T-130), propriétaire de l'eau et des outres.
config.items = {
    pain = { label = 'Miche de pain', description = 'Croûte épaisse, mie serrée.', width = 2, height = 1,
        weight = 400, stack = 10, category = 'nourriture', effects = { hunger = 35 } },
}

config.admin = {
    command = 'accueil',            -- /accueil etat | redoter | rejouer <n° de joueur>
    permission = 'give',            -- droit vava_admin (Sénéchal et au-dessus : le droit « Donner » du Registre)
    ace = 'vava_arrival.admin',     -- repli ACE sans vava_admin
    cooldownMs = 2000,              -- entre deux /accueil d'un même membre (console exceptée)
}

config.rateLimits = {
    welcomed = { capacity = 2, refillPerSecond = 0.05 },  -- RPC vava_arrival:welcomed (accusé), par joueur
}

config.logRetentionDays = 90  -- purge de vava_arrival_log au démarrage

-- Textes du Conseil, lus par le seul serveur (réponses de /accueil, libellés du journal du Registre : 32 octets au
-- plus). Ceux que montre le client au nouveau venu sont dans config_client.lua (messages.*).
local messages = config.messages
messages.admin = {
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
}
messages.journal = {
    regive = 'Dotation redonnée',
    replay = 'Accueil rejoué',
}
