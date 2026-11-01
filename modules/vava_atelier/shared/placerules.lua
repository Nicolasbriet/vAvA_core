--[[
    vava_atelier/shared/placerules.lua
    Rôle : règles de placement pures, les mêmes pour l'aperçu (client) et la décision (serveur) : portée, dedans, écart,
           rayon, sommets, tracé qui se croise. Servie au serveur, et au client du Conseil par le paquet (T-157).
           Testée : tests/spec/atelier_placerules_spec.lua.
    Dépendances : shared/constants.lua
]]

local type, ipairs, tostring = type, ipairs, tostring
local sqrt, floor, huge, min, max = math.sqrt, math.floor, math.huge, math.min, math.max
local format, gsub = string.format, string.gsub

local placerules = {}
VavaAtelier.placerules = placerules

-- marge des comparaisons (bornes atteintes acceptées : 60,0 m pour une portée de 60 m)
local EPSILON = 1e-9

local function finite(value)
    return type(value) == 'number' and value == value and value ~= huge and value ~= -huge
end
placerules.finite = finite

--- Distance au sol entre deux points.
function placerules.ground(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return sqrt(dx * dx + dy * dy)
end
local ground = placerules.ground

--- Distance 3D entre deux points `{ x, y, z }` (z absent : 0).
function placerules.distance(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)
    return sqrt(dx * dx + dy * dy + dz * dz)
end

--- Centre d'un lieu (moyenne des sommets d'un tracé), ou nil sans position finie.
function placerules.center(where)
    if type(where) ~= 'table' then return nil end
    if finite(where.x) and finite(where.y) then
        return { x = where.x, y = where.y, z = finite(where.z) and where.z or 0.0 }
    end
    local points = where.points
    if type(points) ~= 'table' or #points == 0 then return nil end
    local sx, sy = 0.0, 0.0
    for _, point in ipairs(points) do
        if type(point) ~= 'table' or not finite(point.x) or not finite(point.y) then return nil end
        sx, sy = sx + point.x, sy + point.y
    end
    return { x = sx / #points, y = sy / #points, z = finite(where.z) and where.z or 0.0 }
end
local center = placerules.center

--- Point au sol dans un tracé (parité des croisements d'une demi-droite).
function placerules.inPolygon(points, x, y)
    local inside = false
    local n = #points
    local j = n
    for i = 1, n do
        local a, b = points[i], points[j]
        if (a.y > y) ~= (b.y > y) and x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x then inside = not inside end
        j = i
    end
    return inside
end

--- Distance au sol d'un point au segment [a, b].
local function segmentDistance(ax, ay, bx, by, x, y)
    local dx, dy = bx - ax, by - ay
    local length = dx * dx + dy * dy
    if length <= 0 then return ground(ax, ay, x, y) end
    local t = ((x - ax) * dx + (y - ay) * dy) / length
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    return ground(ax + t * dx, ay + t * dy, x, y)
end

--- Distance au sol d'un point au bord d'un tracé fermé.
function placerules.edgeDistance(points, x, y)
    local best = huge
    local n = #points
    for i = 1, n do
        local a, b = points[i], points[i % n + 1]
        local d = segmentDistance(a.x, a.y, b.x, b.y, x, y)
        if d < best then best = d end
    end
    return best
end

--- Orientation de trois points (−1, 0, 1).
local function orient(ax, ay, bx, by, cx, cy)
    local value = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
    if value > EPSILON then return 1 end
    if value < -EPSILON then return -1 end
    return 0
end

--- c, aligné avec [a, b], est-il sur le segment ?
local function onSegment(ax, ay, bx, by, cx, cy)
    return cx >= min(ax, bx) - EPSILON and cx <= max(ax, bx) + EPSILON and cy >= min(ay, by) - EPSILON
        and cy <= max(ay, by) + EPSILON
end

--- Deux segments se touchent-ils ou se croisent-ils ?
local function intersect(a, b, c, d)
    local o1, o2 = orient(a.x, a.y, b.x, b.y, c.x, c.y), orient(a.x, a.y, b.x, b.y, d.x, d.y)
    local o3, o4 = orient(c.x, c.y, d.x, d.y, a.x, a.y), orient(c.x, c.y, d.x, d.y, b.x, b.y)
    if o1 ~= o2 and o3 ~= o4 then return true end
    if o1 == 0 and onSegment(a.x, a.y, b.x, b.y, c.x, c.y) then return true end
    if o2 == 0 and onSegment(a.x, a.y, b.x, b.y, d.x, d.y) then return true end
    if o3 == 0 and onSegment(c.x, c.y, d.x, d.y, a.x, a.y) then return true end
    if o4 == 0 and onSegment(c.x, c.y, d.x, d.y, b.x, b.y) then return true end
    return false
end

--- Un côté du tracé croise-t-il (ou touche-t-il) un côté qui n'est pas son voisin ?
function placerules.crosses(points, open)
    local n = #points
    local edges = open and n - 1 or n
    if edges < 3 then return false end
    for i = 1, edges do
        local a, b = points[i], points[i % n + 1]
        for j = i + 2, edges do
            -- le premier et le dernier côté d'un tracé fermé se touchent au premier sommet : voisins
            if not (not open and i == 1 and j == n) then
                local c, d = points[j], points[j % n + 1]
                if intersect(a, b, c, d) then return true end
            end
        end
    end
    return false
end

--- Nombre fini, sinon 0.
local function num(value)
    return finite(value) and value or 0
end

local function refusal(code, ...)
    return { code = code, args = { ... } }
end

--- Portée : centre à `reach` m (3D), sommets d'un tracé à `reach × polygonFactor` (au sol) ; nil, ou `far`.
function placerules.reach(shape, where, origin, limits, open)
    if shape == 'polygon' then
        local far, worst = limits.reach * limits.polygonFactor, 0
        for _, point in ipairs(where.points or {}) do
            local d = ground(point.x, point.y, origin.x, origin.y)
            if d > worst then worst = d end
        end
        if worst > far + EPSILON then return refusal('far', floor(worst + 0.5)) end
        if open then return nil end
    end
    local at = center(where)
    if not at then return refusal('ground') end
    local d = placerules.distance(at, origin)
    if d > limits.reach + EPSILON then return refusal('far', floor(d + 0.5)) end
    return nil
end

--- Points d'un lieu qui doivent être dans le parent : les sommets d'un tracé, sinon le centre.
local function testedPoints(shape, where)
    if shape == 'polygon' then return where.points or {} end
    local at = center(where)
    return at and { at } or {}
end

--- Le point est-il dans le lieu du parent (cercle ou tracé), à `slack` m près ?
local function within(parent, x, y, slack)
    local area = parent.place
    if parent.shape == 'circle' then
        return ground(x, y, area.x, area.y) <= area.r + slack + EPSILON
    end
    if parent.shape == 'polygon' then
        if placerules.inPolygon(area.points, x, y) then return true end
        return placerules.edgeDistance(area.points, x, y) <= slack + EPSILON
    end
    return true
end

--- Règles déclarées d'un type pour un lieu déjà contrôlé (forme, bornes).
function placerules.check(rules, shape, where, ctx)
    -- sans position finie (rien de visé, NaN, infini) : rien à poser
    if type(where) ~= 'table' or not center(where) then return refusal('ground') end
    rules = rules or {}
    if ctx.origin then
        local far = placerules.reach(shape, where, ctx.origin,
            { reach = ctx.reach or huge, polygonFactor = ctx.polygonFactor or 1 }, ctx.open)
        if far then return far end
    end
    if shape == 'circle' and type(rules.radius) == 'table' then
        local r = where.r
        if not finite(r) or r < rules.radius.min - EPSILON or r > rules.radius.max + EPSILON then
            return refusal('radius', floor(rules.radius.min + 0.5), floor(rules.radius.max + 0.5))
        end
    end
    if shape == 'polygon' then
        local n = #(where.points or {})
        local bounds = rules.vertices
        if type(bounds) == 'table' and (n > bounds.max or (not ctx.open and n < bounds.min)) then
            return refusal('vertices', bounds.min, bounds.max)
        end
        if placerules.crosses(where.points or {}, ctx.open) then return refusal('crossing') end
    end
    local inside, parent = rules.inside, ctx.parent
    if type(inside) == 'table' and type(parent) == 'table' and type(parent.place) == 'table' then
        local slack = finite(inside.slack) and inside.slack or 0
        for _, point in ipairs(testedPoints(shape, where)) do
            if not within(parent, point.x, point.y, slack) then return refusal('inside', parent.title or '') end
        end
    end
    local spacing = rules.spacing
    if finite(spacing) and spacing > 0 and type(ctx.siblings) == 'table' then
        local at = center(where)
        if at then
            local closest, closestDistance = nil, huge
            for _, sibling in ipairs(ctx.siblings) do
                if sibling.id ~= ctx.self and not sibling.removal and finite(sibling.x) and finite(sibling.y)
                    and (ctx.parentId == nil or sibling.parent == nil or sibling.parent == ctx.parentId) then
                    local d = ground(at.x, at.y, sibling.x, sibling.y)
                    if d < spacing - EPSILON and d < closestDistance then closest, closestDistance = sibling, d end
                end
            end
            if closest then return refusal('spacing', closest.title or closest.id, closestDistance) end
        end
    end
    return nil
end

--- Nombre au dixième, à la française : « 1,4 », « 2 », « 81,5 ».
function placerules.number(value)
    if not finite(value) then return '0' end
    local rounded = floor(value * 10 + 0.5) / 10
    if rounded == floor(rounded) then return format('%d', floor(rounded)) end
    return (gsub(format('%.1f', rounded), '%.', ','))
end

--- Refus mis en mots avec `placement.texts` : « Trop loin de vous : approchez-vous (72 m). »
function placerules.text(found, texts)
    local code, args = found.code, found.args or {}
    if code == 'far' then return format(texts.far, floor(num(args[1]))) end
    if code == 'inside' then return format(texts.inside, tostring(args[1] or '')) end
    if code == 'spacing' then return format(texts.spacing, tostring(args[1] or ''), placerules.number(args[2] or 0)) end
    if code == 'radius' then return format(texts.radius, floor(num(args[1])), floor(num(args[2]))) end
    if code == 'vertices' then
        return format(texts.vertices, floor(num(args[1])), floor(num(args[2])))
    end
    if code == 'crossing' then return texts.crossing end
    return texts.ground
end

--- Titre d'un enfant nouveau : libellé du choix et premier numéro libre (« Chêne 4 »).
function placerules.autoTitle(label, titles)
    local taken = {}
    for _, title in ipairs(titles or {}) do
        if type(title) == 'string' then taken[title] = true end
    end
    local n = 1
    while taken[label .. ' ' .. n] do n = n + 1 end
    return label .. ' ' .. n
end
