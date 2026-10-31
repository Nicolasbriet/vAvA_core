--[[
    vava_combat/shared/heading.lua
    Rôle : cap d'un point vers un autre (client : se tourner vers sa cible ; serveur : geometry.headingTo).
    Dépendances : shared/constants.lua
]]

local type, deg, atan, huge = type, math.deg, math.atan, math.huge

local heading = {}
VavaCombat.heading = heading

local function finite(v)
    return type(v) == 'number' and v == v and v ~= huge and v ~= -huge
end

local function point(p)
    local kind = type(p)
    if kind ~= 'table' and kind ~= 'vector3' and kind ~= 'userdata' then return false end
    return finite(p.x) and finite(p.y) and finite(p.z)
end

--- Cap (0 à 360°, 0 = nord, vers l'ouest) de `from` vers `to`, à plat ; nil au contact ou point illisible.
function heading.to(from, to)
    if not point(from) or not point(to) then return nil end
    local dx, dy = to.x - from.x, to.y - from.y
    if dx * dx + dy * dy < 1e-8 then return nil end
    local h = deg(atan(-dx, dy))
    if h < 0 then h = h + 360 end
    return h
end
