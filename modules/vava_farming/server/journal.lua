--[[
    vava_farming/server/journal.lua
    Rôle : journaux (vava_farming_log : plantations, récoltes Excellent+, arrachages, Conseil ; vava_farming_granary_log :
           dépôts et retraits au grenier, une ligne par minute, personnage, grenier, objet et sens, quantités
           additionnées). Écriture hors du thread appelant ; le journal du grenier attend en mémoire (borné) et part
           avec l'écriture groupée, l'arrêt du module, ou aussitôt quand l'attente est pleine. Purge au démarrage.
    Dépendances : config.lua, server/core.lua, bridge/server.lua
]]

local type, pairs, ipairs, pcall, tostring = type, pairs, ipairs, pcall, tostring
local mathType = math.type
local concat = table.concat
local encodeJson = json.encode
local CreateThread = CreateThread
local time = os.time

local bridge = VavaFarming.bridge
local cfg = VavaFarming.config

local INSERT_SQL = 'INSERT INTO `vava_farming_log` (`at`, `kind`, `parcel`, `slot`, `character_id`, `account_id`, `item`, `quality`, `details`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
-- une ligne par minute (clé unique `minute`, grenier, personnage, objet, sens : sql/0002) ; `at` = début de la minute
local UPSERT_GRANARY_SQL = 'INSERT INTO `vava_farming_granary_log` (`at`, `minute`, `parcel`, `character_id`, `action`, `item`, `quantity`) '
    .. 'VALUES (?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE `quantity` = `quantity` + VALUES(`quantity`)'
local PURGE_SQL = 'DELETE FROM `vava_farming_log` WHERE `at` < ?'
local PURGE_GRANARY_SQL = 'DELETE FROM `vava_farming_granary_log` WHERE `at` < ?'

local journal = {}
VavaFarming.journal = journal

-- journal du grenier en attente : clé (minute, grenier, personnage, objet, sens) → ligne, quantités additionnées
local pending, pendingCount = {}, 0
-- lignes perdues (attente pleine), signalées au passage suivant ; une écriture anticipée en route au plus
local lost, early = 0, false

---@class vAvA.FarmingLogEntry
---@field parcel? string
---@field slot? integer
---@field characterId? integer
---@field accountId? integer
---@field item? string
---@field quality? integer
---@field details? table

---@param kind string
---@param entry vAvA.FarmingLogEntry
function journal.write(kind, entry)
    local details = nil
    if type(entry.details) == 'table' then
        local ok, encoded = pcall(encodeJson, entry.details)
        details = ok and encoded or nil
    end
    local at = time()
    CreateThread(function()
        local _, err = bridge.db.insert(INSERT_SQL, {
            at, kind, entry.parcel, entry.slot, entry.characterId, entry.accountId, entry.item, entry.quality, details,
        })
        if err then VavaFarming.log.error("journal '%s' non écrit : %s", kind, tostring(err)) end
    end)
end

--- Dépôt ou retrait au grenier : ajouté à la ligne de la minute (rien n'est écrit ici).
---@param parcel string
---@param characterId integer|nil
---@param action 'deposit'|'withdraw'
---@param item string
---@param quantity integer
function journal.granary(parcel, characterId, action, item, quantity)
    if mathType(quantity) ~= 'integer' or quantity < 1 then return end
    local at = time()
    local minute = at - at % 60
    local key = concat({ minute, parcel, characterId or '', item, action }, '|')
    local entry = pending[key]
    if entry then
        entry.quantity = entry.quantity + quantity
        return
    end
    local limit = cfg.persistence.granaryLogMax
    if pendingCount >= limit then
        lost = lost + 1
        return
    end
    pending[key] = { minute = minute, parcel = parcel, characterId = characterId, action = action, item = item, quantity = quantity }
    pendingCount = pendingCount + 1
    if pendingCount >= limit and not early then
        early = true
        CreateThread(function()
            journal.flushGranary()
            early = false
        end)
    end
end

--- Requêtes du journal du grenier en attente (les quantités s'ajoutent à la ligne de la minute déjà écrite), à joindre
--- à une transaction ; l'attente repart vide. Renvoie le lot, à rendre à `granaryWritten`.
---@param queries table[]
---@return table batch
function journal.collectGranary(queries)
    if lost > 0 then
        VavaFarming.log.error('journal du grenier : %d ligne(s) perdue(s), attente pleine (%d)', lost, cfg.persistence.granaryLogMax)
        lost = 0
    end
    local batch = pending
    pending, pendingCount = {}, 0
    for _, e in pairs(batch) do
        queries[#queries + 1] = { query = UPSERT_GRANARY_SQL, values = { e.minute, e.minute, e.parcel, e.characterId, e.action, e.item, e.quantity } }
    end
    return batch
end

--- Fin de l'écriture d'un lot : en échec (la transaction n'a rien écrit), tout revient en attente, fusionné avec ce qui
--- est arrivé pendant l'attente, dans la borne.
---@param batch table
---@param ok boolean
function journal.granaryWritten(batch, ok)
    if ok then return end
    local limit = cfg.persistence.granaryLogMax
    for key, e in pairs(batch) do
        local current = pending[key]
        if current then
            current.quantity = current.quantity + e.quantity
        elseif pendingCount < limit then
            pending[key] = e
            pendingCount = pendingCount + 1
        else
            lost = lost + 1
        end
    end
end

--- Écrit le journal du grenier en attente, seul, en une transaction (attente pleine). Bloque le thread courant.
function journal.flushGranary()
    local queries = {}
    local batch = journal.collectGranary(queries)
    if #queries == 0 then return end
    local ok, err = bridge.db.transaction(queries)
    journal.granaryWritten(batch, ok == true)
    if not ok then VavaFarming.log.error('journal du grenier non écrit (%d ligne(s)), nouvel essai au prochain passage : %s', #queries, tostring(err)) end
end

--- Purge au-delà de la rétention. Appelé pendant le setup du module (bloque le thread).
function journal.purge()
    local days = cfg.logRetentionDays
    if type(days) ~= 'number' or days <= 0 then return end
    local limit = time() - days * 86400
    for _, sql in ipairs({ PURGE_SQL, PURGE_GRANARY_SQL }) do
        local removed, err = bridge.db.update(sql, { limit })
        if err then
            VavaFarming.log.warn('purge du journal en échec : %s', tostring(err))
        elseif removed and removed > 0 then
            VavaFarming.log.info('journal : %d entrée(s) de plus de %d jours supprimée(s)', removed, days)
        end
    end
end
