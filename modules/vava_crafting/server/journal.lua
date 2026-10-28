--[[
    vava_crafting/server/journal.lua
    Rôle : journal (table vava_crafting_log) : pièces Excellent et au-dessus, réparations, baptêmes, leçons données,
           actions du Conseil. Écriture hors du thread appelant, purge au démarrage au-delà de la rétention.
    Dépendances : config.lua, server/core.lua, bridge/server.lua
]]

local type, pcall, tostring = type, pcall, tostring
local encodeJson = json.encode
local CreateThread = CreateThread
local time = os.time

local bridge = VavaCrafting.bridge
local cfg = VavaCrafting.config

local INSERT_SQL = 'INSERT INTO `vava_crafting_log` (`at`, `kind`, `station`, `recipe`, `character_id`, `account_id`, `item`, `quality`, `details`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
local PURGE_SQL = 'DELETE FROM `vava_crafting_log` WHERE `at` < ?'

local journal = {}
VavaCrafting.journal = journal

---@class vAvA.CraftingLogEntry
---@field station? string
---@field recipe? string
---@field characterId? integer
---@field accountId? integer
---@field item? string
---@field quality? integer
---@field details? table

---@param kind string
---@param entry vAvA.CraftingLogEntry
function journal.write(kind, entry)
    local details = nil
    if type(entry.details) == 'table' then
        local ok, encoded = pcall(encodeJson, entry.details)
        details = ok and encoded or nil
    end
    local at = time()
    CreateThread(function()
        local _, err = bridge.db.insert(INSERT_SQL, {
            at, kind, entry.station, entry.recipe, entry.characterId, entry.accountId, entry.item, entry.quality, details,
        })
        if err then VavaCrafting.log.error("journal '%s' non écrit : %s", kind, tostring(err)) end
    end)
end

--- Purge au-delà de la rétention. Appelé pendant le setup du module (bloque le thread).
function journal.purge()
    local days = cfg.logRetentionDays
    if type(days) ~= 'number' or days <= 0 then return end
    local removed, err = bridge.db.update(PURGE_SQL, { time() - days * 86400 })
    if err then
        VavaCrafting.log.warn('purge du journal en échec : %s', tostring(err))
    elseif removed and removed > 0 then
        VavaCrafting.log.info('journal : %d entrée(s) de plus de %d jours supprimée(s)', removed, days)
    end
end
