--[[
    vava_arrival/server/journal.lua
    Rôle : journal (table vava_arrival_log) : dotations données, retenues, incertaines ; actions du Conseil. Écriture
           hors du thread appelant, purge au démarrage au-delà de la rétention.
    Dépendances : config.lua, server/core.lua, bridge/server.lua
]]

local type, pcall, tostring = type, pcall, tostring
local encodeJson = json.encode
local CreateThread = CreateThread

local bridge = VavaArrival.bridge
local cfg = VavaArrival.config

local INSERT_SQL = 'INSERT INTO `vava_arrival_log` (`at`, `kind`, `character_id`, `account_id`, `actor_account_id`, `details`) VALUES (?, ?, ?, ?, ?, ?)'
local PURGE_SQL = 'DELETE FROM `vava_arrival_log` WHERE `at` < ?'

local journal = {}
VavaArrival.journal = journal
journal.SQL = { INSERT = INSERT_SQL, PURGE = PURGE_SQL }

---@class vAvA.ArrivalLogEntry
---@field characterId integer
---@field accountId? integer
---@field actorAccountId? integer  membre du Conseil ; nil : le serveur ou la console
---@field details? table

--- Note une action. N'attend pas la base.
---@param kind string  kit_given | kit_withheld | kit_uncertain | admin_regive | admin_replay
---@param entry vAvA.ArrivalLogEntry
function journal.write(kind, entry)
    local details = nil
    if type(entry.details) == 'table' then
        local ok, encoded = pcall(encodeJson, entry.details)
        details = ok and encoded or nil
    end
    local at = bridge.Now()
    CreateThread(function()
        local _, err = bridge.db.insert(INSERT_SQL, { at, kind, entry.characterId, entry.accountId, entry.actorAccountId, details })
        if err then VavaArrival.log.error("journal '%s' non écrit : %s", kind, tostring(err)) end
    end)
end

--- Supprime les entrées plus vieilles que la rétention. Appelé pendant le setup du module (bloque le thread).
function journal.purge()
    local days = cfg.logRetentionDays
    if type(days) ~= 'number' or days <= 0 then return end
    local removed, err = bridge.db.update(PURGE_SQL, { bridge.Now() - days * 86400 })
    if err then
        VavaArrival.log.warn('purge du journal en échec : %s', tostring(err))
    elseif removed and removed > 0 then
        VavaArrival.log.info('journal : %d entrée(s) de plus de %d jours supprimée(s)', removed, days)
    end
end
