--[[
    vava_gathering/server/journal.lua
    Rôle : journal (table vava_gathering_log) : épuisements, cicatrices, réactions de la terre, actions du Conseil.
           Écriture hors du thread appelant, purge au démarrage au-delà de la rétention.
    Dépendances : config.lua, server/core.lua, bridge/server.lua
]]

local type, pcall, tostring = type, pcall, tostring
local encodeJson = json.encode
local CreateThread = CreateThread
local time = os.time

local bridge = VavaGathering.bridge
local cfg = VavaGathering.config

local INSERT_SQL = 'INSERT INTO `vava_gathering_log` (`at`, `kind`, `zone`, `node`, `character_id`, `account_id`, `details`) VALUES (?, ?, ?, ?, ?, ?, ?)'
local PURGE_SQL = 'DELETE FROM `vava_gathering_log` WHERE `at` < ?'

local journal = {}
VavaGathering.journal = journal

---@class vAvA.GatheringLogEntry
---@field zone? string
---@field node? string
---@field characterId? integer
---@field accountId? integer
---@field details? table

--- Note une action. N'attend pas la base.
---@param kind string
---@param entry vAvA.GatheringLogEntry
function journal.write(kind, entry)
    local details = nil
    if type(entry.details) == 'table' then
        local ok, encoded = pcall(encodeJson, entry.details)
        details = ok and encoded or nil
    end
    local at = time()
    CreateThread(function()
        local _, err = bridge.db.insert(INSERT_SQL, { at, kind, entry.zone, entry.node, entry.characterId, entry.accountId, details })
        if err then VavaGathering.log.error("journal '%s' non écrit : %s", kind, tostring(err)) end
    end)
end

--- Supprime les entrées plus vieilles que la rétention. Appelé pendant le setup du module (bloque le thread).
function journal.purge()
    local days = cfg.logRetentionDays
    if type(days) ~= 'number' or days <= 0 then return end
    local removed, err = bridge.db.update(PURGE_SQL, { time() - days * 86400 })
    if err then
        VavaGathering.log.warn('purge du journal en échec : %s', tostring(err))
    elseif removed and removed > 0 then
        VavaGathering.log.info('journal : %d entrée(s) de plus de %d jours supprimée(s)', removed, days)
    end
end
