--[[
    vava_provisions/config.lua
    Rôle : réglages des vivres du royaume lus par le seul serveur (servi au seul serveur, jamais téléchargé par les
           joueurs) : objets déclarés s'ils manquent (eau, outre), remplissage, contenants rendus et usés, recette de
           l'outre à la tannerie, gorgées au point d'eau, délai entre deux actions, points d'eau, marge du serveur,
           zone des points, commande du Conseil et ses textes, débit du RPC. Complète la table ouverte par config_client.lua (sortes
           de points d'eau, portée, streaming, gestes, touche, textes) sans en réécrire une clé (T-132).
    Les points d'eau sont des EXEMPLES autour du point d'apparition par défaut (-- PLACEHOLDER) : à remplacer par les
    lieux du royaume. La config est la graine : l'Atelier les reprendra (T-130 § 10.4).
    Dépendances : shared/constants.lua, config_client.lua
]]

local config = VavaProvisions.config

config.coreVersion = '0.11.0'   -- core.zones (0.11.0), core.net.send (0.10.0), registre core:commands (0.7.0)
config.dependencies = { vava_inventory = '1.8.0' }   -- count, exchange, add, hook use avec `consumed`, piles gardées à part

-- Objets déclarés à l'inventaire S'ILS NE LE SONT PAS DÉJÀ (le premier déclaré l'emporte : avertissement en
-- console). Image : nui://vava_provisions/web/items/<nom>.svg, ajoutée à la déclaration. La définition de `eau` est
-- celle de vava_arrival 1.0.0 (taille, pile, poids, soif) : les piles déjà en jeu se relisent telles quelles.
config.items = {
    eau = { label = 'Outre d\'eau', description = 'De l\'eau fraîche et claire. Une fois bue, l\'outre vide vous reste, si la couture tient.',
        width = 1, height = 2, weight = 700, stack = 5, category = 'boisson', effects = { thirst = 40 } },
    outre = { label = 'Outre vide', description = 'Cuir cousu et poissé. Elle se remplit à un puits, une fontaine ou une source.',
        width = 1, height = 2, weight = 150, stack = 5, category = 'divers' },
}

-- Un appui au point d'eau remplit au plus `maxPerDraw` outres vides (1 à 20) : `from` retirés, `to` donnés, tout ou
-- rien. Les outres sont retirées sans filtre (palier ignoré, les plus anciennes d'abord).
config.fill = { from = 'outre', to = 'eau', maxPerDraw = 5 }

-- Boire un objet de la liste rend `empty`, sauf une fois sur dix (`tearChance`, 0 à 1) où l'outre se fend. Une
-- recette future qui consomme `eau` doit rendre `outre` dans sa sortie, sinon l'outre est perdue.
config.containers = {
    eau = { empty = 'outre', tearChance = 0.1 },
}

-- Tannerie (vava_crafting) : un cuir donne deux outres. Ni signée ni transmise : savoir commun du tanneur. Ajoutée
-- au registre des recettes si l'artisanat tourne et que la station `tannerie` y est déclarée.
config.recipe = { id = 'outre', label = 'Outre', skill = 'tannerie', level = 0, station = 'tannerie', durationMs = 6000,
    difficulty = 5, xp = 8, ingredients = { { item = 'cuir', quantity = 1 } }, output = { item = 'outre', quantity = 2 } }

-- Boire au point d'eau (vava_needs) : soif + `thirst` (1 à 100) ; refusé si la soif est à `fullAt` ou plus (même
-- seuil que vava_needs). La réserve n'est pas touchée.
config.drink = { thirst = 20, fullAt = 95 }

-- Délai entre deux actions d'un même joueur (puiser ou boire), tenu par le serveur ; au moins la durée des gestes.
config.cooldownMs = 3000

-- Points d'eau : EXEMPLES autour du point d'apparition par défaut. `model` facultatif : celui de la sorte sinon ;
-- '' : aucun prop (point posé sur un décor de la carte). Jamais à moins de 5 m d'un puits de vava_farming, ni d'une
-- autre cible de la touche E (stations, nœuds de récolte) : deux invites sur la même touche.
config.points = {
    { id = 'fontaine_bourg', kind = 'fontaine', label = 'Fontaine du bourg', x = -250.0, y = -960.0, z = 31.2, heading = 0.0 },  -- PLACEHOLDER
    { id = 'puits_lavoir', kind = 'puits', label = 'Puits du lavoir', x = -300.0, y = -985.0, z = 31.2, heading = 0.0 },         -- PLACEHOLDER
    { id = 'source_claire', kind = 'source', label = 'Source de la Rivière Claire', x = -118.0, y = -876.0, z = 29.0, heading = 0.0 }, -- PLACEHOLDER
}

-- Au plus ce nombre de points (config et ajouts) ; au-delà, refus `too_many`.
config.maxPoints = 256

-- Marge du serveur (latence), lue par le seul serveur : ajoutée à `interact` (config_client.lua), dont le client lit la
-- portée de l'invite (relecture sécurité S-5 de T-132). Refus au-delà de distance + serverTolerance (3,5 m).
config.interact.serverTolerance = 1.5

-- Chaque point est une zone du core de `zoneRadius` mètres, connue à `streaming.radius` (config_client.lua) +
-- `subscribeSlack` de son bord (même sens et mêmes valeurs que vava_crafting). Lus par le seul serveur : ajoutés à
-- `streaming`.
config.streaming.zoneRadius = 2.0
config.streaming.subscribeSlack = 20.0

config.admin = {
    command = 'eau',            -- /eau points | reserve <point> <nombre>
    permission = 'metiers',     -- droit vava_admin (Sénéchal et au-dessus, comme /agriculture)
    ace = 'metiers.admin',      -- repli ACE sans vava_admin
    cooldownMs = 1000,          -- entre deux /eau d'un même membre (console exceptée)
    -- /eau points : lignes regroupées en messages de `replyBytes` octets au plus (sous les 500 signes d'un message
    -- de vava_chat) ; au-delà de `listMax` points, « … et N autres points d'eau. »
    replyBytes = 480,
    listMax = 60,
}

config.rateLimits = {
    draw = { capacity = 3, refillPerSecond = 0.5 },  -- RPC vava_provisions:draw, par joueur
}

-- Textes du Conseil, lus par le seul serveur (T-143) : ajoutés à `messages` (config_client.lua), dont le client lit
-- les textes montrés au joueur. Réponses de /eau (200 octets au plus, texte brut) et libellé du journal du Registre
-- (32 octets au plus).
config.messages.admin = {
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
}
config.messages.journal = {
    reserve = 'Réserve d\'eau fixée',     -- journal du Registre
}
