--[[
    vava_needs/server/state.lua
    Rôle : valeurs des besoins d'un personnage, rangées dans un champ du core (sauvegardé avec le personnage, envoyé
           à son seul joueur). Écriture bornée et arrondie ; rien n'est écrit ni envoyé quand rien ne change ; chaque
           changement déclenche le hook vava_needs:changed.
    Dépendances : shared/constants.lua, config_client.lua, config.lua, server/core.lua
]]

local type, ipairs, pairs = type, ipairs, pairs
local floor = math.floor

local cfg = VavaNeeds.config
local MAX = VavaNeeds.MAX
local FIELD = VavaNeeds.FIELD
local HOOK_CHANGED = VavaNeeds.HOOKS.CHANGED
-- deux décimales : la baisse d'une minute reste visible, sans bruit de flottants dans la sauvegarde
local PRECISION = 100

local state = {}
VavaNeeds.state = state

---@type string[]
local names = {}
---@type table<string, table>
local known = {}
for i, need in ipairs(cfg.needs) do
    names[i] = need.name
    known[need.name] = need
end
state.names = names
state.known = known

---@param value number
---@return number
local function clamp(value)
    if value < 0 then return 0 end
    if value > MAX then return MAX end
    return value
end

---@param value number
---@return number
local function round(value)
    return floor(value * PRECISION + 0.5) / PRECISION
end

--- Définit le champ de personnage. Appelé pendant le setup du module.
---@return boolean ok
---@return string|nil err
function state.define()
    local fields, default = {}, {}
    for _, name in ipairs(names) do
        -- facultatif : un besoin ajouté à la configuration manque dans les sauvegardes existantes
        fields[name] = { type = 'number', min = 0, max = MAX, optional = true }
        default[name] = cfg.initial
    end
    return VavaNeeds.core.characters.defineField(FIELD, {
        schema = { type = 'table', fields = fields },
        default = default,
        visibility = 'owner',
    })
end

--- Valeurs d'un personnage chargé : table neuve et complète (un besoin absent vaut la valeur initiale).
---@param characterId integer
---@return table<string, number>
function state.read(characterId)
    local stored = VavaNeeds.core.characters.get(characterId, FIELD)
    local values = {}
    for _, name in ipairs(names) do
        local value = type(stored) == 'table' and stored[name]
        values[name] = type(value) == 'number' and clamp(value) or cfg.initial
    end
    return values
end

---@class vAvA.NeedsChange
---@field source integer
---@field characterId integer
---@field values table<string, number>    nouvelles valeurs
---@field previous table<string, number>  valeurs avant le changement
---@field reason string                    decay, consume ou api
---@field resource? string                 module à l'origine d'un appel d'API

--- Écrit de nouvelles valeurs (bornées, arrondies) à partir des précédentes.
---@param src integer
---@param characterId integer
---@param previous table<string, number>
---@param values table<string, number>  valeurs souhaitées, un besoin absent garde sa valeur
---@param reason string
---@param resource? string
---@return table<string, number>|nil written  valeurs en place après l'écriture
---@return string|nil err
function state.write(src, characterId, previous, values, reason, resource)
    local written, changed = {}, false
    for _, name in ipairs(names) do
        local value = values[name]
        written[name] = type(value) == 'number' and round(clamp(value)) or previous[name]
        if written[name] ~= previous[name] then changed = true end
    end
    if not changed then return previous end
    local core = VavaNeeds.core
    local ok, err = core.characters.set(characterId, FIELD, written)
    if not ok then return nil, err end
    core.hooks.runAfter(HOOK_CHANGED, {
        source = src, characterId = characterId, values = written, previous = previous, reason = reason, resource = resource,
    })
    return written
end

--- Ajoute des écarts aux valeurs actuelles.
---@param src integer
---@param characterId integer
---@param deltas table<string, number>
---@param reason string
---@param resource? string
---@return table<string, number>|nil written
---@return string|nil err
function state.add(src, characterId, deltas, reason, resource)
    local previous = state.read(characterId)
    local values = {}
    for name, delta in pairs(deltas) do
        if known[name] then values[name] = previous[name] + delta end
    end
    return state.write(src, characterId, previous, values, reason, resource)
end
