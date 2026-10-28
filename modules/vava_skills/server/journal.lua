--[[
    vava_skills/server/journal.lua
    Rôle : journal des actions sensibles (table vava_skills_log) : leçons, mentorats, fondateurs, corrections du
           Conseil, rouille, savoirs appris, Arcanes refusées. Écriture hors du thread appelant (une action de jeu
           n'attend jamais la base), purge au démarrage au-delà de la rétention.
    Dépendances : config.lua, server/core.lua, bridge/server.lua
]]

local type, pcall, tostring = type, pcall, tostring
local encodeJson = json.encode
local CreateThread = CreateThread
local time = os.time

local bridge = VavaSkills.bridge
local cfg = VavaSkills.config

local INSERT_SQL = 'INSERT INTO `vava_skills_log` (`at`, `kind`, `actor_id`, `account_id`, `target_id`, `skill`, `recipe`, `details`) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
local PURGE_SQL = 'DELETE FROM `vava_skills_log` WHERE `at` < ?'

local journal = {}
VavaSkills.journal = journal

---@class vAvA.SkillsLogEntry
---@field actorId? integer    personnage à l'origine (nil : console, système)
---@field accountId? integer  compte de l'acteur (membre du Conseil)
---@field targetId? integer
---@field skill? string
---@field recipe? string
---@field details? table

--- Note une action. N'attend pas la base ; une écriture en échec est signalée dans la console.
---@param kind string
---@param entry vAvA.SkillsLogEntry
function journal.write(kind, entry)
    local details = nil
    if type(entry.details) == 'table' then
        local ok, encoded = pcall(encodeJson, entry.details)
        details = ok and encoded or nil
    end
    local at = time()
    CreateThread(function()
        local _, err = bridge.db.insert(INSERT_SQL, {
            at, kind, entry.actorId, entry.accountId, entry.targetId, entry.skill, entry.recipe, details,
        })
        if err then VavaSkills.log.error("journal '%s' non écrit : %s", kind, tostring(err)) end
    end)
end

--- Supprime les entrées plus vieilles que la rétention. Appelé pendant le setup du module (bloque le thread).
function journal.purge()
    local days = cfg.logRetentionDays
    if type(days) ~= 'number' or days <= 0 then return end
    local removed, err = bridge.db.update(PURGE_SQL, { time() - days * 86400 })
    if err then
        VavaSkills.log.warn('purge du journal en échec : %s', tostring(err))
    elseif removed and removed > 0 then
        VavaSkills.log.info('journal : %d entrée(s) de plus de %d jours supprimée(s)', removed, days)
    end
end
