--[[
    vava_inventory/server/drops.lua
    Rôle : sacs au sol. Chaque sac est un conteneur temporaire (jamais écrit en base) matérialisé par une entité réseau
           créée par le serveur : OneSync la rend visible aux seuls joueurs proches, sans diffusion maison. Son statebag
           public ne contient que l'id du conteneur. Le sac disparaît vide ou après lifetimeMs (son contenu avec).
    Dépendances : shared/constants.lua, config.lua, server/core.lua, server/containers.lua, server/viewers.lua
]]

local pairs = pairs
local GetPlayerPed, GetEntityCoords, DoesEntityExist, DeleteEntity = GetPlayerPed, GetEntityCoords, DoesEntityExist, DeleteEntity
local CreateObjectNoOffset, FreezeEntityPosition, GetHashKey, SetTimeout, Entity = CreateObjectNoOffset, FreezeEntityPosition, GetHashKey, SetTimeout, Entity

local containers = VavaInventory.containers
local viewers = VavaInventory.viewers
local cfg = VavaInventory.config.drop
local KIND = VavaInventory.KIND
local DROP_STATE = VavaInventory.DROP_STATE
local MODEL = GetHashKey(cfg.model)

local drops = {}
VavaInventory.drops = drops

-- id de conteneur → { entity, x, y, z }
local active = {}

---@param src integer
---@return number|nil x, number|nil y, number|nil z
local function playerPosition(src)
    local ped = GetPlayerPed(src)
    if ped == 0 or not DoesEntityExist(ped) then return nil end
    local coords = GetEntityCoords(ped)
    return coords.x, coords.y, coords.z
end

---@param drop table
---@param x number
---@param y number
---@param z number
---@return number
local function distanceSquared(drop, x, y, z)
    local dx, dy, dz = drop.x - x, drop.y - y, drop.z - z
    return dx * dx + dy * dy + dz * dz
end

--- Retire un sac : spectateurs prévenus, entité supprimée, conteneur oublié.
---@param id integer
function drops.remove(id)
    local drop = active[id]
    if not drop then return end
    active[id] = nil
    viewers.closeContainer(id)
    if DoesEntityExist(drop.entity) then DeleteEntity(drop.entity) end
    containers.unload(id)
end

--- Crée un sac aux pieds du joueur. Synchrone.
---@param src integer
---@return vAvA.Container|nil
function drops.create(src)
    local x, y, z = playerPosition(src)
    if not x then return nil end
    local container = containers.createTransient({
        kind = KIND.DROP, width = cfg.width, height = cfg.height, maxWeight = cfg.maxWeight, label = cfg.label,
    })
    if not container then return nil end
    local groundZ = z - cfg.groundOffset
    local entity = CreateObjectNoOffset(MODEL, x, y, groundZ, true, true, false)
    if entity == 0 then
        containers.unload(container.id)
        return nil
    end
    FreezeEntityPosition(entity, true)
    Entity(entity).state:set(DROP_STATE, container.id, true)
    local drop = { entity = entity, x = x, y = y, z = groundZ }
    active[container.id] = drop
    SetTimeout(cfg.lifetimeMs, function()
        if active[container.id] == drop then drops.remove(container.id) end
    end)
    return container
end

--- Vrai si le joueur est assez près du sac pour s'en servir (position lue côté serveur).
---@param src integer
---@param id integer
---@return boolean
function drops.inRange(src, id)
    local drop = active[id]
    if not drop then return false end
    local x, y, z = playerPosition(src)
    if not x then return false end
    return distanceSquared(drop, x, y, z) <= cfg.interactDistance * cfg.interactDistance
end

--- Sac le plus proche du joueur dans un rayon donné.
---@param src integer
---@param radius number
---@return vAvA.Container|nil
function drops.near(src, radius)
    local x, y, z = playerPosition(src)
    if not x then return nil end
    local bestId, bestDistance = nil, radius * radius
    for id, drop in pairs(active) do
        local distance = distanceSquared(drop, x, y, z)
        if distance <= bestDistance then bestId, bestDistance = id, distance end
    end
    return bestId and containers.get(bestId)
end

--- Supprime le sac s'il est vide (après qu'un objet en a été retiré).
---@param container vAvA.Container
function drops.cleanup(container)
    if container.kind == KIND.DROP and containers.isEmpty(container) then drops.remove(container.id) end
end

--- Supprime tous les sacs (arrêt du module).
function drops.clear()
    for id in pairs(active) do drops.remove(id) end
end
