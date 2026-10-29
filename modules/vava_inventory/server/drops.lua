--[[
    vava_inventory/server/drops.lua
    Rôle : sacs au sol. Chaque sac est un conteneur temporaire (jamais écrit en base) matérialisé par une entité réseau
           créée par le serveur : OneSync la rend visible aux seuls joueurs proches, sans diffusion maison. Son statebag
           public ne contient que l'id du conteneur. Le sac disparaît vide ou après lifetimeMs (son contenu avec).
           Plafonds (config.drop) : sacs encore au sol posés par un même personnage (maxPerPlayer), et sur tout le
           serveur (maxTotal) ; un sac compte de sa pose à sa disparition, que son auteur soit encore là ou non.
    Dépendances : shared/constants.lua, config.lua, server/core.lua, server/positions.lua, server/containers.lua,
                  server/viewers.lua
]]

local pairs = pairs
local DoesEntityExist, DeleteEntity = DoesEntityExist, DeleteEntity
local CreateObjectNoOffset, FreezeEntityPosition, GetHashKey, SetTimeout, Entity = CreateObjectNoOffset, FreezeEntityPosition, GetHashKey, SetTimeout, Entity

local positions = VavaInventory.positions
local containers = VavaInventory.containers
local viewers = VavaInventory.viewers
local cfg = VavaInventory.config.drop
local KIND = VavaInventory.KIND
local DROP_STATE = VavaInventory.DROP_STATE
local MODEL = GetHashKey(cfg.model)
local playerPosition = positions.of

local drops = {}
VavaInventory.drops = drops

-- id de conteneur → { entity, x, y, z, owner }
local active = {}
-- personnage → nombre de ses sacs encore au sol (entrée retirée à zéro) ; nombre de sacs au sol sur le serveur
local perOwner = {}
local total = 0

---@param drop table
---@param x number
---@param y number
---@param z number
---@return number
local function distanceSquared(drop, x, y, z)
    return positions.distanceSquared(drop.x, drop.y, drop.z, x, y, z)
end

--- Retire un sac : spectateurs prévenus, entité supprimée, conteneur oublié.
---@param id integer
function drops.remove(id)
    local drop = active[id]
    if not drop then return end
    active[id] = nil
    total = total - 1
    local left = perOwner[drop.owner] - 1
    perOwner[drop.owner] = left > 0 and left or nil
    viewers.closeContainer(id)
    if DoesEntityExist(drop.entity) then DeleteEntity(drop.entity) end
    containers.unload(id)
end

--- Crée un sac aux pieds du joueur, posé par le personnage `owner`, dans la limite des plafonds. Synchrone.
---@param src integer
---@param owner integer  personnage qui pose le sac
---@return vAvA.Container|nil
---@return string|nil code  too_many_drops (plafond atteint), drop_failed
function drops.create(src, owner)
    if owner == nil then return nil, 'drop_failed' end
    if total >= cfg.maxTotal or (perOwner[owner] or 0) >= cfg.maxPerPlayer then return nil, 'too_many_drops' end
    local x, y, z = playerPosition(src)
    if not x then return nil, 'drop_failed' end
    local container = containers.createTransient({
        kind = KIND.DROP, width = cfg.width, height = cfg.height, maxWeight = cfg.maxWeight, label = cfg.label,
    })
    if not container then return nil, 'drop_failed' end
    local groundZ = z - cfg.groundOffset
    local entity = CreateObjectNoOffset(MODEL, x, y, groundZ, true, true, false)
    if entity == 0 then
        containers.unload(container.id)
        return nil, 'drop_failed'
    end
    FreezeEntityPosition(entity, true)
    Entity(entity).state:set(DROP_STATE, container.id, true)
    local drop = { entity = entity, x = x, y = y, z = groundZ, owner = owner }
    active[container.id] = drop
    total = total + 1
    perOwner[owner] = (perOwner[owner] or 0) + 1
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
