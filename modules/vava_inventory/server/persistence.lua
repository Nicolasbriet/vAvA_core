--[[
    vava_inventory/server/persistence.lua
    Rôle : journal des modifications et écriture groupée. Chaque mutation note l'état final d'un objet (à écrire ou à
           supprimer) ; le journal part en UNE transaction toutes les flushIntervalMs, et aussitôt au déchargement d'un
           personnage, à la fermeture d'un inventaire (au plus une fois par flushIntervalMs et par joueur : voir
           operations.close) et à l'arrêt du module (sauf pendant une écriture en cours). Un échange entre deux
           conteneurs est donc toujours écrit d'un bloc. Les écritures sont sérialisées : une écriture immédiate attend
           celle en cours.
           Chaque objet sait s'il a peut-être sa ligne en base (`stored` : lu en base, ou écriture envoyée, jusqu'à un
           effacement validé). Celui qui n'en a pas (né dans le catalogue ou un sac, repris avant toute écriture)
           n'écrit rien quand il quitte les conteneurs conservés : le catalogue ne touche jamais la base.
    Dépendances : config.lua, server/core.lua
]]

local pairs, next, pcall, tostring = pairs, next, pcall, tostring
local encodeJson = json.encode
local CreateThread, Wait = CreateThread, Wait
local newPromise, await = promise.new, Citizen.Await

local cfg = VavaInventory.config

local UPSERT_SQL = 'INSERT INTO `vava_inventory_items` (`id`, `container_id`, `item`, `x`, `y`, `rotated`, `quantity`, `metadata`) '
    .. 'VALUES (?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE `container_id` = VALUES(`container_id`), `item` = VALUES(`item`), '
    .. '`x` = VALUES(`x`), `y` = VALUES(`y`), `rotated` = VALUES(`rotated`), `quantity` = VALUES(`quantity`), `metadata` = VALUES(`metadata`)'
local DELETE_SQL = 'DELETE FROM `vava_inventory_items` WHERE `id` = ?'
local EMPTY_METADATA = '{}'

local persistence = {}
VavaInventory.persistence = persistence

-- id d'objet → { instance = objet } (à écrire) ou { instance = objet, delete = true } (à effacer) ; seul le dernier
-- état compte
local journal = {}
-- dernière écriture en file : chacune attend la précédente
local queueTail = nil

--- Note la disparition d'un objet de la base (consommé, retiré, ou parti dans un conteneur non conservé). S'il n'y a
--- jamais eu sa ligne, rien n'est à effacer, et une écriture encore en attente n'a plus lieu d'être.
---@param instance vAvA.ItemInstance
function persistence.forget(instance)
    if instance.stored then
        journal[instance.id] = { instance = instance, delete = true }
    else
        journal[instance.id] = nil
    end
end

--- Note l'état d'un objet. Un objet placé dans un conteneur non conservé (sac au sol, catalogue) quitte la base.
---@param instance vAvA.ItemInstance
---@param persisted boolean  le conteneur de l'objet est conservé en base
function persistence.touch(instance, persisted)
    if persisted then
        journal[instance.id] = { instance = instance }
    else
        persistence.forget(instance)
    end
end

---@param metadata table|nil
---@return string
local function encodeMetadata(metadata)
    if metadata == nil or next(metadata) == nil then return EMPTY_METADATA end
    local ok, encoded = pcall(encodeJson, metadata)
    return ok and encoded or EMPTY_METADATA
end

---@return boolean ok
---@return string|nil err
local function write()
    if next(journal) == nil then return true end
    local batch = journal
    journal = {}
    local queries = {}
    for id, entry in pairs(batch) do
        local instance = entry.instance
        if entry.delete then
            queries[#queries + 1] = { query = DELETE_SQL, values = { id } }
        else
            -- envoyée avant toute attente : l'objet a désormais peut-être sa ligne, un retrait devra l'effacer
            instance.stored = true
            queries[#queries + 1] = { query = UPSERT_SQL, values = {
                instance.id, instance.containerId, instance.item, instance.x, instance.y,
                instance.rotated and 1 or 0, instance.quantity, encodeMetadata(instance.metadata),
            } }
        end
    end
    local ok, err = VavaInventory.core.db.transaction(queries)
    if not ok then
        -- rien n'est perdu : les entrées remises en file, sauf celles remplacées par une modification plus récente ;
        -- un effacement en échec laisse `stored` vrai (la ligne existe encore)
        for id, entry in pairs(batch) do
            if journal[id] == nil then journal[id] = entry end
        end
        VavaInventory.log.error('écriture de l\'inventaire en échec (%d objet(s)), nouvel essai : %s', #queries, tostring(err))
        return false, err
    end
    -- effacements validés : plus de ligne. Les écritures étant sérialisées, aucune autre n'a pu en recréer une entre-temps
    -- (une écriture notée pendant l'attente remettra `stored` en partant)
    for _, entry in pairs(batch) do
        if entry.delete then entry.instance.stored = nil end
    end
    return true
end

--- Écrit le journal maintenant. Bloque le thread courant jusqu'à la fin de l'écriture.
---@return boolean ok
---@return string|nil err
function persistence.flush()
    local previous = queueTail
    local done = newPromise()
    queueTail = done
    if previous then await(previous) end
    local called, ok, err = pcall(write)
    done:resolve(true)
    if queueTail == done then queueTail = nil end
    if not called then return false, tostring(ok) end
    return ok, err
end

--- Écriture sans attendre le résultat (fermeture d'inventaire).
function persistence.flushSoon()
    CreateThread(persistence.flush)
end

--- Arrêt du module : dernière écriture, lancée sans pouvoir en attendre la fin (la ressource s'arrête). Jamais pendant
--- une écriture en cours : deux transactions croisées pourraient écrire un état plus ancien après le plus récent.
--- Renvoie le nombre d'objets restés sans écriture (0 : rien à écrire, ou écriture partie).
---@return integer
function persistence.flushOnStop()
    if next(journal) == nil then return 0 end
    if queueTail then return persistence.pending() end
    -- peut ne jamais rendre la main (la ressource s'arrête pendant l'attente) : la transaction est déjà partie
    persistence.flush()
    return persistence.pending()
end

--- Nombre d'objets en attente d'écriture.
---@return integer
function persistence.pending()
    local count = 0
    for _ in pairs(journal) do count = count + 1 end
    return count
end

--- Vrai si un objet de ce conteneur attend encore une écriture ou un effacement (un objet retiré garde le numéro du
--- conteneur qu'il a quitté).
---@param containerId integer
---@return boolean
function persistence.pendingFor(containerId)
    for _, entry in pairs(journal) do
        if entry.instance.containerId == containerId then return true end
    end
    return false
end

--- Lance l'écriture périodique. Appelé pendant le setup du module.
function persistence.start()
    CreateThread(function()
        -- boucle lente justifiée : au plus une transaction toutes les flushIntervalMs, rien si le journal est vide
        while true do
            Wait(cfg.flushIntervalMs)
            if next(journal) ~= nil then persistence.flush() end
        end
    end)
end
