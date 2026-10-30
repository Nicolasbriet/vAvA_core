--[[
    server/core/netsize.lua
    Rôle : estimation pure de la taille msgpack d'une liste d'arguments (repli de core.net quand le runtime n'offre pas
           la sérialisation à part, ou mode forcé par la config). Parcours des valeurs sans rien sérialiser, arrêté dès
           que la limite est dépassée.
    Règles (msgpack) : nil et booléens 1 ; entiers 1, 2, 3, 5 ou 9 selon leur grandeur ; flottants 9 (majorant :
           float64) ; chaînes 1, 2, 3 ou 5 + longueur ; tables : en-tête 1 (jusqu'à 15 éléments), 3 (65 535), 5 au-delà,
           puis chaque élément (liste pure) ou chaque clé et valeur (table à clés) ; une table mixte ou à trous compte
           comme une table à clés, index compris (majorant : selon le sérialiseur, elle part en liste ou en table à
           clés) ; vecteurs 3 + 4 par composante.
           Refus : cycle, profondeur au-delà de 32, fonction ou autre type.
    Dépendances : shared/init.lua
]]

local type, next, select, rawlen, rawget = type, next, select, rawlen, rawget
local mathType = math.type

local netsize = {}
vAvA.netsize = netsize

local MAX_DEPTH = 32

-- Composantes des vecteurs du runtime FiveM (type() les nomme) : 3 octets d'en-tête d'extension + 4 par composante.
local VECTOR_BYTES = { vector2 = 11, vector3 = 15, vector4 = 19, quat = 19 }

---@param n integer  nombre d'éléments ou de paires
---@return integer
local function headerSize(n)
    if n <= 15 then return 1 end
    if n <= 0xFFFF then return 3 end
    return 5
end

---@param value integer
---@return integer
local function integerSize(value)
    if value >= 0 then
        if value <= 127 then return 1 end
        if value <= 0xFF then return 2 end
        if value <= 0xFFFF then return 3 end
        if value <= 0xFFFFFFFF then return 5 end
        return 9
    end
    if value >= -32 then return 1 end
    if value >= -128 then return 2 end
    if value >= -32768 then return 3 end
    if value >= -2147483648 then return 5 end
    return 9
end

---@param length integer
---@return integer
local function stringSize(length)
    if length <= 31 then return 1 + length end
    if length <= 0xFF then return 2 + length end
    if length <= 0xFFFF then return 3 + length end
    return 5 + length
end

-- Parcours : `state.total` grandit à chaque valeur ; `state.visiting` tient les tables du chemin en cours (cycle).
local measure

---@param state table
---@param value table
---@param depth integer
---@return boolean ok
---@return string|nil err
local function measureTable(state, value, depth)
    if depth > MAX_DEPTH then return false, 'depth' end
    local visiting = state.visiting
    if visiting[value] then return false, 'cycle' end
    visiting[value] = true
    local length = rawlen(value)
    if length > 0 then
        -- liste pure : exactement `length` paires ; sinon (clés nommées, trous) comptée comme une table à clés, la plus
        -- grosse des deux formes possibles (par prudence : l'estimation reste un majorant)
        local pairsCount = 0
        for _ in next, value do
            pairsCount = pairsCount + 1
            if pairsCount > length then break end
        end
        if pairsCount ~= length then length = 0 end
    end
    local ok, err
    if length > 0 then
        state.total = state.total + headerSize(length)
        for i = 1, length do
            ok, err = measure(state, rawget(value, i), depth)
            if not ok then
                visiting[value] = nil
                return false, err
            end
        end
    else
        local pairsCount = 0
        for key, item in next, value do
            pairsCount = pairsCount + 1
            ok, err = measure(state, key, depth)
            if ok then ok, err = measure(state, item, depth) end
            if not ok then
                visiting[value] = nil
                return false, err
            end
        end
        state.total = state.total + headerSize(pairsCount)
    end
    visiting[value] = nil
    if state.total > state.limit then return false, 'too_large' end
    return true
end

---@param state table
---@param value any
---@param depth integer  profondeur du conteneur de la valeur
---@return boolean ok
---@return string|nil err
measure = function(state, value, depth)
    local kind = type(value)
    local size
    if kind == 'nil' or kind == 'boolean' then
        size = 1
    elseif kind == 'number' then
        size = mathType(value) == 'integer' and integerSize(value) or 9
    elseif kind == 'string' then
        size = stringSize(#value)
    elseif kind == 'table' then
        return measureTable(state, value, depth + 1)
    else
        size = VECTOR_BYTES[kind]
        if not size then return false, 'type' end
    end
    local total = state.total + size
    state.total = total
    if total > state.limit then return false, 'too_large' end
    return true
end

--- Taille msgpack estimée d'une liste d'arguments (en-tête de la liste compris, nil finaux comptés).
---@param limit integer  octets : au-delà, le parcours s'arrête
---@return integer|nil bytes
---@return string|nil err  'cycle' | 'depth' | 'type' | 'too_large'
function netsize.args(limit, ...)
    local count = select('#', ...)
    local state = { total = headerSize(count), limit = limit, visiting = {} }
    if state.total > limit then return nil, 'too_large' end
    for i = 1, count do
        local ok, err = measure(state, (select(i, ...)), 0)
        if not ok then return nil, err end
    end
    return state.total
end

--- Taille msgpack estimée d'une seule valeur.
---@param limit integer
---@param value any
---@return integer|nil bytes
---@return string|nil err
function netsize.value(limit, value)
    local state = { total = 0, limit = limit, visiting = {} }
    local ok, err = measure(state, value, 0)
    if not ok then return nil, err end
    return state.total
end
