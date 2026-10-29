--[[
    vava_time/server/clock.lua
    Rôle : heure du royaume tenue par le serveur : décalage sur l'heure de Paris et gel, actions du Conseil (mettre
           l'heure, décaler, figer, reprendre, revenir à l'heure réelle), publication par GlobalState au seul changement
           (les clients font avancer leur horloge eux-mêmes au rythme réel).
    Dépendances : shared/, config.lua, server/core.lua
]]

local floor = math.floor
local GlobalState = GlobalState

local calendar = VavaTime.calendar
local DAY = VavaTime.DAY_SECONDS
local KEY = VavaTime.STATE.CLOCK
local MAX_SHIFT = VavaTime.config.clock.maxShiftMinutes * 60

local clock = {}
VavaTime.clock = clock

---@type vAvA.TimeClockState
local state = { shift = 0, frozen = false }

---@param shift integer
---@return boolean
local function withinBounds(shift)
    return shift >= -MAX_SHIFT and shift <= MAX_SHIFT
end

--- Reprend l'état gardé en base (un décalage hors des bornes de la config est oublié).
---@param row vAvA.TimeRow
function clock.load(row)
    state.shift = withinBounds(row.shift) and row.shift or 0
    state.frozen = (row.frozen and row.frozen >= 0 and row.frozen < DAY) and row.frozen or false
end

--- Copie de l'état : { shift, frozen }.
---@return vAvA.TimeClockState
function clock.state()
    return { shift = state.shift, frozen = state.frozen }
end

--- Seconde du jour de l'heure du royaume.
---@param now integer secondes UTC
---@return number
function clock.seconds(now)
    return calendar.clock(now, state)
end

--- Publie l'état à tous les joueurs (petit, rare : au démarrage et à chaque décision du Conseil).
function clock.publish()
    GlobalState[KEY] = { shift = state.shift, frozen = state.frozen } -- audit: ok (heure du royaume : petite, rare, utile à tous)
end

--- Applique une action du Conseil. `value` en secondes : `set` seconde du jour voulue, `shift` décalage à ajouter.
---@param action string set | shift | freeze | resume | real
---@param value integer
---@param now integer
---@return boolean ok
---@return boolean|string changed  ou code d'erreur
function clock.apply(action, value, now)
    if action == 'set' then
        if state.frozen then
            if state.frozen == value then return true, false end
            state.frozen = value
            return true, true
        end
        local shift = calendar.shiftFor(now, value)
        if not withinBounds(shift) then return false, 'invalid_value' end
        local changed = shift ~= state.shift
        state.shift = shift
        return true, changed
    elseif action == 'shift' then
        if state.frozen then
            state.frozen = (state.frozen + value) % DAY
            return true, true
        end
        local shift = floor(calendar.normalizeShift(state.shift + value))
        if not withinBounds(shift) then return false, 'invalid_value' end
        local changed = shift ~= state.shift
        state.shift = shift
        return true, changed
    elseif action == 'freeze' then
        if state.frozen then return true, false end
        state.frozen = floor(calendar.clock(now, state))
        return true, true
    elseif action == 'resume' then
        if not state.frozen then return true, false end
        local shift = calendar.shiftFor(now, state.frozen)
        if not withinBounds(shift) then return false, 'invalid_value' end
        state.shift, state.frozen = shift, false
        return true, true
    elseif action == 'real' then
        if state.shift == 0 and not state.frozen then return true, false end
        state.shift, state.frozen = 0, false
        return true, true
    end
    return false, 'invalid_value'
end
