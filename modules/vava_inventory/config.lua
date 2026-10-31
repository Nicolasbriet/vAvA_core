--[[
    vava_inventory/config.lua
    Rôle : réglages de l'inventaire que lit le seul serveur (servi au seul serveur, jamais téléchargé par les
           joueurs). Poids en grammes. Grille du personnage, sacs au sol, bornes des objets, effets et métadonnées,
           ancrages, garde de l'objet tenu en main, journal, catalogue de développement, objets de départ, débits.
           Complète la table ouverte par config_client.lua (distance et attente des sacs, cadences de la main,
           raccourcis, touches) sans en réécrire une clé (T-132).
    Dépendances : shared/constants.lua, config_client.lua
]]

local config = VavaInventory.config

config.coreVersion = '0.3.0'

-- Inventaire porté par chaque personnage. Agrandir la grille s'applique aussi aux personnages existants.
config.character = { label = 'Besace', width = 10, height = 6, maxWeight = 25000 }

-- Sacs au sol : conteneurs temporaires (non conservés au redémarrage du serveur), entités réseau visibles des
-- joueurs proches. Distance d'interaction et attente de l'entité par le client : config_client.lua.
local drop = config.drop
drop.label = 'Sac au sol'
drop.width, drop.height, drop.maxWeight = 6, 4, 60000
drop.model = 'prop_money_bag_01'
drop.lifetimeMs = 600000           -- disparition après 10 minutes
drop.groundOffset = 0.98           -- hauteur du centre du ped au-dessus du sol
drop.reuseDistance = 1.5           -- jeter près d'un sac existant le remplit plutôt que d'en créer un autre
-- Plafonds des sacs encore au sol (entités réseau) : posés par un même personnage, et sur tout le serveur. Au-delà, un
-- jet qui poserait un nouveau sac est refusé ; remplir un sac existant reste possible. Un sac compte jusqu'à sa
-- disparition (vidé, expiré), même si son auteur a quitté le jeu.
drop.maxPerPlayer = 10
drop.maxTotal = 300

config.maxItemSize = 8               -- taille maximale d'un objet (cases), en largeur comme en hauteur
-- Effets déclarés par un objet (`effects = { hunger = 35 }`), appliqués par les modules qui les lisent.
config.effects = { maxEntries = 8, maxValue = 1000 }
-- Métadonnées portées par une pile (toujours un objet JSON) : bornes vérifiées à chaque écriture par un module.
-- maxEntries s'applique à chaque table (racine comme imbriquée), maxDepth compte la racine.
config.metadata = { maxEntries = 32, maxDepth = 4, maxStringLength = 256 }
-- Conteneurs ouverts par un module avec un ancrage (coffre, grenier, station…) : rayon maximal (m) et cadence
-- de la vérification d'éloignement, active seulement tant qu'un conteneur ancré est ouvert par quelqu'un.
config.anchor = { maxRadius = 25.0, sweepMs = 2000 }
-- Objet tenu en main : ce que tient un joueur est publié sur le statebag de son ped (1.7.0) : seuls les joueurs qui
-- voient ce ped le reçoivent, et le reçoivent quand il apparaît chez eux. Cadences du client : config_client.lua.
local hands = config.hands
hands.defaultBone = 57005          -- main droite (SKEL_R_Hand)
hands.pedCheckMs = 1000            -- serveur : cadence du contrôle du ped des porteurs (réapparition, changement de
                                   -- modèle), active seulement tant que quelqu'un tient quelque chose
-- serveur : garde du statebag du ped (une main réécrite par le client du porteur est remise) ; délai de la remise, puis
-- remises espacées (doublées jusqu'au plafond) au-delà de guardMaxCorrections sans publication. La comparaison
-- { id, item } est exacte (aucune boucle légitime à amortir) : le plafond reste court, une fausse main n'est jamais
-- visible plus d'une seconde environ
hands.guardDelayMs = 250
hands.guardMaxCorrections = 3
hands.guardMaxDelayMs = 1000
hands.guardWarnMs = 10000          -- serveur : une ligne en console au plus par joueur et par intervalle
-- écriture groupée du journal des modifications ; aussi l'écart minimal entre deux écritures déclenchées par les
-- fermetures d'inventaire d'un même joueur (le déchargement du personnage écrit toujours aussitôt)
config.flushIntervalMs = 3000

-- Catalogue de développement (1.5.0) : un conteneur temporaire garni d'une pile pleine de chaque objet connu,
-- par catégorie, découpé en pages à la taille de sa grille. `/catalogue [catégorie] [page]` en jeu (droit
-- `permission` de vava_admin ; sans lui, ACE `ace`), `catalogue <joueur> [catégorie] [page]` en console. Ce qu'on
-- en prend est regarni, ce qu'on y dépose disparaît, rien n'est écrit en base. À n'activer que sur un serveur
-- de test : tout y est gratuit.
config.catalog = {
    enabled = true,
    command = 'catalogue',
    label = 'Catalogue (développement)',
    width = 16, height = 10,
    permission = 'staff', ace = 'vava_inventory.catalogue',
}

-- Objets donnés à la création d'un personnage : { { item = 'nom', quantity = 1 }, ... }.
config.startingItems = {}

config.rateLimits = {
    open = { capacity = 4, refillPerSecond = 1 },
    action = { capacity = 20, refillPerSecond = 10 },  -- déplacer, diviser, fusionner, jeter, raccourcis
    use = { capacity = 4, refillPerSecond = 1 },
    -- prendre en main ou reposer depuis l'interface (1.7.0) : chaque geste réécrit le statebag du ped, envoyé aux
    -- joueurs proches ; la ceinture passe par `use`
    hold = { capacity = 4, refillPerSecond = 2 },
}
