--[[
    vava_chat/server/audience.lua
    Rôle : qui reçoit un message : les joueurs en jeu à portée (positions lues côté serveur, même monde de routage),
           ou les membres du Conseil en jeu. L'auteur reçoit toujours son propre message.
    Dépendances : server/sessions.lua
]]

local pairs = pairs
local GetPlayerPed, GetEntityCoords, GetPlayerRoutingBucket = GetPlayerPed, GetEntityCoords, GetPlayerRoutingBucket

local sessions = VavaChat.sessions

local audience = {}
VavaChat.audience = audience

--- Joueurs en jeu à moins de `range` mètres de l'auteur (l'auteur en tête).
---@param src integer
---@param range number
---@return integer[]
function audience.nearby(src, range)
    local list = { src }
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return list end
    local origin = GetEntityCoords(ped)
    local bucket = GetPlayerRoutingBucket(src)
    local limit = range * range
    for other in pairs(sessions.all()) do
        if other ~= src then
            local otherPed = GetPlayerPed(other)
            if otherPed and otherPed ~= 0 and GetPlayerRoutingBucket(other) == bucket then
                local coords = GetEntityCoords(otherPed)
                local dx, dy, dz = coords.x - origin.x, coords.y - origin.y, coords.z - origin.z
                if dx * dx + dy * dy + dz * dz <= limit then list[#list + 1] = other end
            end
        end
    end
    return list
end

--- Membres du Conseil en jeu.
---@return integer[]
function audience.staff()
    local list = {}
    for src, session in pairs(sessions.all()) do
        if session.staff then list[#list + 1] = src end
    end
    return list
end
