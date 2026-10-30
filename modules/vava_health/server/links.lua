--[[
    vava_health/server/links.lua
    Rôle : liens avec les autres modules, tous par leurs hooks (aucun n'est requis) :
      - vava_inventory : à terre, aucun geste sur les objets (prise en main comprise) ; objets de soin
        (`effects = { health = 20 }` : +20 % de la vie), refusés si le joueur n'est pas blessé ; à la chute,
        l'inventaire ouvert (grenier, coffre, fouille, sac) se ferme (export `close`, inventaire 1.6.4, appel isolé) ;
      - vava_needs : pas de baisse de la faim et de la soif à terre.
    Dépendances : shared/constants.lua, config.lua, server/core.lua, server/life.lua
]]

local type, pairs, ipairs, pcall, tostring = type, pairs, ipairs, pcall, tostring
local GetResourceState = GetResourceState

local life = VavaHealth.life
local cfg = VavaHealth.config
local messages = cfg.messages
local EFFECT = VavaHealth.EFFECT
-- avant les autres abonnés : un joueur à terre est refusé d'emblée
local GUARD_PRIORITY = 10
local INVENTORY = 'vava_inventory'

local links = {}
VavaHealth.links = links

---@param payload table
local function guard(payload)
    local entry = life.entry(payload.source)
    if entry and entry.downed then return false, messages.downed_inventory end
end

--- Prendre en main ou reposer : refusé à terre quand c'est un geste du joueur ; un module (désarmement, outil brisé)
--- garde la main.
---@param payload table  { source, instanceId, item?, previous, owner? }
local function guardHold(payload)
    if payload.owner == nil then return guard(payload) end
end

--- Effet de soin d'un objet (part de la vie) et vrai s'il a d'autres effets (lus par d'autres modules).
---@param effects any
---@return number|nil heal
---@return boolean foreign
local function healOf(effects)
    if type(effects) ~= 'table' or type(effects[EFFECT]) ~= 'number' then return nil, false end
    local foreign = false
    for name in pairs(effects) do
        if name ~= EFFECT then foreign = true end
    end
    return effects[EFFECT] / 100, foreign
end

local function beforeUse(payload)
    local heal, foreign = healOf(payload.effects)
    if not heal or heal <= 0 or foreign then return end
    local entry = life.entry(payload.source)
    if entry and not entry.downed and life.currentHealth(payload.source, entry) >= cfg.healing.fullAt then
        return false, messages.not_injured
    end
end

local function afterUse(payload)
    if not payload.consumed then return end
    local heal = healOf(payload.effects)
    if heal and heal ~= 0 then life.adjust(payload.source, heal) end
end

local function beforeDecay(payload)
    local entry = life.entry(payload.source)
    if entry and entry.downed then return false, 'downed' end
end

--- Appel isolé à un export de l'inventaire (facultatif). Renvoie vrai si l'appel a abouti, puis son résultat.
---@return boolean called
---@return any result
local function inventory(fn, ...)
    if GetResourceState(INVENTORY) ~= 'started' then return false end
    local called, result = pcall(function(...) return exports[INVENTORY][fn](exports[INVENTORY], ...) end, ...)
    if not called then
        VavaHealth.log.warn('%s.%s en erreur : %s', INVENTORY, fn, tostring(result))
        return false
    end
    return true, result
end

--- À la chute, l'inventaire ouvert se ferme (grenier, coffre, fouille, sac) : à terre, on ne consulte plus rien.
---@param payload table  { source, … }
local function afterDowned(payload)
    inventory('close', payload.source)
end

--- Branche les hooks. Appelé pendant le setup du module.
---@return boolean ok
---@return string|nil err
function links.start()
    local hooks = VavaHealth.core.hooks
    for _, name in ipairs(VavaHealth.INVENTORY_HOOKS) do
        local id, err = hooks.before(name, guard, GUARD_PRIORITY)
        if not id then return false, err end
    end
    for _, def in ipairs({
        { 'before', VavaHealth.INVENTORY_HOLD, guardHold, GUARD_PRIORITY },
        { 'before', VavaHealth.INVENTORY_USE, beforeUse },
        { 'after', VavaHealth.INVENTORY_USE, afterUse },
        { 'before', VavaHealth.NEEDS_DECAY, beforeDecay },
        { 'after', VavaHealth.HOOKS.DOWNED, afterDowned },
    }) do
        local id, err = hooks[def[1]](def[2], def[3], def[4])
        if not id then return false, err end
    end
    return true
end
