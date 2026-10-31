--[[
    vava_atelier/shared/place.lua
    Rôle : logique pure du lieu d'une fiche (`place`, § 5.4 de la spec T-101). Le type déclare sa forme par
           `placement` ; T-101 stocke et contrôle le lieu, T-102 l'éditera (il peut ajouter des formes, jamais les
           changer). Tables à clés nommées, nombres finis, arrondis : coordonnées au centimètre, cap au dixième de
           degré ramené dans [0, 360).
             - point    { x, y, z }
             - oriented { x, y, z, h }
             - circle   { x, y, z, r }            0 < r ≤ maxRadius
             - polygon  { z, points = { { x, y }, … } }   3 à 32 sommets, deux sommets consécutifs à 5 cm au moins,
                                                         aire non nulle
             - door     { x, y, z, h, model }     model : empreinte de modèle, entier signé ou non (32 bits)
           Un type sans `placement` n'a jamais de lieu : `check(nil, …)` rend nil (le lieu reçu est ignoré).
           Testée : tests/spec/atelier_place_spec.lua.
    Dépendances : shared/constants.lua
]]

local type, pairs, ipairs, tostring = type, pairs, ipairs, tostring
local floor, abs, huge, tointeger, mathType = math.floor, math.abs, math.huge, math.tointeger, math.type
local format = string.format

local P = VavaAtelier.PLACE

local place = {}
VavaAtelier.place = place

-- clés permises par forme (toute autre clé est refusée)
local KEYS = {
    point = { x = true, y = true, z = true },
    oriented = { x = true, y = true, z = true, h = true },
    circle = { x = true, y = true, z = true, r = true },
    polygon = { z = true, points = true },
    door = { x = true, y = true, z = true, h = true, model = true },
}
local POINT_KEYS = { x = true, y = true }

---@param value any
---@return boolean
local function finite(value)
    return type(value) == 'number' and value == value and value ~= huge and value ~= -huge
end

--- Arrondi au multiple de `step` le plus proche (moitié vers le haut) ; toujours un réel.
---@param value number
---@param step number
---@return number
local function round(value, step)
    local scale = 1 / step
    return floor(value * scale + 0.5) / scale + 0.0
end
place.round = round

--- Cap en degrés, arrondi au dixième et ramené dans [0, 360) : −90 → 270, 360 → 0.
---@param value number
---@return number
function place.heading(value)
    local h = round(value, P.roundHeading) % 360
    h = round(h, P.roundHeading)
    if h >= 360 then h = 0.0 end
    return h
end

---@return nil
---@return string
local function fail(key, message)
    return nil, key .. ' : ' .. message
end

--- Première clé hors de `allowed`, ou nil.
local function unknownKey(value, allowed)
    for key in pairs(value) do
        if not allowed[key] then return tostring(key) end
    end
    return nil
end

--- Coordonnée lue, arrondie et bornée.
---@return number|nil value
---@return string|nil err
local function coordinate(value, key, limit)
    if not finite(value) then return fail(key, 'nombre fini attendu') end
    local rounded = round(value, P.round)
    if abs(rounded) > limit then return fail(key, format('hors des bornes (%s au plus)', tostring(limit))) end
    return rounded
end

--- Liste pure de `min` à `max` éléments.
local function isList(value, min, max)
    if type(value) ~= 'table' then return false end
    local count = 0
    for key in pairs(value) do
        if mathType(key) ~= 'integer' then return false end
        count = count + 1
    end
    return count == #value and count >= min and count <= max
end

local shapes = {}

function shapes.point(value, limits, out)
    local err
    out.x, err = coordinate(value.x, 'x', limits.maxXY)
    if not out.x then return nil, err end
    out.y, err = coordinate(value.y, 'y', limits.maxXY)
    if not out.y then return nil, err end
    out.z, err = coordinate(value.z, 'z', limits.maxZ)
    if not out.z then return nil, err end
    return out
end

function shapes.oriented(value, limits, out)
    local ok, err = shapes.point(value, limits, out)
    if not ok then return nil, err end
    if not finite(value.h) then return fail('h', 'cap en degrés attendu') end
    out.h = place.heading(value.h)
    return out
end

function shapes.circle(value, limits, out)
    local ok, err = shapes.point(value, limits, out)
    if not ok then return nil, err end
    if not finite(value.r) then return fail('r', 'rayon attendu') end
    local r = round(value.r, P.round)
    if r <= 0 or r > limits.maxRadius then
        return fail('r', format('rayon de plus de 0 à %s m', tostring(limits.maxRadius)))
    end
    out.r = r
    return out
end

function shapes.door(value, limits, out)
    local ok, err = shapes.oriented(value, limits, out)
    if not ok then return nil, err end
    local model = finite(value.model) and tointeger(value.model) or nil
    if not model or model < P.modelMin or model > P.modelMax then
        return fail('model', 'empreinte de modèle attendue (entier sur 32 bits)')
    end
    out.model = model
    return out
end

--- Aire signée (formule du lacet) d'une suite de sommets { x, y }.
---@param points { x: number, y: number }[]
---@return number
local function area(points)
    local sum, n = 0, #points
    for i = 1, n do
        local a, b = points[i], points[i % n + 1]
        sum = sum + a.x * b.y - b.x * a.y
    end
    return sum / 2
end
place.area = area

function shapes.polygon(value, limits, out)
    local err
    out.z, err = coordinate(value.z, 'z', limits.maxZ)
    if not out.z then return nil, err end
    local bounds = limits.polygonPoints
    if not isList(value.points, bounds.min, bounds.max) then
        return fail('points', format('liste de %d à %d sommets attendue', bounds.min, bounds.max))
    end
    local points = {}
    for i, point in ipairs(value.points) do
        local here = format('points[%d]', i)
        if type(point) ~= 'table' then return fail(here, 'sommet { x, y } attendu') end
        local key = unknownKey(point, POINT_KEYS)
        if key then return fail(here .. '.' .. key, 'clé inconnue') end
        local x, y
        x, err = coordinate(point.x, here .. '.x', limits.maxXY)
        if not x then return nil, err end
        y, err = coordinate(point.y, here .. '.y', limits.maxXY)
        if not y then return nil, err end
        points[i] = { x = x, y = y }
    end
    local n = #points
    for i = 1, n do
        local a, b = points[i], points[i % n + 1]
        local dx, dy = b.x - a.x, b.y - a.y
        if dx * dx + dy * dy < P.minEdge * P.minEdge then
            return fail(format('points[%d]', i % n + 1), format('à moins de %s m du sommet précédent',
                tostring(P.minEdge)))
        end
    end
    if abs(area(points)) < P.minArea then return fail('points', 'aire nulle (sommets alignés)') end
    out.points = points
    return out
end

---@class vAvA.AtelierPlaceLimits
---@field maxXY number
---@field maxZ number
---@field maxRadius number
---@field polygonPoints { min: integer, max: integer }

--- Lieu contrôlé et arrondi : une nouvelle table, ou nil et une raison (« r : rayon de plus de 0 à 500 m »).
--- `shape` nil (type sans placement) ou `value` nil (lieu pas encore posé) : nil, sans raison.
---@param shape string|nil  point | oriented | circle | polygon | door
---@param value any
---@param limits vAvA.AtelierPlaceLimits
---@return table|nil value
---@return string|nil err
function place.check(shape, value, limits)
    if shape == nil or value == nil then return nil end
    local allowed = KEYS[shape]
    if not allowed then return nil, 'forme de lieu inconnue : ' .. tostring(shape) end
    if type(value) ~= 'table' then return nil, 'lieu : table attendue' end
    local key = unknownKey(value, allowed)
    if key then return fail(key, 'clé inconnue pour un lieu ' .. shape) end
    return shapes[shape](value, limits, {})
end

--- Vrai si un lieu reçu doit être ignoré (type sans placement) : l'appelant l'écrit en console.
---@param shape string|nil
---@param value any
---@return boolean
function place.ignored(shape, value)
    return shape == nil and value ~= nil
end

--- Centre au sol d'un lieu (pour une zone du core), ou nil : { x, y, z }.
---@param value table|nil
---@return { x: number, y: number, z: number }|nil
function place.center(value)
    if type(value) ~= 'table' then return nil end
    if value.x and value.y then return { x = value.x, y = value.y, z = value.z or 0.0 } end
    if type(value.points) == 'table' and #value.points > 0 then
        local sx, sy = 0, 0
        for _, point in ipairs(value.points) do sx, sy = sx + point.x, sy + point.y end
        return { x = sx / #value.points, y = sy / #value.points, z = value.z or 0.0 }
    end
    return nil
end
