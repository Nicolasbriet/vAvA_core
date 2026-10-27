--[[
    vava_magic/client/aim.lua
    Rôle : visée du joueur, pour les sorts qui en ont besoin : direction de la caméra, point visé à portée du corps
           (rayon contre le décor). Ce n'est qu'une proposition : le serveur revérifie portée et direction.
    Dépendances : shared/geometry.lua
]]

local rad, sin, cos, abs = math.rad, math.sin, math.cos, math.abs
local PlayerPedId, GetEntityCoords, GetGameplayCamRot, GetGameplayCamCoord =
    PlayerPedId, GetEntityCoords, GetGameplayCamRot, GetGameplayCamCoord
local StartExpensiveSynchronousShapeTestLosProbe, GetShapeTestResult =
    StartExpensiveSynchronousShapeTestLosProbe, GetShapeTestResult

local geometry = VavaMagic.geometry
local SHAPE_TEST_WORLD = 1
local ROTATION_ORDER = 2

local aim = {}
VavaMagic.aim = aim

--- Direction de la caméra (vecteur unitaire).
---@return table
function aim.direction()
    local rotation = GetGameplayCamRot(ROTATION_ORDER)
    local pitch, yaw = rad(rotation.x), rad(rotation.z)
    local flat = abs(cos(pitch))
    return { x = -sin(yaw) * flat, y = cos(yaw) * flat, z = sin(pitch) }
end

--- Point visé, à `reach` mètres au plus du corps ; posé `pullback` mètres en deçà d'un mur touché.
---@param reach number
---@param pullback number
---@return table
function aim.point(reach, pullback)
    local ped = PlayerPedId()
    local body = GetEntityCoords(ped)
    local from = GetGameplayCamCoord()
    local direction = aim.direction()
    local length = reach + geometry.distance(from, body)
    local to = { x = from.x + direction.x * length, y = from.y + direction.y * length, z = from.z + direction.z * length }
    local handle = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, SHAPE_TEST_WORLD, ped, 0)
    local _, hit, coords = GetShapeTestResult(handle)
    local point = to
    if hit == 1 or hit == true then
        point = { x = coords.x - direction.x * pullback, y = coords.y - direction.y * pullback, z = coords.z - direction.z * pullback }
    end
    -- ramené à portée du corps (la caméra est derrière le personnage)
    local distance = geometry.distance(body, point)
    local limit = reach - pullback
    if distance > limit then
        local share = limit / distance
        point = { x = body.x + (point.x - body.x) * share, y = body.y + (point.y - body.y) * share, z = body.z + (point.z - body.z) * share }
    end
    return point
end
