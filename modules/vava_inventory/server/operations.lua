--[[
    vava_inventory/server/operations.lua
    Rôle : opérations sur les objets : déplacer, diviser, fusionner, jeter, utiliser, raccourcis, et échange
           « tout ou rien » pour les autres modules (ajout, retrait, artisanat, boutiques).
    Chaque opération : validation → hook before (annulable) → revérification (un hook a pu céder la main) →
    mutation d'un bloc, sans attendre la base → journal → différences aux spectateurs → hook after.
    Dépendances : shared/, config.lua, server/core.lua, server/items.lua, server/persistence.lua,
                  server/containers.lua, server/viewers.lua, server/drops.lua
]]

local type, pairs, ipairs, next, pcall, tostring = type, pairs, ipairs, next, pcall, tostring
local mathType, min = math.type, math.min
local sort = table.sort
local TriggerClientEvent = TriggerClientEvent

local grid = VavaInventory.grid
local items = VavaInventory.items
local persistence = VavaInventory.persistence
local containers = VavaInventory.containers
local viewers = VavaInventory.viewers
local drops = VavaInventory.drops
local cfg = VavaInventory.config
local EVENTS = VavaInventory.EVENTS
local HOTBAR_FIELD = VavaInventory.HOTBAR_FIELD
local MAX_QUANTITY = VavaInventory.MAX_QUANTITY

local HOOK = {
    MOVE = 'vava_inventory:move', SPLIT = 'vava_inventory:split', MERGE = 'vava_inventory:merge',
    DROP = 'vava_inventory:drop', USE = 'vava_inventory:use', ADD = 'vava_inventory:add', REMOVE = 'vava_inventory:remove',
}
-- case réservée pendant la planification d'un échange
local PLANNED = -1

local operations = {}
VavaInventory.operations = operations

---@class vAvA.InventorySession
---@field characterId integer
---@field containerId integer

---@type table<integer, vAvA.InventorySession>
local sessions = {}

local function hooks()
    return VavaInventory.core.hooks
end

---@param src integer
---@param message string
local function notify(src, message)
    TriggerClientEvent(EVENTS.NOTIFY, src, message)
end

---@param value any
---@return boolean
local function isCount(value)
    return mathType(value) == 'integer' and value >= 1 and value <= MAX_QUANTITY
end

---@param a any
---@param b any
---@return boolean
local function deepEqual(a, b)
    if type(a) ~= 'table' or type(b) ~= 'table' then return a == b end
    for key, value in pairs(a) do
        if not deepEqual(value, b[key]) then return false end
    end
    for key in pairs(b) do
        if a[key] == nil then return false end
    end
    return true
end

---@param metadata table|nil
---@return boolean
local function isBare(metadata)
    return metadata == nil or next(metadata) == nil
end

---@param source table
---@return table
local function copy(source)
    local result = {}
    for key, value in pairs(source) do result[key] = type(value) == 'table' and copy(value) or value end
    return result
end

-- Accumulateur de modifications : publiées en une fois, un incrément de révision par conteneur ----------------

local function newChange()
    return { entries = {}, order = {} }
end

---@param change table
---@param container vAvA.Container
---@param instance? vAvA.ItemInstance  objet modifié ou arrivé
---@param removedId? integer           objet parti de ce conteneur
---@param deleted? boolean             l'objet parti n'existe plus
local function note(change, container, instance, removedId, deleted)
    local entry = change.entries[container]
    if not entry then
        entry = { set = {}, removed = {}, deleted = {} }
        change.entries[container] = entry
        change.order[#change.order + 1] = container
    end
    if instance then entry.set[#entry.set + 1] = instance end
    if removedId then
        entry.removed[#entry.removed + 1] = removedId
        if deleted then entry.deleted[#entry.deleted + 1] = removedId end
    end
end

---@param change table
local function publish(change)
    for _, container in ipairs(change.order) do
        local entry = change.entries[container]
        container.revision = container.revision + 1
        for _, instance in ipairs(entry.set) do persistence.touch(instance, container.persisted) end
        for _, id in ipairs(entry.deleted) do persistence.forget(id) end
        viewers.publish(container, entry.set, entry.removed)
    end
end

--- Hook before + revérification : si un conteneur concerné a changé pendant les hooks, l'opération est refusée.
---@param hook string
---@param payload table
---@param involved vAvA.Container[]
---@return boolean ok
---@return string|nil code
local function guarded(hook, payload, involved)
    local revisions = {}
    for i, container in ipairs(involved) do revisions[i] = container.revision end
    local allowed, reason = hooks().runBefore(hook, payload)
    if not allowed then
        return false, (type(reason) == 'string' and reason ~= 'hook_error') and reason or 'refused'
    end
    for i, container in ipairs(involved) do
        if container.revision ~= revisions[i] or containers.get(container.id) ~= container then return false, 'conflict' end
    end
    return true
end

-- Accès -----------------------------------------------------------------------------------------------------

---@param src integer
---@param container vAvA.Container|nil
---@return boolean
local function canOperate(src, container)
    if not container then return false end
    local session = sessions[src]
    if session and session.containerId == container.id then return true end
    if not viewers.isViewing(src, container.id) then return false end
    if container.kind == VavaInventory.KIND.DROP then return drops.inRange(src, container.id) end
    return true
end

--- Objet, conteneur et définition, si le joueur peut y toucher.
---@return vAvA.ItemInstance|nil instance
---@return vAvA.Container|string containerOrCode
---@return vAvA.ItemDefinition|nil def
local function resolve(src, instanceId)
    local container = containers.ofInstance(instanceId)
    if not container then return nil, 'not_found' end
    if not canOperate(src, container) then return nil, 'no_access' end
    local instance = container.items[instanceId]
    local def = instance and items.get(instance.item)
    if not def then return nil, 'unknown_item' end
    return instance, container, def
end

---@param def vAvA.ItemDefinition
---@param from vAvA.Container
---@param to vAvA.Container
---@param x integer
---@param y integer
---@param rotated boolean
---@param quantity integer
---@param ignoreId? integer
---@return boolean ok
---@return string|nil code
local function checkPlacement(def, from, to, x, y, rotated, quantity, ignoreId)
    local w, h = grid.footprint(def, rotated)
    if not grid.fits(to, w, h, x, y, ignoreId) then return false, 'no_space' end
    if to ~= from and to.maxWeight > 0 and to.weight + def.weight * quantity > to.maxWeight then return false, 'too_heavy' end
    return true
end

-- Sessions et ouverture --------------------------------------------------------------------------------------

---@param src integer
---@param characterId integer
---@param containerId integer
function operations.bind(src, characterId, containerId)
    sessions[src] = { characterId = characterId, containerId = containerId }
end

---@param src integer
---@return vAvA.InventorySession|nil
function operations.unbind(src)
    local session = sessions[src]
    sessions[src] = nil
    viewers.removePlayer(src)
    return session
end

---@param src integer
---@return vAvA.Container|nil
function operations.ownContainer(src)
    local session = sessions[src]
    return session and containers.get(session.containerId)
end

---@param session vAvA.InventorySession
---@return integer[]
local function hotbarOf(session)
    local stored = VavaInventory.core.characters.get(session.characterId, HOTBAR_FIELD)
    local bar = {}
    for i = 1, cfg.hotbarSize do bar[i] = type(stored) == 'table' and stored[i] or 0 end
    return bar
end

--- Envoie au joueur l'état de tout ce qu'il a ouvert (son inventaire d'abord), avec les définitions nécessaires.
---@param src integer
function operations.snapshot(src)
    local session = sessions[src]
    if not session then return end
    local list, instances = {}, {}
    local ids = viewers.containersOf(src)
    sort(ids, function(a, b)
        if a == session.containerId then return true end
        if b == session.containerId then return false end
        return a < b
    end)
    for _, id in ipairs(ids) do
        local container = containers.get(id)
        if container then
            list[#list + 1] = containers.describe(container)
            for _, instance in pairs(container.items) do instances[#instances + 1] = instance end
        end
    end
    TriggerClientEvent(EVENTS.SNAPSHOT, src, {
        own = session.containerId, containers = list, hotbar = hotbarOf(session),
        definitions = viewers.definitionsFor(src, instances, true),
    })
end

--- Ouvre l'inventaire du joueur, et un sac au sol proche s'il en désigne un (distance vérifiée ici).
---@param src integer
---@param hintId integer  0 si aucun
---@return boolean ok
---@return string|nil code
function operations.open(src, hintId)
    local session = sessions[src]
    if not session then return false, 'no_character' end
    viewers.add(session.containerId, src)
    if hintId ~= 0 then
        local container = containers.get(hintId)
        if container and container.kind == VavaInventory.KIND.DROP and drops.inRange(src, hintId) then
            viewers.add(hintId, src)
        end
    end
    operations.snapshot(src)
    return true
end

--- Ouvre un conteneur pour un joueur, à la demande d'un module (coffre, magasin…). Le module a vérifié l'accès.
---@param src integer
---@param container vAvA.Container
---@return boolean ok
---@return string|nil code
function operations.openContainer(src, container)
    local session = sessions[src]
    if not session then return false, 'no_character' end
    viewers.add(session.containerId, src)
    viewers.add(container.id, src)
    operations.snapshot(src)
    return true
end

---@param src integer
function operations.close(src)
    local session = sessions[src]
    viewers.removePlayer(src)
    if session then persistence.flushSoon() end
end

-- Opérations du joueur ---------------------------------------------------------------------------------------

---@return boolean ok
---@return string|nil code
function operations.move(src, instanceId, toId, x, y, rotated)
    local instance, from, def = resolve(src, instanceId)
    if not instance then return false, from end
    local to = containers.get(toId)
    if not canOperate(src, to) then return false, to and 'no_access' or 'not_found' end
    local ok, code = checkPlacement(def, from, to, x, y, rotated, instance.quantity, to == from and instanceId or nil)
    if not ok then return false, code end

    local payload = { source = src, instanceId = instanceId, item = instance.item, quantity = instance.quantity, from = from.id, to = to.id }
    ok, code = guarded(HOOK.MOVE, payload, { from, to })
    if not ok then return false, code end

    containers.detach(from, instance, def)
    instance.x, instance.y, instance.rotated = x, y, rotated
    containers.attach(to, instance, def)
    local change = newChange()
    if from ~= to then note(change, from, nil, instanceId) end
    note(change, to, instance)
    publish(change)
    hooks().runAfter(HOOK.MOVE, payload)
    drops.cleanup(from)
    return true
end

---@return boolean ok
---@return string|nil code
function operations.split(src, instanceId, quantity, toId, x, y, rotated)
    local instance, from, def = resolve(src, instanceId)
    if not instance then return false, from end
    if def.stack <= 1 then return false, 'not_stackable' end
    if not isCount(quantity) or quantity >= instance.quantity then return false, 'invalid_quantity' end
    local to = containers.get(toId)
    if not canOperate(src, to) then return false, to and 'no_access' or 'not_found' end
    local ok, code = checkPlacement(def, from, to, x, y, rotated, quantity, nil)
    if not ok then return false, code end

    local payload = { source = src, instanceId = instanceId, item = instance.item, quantity = quantity, from = from.id, to = to.id }
    ok, code = guarded(HOOK.SPLIT, payload, { from, to })
    if not ok then return false, code end

    containers.adjust(from, instance, def, -quantity)
    local part = {
        id = containers.nextInstanceId(), item = instance.item, x = x, y = y, rotated = rotated,
        quantity = quantity, metadata = copy(instance.metadata),
    }
    containers.attach(to, part, def)
    local change = newChange()
    note(change, from, instance)
    note(change, to, part)
    publish(change)
    payload.newInstanceId = part.id
    hooks().runAfter(HOOK.SPLIT, payload)
    return true
end

---@return boolean ok
---@return string|nil code
function operations.merge(src, sourceId, targetId, quantity)
    if sourceId == targetId then return false, 'invalid_target' end
    local source, from, def = resolve(src, sourceId)
    if not source then return false, from end
    local target, into = resolve(src, targetId)
    if not target then return false, into end
    if source.item ~= target.item or def.stack <= 1 or not deepEqual(source.metadata, target.metadata) then
        return false, 'not_stackable'
    end
    if quantity ~= nil and not isCount(quantity) then return false, 'invalid_quantity' end
    local amount = min(quantity or source.quantity, source.quantity, def.stack - target.quantity)
    if amount < 1 then return false, 'stack_full' end
    if into ~= from and into.maxWeight > 0 and into.weight + def.weight * amount > into.maxWeight then return false, 'too_heavy' end

    local payload = { source = src, instanceId = sourceId, targetId = targetId, item = source.item, quantity = amount, from = from.id, to = into.id }
    local ok, code = guarded(HOOK.MERGE, payload, { from, into })
    if not ok then return false, code end

    containers.adjust(into, target, def, amount)
    containers.adjust(from, source, def, -amount)
    local change = newChange()
    if source.quantity == 0 then
        containers.detach(from, source, def)
        note(change, from, nil, sourceId, true)
    else
        note(change, from, source)
    end
    note(change, into, target)
    publish(change)
    hooks().runAfter(HOOK.MERGE, payload)
    drops.cleanup(from)
    return true
end

--- Jette tout ou partie d'une pile dans un sac au sol (le plus proche s'il a la place, sinon un nouveau).
---@return boolean ok
---@return string|nil code
function operations.drop(src, instanceId, quantity)
    local instance, from, def = resolve(src, instanceId)
    if not instance then return false, from end
    quantity = quantity or instance.quantity
    if not isCount(quantity) or quantity > instance.quantity then return false, 'invalid_quantity' end
    if from.kind == VavaInventory.KIND.DROP then return false, 'already_dropped' end

    local target = drops.near(src, cfg.drop.reuseDistance)
    local x, y, rotated
    if target and (target.maxWeight == 0 or target.weight + def.weight * quantity <= target.maxWeight) then
        x, y, rotated = grid.findSpace(target, def)
    end
    if not x then
        target = drops.create(src)
        if not target then return false, 'drop_failed' end
        x, y, rotated = grid.findSpace(target, def)
        if not x or (target.maxWeight > 0 and def.weight * quantity > target.maxWeight) then
            drops.cleanup(target)
            return false, 'too_big'
        end
    end

    local payload = { source = src, instanceId = instanceId, item = instance.item, quantity = quantity, from = from.id, to = target.id }
    local ok, code = guarded(HOOK.DROP, payload, { from, target })
    if not ok then
        drops.cleanup(target)
        return false, code
    end

    local change = newChange()
    if quantity == instance.quantity then
        containers.detach(from, instance, def)
        instance.x, instance.y, instance.rotated = x, y, rotated
        containers.attach(target, instance, def)
        note(change, from, nil, instanceId)
        note(change, target, instance)
    else
        containers.adjust(from, instance, def, -quantity)
        local part = {
            id = containers.nextInstanceId(), item = instance.item, x = x, y = y, rotated = rotated,
            quantity = quantity, metadata = copy(instance.metadata),
        }
        containers.attach(target, part, def)
        note(change, from, instance)
        note(change, target, part)
    end
    publish(change)
    -- inventaire ouvert : le sac apparaît aussitôt à côté
    if viewers.isViewing(src, from.id) and not viewers.isViewing(src, target.id) then
        viewers.add(target.id, src)
        operations.snapshot(src)
    end
    hooks().runAfter(HOOK.DROP, payload)
    return true
end

--- Utilise un objet de son propre inventaire. La fonction du module déclarant décide de la consommation.
---@return boolean ok
---@return string|nil code
function operations.use(src, instanceId)
    local session = sessions[src]
    local container = containers.ofInstance(instanceId)
    if not session or not container or container.id ~= session.containerId then return false, 'no_access' end
    local instance = container.items[instanceId]
    local def = instance and items.get(instance.item)
    if not def then return false, 'unknown_item' end
    if not items.isUsable(def) then return false, 'not_usable' end

    -- effets et catégorie : les modules qui appliquent les effets (faim, soif…) n'ont pas à relire le registre
    local payload = { source = src, instanceId = instanceId, item = instance.item, category = def.category, effects = def.effects }
    local ok, code = guarded(HOOK.USE, payload, { container })
    -- troisième valeur : refus rédigé par un module, à montrer au joueur
    if not ok then return false, code, code ~= 'refused' and code ~= 'conflict' end

    -- sans fonction d'utilisation, l'objet n'a que des effets : une unité est consommée
    local consume, message = true, nil
    if def.onUse then
        local called
        called, consume, message = pcall(def.onUse, src, containers.wire(instance))
        if not called then
            VavaInventory.log.error("utilisation de '%s' en erreur : %s", instance.item, tostring(consume))
            return false, 'use_failed'
        end
    end
    if type(message) == 'string' then notify(src, message) end
    -- la fonction a pu céder la main : l'objet doit toujours être là pour être consommé
    if consume == true and container.items[instanceId] == instance and containers.get(container.id) == container then
        containers.adjust(container, instance, def, -1)
        local change = newChange()
        if instance.quantity == 0 then
            containers.detach(container, instance, def)
            note(change, container, nil, instanceId, true)
        else
            note(change, container, instance)
        end
        publish(change)
    end
    payload.consumed = consume == true
    hooks().runAfter(HOOK.USE, payload)
    return true
end

--- Assigne un objet de son inventaire à un raccourci (0 = vider). Un objet n'occupe qu'un raccourci.
---@return boolean ok
---@return string|nil code
function operations.hotbarSet(src, slot, instanceId)
    local session = sessions[src]
    if not session then return false, 'no_character' end
    if instanceId ~= 0 then
        local container = containers.ofInstance(instanceId)
        if not container or container.id ~= session.containerId then return false, 'no_access' end
    end
    local bar = hotbarOf(session)
    for i = 1, cfg.hotbarSize do
        if instanceId ~= 0 and bar[i] == instanceId then bar[i] = 0 end
    end
    bar[slot] = instanceId
    return VavaInventory.core.characters.set(session.characterId, HOTBAR_FIELD, bar)
end

---@return boolean ok
---@return string|nil code
function operations.hotbarUse(src, slot)
    local session = sessions[src]
    if not session then return false, 'no_character' end
    local instanceId = hotbarOf(session)[slot]
    if not instanceId or instanceId == 0 then return false, 'empty_slot' end
    local ok, code, readable = operations.use(src, instanceId)
    -- un raccourci s'utilise hors de l'interface : le refus d'un module passe par une notification
    if not ok and readable then notify(src, code) end
    return ok, code
end

--- Remplace les métadonnées d'un objet (numéro d'un registre, inscription…), décidé par un module. Sauvegardé et
--- publié aux spectateurs comme toute modification.
---@param container vAvA.Container
---@param instanceId any
---@param metadata any  table, ou nil pour les retirer
---@return boolean ok
---@return string|nil code
function operations.setMetadata(container, instanceId, metadata)
    if mathType(instanceId) ~= 'integer' or (metadata ~= nil and type(metadata) ~= 'table') then return false, 'invalid_request' end
    local instance = container.items[instanceId]
    if not instance then return false, 'not_found' end
    instance.metadata = metadata and copy(metadata) or {}
    local change = newChange()
    note(change, container, instance)
    publish(change)
    return true
end

-- Échange tout ou rien (API des autres modules) ---------------------------------------------------------------

---@class vAvA.ItemRequest
---@field item string
---@field quantity integer
---@field metadata? table

---@param list any
---@param withMetadata boolean
---@return boolean
local function validRequests(list, withMetadata)
    if type(list) ~= 'table' then return false end
    for _, request in ipairs(list) do
        if type(request) ~= 'table' or not items.get(request.item) or not isCount(request.quantity) then return false end
        if withMetadata and request.metadata ~= nil and type(request.metadata) ~= 'table' then return false end
    end
    return true
end

--- Planifie un échange sans rien modifier : retraits, fusions dans les piles existantes, nouvelles piles.
---@param container vAvA.Container
---@param removals vAvA.ItemRequest[]
---@param additions vAvA.ItemRequest[]
---@return table|nil plan
---@return string|nil code
local function plan(container, removals, additions)
    local takes, fills, places = {}, {}, {}
    local remaining = {}
    local weight = container.weight
    local view = { width = container.width, height = container.height, occupancy = {} }
    for index, owner in pairs(container.occupancy) do view.occupancy[index] = owner end

    for _, request in ipairs(removals) do
        local def = items.get(request.item)
        local needed = request.quantity
        for _, instance in pairs(container.items) do
            if needed == 0 then break end
            if instance.item == request.item then
                local available = (remaining[instance] or instance.quantity)
                local take = min(available, needed)
                if take > 0 then
                    remaining[instance] = available - take
                    takes[#takes + 1] = { instance = instance, def = def, quantity = take }
                    needed = needed - take
                    weight = weight - def.weight * take
                end
            end
        end
        if needed > 0 then return nil, 'missing_items' end
    end
    -- les piles entièrement retirées libèrent leurs cases pour les ajouts
    for instance, left in pairs(remaining) do
        if left == 0 then
            local w, h = grid.footprint(items.get(instance.item), instance.rotated)
            grid.unmark(view, w, h, instance.x, instance.y, instance.id)
        end
    end

    for _, request in ipairs(additions) do
        local def = items.get(request.item)
        local left = request.quantity
        weight = weight + def.weight * left
        if def.stack > 1 and isBare(request.metadata) then
            for _, instance in pairs(container.items) do
                if left == 0 then break end
                local current = remaining[instance] or instance.quantity
                if instance.item == request.item and current > 0 and isBare(instance.metadata) then
                    local extra = fills[instance] or 0
                    local room = def.stack - current - extra
                    if room > 0 then
                        local put = min(room, left)
                        fills[instance] = extra + put
                        left = left - put
                    end
                end
            end
        end
        while left > 0 do
            local x, y, rotated = grid.findSpace(view, def)
            if not x then return nil, 'no_space' end
            local put = min(left, def.stack)
            local w, h = grid.footprint(def, rotated)
            grid.mark(view, w, h, x, y, PLANNED)
            places[#places + 1] = { def = def, item = request.item, x = x, y = y, rotated = rotated, quantity = put, metadata = request.metadata }
            left = left - put
        end
    end
    if container.maxWeight > 0 and weight > container.maxWeight then return nil, 'too_heavy' end
    return { takes = takes, fills = fills, places = places }
end

--- Retire puis ajoute des objets dans un conteneur, tout ou rien. `dryRun` : vérifie seulement.
---@param container vAvA.Container
---@param removals vAvA.ItemRequest[]
---@param additions vAvA.ItemRequest[]
---@param owner string   ressource à l'origine de l'échange (transmise aux hooks)
---@param dryRun? boolean
---@return boolean ok
---@return string|nil code
function operations.exchange(container, removals, additions, owner, dryRun)
    if not validRequests(removals, false) or not validRequests(additions, true) then return false, 'invalid_request' end
    if dryRun then
        local planned, code = plan(container, removals, additions)
        return planned ~= nil, code
    end

    local payload = { container = container.id, removals = removals, additions = additions, owner = owner }
    if #removals > 0 then
        local ok, code = guarded(HOOK.REMOVE, payload, { container })
        if not ok then return false, code end
    end
    if #additions > 0 then
        local ok, code = guarded(HOOK.ADD, payload, { container })
        if not ok then return false, code end
    end
    -- après les hooks : planification puis application sans aucune attente, donc sans conflit possible
    local planned, code = plan(container, removals, additions)
    if not planned then return false, code end

    local change = newChange()
    for _, take in ipairs(planned.takes) do
        local instance = take.instance
        containers.adjust(container, instance, take.def, -take.quantity)
        if instance.quantity == 0 then
            containers.detach(container, instance, take.def)
            note(change, container, nil, instance.id, true)
        end
    end
    for instance, extra in pairs(planned.fills) do
        containers.adjust(container, instance, items.get(instance.item), extra)
    end
    for _, take in ipairs(planned.takes) do
        if take.instance.quantity > 0 and planned.fills[take.instance] == nil then note(change, container, take.instance) end
    end
    for instance in pairs(planned.fills) do note(change, container, instance) end
    for _, place in ipairs(planned.places) do
        local instance = {
            id = containers.nextInstanceId(), item = place.item, x = place.x, y = place.y, rotated = place.rotated,
            quantity = place.quantity, metadata = place.metadata and copy(place.metadata) or {},
        }
        containers.attach(container, instance, place.def)
        note(change, container, instance)
    end
    publish(change)
    if #removals > 0 then hooks().runAfter(HOOK.REMOVE, payload) end
    if #additions > 0 then hooks().runAfter(HOOK.ADD, payload) end
    return true
end

--- Quantité totale d'un objet dans un conteneur (hors objets sans place).
---@param container vAvA.Container
---@param item string
---@return integer
function operations.count(container, item)
    local total = 0
    for _, instance in pairs(container.items) do
        if instance.item == item then total = total + instance.quantity end
    end
    return total
end
