--[[
    vava_gathering/shared/proximity.lua
    Rôle : règles pures du streaming des props côté client : cibles regroupées (par zone ou par case de grille), centre
           et étendue de chaque groupe, distance minimale possible d'un point à une cible d'un groupe (pour ne mesurer
           que les cibles d'un groupe à portée), intervalle du prochain passage (court près d'un groupe, long loin de
           tout). Même fichier dans vava_gathering, vava_farming et vava_crafting, testé pour les trois dans
           tests/spec/props_proximity_spec.lua.
    Dépendances : shared/constants.lua
]]

local type, ipairs, sqrt, floor, huge, format = type, ipairs, math.sqrt, math.floor, math.huge, string.format

local proximity = {}
VavaGathering.proximity = proximity

---@class vAvA.ProximityGroup
---@field key string
---@field x number          centre : moyenne des positions des cibles
---@field y number
---@field z number
---@field extent number     distance du centre à la cible la plus éloignée
---@field targets table[]   cibles du groupe, dans l'ordre de la liste d'origine

---@param value any
---@return boolean
local function finite(value)
    return type(value) == 'number' and value == value and value ~= huge and value ~= -huge
end

---@param target any
---@return boolean
local function placed(target)
    return type(target) == 'table' and finite(target.x) and finite(target.y) and finite(target.z)
end

--- Regroupe des cibles `{ x, y, z, … }` selon la clé que rend `keyOf(target)`. Une cible sans position finie
--- (nombre, ni NaN ni infini) ou sans clé est ignorée. Les groupes suivent l'ordre de leur première cible.
---@param targets table[]
---@param keyOf fun(target: table): string|nil
---@return vAvA.ProximityGroup[]
function proximity.group(targets, keyOf)
    local groups, byKey = {}, {}
    for _, target in ipairs(targets) do
        local key = placed(target) and keyOf(target) or nil
        if key ~= nil then
            local group = byKey[key]
            if not group then
                group = { key = key, x = 0.0, y = 0.0, z = 0.0, extent = 0.0, targets = {} }
                byKey[key] = group
                groups[#groups + 1] = group
            end
            group.targets[#group.targets + 1] = target
        end
    end
    for _, group in ipairs(groups) do
        local count = #group.targets
        local sx, sy, sz = 0.0, 0.0, 0.0
        for _, target in ipairs(group.targets) do sx, sy, sz = sx + target.x, sy + target.y, sz + target.z end
        group.x, group.y, group.z = sx / count, sy / count, sz / count
        local extent = 0.0
        for _, target in ipairs(group.targets) do
            local dx, dy, dz = target.x - group.x, target.y - group.y, target.z - group.z
            local d = sqrt(dx * dx + dy * dy + dz * dz)
            if d > extent then extent = d end
        end
        group.extent = extent
    end
    return groups
end

--- Clé de la case de grille (côté `size` mètres, au sol) qui contient le point : pour regrouper des cibles sans zone.
---@param x number
---@param y number
---@param size number
---@return string
function proximity.cell(x, y, size)
    return format('%.0f:%.0f', floor(x / size), floor(y / size))
end

--- Distance minimale possible entre un point et une cible du groupe (0 si le point est dans son étendue) : aucune
--- cible du groupe n'est plus proche.
---@param group vAvA.ProximityGroup
---@param x number
---@param y number
---@param z number
---@return number
function proximity.gap(group, x, y, z)
    local dx, dy, dz = x - group.x, y - group.y, z - group.z
    local gap = sqrt(dx * dx + dy * dy + dz * dz) - group.extent
    return gap > 0 and gap or 0.0
end

--- Le groupe a-t-il peut-être une cible à moins de `reach` du point ? Rend aussi la distance minimale possible.
---@param group vAvA.ProximityGroup
---@param x number
---@param y number
---@param z number
---@param reach number
---@return boolean reachable
---@return number gap
function proximity.reachable(group, x, y, z, reach)
    local gap = proximity.gap(group, x, y, z)
    return gap <= reach, gap
end

--- Plus petite distance possible du point à une cible de tous les groupes (`math.huge` sans groupe).
---@param groups vAvA.ProximityGroup[]
---@param x number
---@param y number
---@param z number
---@return number
function proximity.closest(groups, x, y, z)
    local best = huge
    for _, group in ipairs(groups) do
        local gap = proximity.gap(group, x, y, z)
        if gap < best then best = gap end
    end
    return best
end

--- Intervalle du prochain passage : `nearMs` tant qu'une cible peut être à moins de `radius + margin` (la marge couvre
--- le chemin d'un cavalier rapide pendant `idleMs`), sinon `idleMs` (`nearMs` s'il n'est pas réglé).
---@param gap number         plus petite distance possible à une cible (proximity.closest)
---@param radius number      portée du streaming
---@param margin number|nil  marge d'approche (mètres)
---@param nearMs integer
---@param idleMs integer|nil
---@return integer
function proximity.interval(gap, radius, margin, nearMs, idleMs)
    if type(idleMs) ~= 'number' or idleMs < nearMs then return nearMs end
    if gap <= radius + (type(margin) == 'number' and margin or 0) then return nearMs end
    return idleMs
end
