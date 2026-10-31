--[[
    vava_atelier/shared/aim.lua
    Rôle : logique pure de la visée de l'outil de placement (§ 8.1 et § 8.2 de la spec T-102), lue par le client
           (client/placer.lua) : direction de la caméra, candidat selon la forme (point, orienté, cercle, tracé), pas de
           la molette (cap ramené dans [0, 360), rayon borné et arrondi au pas), candidat qui a bougé (règles à
           réévaluer), pile d'annulation bornée (le plus ancien geste sort), ce que coûte l'annulation d'un geste
           (sommet retiré sans RPC, création → abandon du brouillon, déplacement → lieu d'avant), élément visé au clic
           droit (le plus proche, à `pickRadius` au plus, au sol), éléments les plus proches (étiquettes, fantômes),
           barre des touches du mode. Aucune native.
           Testée : tests/spec/atelier_aim_spec.lua.
    Dépendances : shared/constants.lua
]]

local type, ipairs = type, ipairs
local sqrt, floor, abs, rad, sin, cos, huge = math.sqrt, math.floor, math.abs, math.rad, math.sin, math.cos, math.huge
local remove, sort = table.remove, table.sort

local aim = {}
VavaAtelier.aim = aim

-- un candidat a bougé au-delà de 5 cm (au sol)
local MOVED = 0.05

---@param value any
---@return boolean
local function finite(value)
    return type(value) == 'number' and value == value and value ~= huge and value ~= -huge
end

--- Direction (vecteur unitaire) d'une caméra tournée de `pitch` (rotation x) et `yaw` (rotation z), en degrés.
---@param pitch number
---@param yaw number
---@return number dx
---@return number dy
---@return number dz
function aim.direction(pitch, yaw)
    local x, z = rad(pitch), rad(yaw)
    local c = abs(cos(x))
    return -sin(z) * c, cos(z) * c, sin(x)
end

--- Cap tourné d'un cran de molette : ±`steps.heading`, ou ±`steps.headingFine` avec `fine` ; ramené dans [0, 360) et
--- arrondi au dixième (350 + 15 → 5 ; 0 − 1 → 359).
---@param heading number
---@param direction integer  1 ou −1
---@param fine boolean
---@param steps { heading: number, headingFine: number }
---@return number
function aim.turn(heading, direction, fine, steps)
    local step = fine and steps.headingFine or steps.heading
    local h = ((finite(heading) and heading or 0.0) + direction * step) % 360
    h = floor(h * 10 + 0.5) / 10
    if h >= 360 then h = 0.0 end
    return h + 0.0
end

--- Rayon changé d'un cran de molette : ±`steps.radius`, ou ±`steps.radiusFine` avec `fine` ; arrondi au pas du cran,
--- borné par `bounds` (rules.radius du type).
---@param radius number
---@param direction integer
---@param fine boolean
---@param steps { radius: number, radiusFine: number }
---@param bounds { min: number, max: number }
---@return number
function aim.resize(radius, direction, fine, steps, bounds)
    local step = fine and steps.radiusFine or steps.radius
    local r = (finite(radius) and radius or bounds.min) + direction * step
    r = floor(r / step + 0.5) * step
    if r < bounds.min then r = bounds.min end
    if r > bounds.max then r = bounds.max end
    return floor(r * 100 + 0.5) / 100
end

--- Candidat de la visée selon la forme : le point touché (`hit`, nil si la visée ne touche rien), le cap et le rayon
--- courants, les sommets déjà posés d'un tracé (suivis du sommet sous la visée). nil sans point touché, sauf pour un
--- tracé qui a déjà des sommets.
---@param shape string  point | oriented | circle | polygon
---@param hit { x: number, y: number, z: number }|nil
---@param state { heading?: number, radius?: number, vertices?: { x: number, y: number, z: number }[] }
---@return table|nil
function aim.candidate(shape, hit, state)
    if shape == 'polygon' then
        local vertices = state.vertices or {}
        if #vertices == 0 and not hit then return nil end
        local points = {}
        for i, v in ipairs(vertices) do points[i] = { x = v.x, y = v.y } end
        if hit then points[#points + 1] = { x = hit.x, y = hit.y } end
        return { z = vertices[1] and vertices[1].z or hit.z, points = points }
    end
    if not hit then return nil end
    if shape == 'oriented' then return { x = hit.x, y = hit.y, z = hit.z, h = state.heading or 0.0 } end
    if shape == 'circle' then return { x = hit.x, y = hit.y, z = hit.z, r = state.radius or 0.0 } end
    return { x = hit.x, y = hit.y, z = hit.z }
end

--- Le candidat a-t-il changé assez pour réévaluer les règles (5 cm au sol, cap, rayon, nombre de sommets) ?
---@param a table|nil
---@param b table|nil
---@return boolean
function aim.moved(a, b)
    if a == nil or b == nil then return a ~= b end
    if a.points or b.points then
        local pa, pb = a.points or {}, b.points or {}
        if #pa ~= #pb then return true end
        local last, other = pa[#pa], pb[#pb]
        if not last or not other then return false end
        local dx, dy = last.x - other.x, last.y - other.y
        return sqrt(dx * dx + dy * dy) > MOVED
    end
    if a.h ~= b.h or a.r ~= b.r then return true end
    local dx, dy = (a.x or 0) - (b.x or 0), (a.y or 0) - (b.y or 0)
    return sqrt(dx * dx + dy * dy) > MOVED
end

-- Pile d'annulation --------------------------------------------------------------------------------------------------

---@class vAvA.AtelierUndoStack
---@field max integer
---@field items table[]

--- Pile vide, bornée à `max` gestes.
---@param max integer
---@return vAvA.AtelierUndoStack
function aim.stack(max)
    return { max = max, items = {} }
end

--- Geste ajouté : { kind = 'vertex' } (sommet d'un tracé, pas encore envoyé), { kind = 'create', entryKind, id }
--- (fiche créée par un clic), { kind = 'move', entryKind, id, before } (fiche déplacée, lieu d'avant). Au-delà de
--- `max`, le plus ancien sort.
---@param stack vAvA.AtelierUndoStack
---@param gesture table
function aim.push(stack, gesture)
    local items = stack.items
    items[#items + 1] = gesture
    while #items > stack.max do remove(items, 1) end
end

--- Dernier geste retiré de la pile, ou nil (« Rien à annuler. »).
---@param stack vAvA.AtelierUndoStack
---@return table|nil
function aim.pop(stack)
    return remove(stack.items)
end

--- Gestes d'une fiche oubliés (fiche abandonnée ailleurs, ou annulation impossible).
---@param stack vAvA.AtelierUndoStack
---@param id string
function aim.forget(stack, id)
    local items = stack.items
    for i = #items, 1, -1 do
        if items[i].id == id then remove(items, i) end
    end
end

--- Ce que coûte l'annulation d'un geste : { action = 'vertex' } (sommet retiré, aucun RPC), { action = 'discard',
--- entryKind, id } (brouillon créé abandonné : RPC discard), { action = 'place', entryKind, id, place } (lieu d'avant :
--- RPC place). nil pour un geste inconnu.
---@param gesture table
---@return table|nil
function aim.undoPlan(gesture)
    if type(gesture) ~= 'table' then return nil end
    if gesture.kind == 'vertex' then return { action = 'vertex' } end
    if gesture.kind == 'create' then return { action = 'discard', entryKind = gesture.entryKind, id = gesture.id } end
    if gesture.kind == 'move' and type(gesture.before) == 'table' then
        return { action = 'place', entryKind = gesture.entryKind, id = gesture.id, place = gesture.before }
    end
    return nil
end

-- Éléments proches -----------------------------------------------------------------------------------------------------

--- Élément le plus proche du point visé, au sol, à `radius` au plus ; nil sinon. Éléments : { x, y, … }.
---@param items table[]
---@param x number
---@param y number
---@param radius number
---@return table|nil
function aim.pick(items, x, y, radius)
    local best, bestDistance = nil, huge
    for _, item in ipairs(items) do
        if finite(item.x) and finite(item.y) then
            local dx, dy = item.x - x, item.y - y
            local d = sqrt(dx * dx + dy * dy)
            if d <= radius and d < bestDistance then best, bestDistance = item, d end
        end
    end
    return best
end

--- Les `count` éléments les plus proches d'un point (3D), à `distance` au plus, du plus proche au plus lointain.
---@param items table[]
---@param x number
---@param y number
---@param z number
---@param count integer
---@param distance number
---@return table[]
function aim.nearest(items, x, y, z, count, distance)
    local found = {}
    for _, item in ipairs(items) do
        if finite(item.x) and finite(item.y) then
            local dx, dy, dz = item.x - x, item.y - y, (item.z or z) - z
            local d = sqrt(dx * dx + dy * dy + dz * dz)
            if d <= distance then found[#found + 1] = { item = item, d = d } end
        end
    end
    sort(found, function(a, b) return a.d < b.d end)
    local out = {}
    for i = 1, math.min(count, #found) do out[i] = found[i].item end
    return out
end

--- Barre des touches d'une visée : celle des enfants (« Poser des points »), d'un point choisi, sinon celle de la forme.
---@param mode string  self | children
---@param shape string
---@param picked boolean
---@param keybar table  placement.keybar
---@return table[]
function aim.keys(mode, shape, picked, keybar)
    if mode == 'children' then return picked and keybar.picked or keybar.children end
    return keybar[shape] or keybar.point
end
