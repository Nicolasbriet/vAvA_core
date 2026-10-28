--[[
    vava_skills/server/shortages.lua
    Rôle : métiers en pénurie. Compte, par compétence, les personnages actifs (joués depuis `activeDays` jours) qui
           atteignent le rang `minRank` ; une compétence sous `minPlayers` reçoit un multiplicateur d'XP — sauf si le
           royaume compte moins de `minActivePlayers` personnages actifs (au lancement, tout serait en pénurie). Calculé
           au démarrage puis toutes les `refreshMs` (boucle lente), exposé au livre des compétences et au panneau
           d'affichage en jeu.
    Dépendances : config.lua, server/core.lua, bridge/server.lua, server/registries.lua, shared/progression.lua
]]

local ipairs, tostring = ipairs, tostring
local CreateThread, Wait = CreateThread, Wait
local time = os.time

local bridge = VavaSkills.bridge
local registries = VavaSkills.registries
local progression = VavaSkills.progression
local cfg = VavaSkills.config.shortages

local COUNT_SQL = 'SELECT s.`skill`, COUNT(*) AS `n` FROM `vava_skills_skills` s '
    .. 'JOIN `vava_characters` c ON c.`id` = s.`character_id` '
    .. 'WHERE s.`level` >= ? AND c.`deleted_at` IS NULL AND c.`last_played_at` >= FROM_UNIXTIME(?) GROUP BY s.`skill`'
local ACTIVE_SQL = 'SELECT COUNT(*) FROM `vava_characters` WHERE `deleted_at` IS NULL AND `last_played_at` >= FROM_UNIXTIME(?)'

local shortages = {}
VavaSkills.shortages = shortages

-- compétence → nombre de personnages actifs au rang requis
local counts = {}
-- personnages actifs dans le royaume, toutes compétences confondues
local activeCharacters = 0
local refreshedAt = 0

--- Recompte. Bloque le thread courant.
---@return boolean ok
function shortages.refresh()
    local rank = progression.rank(cfg.minRank)
    local minLevel = rank and rank.min or 0
    local since = time() - cfg.activeDays * 86400
    local active, activeErr = bridge.db.scalar(ACTIVE_SQL, { since })
    if activeErr then
        VavaSkills.log.warn('pénurie : comptage des personnages actifs en échec : %s', tostring(activeErr))
        return false
    end
    local rows, err = bridge.db.query(COUNT_SQL, { minLevel, since })
    if err then
        VavaSkills.log.warn('pénurie : comptage en échec : %s', tostring(err))
        return false
    end
    local fresh = {}
    for _, row in ipairs(rows) do fresh[row.skill] = bridge.Integer(row.n, 0) end
    counts = fresh
    activeCharacters = bridge.Integer(active, 0)
    refreshedAt = time()
    return true
end

--- Personnages actifs dans le royaume au dernier recompte.
---@return integer
function shortages.activeCharacters()
    return activeCharacters
end

---@param skill string
---@return integer
function shortages.count(skill)
    return counts[skill] or 0
end

--- Multiplicateur d'XP d'une compétence en pénurie, nil sinon (jamais sous `minActivePlayers` personnages actifs).
---@param skill string
---@return number|nil
function shortages.multiplier(skill)
    if activeCharacters < cfg.minActivePlayers then return nil end
    if shortages.count(skill) < cfg.minPlayers then return cfg.multiplier end
    return nil
end

--- Métiers en pénurie, dans l'ordre d'affichage : { skill, label, count, multiplier }.
---@return table[]
function shortages.list()
    local list = {}
    for _, def in ipairs(registries.skills()) do
        local multiplier = shortages.multiplier(def.id)
        if multiplier then
            list[#list + 1] = { skill = def.id, label = def.label, count = shortages.count(def.id), multiplier = multiplier }
        end
    end
    return list
end

---@return integer
function shortages.refreshedAt()
    return refreshedAt
end

--- Premier comptage puis recomptes réguliers. Appelé pendant le setup du module (le premier comptage bloque).
function shortages.start()
    shortages.refresh()
    CreateThread(function()
        -- boucle lente justifiée : une requête groupée toutes les refreshMs (30 min par défaut)
        while true do
            Wait(cfg.refreshMs)
            shortages.refresh()
        end
    end)
end
