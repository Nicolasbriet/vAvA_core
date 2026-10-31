--[[
    vava_time/server/sky.lua
    Rôle : la météo tenue par le serveur. Cycle : chaque ciel dure une durée tirée de la config, puis un successeur est
           tiré selon les poids de la saison (règles pures de shared/cycle.lua) ; un ciel qui n'est plus de saison
           (neige au printemps) change aussitôt. Conseil : imposer un ciel (il dure sa durée, ou reste s'il est figé),
           figer le ciel, rendre la main au cycle. Publication par GlobalState au seul changement : ciel visé, ciel
           d'avant et début de la transition, que chaque client suit seul.
    Dépendances : shared/, config.lua, server/core.lua, server/store.lua
]]

local random = math.random
local GlobalState = GlobalState

local rules = VavaTime.weatherRules
local store = VavaTime.store
local wcfg = VavaTime.config.weather
local councilFade = VavaTime.config.council.fadeSeconds
local KEY = VavaTime.STATE.WEATHER
local HOOK = VavaTime.HOOKS.WEATHER

local sky = {}
VavaTime.sky = sky

---@class vAvA.SkyState
---@field id string        ciel visé
---@field from string      ciel d'avant la transition
---@field at integer       début de la transition (secondes UTC)
---@field fade integer     durée de la transition (s)
---@field forced boolean   imposé par le Conseil
---@field frozen boolean   figé par le Conseil
---@field untilAt integer  fin prévue par le cycle (secondes UTC)

---@type vAvA.SkyState
local state = nil
-- avertissement « aucun ciel de saison » donné une fois par saison
local warnedSeason = nil

--- Copie de l'état.
---@return vAvA.SkyState
function sky.state()
    return {
        id = state.id, from = state.from, at = state.at, fade = state.fade, forced = state.forced, frozen = state.frozen,
        untilAt = state.untilAt,
    }
end

function sky.publish()
    GlobalState[KEY] = { -- audit: ok (météo du royaume : petite, toutes les 25 à 50 min, utile à tous)
        id = state.id, from = state.from, at = state.at, fade = state.fade, forced = state.forced, frozen = state.frozen,
    }
end

--- Premier ciel d'une saison ; le premier de la config si la saison n'en a aucun.
---@param season string
---@return string
local function first(season)
    return rules.pick(nil, season, random) or wcfg.types[1].id
end

--- Reprend l'état gardé : un ciel connu, figé ou pas encore fini, continue tel quel (sans transition) ; sinon un ciel
--- de la saison est tiré.
---@param row vAvA.TimeRow
---@param now integer
---@param season string
function sky.load(row, now, season)
    local def = row.weather ~= '' and rules.get(row.weather)
    if def and (row.weatherFrozen or row.untilAt > now) then
        state = {
            id = def.id, from = def.id, at = now, fade = 0, forced = row.forced, frozen = row.weatherFrozen,
            untilAt = row.untilAt > now and row.untilAt or now + rules.duration(def.id, random),
        }
        return
    end
    local id = first(season)
    state = { id = id, from = id, at = now, fade = 0, forced = false, frozen = false, untilAt = now + rules.duration(id, random) }
end

--- Passe à un ciel (ou renouvelle le même) : publié, écrit, annoncé aux autres modules s'il change quelque chose.
---@param id string
---@param fade integer
---@param now integer
---@param forced boolean
---@param frozen boolean
---@param by string cycle | council | web
---@return boolean changed
local function change(id, fade, now, forced, frozen, by)
    local previous = state.id
    local same = id == previous and forced == state.forced and frozen == state.frozen
    state.untilAt = now + rules.duration(id, random)
    if same then
        -- le même ciel continue : seule sa fin prévue change, gardée pour un redémarrage
        store.save()
        return false
    end
    if id ~= previous then
        state.from, state.at, state.fade = previous, now, fade
    end
    state.id, state.forced, state.frozen = id, forced, frozen
    sky.publish()
    store.save()
    VavaTime.core.hooks.runAfter(HOOK, { weather = id, previous = previous, forced = forced, frozen = frozen, by = by })
    return true
end

--- Passage de la boucle lente : fin du ciel, ou ciel qui n'est plus de saison. Un ciel figé ne bouge pas ; un ciel
--- imposé reste jusqu'à sa fin, même hors saison.
---@param now integer
---@param season string
function sky.tick(now, season)
    if state.frozen then return end
    local expired = now >= state.untilAt
    local outOfSeason = not state.forced and not rules.allowed(state.id, season)
    if not expired and not outOfSeason then return end
    local id = rules.pick(state.id, season, random)
    if not id then
        if warnedSeason ~= season then
            warnedSeason = season
            VavaTime.log.warn('aucun ciel de la saison « %s » dans la config : le ciel reste tel quel', season)
        end
        state.untilAt = now + rules.duration(state.id, random)
        store.save()
        return
    end
    change(id, wcfg.fadeSeconds, now, false, false, 'cycle')
end

--- Le Conseil impose un ciel ; `hold` le fige.
---@param id string ciel connu
---@param hold boolean
---@param now integer
---@param by string
---@return boolean changed
function sky.impose(id, hold, now, by)
    return change(id, councilFade, now, true, hold, by)
end

--- Le Conseil fige le ciel actuel.
---@param now integer
---@param by string
---@return boolean changed
function sky.freeze(now, by)
    if state.frozen then return false end
    return change(state.id, 0, now, state.forced, true, by)
end

--- Le Conseil rend la main au cycle : le ciel suivant est tiré tout de suite (le même peut revenir).
---@param now integer
---@param season string
---@param by string
---@return boolean changed
function sky.release(now, season, by)
    local id = rules.pick(state.id, season, random) or state.id
    local changed = change(id, wcfg.fadeSeconds, now, false, false, by)
    return changed
end

--- Vue pour les interfaces du Conseil.
---@param now integer
---@param season string
---@return table
function sky.view(now, season)
    local def = rules.get(state.id)
    local from = rules.get(state.from)
    return {
        id = state.id, label = def and def.label or state.id,
        from = state.from, fromLabel = from and from.label or state.from,
        fading = rules.progress(state.at, state.fade, now) < 1,
        forced = state.forced, frozen = state.frozen,
        endsIn = state.frozen and -1 or (state.untilAt > now and state.untilAt - now or 0),
        inSeason = rules.allowed(state.id, season),
    }
end
