--[[
    vava_inventory/server/api.lua
    Rôle : exports serveur pour les autres modules (boutiques, artisanat, récolte, butin, coffres de propriétés…).
    Cible d'un appel : un joueur (son personnage actif) ou { container = id }. Les ajouts et retraits sont
    « tout ou rien ». Les fonctions qui chargent un conteneur bloquent le thread de l'appelant.
    Depuis 1.4.0 : retraits et comptages filtrés par métadonnées ou par instance, écriture partielle des métadonnées
    (patchMetadata), filtre de getItems, ancrage d'un conteneur ouvert à un lieu (open), objet tenu en main (held, hold).
    Dépendances : server/core.lua, server/containers.lua, server/operations.lua
]]

local type, ipairs = type, ipairs
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

--- Ajoute un objet. Une pile existante aux métadonnées identiques est complétée d'abord (1.4.0).
exports('add', function(target, item, quantity, metadata)
    return call(target, function(container)
        return operations.exchange(container, {}, { { item = item, quantity = quantity, metadata = metadata } }, GetInvokingResource())
    end)
end)

--- Retire un objet ; avec `metadata`, seules les piles portant ces clés (sous-ensemble) sont consommées (1.4.0).
exports('remove', function(target, item, quantity, metadata)
    return call(target, function(container)
        return operations.exchange(container, { { item = item, quantity = quantity, metadata = metadata } }, {}, GetInvokingResource())
    end)
end)

--- Retire `removals` puis ajoute `additions`, tout ou rien (recette d'artisanat, achat…). Un retrait est
--- `{ item, quantity, metadata? }` ou `{ instanceId, quantity? }` (1.4.0) ; un ajout `{ item, quantity, metadata? }`.
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

--- Quantité d'un objet ; avec `metadata`, seules les piles portant ces clés sont comptées (1.4.0).
exports('count', function(target, item, metadata)
    if metadata ~= nil and type(metadata) ~= 'table' then return 0, 'invalid_request' end
    local container, code = resolve(target)
    if not container then return 0, code end
    return operations.count(container, item, metadata)
end)

--- Remplace les métadonnées d'un objet (numéro d'un registre…) ; nil les retire. Depuis 1.3.0.
exports('setMetadata', function(target, instanceId, metadata)
    return call(target, function(container)
        return operations.setMetadata(container, instanceId, metadata, GetInvokingResource())
    end)
end)

--- Écrit ou remplace les clés de `patch` et retire celles de `removed`, le reste du bloc étant conservé. Depuis 1.4.0.
exports('patchMetadata', function(target, instanceId, patch, removed)
    return call(target, function(container)
        return operations.patchMetadata(container, instanceId, patch, removed, GetInvokingResource())
    end)
end)

--- Objets d'un conteneur (représentation réseau), de la plus ancienne pile à la plus récente, pour l'interface ou la
--- logique d'un autre module. `filter` (1.4.0) : `{ item?, metadata? }`, `metadata` étant un sous-ensemble à porter.
exports('getItems', function(target, filter)
    if filter ~= nil and type(filter) ~= 'table' then return nil, 'invalid_request' end
    local container, code = resolve(target)
    if not container then return nil, code end
    local list = {}
    for i, instance in ipairs(operations.select(container, filter)) do list[i] = containers.wire(instance) end
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

--- Pile tenue en main par le personnage actif d'un joueur (représentation réseau, avec ses métadonnées), ou nil.
--- Depuis 1.4.0.
exports('held', function(source)
    if not VavaInventory.ready then return nil, 'not_ready' end
    if mathType(source) ~= 'integer' then return nil, 'invalid_target' end
    local instance = VavaInventory.hands.instance(source)
    return instance and containers.wire(instance) or nil
end)

--- Fait prendre en main une pile de la besace du joueur (`instanceId`), ou reposer ce qu'il tient (0), à la demande
--- d'un module (outil brisé, désarmement…). Mêmes contrôles et hooks qu'un geste du joueur. Depuis 1.4.0.
exports('hold', function(source, instanceId)
    if not VavaInventory.ready then return false, 'not_ready' end
    if mathType(source) ~= 'integer' then return false, 'invalid_target' end
    local ok, code = operations.hold(source, instanceId, GetInvokingResource())
    return ok, code
end)

--- Ouvre un conteneur à un joueur. L'appelant a vérifié le droit d'accès (propriétaire, clé…). Avec `anchor`
--- `{ x, y, z, radius }` (1.4.0), la distance est vérifiée côté serveur à l'ouverture et à chaque opération, et le
--- conteneur se ferme chez le joueur qui s'en éloigne.
exports('open', function(source, containerId, anchor)
    local container, code = resolve({ container = containerId })
    if not container then return false, code end
    return operations.openContainer(source, container, anchor)
end)
