--[[
    vava_needs/server/consume.lua
    Rôle : manger et boire. Abonné au hook vava_inventory:use, qui transmet les effets déclarés par l'objet :
      before → refus si un geste est en cours, ou si tous les besoins que l'objet comble sont déjà pleins ;
      after  → objet consommé : effets appliqués, geste joué par le client (selon la catégorie de l'objet).
    L'inventaire reste facultatif : sans lui, ces hooks ne se déclenchent jamais.
    Dépendances : shared/constants.lua, config_client.lua, config.lua, server/core.lua, server/state.lua,
                  server/decay.lua
]]

local type, pairs, tostring = type, pairs, tostring
local GetGameTimer, TriggerClientEvent = GetGameTimer, TriggerClientEvent

local state = VavaNeeds.state
local decay = VavaNeeds.decay
local known = state.known
local rules = VavaNeeds.config.consumption
local CONSUME = VavaNeeds.EVENTS.CONSUME

local consume = {}
VavaNeeds.consume = consume

--- Effets de l'objet qui concernent les besoins, et vrai s'il en a d'autres (lus par d'autres modules).
---@param effects any
---@return table<string, number>|nil needs
---@return boolean foreign
local function needEffects(effects)
    if type(effects) ~= 'table' then return nil, false end
    local found, foreign = nil, false
    for name, value in pairs(effects) do
        if known[name] and type(value) == 'number' then
            found = found or {}
            found[name] = value
        else
            foreign = true
        end
    end
    return found, foreign
end

---@param payload table  { source, item, category, effects }
---@return boolean|nil allowed
---@return string|nil reason
local function before(payload)
    local effects, foreign = needEffects(payload.effects)
    if not effects then return end
    local entry = decay.entry(payload.source)
    if not entry then return end
    if GetGameTimer() < entry.busyUntil then return false, rules.busyMessage end
    -- l'objet sert aussi à autre chose (soin, ivresse…) : jamais refusé pour cause de satiété
    if foreign then return end

    local values = state.read(entry.characterId)
    local full, gains = nil, 0
    for name, value in pairs(effects) do
        if value > 0 then
            gains = gains + 1
            if values[name] < rules.fullAt then return end   -- au moins un besoin en profite
            full = name
        end
    end
    if gains == 0 then return end
    if gains == 1 then return false, known[full].messages.full end
    return false, rules.fullMessage
end

---@param payload table  { source, item, category, effects, consumed }
local function after(payload)
    if not payload.consumed then return end
    local effects = needEffects(payload.effects)
    if not effects then return end
    local src = payload.source
    local entry = decay.entry(src)
    if not entry then return end
    entry.busyUntil = GetGameTimer() + rules.cooldownMs
    local written, err = state.add(src, entry.characterId, effects, 'consume')
    if not written then
        VavaNeeds.log.warn("effets de '%s' non appliqués au personnage #%d : %s", tostring(payload.item), entry.characterId, tostring(err))
        return
    end
    local gesture = rules.gestureByCategory[payload.category or ''] or rules.defaultGesture
    TriggerClientEvent(CONSUME, src, gesture)
end

--- Branche les hooks de l'inventaire. Appelé pendant le setup du module.
---@return boolean ok
---@return string|nil err
function consume.start()
    local hooks = VavaNeeds.core.hooks
    local id, err = hooks.before(VavaNeeds.INVENTORY_USE, before)
    if not id then return false, err end
    id, err = hooks.after(VavaNeeds.INVENTORY_USE, after)
    if not id then return false, err end
    return true
end
