--[[
    vava_magic/server/obstacles.lua
    Rôle : obstacles des sorts, décidés par le serveur. Un sort qui dresse quelque chose (rempart) déclare ici de quoi
           dire si un trajet est coupé ; les sorts qui frappent à distance (projectiles, vague, nova, éclats d'un
           impact) demandent si leur trajet est libre avant de toucher. Le noyau ne connaît aucun obstacle par son nom.
    Dépendances : shared/constants.lua
]]

local ipairs, pcall, tostring = ipairs, pcall, tostring

local obstacles = {}
VavaMagic.obstacles = obstacles

---@type (fun(from: table, to: table): table|nil)[]
local checks = {}

--- Déclare un obstacle : `check(from, to)` renvoie le point où le trajet [from, to] est coupé, ou nil.
---@param check fun(from: table, to: table): table|nil
function obstacles.add(check)
    checks[#checks + 1] = check
end

--- Premier point où le trajet [from, to] est coupé (le plus proche de `from`), ou nil s'il est libre.
---@param from table
---@param to table
---@return table|nil
function obstacles.blocked(from, to)
    local nearest, best = nil, math.huge
    for _, check in ipairs(checks) do
        local ok, point = pcall(check, from, to)
        if not ok then
            VavaMagic.log.error('obstacle en erreur : %s', tostring(point))
        elseif point then
            local dx, dy, dz = point.x - from.x, point.y - from.y, point.z - from.z
            local distance = dx * dx + dy * dy + dz * dz
            if distance < best then nearest, best = point, distance end
        end
    end
    return nearest
end
