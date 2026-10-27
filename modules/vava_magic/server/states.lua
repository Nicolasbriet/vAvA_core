--[[
    vava_magic/server/states.lua
    Rôle : états élémentaires des joueurs, décidés par le serveur : Brûlure (dégâts sur la durée), Mouillé, Ralenti (le
           plus fort l'emporte, jamais cumulé), Chancelant, Renversé, Gelé. Chaque état a sa fin, tenue ici ; le state
           bag du ped les montre aux joueurs proches (flammes, gouttes, givre, poussière) et au joueur lui-même, qui
           reçoit aussi leurs durées (icônes de son écran) et applique ce qui touche à son ped (allure, chute).
      - Contrôles durs (Chancelant, Renversé, Gelé) : impossible d'incanter, une incantation en cours se brise. Dès
        qu'un contrôle dur touche, la cible est protégée des autres jusqu'à `hardImmunityMs` après sa fin (règle
        d'équité : aucun enchaînement) ; les dégâts, eux, s'appliquent toujours.
      - Gelé : le ped est aussi figé par le serveur.
      - Hook `vava_magic:stateApplying` (before) : un autre module peut refuser un état (résistance, objet…).
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua, server/world.lua, server/combat.lua
]]

local pairs, ipairs, type, max = pairs, ipairs, type, math.max
local GetGameTimer, SetTimeout, TriggerClientEvent = GetGameTimer, SetTimeout, TriggerClientEvent

local core = VavaMagic.core
local bridge = VavaMagic.bridge
local world = VavaMagic.world
local combat = VavaMagic.combat
local cfg = VavaMagic.config.states
local STATES = VavaMagic.STATES
local EVENTS = VavaMagic.EVENTS
local HOOKS = VavaMagic.HOOKS
local NAMES = VavaMagic.CONDITION_NAMES
local HARD = cfg.hard
-- code de refus d'une incantation pendant un contrôle dur
local BLOCKS = { stagger = 'staggered', knockdown = 'knocked', frozen = 'frozen' }

local states = {}
VavaMagic.states = states

---@class vAvA.MagicCondition
---@field untilMs integer
---@field token integer
---@field strength number|nil    Ralenti : part de l'allure retirée
---@field burn table|nil         Brûlure : { tickMs, damage, caster, casterCharacter, spell }

---@type table<integer, { conditions: table<string, vAvA.MagicCondition>, immuneUntil: integer, token: integer }>
local players = {}

---@param src integer
---@return table
local function entryOf(src)
    local entry = players[src]
    if not entry then
        entry = { conditions = {}, immuneUntil = 0, token = 0 }
        players[src] = entry
    end
    return entry
end

---@param entry table
---@return boolean
local function hardActive(entry)
    for name in pairs(HARD) do
        if entry.conditions[name] then return true end
    end
    return false
end

--- État visible (state bag du ped) et durées pour le joueur lui-même.
---@param src integer
local function publish(src)
    local entry = players[src]
    local now = GetGameTimer()
    local view, timers, any = {}, {}, false
    if entry then
        for name, condition in pairs(entry.conditions) do
            any = true
            view[name] = name == 'slow' and condition.strength or true
            timers[#timers + 1] = { name = name, ms = max(0, condition.untilMs - now), strength = condition.strength }
        end
        if now < entry.immuneUntil and not hardActive(entry) then
            any = true
            view.immune = true
            timers[#timers + 1] = { name = 'immune', ms = entry.immuneUntil - now }
        end
    end
    world.setState(src, STATES.CONDITIONS, any and view or nil)
    TriggerClientEvent(EVENTS.CONDITIONS, src, timers)
    if entry and not any then players[src] = nil end
end

--- Fin d'un état (à expiration, ou retiré par une combinaison).
---@param src integer
---@param name string
local function finish(src, name)
    local entry = players[src]
    local condition = entry and entry.conditions[name]
    if not condition then return end
    entry.conditions[name] = nil
    if name == 'frozen' then world.freeze(src, false) end
    -- fin du dernier contrôle dur : la protection se montre, puis s'efface d'elle-même
    if HARD[name] and not hardActive(entry) and entry.immuneUntil > GetGameTimer() then
        local token = entry.token
        SetTimeout(entry.immuneUntil - GetGameTimer(), function()
            if players[src] and players[src].token == token then publish(src) end
        end)
    end
    publish(src)
end

--- Morsures d'une brûlure tant qu'elle dure ; la dernière l'éteint (une brûlure ravivée relance ses morsures).
---@param src integer
---@param condition vAvA.MagicCondition
local function burnTicks(src, condition)
    local burn = condition.burn
    local function tick()
        SetTimeout(burn.tickMs, function()
            local entry = players[src]
            if not entry or entry.conditions.burn ~= condition then return end
            if burn.damage > 0 then combat.damage(burn.caster, src, burn.spell, burn.damage, combat.KIND.BURN, burn.casterCharacter) end
            if GetGameTimer() + burn.tickMs <= condition.untilMs then tick() else finish(src, 'burn') end
        end)
    end
    tick()
end

--- Pose un état sur un joueur en jeu. `opts` : durationMs, strength (Ralenti, 0 à 1), caster, spell, et pour la
--- Brûlure tickMs et damage (points de vie par morsure). Renvoie true, ou false et la raison (immune, refused…).
---@param src integer
---@param name string
---@param opts? table
---@return boolean ok
---@return string|nil reason
function states.apply(src, name, opts)
    opts = opts or {}
    if not NAMES[name] then return false, 'unknown_state' end
    if not bridge.GetCharacterId(src) then return false, 'no_target' end
    local entry = entryOf(src)
    local now = GetGameTimer()
    if HARD[name] and now < entry.immuneUntil then return false, 'immune' end
    local duration = opts.durationMs or cfg.durations[name]
    local allowed, reason = core.hooks.runBefore(HOOKS.STATE, {
        source = src, state = name, durationMs = duration, caster = opts.caster, spell = opts.spell,
    })
    if not allowed then return false, type(reason) == 'string' and reason or 'refused' end

    local current = entry.conditions[name]
    local untilMs = now + duration
    if name == 'slow' then
        -- jamais cumulé : le plus fort l'emporte ; un plus faible ne change rien tant que le plus fort dure
        local strength = opts.strength or 0
        if current and current.strength > strength then return true end
        if current and current.strength == strength then untilMs = max(untilMs, current.untilMs) end
    elseif current then
        untilMs = max(untilMs, current.untilMs)
    end
    entry.token = entry.token + 1
    local condition = { untilMs = untilMs, token = entry.token, strength = name == 'slow' and opts.strength or nil }
    if name == 'burn' then
        condition.burn = {
            tickMs = opts.tickMs or 1000, damage = opts.damage or 0, caster = opts.caster or 0,
            casterCharacter = opts.caster and bridge.GetCharacterId(opts.caster) or 0, spell = opts.spell or '',
        }
    end
    entry.conditions[name] = condition
    if HARD[name] then
        entry.immuneUntil = untilMs + cfg.hardImmunityMs
        local cast = VavaMagic.casting.current(src)
        if cast and not cast.finishing then VavaMagic.casting.abort(src, BLOCKS[name], true) end
    end
    if name == 'frozen' then world.freeze(src, true) end
    if name == 'burn' then
        burnTicks(src, condition)
    else
        SetTimeout(untilMs - now, function()
            local live = players[src]
            if live and live.conditions[name] == condition then finish(src, name) end
        end)
    end
    publish(src)
    return true
end

--- Retire un état (eau sur une brûlure, feu sur un joueur mouillé…). Renvoie vrai s'il était posé.
---@param src integer
---@param name string
---@return boolean
function states.remove(src, name)
    local entry = players[src]
    if not entry or not entry.conditions[name] then return false end
    finish(src, name)
    return true
end

---@param src integer
---@param name string
---@return boolean
function states.has(src, name)
    local entry = players[src]
    return entry ~= nil and entry.conditions[name] ~= nil
end

--- Force du Ralenti en cours (0 sans).
---@param src integer
---@return number
function states.slowStrength(src)
    local entry = players[src]
    local condition = entry and entry.conditions.slow
    return condition and condition.strength or 0
end

---@param src integer
---@return boolean
function states.immune(src)
    local entry = players[src]
    return entry ~= nil and GetGameTimer() < entry.immuneUntil
end

--- Départ du joueur, ou arrêt du module : tout est retiré, le ped libéré.
---@param src integer
function states.clear(src)
    local entry = players[src]
    if not entry then return end
    if entry.conditions.frozen then world.freeze(src, false) end
    players[src] = nil
    world.setState(src, STATES.CONDITIONS, nil)
end

function states.clearAll()
    for src in pairs(players) do states.clear(src) end
end

--- Empêchement d'incanter pendant un contrôle dur. Appelé pendant le setup du module.
function states.start()
    VavaMagic.casting.addBlocker(function(src)
        local entry = players[src]
        if not entry then return nil end
        for _, name in ipairs(cfg.order) do
            if BLOCKS[name] and entry.conditions[name] then return BLOCKS[name] end
        end
        return nil
    end)
end

