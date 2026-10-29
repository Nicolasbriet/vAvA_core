--[[
    vava_time/server/store.lua
    Rôle : état du Conseil gardé en base (une ligne) : lu une fois au démarrage, écrit après chaque action du Conseil
           et chaque changement de ciel. Une écriture à la fois : un changement pendant l'attente est écrit juste après,
           avec l'état le plus récent (rien n'est perdu, rien n'est écrit dans le désordre).
    Dépendances : shared/constants.lua, server/core.lua, bridge/server.lua ; server/clock.lua et server/sky.lua (lus à
                  l'écriture)
]]

local tostring, type = tostring, type
local time = os.time
local CreateThread = CreateThread

local bridge = VavaTime.bridge
local ROW = 1
-- `clock_frozen` quand l'heure court
local NOT_FROZEN = -1

local SELECT_SQL = 'SELECT `clock_shift`, `clock_frozen`, `weather`, `weather_until`, `weather_forced`, `weather_frozen` '
    .. 'FROM `vava_time_state` WHERE `id` = ?'
local UPSERT_SQL = 'INSERT INTO `vava_time_state` (`id`, `clock_shift`, `clock_frozen`, `weather`, `weather_until`, '
    .. '`weather_forced`, `weather_frozen`, `updated_at`) VALUES (?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE '
    .. '`clock_shift` = VALUES(`clock_shift`), `clock_frozen` = VALUES(`clock_frozen`), `weather` = VALUES(`weather`), '
    .. '`weather_until` = VALUES(`weather_until`), `weather_forced` = VALUES(`weather_forced`), '
    .. '`weather_frozen` = VALUES(`weather_frozen`), `updated_at` = VALUES(`updated_at`)'

local store = {}
VavaTime.store = store

---@class vAvA.TimeRow
---@field shift integer
---@field frozen integer|nil  nil : l'heure court
---@field weather string
---@field untilAt integer
---@field forced boolean
---@field weatherFrozen boolean

--- Lit l'état gardé (valeurs par défaut s'il n'y en a pas encore). Bloque le thread courant.
---@return vAvA.TimeRow|nil row
---@return string|nil err
function store.load()
    local row, err = bridge.db.single(SELECT_SQL, { ROW })
    if err then return nil, tostring(err) end
    if not row then return { shift = 0, frozen = nil, weather = '', untilAt = 0, forced = false, weatherFrozen = false } end
    local frozen = bridge.Integer(row.clock_frozen, NOT_FROZEN)
    return {
        shift = bridge.Integer(row.clock_shift, 0),
        frozen = frozen >= 0 and frozen or nil,
        weather = type(row.weather) == 'string' and row.weather or '',
        untilAt = bridge.Integer(row.weather_until, 0),
        forced = bridge.Integer(row.weather_forced, 0) == 1,
        weatherFrozen = bridge.Integer(row.weather_frozen, 0) == 1,
    }
end

--- Valeurs de l'état actuel, relevées juste avant l'écriture.
---@return table
local function values()
    local clock = VavaTime.clock.state()
    local sky = VavaTime.sky.state()
    return {
        ROW, clock.shift, clock.frozen or NOT_FROZEN, sky.id, sky.untilAt, sky.forced and 1 or 0, sky.frozen and 1 or 0, time(),
    }
end

local writing, pending = false, false

--- Écrit l'état actuel, dans son propre thread (l'appelant ne cède jamais la main).
function store.save()
    if writing then
        pending = true
        return
    end
    writing = true
    CreateThread(function()
        repeat
            pending = false
            local _, err = bridge.db.update(UPSERT_SQL, values())
            if err then VavaTime.log.warn('état du ciel et de l\'heure non écrit : %s', tostring(err)) end
        until not pending
        writing = false
    end)
end
