--[[
    vava_inventory/server/api.lua
    Rôle : exports serveur pour les autres modules (boutiques, artisanat, butin, coffres de propriétés…).
    Cible d'un appel : un joueur (son personnage actif) ou { container = id }. Les ajouts et retraits sont
    « tout ou rien ». Les fonctions qui chargent un conteneur bloquent le thread de l'appelant.
    Dépendances : server/core.lua, server/containers.lua, server/operations.lua
]]

local type, pairs = type, pairs
local mathType = math.type
local GetInvokingResource = GetInvokingResource

local containers = VavaInventory.containers
local operations = VavaInventory.operations

---@param target integer|{ container: integer }
---@return vAvA.Container|nil
---@return string|nil code
local function resolve(target)
    if not VavaInventory.ready then return nil, 'not_ready' end
    if mathType(target) == 'integer' then
        local container = operations.ownContainer(target)
        if not container then return nil, 'no_character' end
        return container
    end
    if type(target) == 'table' and mathType(target.container) == 'integer' then
        local container = containers.get(target.container)
        if container then return container end
        if target.container < 0 then return nil, 'not_found' end
        return containers.load(target.container)
    end
    return nil, 'invalid_target'
end

---@param target any
---@param fn fun(container: vAvA.Container): boolean, string?
---@return boolean ok
---@return string|nil code
local function call(target, fn)
    local container, code = resolve(target)
    if not container then return false, code end
    return fn(container)
end

exports('add', function(target, item, quantity, metadata)
    return call(target, function(container)
        return operations.exchange(container, {}, { { item = item, quantity = quantity, metadata = metadata } }, GetInvokingResource())
    end)
end)

exports('remove', function(target, item, quantity)
    return call(target, function(container)
        return operations.exchange(container, { { item = item, quantity = quantity } }, {}, GetInvokingResource())
    end)
end)

--- Retire `removals` puis ajoute `additions`, tout ou rien (recette d'artisanat, achat…).
exports('exchange', function(target, removals, additions)
    return call(target, function(container)
        return operations.exchange(container, removals or {}, additions or {}, GetInvokingResource())
    end)
end)

exports('canCarry', function(target, item, quantity, metadata)
    return call(target, function(container)
        return operations.exchange(container, {}, { { item = item, quantity = quantity, metadata = metadata } }, GetInvokingResource(), true)
    end)
end)

exports('count', function(target, item)
    local container, code = resolve(target)
    if not container then return 0, code end
    return operations.count(container, item)
end)

--- Remplace les métadonnées d'un objet de la cible (numéro d'un registre…) ; nil les retire. Depuis 1.3.0.
exports('setMetadata', function(target, instanceId, metadata)
    return call(target, function(container)
        return operations.setMetadata(container, instanceId, metadata)
    end)
end)

--- Objets d'un conteneur (représentation réseau), pour l'interface d'un autre module.
exports('getItems', function(target)
    local container, code = resolve(target)
    if not container then return nil, code end
    local list = {}
    for _, instance in pairs(container.items) do list[#list + 1] = containers.wire(instance) end
    return list
end)

--- Crée un conteneur conservé (coffre, coffre de véhicule…) et renvoie son id. Bloque le thread de l'appelant.
exports('createContainer', function(spec)
    if not VavaInventory.ready then return nil, 'not_ready' end
    local container, code = containers.create(spec)
    if not container then return nil, code end
    return container.id
end)

--- Conteneur porté par le personnage actif d'un joueur (fouille, outil d'administration…), à ouvrir avec `open`.
exports('containerOf', function(source)
    if not VavaInventory.ready then return nil, 'not_ready' end
    local container = mathType(source) == 'integer' and operations.ownContainer(source)
    if not container then return nil, 'no_character' end
    return container.id
end)

--- Ouvre un conteneur à un joueur. L'appelant a vérifié que le joueur y a droit (propriétaire, clé, distance…).
exports('open', function(source, containerId)
    local container, code = resolve({ container = containerId })
    if not container then return false, code end
    return operations.openContainer(source, container)
end)
