--[[
    vava_health/server/modifiers.lua
    Rôle : registre vava_health:modifiers (spec T-110 § 5.2). Défini au démarrage du module ; les autres modules y
           déclarent leurs modificateurs (au plus un par étape et par module, chacun lit ses propres données : un
           second à la même étape est retiré aussitôt). Contrôle du propriétaire : une clé dont le préfixe n'est pas la
           ressource qui l'a ajoutée est retirée aussitôt (comme vava_atelier:editors). Cache trié tenu par les hooks du registre : reconstruit (copie, jamais en place) à
           chaque ajout ou retrait ; un coup en cours garde la liste qu'il a prise.
    Dépendances : shared/constants.lua, config.lua, shared/chain.lua, server/core.lua
]]

local type, ipairs, pairs, tostring = type, ipairs, pairs, tostring
local match = string.match

local chain = VavaHealth.chain
local cfg = VavaHealth.config.chain
local REGISTRY = VavaHealth.MODIFIERS

local modifiers = {}
VavaHealth.modifiers = modifiers

local KINDS = {}
for _, kind in ipairs(cfg.kinds) do KINDS[kind] = true end

---@class vAvA.HealthModifier
---@field key string
---@field owner string
---@field stage string
---@field priority integer
---@field label string
---@field kinds table<string, true>|nil   ensemble des types (absent : tous)
---@field kindList string[]|nil
---@field apply any                       fonction (référence d'une autre ressource)

---@type table<string, vAvA.HealthModifier>
local loaded = {}
---@type vAvA.HealthModifier[]
local ordered = {}

local function rebuild()
    local list = {}
    for _, entry in pairs(loaded) do list[#list + 1] = entry end
    ordered = chain.sort(list)
end

--- Validateur du registre : clé, forme, types connus et sans doublon.
---@param key any
---@param data any
---@return boolean ok
---@return string|nil reason
local function validator(key, data)
    return chain.checkEntry(key, data, KINDS)
end

--- Définit le registre. Appelé pendant le setup du module.
---@return boolean ok
---@return string|nil err
function modifiers.define()
    loaded, ordered = {}, {}
    return VavaHealth.core.registry.define(REGISTRY, {
        schema = { type = 'table', fields = {
            stage = { type = 'string', enum = VavaHealth.STAGES },
            priority = { type = 'integer', min = 0, max = 99, optional = true },
            label = { type = 'string', min = 1, max = 48 },
            kinds = { type = 'array', min = 1, max = #cfg.kinds, items = { type = 'string', enum = cfg.kinds },
                optional = true },
            apply = { type = 'function' },
        } },
        validator = validator,
        maxEntries = cfg.maxModifiers,
    })
end

--- Hook `core:registry:added` d'une entrée du registre : propriétaire vérifié, puis cache.
---@param key string
---@param owner string
function modifiers.added(key, owner)
    local core = VavaHealth.core
    if match(key, '^([^:]+):') ~= owner then
        VavaHealth.log.warn("modificateur '%s' ajouté par '%s' : un module ne déclare que sous son nom, entrée retirée",
            key, tostring(owner))
        core.registry.remove(REGISTRY, key)
        return
    end
    local data = core.registry.get(REGISTRY, key)
    if type(data) ~= 'table' then return end
    -- un module, un modificateur par étape : il lit ses propres données, un second ne ferait que doubler l'effet
    for otherKey, other in pairs(loaded) do
        if other.owner == owner and other.stage == data.stage and otherKey ~= key then
            VavaHealth.log.warn("modificateur '%s' refusé : %s déclare déjà '%s' à l'étape %s (un par étape et par "
                .. 'module), entrée retirée', key, owner, otherKey, data.stage)
            core.registry.remove(REGISTRY, key)
            return
        end
    end
    local kindSet, kindList
    if type(data.kinds) == 'table' then
        kindSet, kindList = {}, {}
        for i, kind in ipairs(data.kinds) do
            kindSet[kind] = true
            kindList[i] = kind
        end
    end
    loaded[key] = {
        key = key, owner = owner, stage = data.stage, priority = data.priority or chain.DEFAULT_PRIORITY,
        label = data.label, kinds = kindSet, kindList = kindList, apply = data.apply,
    }
    rebuild()
    VavaHealth.log.info("modificateur '%s' (%s, étape %s) déclaré par %s", key, data.label, data.stage, owner)
end

--- Hook `core:registry:removed` (retrait, ou propriétaire arrêté) : oublié.
---@param key string
function modifiers.removed(key)
    if not loaded[key] then return end
    loaded[key] = nil
    rebuild()
end

--- Hook `core:registry:dropped` du registre (ce module s'arrête) : tout est oublié.
function modifiers.dropped()
    loaded, ordered = {}, {}
end

--- Liste triée courante (ne jamais la modifier : elle est remplacée, pas changée, à chaque ajout ou retrait).
---@return vAvA.HealthModifier[]
function modifiers.list()
    return ordered
end

--- Liste ordonnée sans les fonctions, pour l'export modifiers() : `{ { key, stage, priority, label, kinds? } }`.
---@return table[]
function modifiers.describe()
    local out = {}
    for i, entry in ipairs(ordered) do
        local kinds
        if entry.kindList then
            kinds = {}
            for j, kind in ipairs(entry.kindList) do kinds[j] = kind end
        end
        out[i] = { key = entry.key, stage = entry.stage, priority = entry.priority, label = entry.label, kinds = kinds }
    end
    return out
end

--- Branche les hooks du registre. Appelé pendant le setup du module, après define().
---@return boolean ok
---@return string|nil err
function modifiers.start()
    local hooks = VavaHealth.core.hooks
    for _, def in ipairs({
        { 'core:registry:added', function(payload)
            if payload.registry == REGISTRY then modifiers.added(payload.key, payload.owner) end
        end },
        { 'core:registry:removed', function(payload)
            if payload.registry == REGISTRY then modifiers.removed(payload.key) end
        end },
        { 'core:registry:dropped', function(payload)
            if payload.registry == REGISTRY then modifiers.dropped() end
        end },
    }) do
        local id, err = hooks.after(def[1], def[2])
        if not id then return false, err end
    end
    return true
end
