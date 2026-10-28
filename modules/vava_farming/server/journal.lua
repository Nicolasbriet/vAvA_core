--[[
    vava_farming/server/journal.lua
    Rôle : journaux (vava_farming_log : plantations, récoltes Excellent+, arrachages, Conseil ; vava_farming_granary_log :
           dépôts et retraits au grenier). Écriture hors du thread appelant, purge au démarrage.
    Dépendances : config.lua, server/core.lua, bridge/server.lua
]]

local type, pcall, tostring = type, pcall, tostring
local encodeJson = json.encode
local CreateThread = CreateThread
local time = os.time

local bridge = VavaFarming.bridge
local cfg = VavaFarming.config

local INSERT_SQL = 'INSERT INTO `vava_farming_log` (`at`, `kind`, `parcel`, `slot`, `character_id`, `account_id`, `item`, `quality`, `details`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
local INSERT_GRANARY_SQL = 'INSERT INTO `vava_farming_granary_log` (`at`, `parcel`, `character_id`, `action`, `item`, `quantity`) VALUES (?, ?, ?, ?, ?, ?)'
local PURGE_SQL = 'DELETE FROM `vava_farming_log` WHERE `at` < ?'
local PURGE_GRANARY_SQL = 'DELETE FROM `vava_farming_granary_log` WHERE `at` < ?'

local journal = {}
VavaFarming.journal = journal

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

--- Dépôt ou retrait au grenier.
---@param parcel string
---@param characterId integer|nil
---@param action 'deposit'|'withdraw'
---@param item string
---@param quantity integer
function journal.granary(parcel, characterId, action, item, quantity)
    local at = time()
    CreateThread(function()
        local _, err = bridge.db.insert(INSERT_GRANARY_SQL, { at, parcel, characterId, action, item, quantity })
        if err then VavaFarming.log.error('journal du grenier non écrit : %s', tostring(err)) end
    end)
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
