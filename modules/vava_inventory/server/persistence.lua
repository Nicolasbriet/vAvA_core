--[[
    vava_inventory/server/persistence.lua
    Rôle : journal des modifications et écriture groupée. Chaque mutation note l'état final d'un objet (à écrire ou à
           supprimer) ; le journal part en UNE transaction toutes les flushIntervalMs, et immédiatement à la fermeture
           d'un inventaire ou au déchargement d'un personnage. Un échange entre deux conteneurs est donc toujours
           écrit d'un bloc. Les écritures sont sérialisées : une écriture immédiate attend celle en cours.
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

-- id d'objet → { instance = objet } (à écrire) ou { delete = true } ; seul le dernier état compte
local journal = {}
-- dernière écriture en file : chacune attend la précédente
local queueTail = nil

--- Note l'état d'un objet. Un objet placé dans un conteneur non conservé (sac au sol) est supprimé de la base.
---@param instance vAvA.ItemInstance
---@param persisted boolean  le conteneur de l'objet est conservé en base
function persistence.touch(instance, persisted)
    journal[instance.id] = persisted and { instance = instance } or { delete = true }
end

--- Note la disparition d'un objet (consommé, retiré).
---@param id integer
function persistence.forget(id)
    journal[id] = { delete = true }
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
        if instance then
            queries[#queries + 1] = { query = UPSERT_SQL, values = {
                instance.id, instance.containerId, instance.item, instance.x, instance.y,
                instance.rotated and 1 or 0, instance.quantity, encodeMetadata(instance.metadata),
            } }
        else
            queries[#queries + 1] = { query = DELETE_SQL, values = { id } }
        end
    end
    local ok, err = VavaInventory.core.db.transaction(queries)
    if not ok then
        -- rien n'est perdu : les entrées remises en file, sauf celles remplacées par une modification plus récente
        for id, entry in pairs(batch) do
            if journal[id] == nil then journal[id] = entry end
        end
        VavaInventory.log.error('écriture de l\'inventaire en échec (%d objet(s)), nouvel essai : %s', #queries, tostring(err))
        return false, err
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

--- Nombre d'objets en attente d'écriture.
---@return integer
function persistence.pending()
    local count = 0
    for _ in pairs(journal) do count = count + 1 end
    return count
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
