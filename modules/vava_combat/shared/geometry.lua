--[[
    vava_combat/shared/geometry.lua
    Rôle : géométrie pure d'un coup, côté client et serveur (docs/plan/specs/T-112.md § 7.3). Repère de GTA : cap 0 =
           nord (+y), croissant vers l'ouest (sens trigonométrique vu de dessus). Avant d'un cap, cap d'un point vers un
           autre (le client s'oriente vers sa cible), distance au sol et écart de hauteur, angle à plat entre l'avant et
           une cible, arc d'une technique (portée, demi-angle, hauteur, contact) et cible dans l'arc, ordre des
           candidats, bond plausible de l'attaquant. Le serveur juge seul : le client ne s'en sert que pour se tourner.
           Aucune native ; une valeur non finie rend nil ou faux, jamais une erreur.
    Dépendances : shared/constants.lua
]]

local type, ipairs, sort = type, ipairs, table.sort
local sin, cos, rad, deg, atan, acos, sqrt, abs, huge = math.sin, math.cos, math.rad, math.deg, math.atan, math.acos,
    math.sqrt, math.abs, math.huge
local max, min = math.max, math.min

-- en dessous (carré de la distance au sol), deux points sont confondus : aucun cap
local SAME_POINT_SQ = 1e-8

local geometry = {}
VavaCombat.geometry = geometry

---@param value any
---@return boolean
local function finite(value)
    return type(value) == 'number' and value == value and value ~= huge and value ~= -huge
end

--- Point lisible : { x, y, z } (ou vector3) aux trois coordonnées finies.
---@param p any
---@return boolean
local function point(p)
    local kind = type(p)
    if kind ~= 'table' and kind ~= 'vector3' and kind ~= 'userdata' then return false end
    return finite(p.x) and finite(p.y) and finite(p.z)
end

--- Avant d'un cap (degrés), à plat : { x = −sin h, y = cos h }, ou nil.
---@param heading any
---@return { x: number, y: number }|nil
function geometry.forward(heading)
    if not finite(heading) then return nil end
    local h = rad(heading)
    return { x = -sin(h), y = cos(h) }
end

--- Cap (0 à 360, degrés) de `from` vers `to`, à plat ; nil au contact ou pour un point illisible.
---@param from table
---@param to table
---@return number|nil
function geometry.headingTo(from, to)
    if not point(from) or not point(to) then return nil end
    local dx, dy = to.x - from.x, to.y - from.y
    if dx * dx + dy * dy < SAME_POINT_SQ then return nil end
    local heading = deg(atan(-dx, dy))
    if heading < 0 then heading = heading + 360 end
    return heading
end

--- Distance au sol et écart de hauteur |dz| entre deux points, ou nil.
---@param from table
---@param to table
---@return number|nil distance
---@return number|nil height
function geometry.flat(from, to)
    if not point(from) or not point(to) then return nil, nil end
    local dx, dy = to.x - from.x, to.y - from.y
    return sqrt(dx * dx + dy * dy), abs(to.z - from.z)
end

--- Angle (0 à 180 degrés) entre l'avant `forward` et la direction à plat de `from` vers `to` ; 0 au contact ; nil pour
--- une valeur illisible.
---@param forward { x: number, y: number }
---@param from table
---@param to table
---@return number|nil
function geometry.flatAngle(forward, from, to)
    if type(forward) ~= 'table' or not finite(forward.x) or not finite(forward.y) then return nil end
    if not point(from) or not point(to) then return nil end
    local dx, dy = to.x - from.x, to.y - from.y
    local length = sqrt(dx * dx + dy * dy)
    local norm = sqrt(forward.x * forward.x + forward.y * forward.y)
    if length * length < SAME_POINT_SQ or norm == 0 then return 0 end
    local dot = (forward.x * dx + forward.y * dy) / (length * norm)
    return deg(acos(max(-1, min(1, dot))))
end

--- Cible dans l'arc d'un coup porté depuis `a` au cap `heading` : `true, distance, angle`, ou `false, raison`
--- (`height`, `range`, `angle` ; `invalid` pour une valeur illisible). Au contact (distance < closeRange), l'angle ne
--- compte plus (0).
---@param a table        position de l'attaquant
---@param heading number cap de l'attaquant
---@param b table        position de la cible
---@param arc { reach: number, halfAngle: number, maxHeight: number, closeRange: number }
---@return boolean
---@return number|string distance_or_reason
---@return number|nil angle
function geometry.inArc(a, heading, b, arc)
    if type(arc) ~= 'table' or not finite(heading) then return false, 'invalid' end
    local distance, height = geometry.flat(a, b)
    if not distance then return false, 'invalid' end
    if height > arc.maxHeight then return false, 'height' end
    if distance > arc.reach then return false, 'range' end
    if distance < arc.closeRange then return true, distance, 0 end
    local angle = geometry.flatAngle(geometry.forward(heading), a, b)
    if not angle then return false, 'invalid' end
    if angle > arc.halfAngle then return false, 'angle' end
    return true, distance, angle
end

--- Arc d'une technique tenue avec une arme : portée = hit.range + bonus de l'arme + tolérance (0,5 m au moins),
--- demi-angle = hit.angle / 2 + tolérance (180 au plus), hauteur = geometry.maxHeight + tolérance, contact.
---@param def table     technique ({ hit = { range, angle } })
---@param weapon table  fiche de l'arme ({ reachBonus })
---@param cfg table     config (tolerance, geometry)
---@return { reach: number, halfAngle: number, maxHeight: number, closeRange: number }
function geometry.arcOf(def, weapon, cfg)
    local tol, g = cfg.tolerance, cfg.geometry
    return {
        reach = max(0.5, def.hit.range + (weapon.reachBonus or 0) + tol.range),
        halfAngle = min(180, def.hit.angle / 2 + tol.angle),
        maxHeight = g.maxHeight + tol.height,
        closeRange = g.closeRange,
    }
end

--- Candidats triés (copie) : la cible verrouillée d'abord, puis l'angle croissant, la distance, le numéro de joueur.
---@param list { player: integer, distance: number, angle: number }[]
---@param locked integer|nil
---@return table[]
function geometry.order(list, locked)
    local out = {}
    for i, entry in ipairs(list) do out[i] = entry end
    sort(out, function(a, b)
        local la, lb = locked ~= nil and a.player == locked, locked ~= nil and b.player == locked
        if la ~= lb then return la end
        if a.angle ~= b.angle then return a.angle < b.angle end
        if a.distance ~= b.distance then return a.distance < b.distance end
        return a.player < b.player
    end)
    return out
end

--- Vrai si l'attaquant a pu aller, à plat, de `origin` (sa position à la demande, instant `startedAt`) à `position` à
--- l'instant `now` : distance ≤ maxSpeed × durée + margin.
---@param origin table
---@param now integer
---@param startedAt integer
---@param position table
---@param lunge { maxSpeed: number, margin: number }
---@return boolean
function geometry.plausibleMove(origin, now, startedAt, position, lunge)
    if not finite(now) or not finite(startedAt) or type(lunge) ~= 'table' then return false end
    local distance = geometry.flat(origin, position)
    if not distance then return false end
    local elapsed = max(0, now - startedAt)
    return distance <= lunge.maxSpeed * elapsed / 1000 + lunge.margin
end
