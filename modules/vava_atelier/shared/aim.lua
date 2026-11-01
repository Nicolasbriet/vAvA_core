--[[
    vava_atelier/shared/aim.lua
    Rôle : logique pure de la visée (client) : candidat, molette, pile d'annulation, choix, étiquettes, barre des touches.
           Livrée dans le paquet du Conseil (T-157). Testée : tests/spec/atelier_aim_spec.lua.
    Dépendances : shared/constants.lua
]]

local type, ipairs = type, ipairs
local sqrt, floor, abs, rad, sin, cos, huge = math.sqrt, math.floor, math.abs, math.rad, math.sin, math.cos, math.huge
local remove, sort = table.remove, table.sort

local aim = {}
VavaAtelier.aim = aim

-- un candidat a bougé au-delà de 5 cm (au sol)
local MOVED = 0.05

local function finite(value)
    return type(value) == 'number' and value == value and value ~= huge and value ~= -huge
end

--- Direction (vecteur unitaire) d'une caméra tournée de `pitch` (rotation x) et `yaw` (rotation z), en degrés.
function aim.direction(pitch, yaw)
    local x, z = rad(pitch), rad(yaw)
    local c = abs(cos(x))
    return -sin(z) * c, cos(z) * c, sin(x)
end

--- Cap tourné d'un cran de molette (pas fin avec `fine`), ramené dans [0, 360).
function aim.turn(heading, direction, fine, steps)
    local step = fine and steps.headingFine or steps.heading
    local h = ((finite(heading) and heading or 0.0) + direction * step) % 360
    h = floor(h * 10 + 0.5) / 10
    if h >= 360 then h = 0.0 end
    return h + 0.0
end

--- Rayon changé d'un cran de molette (pas fin avec `fine`), borné et arrondi au pas.
function aim.resize(radius, direction, fine, steps, bounds)
    local step = fine and steps.radiusFine or steps.radius
    local r = (finite(radius) and radius or bounds.min) + direction * step
    r = floor(r / step + 0.5) * step
    if r < bounds.min then r = bounds.min end
    if r > bounds.max then r = bounds.max end
    return floor(r * 100 + 0.5) / 100
end

--- Candidat de la visée selon la forme (point, orienté, cercle, tracé), ou nil.
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

--- Pile vide, bornée à `max` gestes.
function aim.stack(max)
    return { max = max, items = {} }
end

--- Geste ajouté à la pile d'annulation (le plus ancien sort au-delà de la taille).
function aim.push(stack, gesture)
    local items = stack.items
    items[#items + 1] = gesture
    while #items > stack.max do remove(items, 1) end
end

--- Dernier geste retiré de la pile, ou nil (« Rien à annuler. »).
function aim.pop(stack)
    return remove(stack.items)
end

--- Gestes d'une fiche oubliés (fiche abandonnée ailleurs, ou annulation impossible).
function aim.forget(stack, id)
    local items = stack.items
    for i = #items, 1, -1 do
        if items[i].id == id then remove(items, i) end
    end
end

--- Annulation d'un geste : sommet retiré, `discard` d'une création, `place` au lieu d'avant.
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

--- Barre des touches d'une visée selon le mode, la forme et l'élément choisi.
function aim.keys(mode, shape, picked, keybar)
    if mode == 'children' then return picked and keybar.picked or keybar.children end
    return keybar[shape] or keybar.point
end
