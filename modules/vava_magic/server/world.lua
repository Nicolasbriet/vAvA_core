--[[
    vava_magic/server/world.lua
    Rôle : le monde vu par le serveur (OneSync) : ped et position d'un joueur lus côté serveur, vie, véhicule, joueurs
           en jeu proches d'un point et envoi d'un évènement à eux seuls, ped figé (gel), state bags posés sur le ped
           d'un joueur (répliqués aux seuls joueurs proches, jamais à tout le serveur).
    Dépendances : shared/constants.lua, server/core.lua, bridge/server.lua
]]

local ipairs, pairs, sort = ipairs, pairs, table.sort
local GetPlayerPed, GetEntityCoords, DoesEntityExist, GetVehiclePedIsIn, GetEntityHealth, Entity =
    GetPlayerPed, GetEntityCoords, DoesEntityExist, GetVehiclePedIsIn, GetEntityHealth, Entity
local FreezeEntityPosition, TriggerClientEvent = FreezeEntityPosition, TriggerClientEvent

local bridge = VavaMagic.bridge
local geometry = VavaMagic.geometry
local STATES = VavaMagic.STATES

local world = {}
VavaMagic.world = world

---@param src integer
---@return integer|nil
function world.ped(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return ped
end

--- Position du joueur lue côté serveur : { x, y, z }, ou nil.
---@param src integer
---@return table|nil
function world.position(src)
    local ped = world.ped(src)
    if not ped then return nil end
    local coords = GetEntityCoords(ped)
    return { x = coords.x, y = coords.y, z = coords.z }
end

--- Vie brute du ped (points GTA), lue côté serveur.
---@param src integer
---@return integer|nil
function world.health(src)
    local ped = world.ped(src)
    if not ped then return nil end
    return GetEntityHealth(ped)
end

---@param src integer
---@return boolean
function world.inVehicle(src)
    local ped = world.ped(src)
    return ped ~= nil and GetVehiclePedIsIn(ped, false) ~= 0
end

--- Joueurs en jeu à moins de `radius` mètres d'un point, du plus proche au plus loin : { source, position, distance }.
---@param point table
---@param radius number
---@param except? integer  source à écarter
---@return table[]
function world.near(point, radius, except)
    local found = {}
    for _, src in ipairs(bridge.ActivePlayers()) do
        if src ~= except then
            local position = world.position(src)
            if position then
                local distance = geometry.distance(point, position)
                if distance <= radius then found[#found + 1] = { source = src, position = position, distance = distance } end
            end
        end
    end
    sort(found, function(a, b) return a.distance < b.distance end)
    return found
end

--- Fige (ou libère) le ped d'un joueur, côté serveur (état « gelé »).
---@param src integer
---@param frozen boolean
function world.freeze(src, frozen)
    local ped = world.ped(src)
    if ped then FreezeEntityPosition(ped, frozen) end
end

--- Envoie un évènement aux joueurs en jeu proches d'un point.
---@param point table
---@param radius number
---@param event string
function world.broadcast(point, radius, event, ...)
    for _, entry in ipairs(world.near(point, radius)) do
        TriggerClientEvent(event, entry.source, ...)
    end
end

--- Pose (ou retire, avec nil) un state bag sur le ped du joueur.
---@param src integer
---@param key string
---@param value any
function world.setState(src, key, value)
    local ped = world.ped(src)
    if ped then Entity(ped).state:set(key, value, true) end
end

--- Retire tous les effets du module posés sur le ped (départ, changement de personnage).
---@param src integer
function world.clearStates(src)
    local ped = world.ped(src)
    if not ped then return end
    local state = Entity(ped).state
    for _, key in pairs(STATES) do
        if key ~= STATES.ORB then state:set(key, nil, true) end
    end
end
