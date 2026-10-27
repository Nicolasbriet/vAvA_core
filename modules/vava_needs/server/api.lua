--[[
    vava_needs/server/api.lua
    Rôle : exports serveur pour les autres modules (médecin, prison, maladie, auberge…). Cible : un joueur (son
           personnage actif). Valeurs de 0 à 100, bornées à l'écriture.
    Dépendances : shared/constants.lua, server/core.lua, server/state.lua, server/decay.lua
]]

local type, pairs = type, pairs
local mathType, huge = math.type, math.huge
local GetInvokingResource = GetInvokingResource

local state = VavaNeeds.state
local decay = VavaNeeds.decay
local known = state.known

-- bornes d'un multiplicateur de vitesse de baisse (0 = besoin figé)
local MAX_MULTIPLIER = 10
local KEY_PATTERN = '^[%w_%-%.:]+$'
local MAX_KEY_LENGTH = 64

---@param src any
---@return vAvA.NeedsEntry|nil
---@return string|nil code
local function resolve(src)
    if not VavaNeeds.ready then return nil, 'not_ready' end
    if mathType(src) ~= 'integer' then return nil, 'invalid_target' end
    local entry = decay.entry(src)
    if not entry then return nil, 'no_character' end
    return entry
end

--- Table { besoin = nombre } non vide, besoins connus, nombres finis dans [low, high].
---@param values any
---@param low number
---@param high number
---@return boolean
local function validNumbers(values, low, high)
    if type(values) ~= 'table' then return false end
    local count = 0
    for name, value in pairs(values) do
        if not known[name] or type(value) ~= 'number' or value ~= value or value == huge or value == -huge then return false end
        if value < low or value > high then return false end
        count = count + 1
    end
    return count > 0
end

---@return string
local function caller()
    return GetInvokingResource() or VavaNeeds.resource
end

--- Valeurs actuelles : { hunger = 72.5, thirst = 60.25 }.
exports('get', function(src)
    local entry, code = resolve(src)
    if not entry then return nil, code end
    return state.read(entry.characterId)
end)

--- Fixe des valeurs (un besoin absent est inchangé).
exports('set', function(src, values)
    local entry, code = resolve(src)
    if not entry then return false, code end
    if not validNumbers(values, 0, VavaNeeds.MAX) then return false, 'invalid_values' end
    local written, err = state.write(src, entry.characterId, state.read(entry.characterId), values, 'api', caller())
    if not written then return false, err end
    return true, written
end)

--- Ajoute (ou retire, écart négatif) aux valeurs actuelles.
exports('add', function(src, deltas)
    local entry, code = resolve(src)
    if not entry then return false, code end
    if not validNumbers(deltas, -VavaNeeds.MAX, VavaNeeds.MAX) then return false, 'invalid_values' end
    local written, err = state.add(src, entry.characterId, deltas, 'api', caller())
    if not written then return false, err end
    return true, written
end)

--- Modificateur de vitesse de baisse, propre au personnage actif (retiré à son déchargement et à l'arrêt du
--- module qui l'a posé). Les modificateurs se multiplient : { hunger = 2 } double la faim, { thirst = 0 } la fige.
exports('setModifier', function(src, key, multipliers)
    local entry, code = resolve(src)
    if not entry then return false, code end
    if type(key) ~= 'string' or #key > MAX_KEY_LENGTH or not key:find(KEY_PATTERN) then return false, 'invalid_key' end
    if not validNumbers(multipliers, 0, MAX_MULTIPLIER) then return false, 'invalid_values' end
    local copy = {}
    for name, value in pairs(multipliers) do copy[name] = value end
    return decay.setModifier(entry, key, caller(), copy)
end)

exports('removeModifier', function(src, key)
    local entry, code = resolve(src)
    if not entry then return false, code end
    if type(key) ~= 'string' then return false, 'invalid_key' end
    return decay.removeModifier(entry, key, caller())
end)
