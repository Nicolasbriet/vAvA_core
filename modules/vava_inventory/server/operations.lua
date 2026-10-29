--[[
    vava_inventory/server/operations.lua
    Rôle : opérations sur les objets : déplacer, diviser, fusionner, jeter, utiliser, raccourcis, et pour les autres
           modules : échange « tout ou rien » (ajout, retrait, artisanat, boutiques) et écriture des métadonnées.
    Chaque opération : validation → hook before (annulable) → revérification (un hook a pu céder la main) →
    mutation d'un bloc, sans attendre la base → journal → différences aux spectateurs → hook after.
    Métadonnées (1.4.0) : toujours un objet JSON (clés texte à la racine, bornes de config.metadata) ; une pile se
    complète par égalité stricte des métadonnées ; un retrait vise un objet filtré par sous-ensemble de métadonnées,
    ou une pile précise par son identifiant ; les piles se consomment de la plus ancienne à la plus récente.
    Mains (1.4.0) : prendre ou reposer un objet qui se tient en main (hook `vava_inventory:hold`) ; la main se vide
    d'elle-même quand la pile tenue quitte la besace.
    Dépendances : shared/, config.lua, server/core.lua, server/positions.lua, server/items.lua, server/persistence.lua,
                  server/containers.lua, server/viewers.lua, server/drops.lua, server/hands.lua
]]

local type, pairs, ipairs, pcall, tostring, getmetatable = type, pairs, ipairs, pcall, tostring, getmetatable
local mathType, min = math.type, math.min
local HUGE = math.huge
local sort = table.sort
local TriggerClientEvent, GetGameTimer = TriggerClientEvent, GetGameTimer

local grid = VavaInventory.grid
local positions = VavaInventory.positions
local items = VavaInventory.items
local persistence = VavaInventory.persistence
local containers = VavaInventory.containers
local viewers = VavaInventory.viewers
local drops = VavaInventory.drops
local hands = VavaInventory.hands
local cfg = VavaInventory.config
local metaCfg = cfg.metadata
local EVENTS = VavaInventory.EVENTS
local KIND = VavaInventory.KIND
local HOTBAR_FIELD = VavaInventory.HOTBAR_FIELD
local MAX_QUANTITY = VavaInventory.MAX_QUANTITY

local HOOK = {
    MOVE = 'vava_inventory:move', SPLIT = 'vava_inventory:split', MERGE = 'vava_inventory:merge',
    DROP = 'vava_inventory:drop', USE = 'vava_inventory:use', ADD = 'vava_inventory:add', REMOVE = 'vava_inventory:remove',
    METADATA = 'vava_inventory:metadata', HOLD = 'vava_inventory:hold',
}
-- case réservée pendant la planification d'un échange
local PLANNED = -1
-- métadonnées d'une pile qui n'en a pas : comparées par égalité avec celles d'un ajout sans métadonnées
local EMPTY_METADATA = {}
local ANCHOR_KEYS = { 'x', 'y', 'z', 'radius' }

local operations = {}
VavaInventory.operations = operations

---@class vAvA.InventorySession
---@field characterId integer
---@field containerId integer
---@field closeFlushAt? integer  dernière écriture demandée par une fermeture (GetGameTimer)

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

--- Vrai si la valeur respecte le contrat des métadonnées : objet JSON à la racine (clés texte), tables imbriquées
--- soit objets soit listes sans trou, valeurs texte, nombre fini ou booléen, bornes de config.metadata.
--- Une table à clés entières à la racine deviendrait une liste JSON et casserait la colonne `metadata`.
---@param value any
---@param depth integer  1 pour la racine
---@return boolean
local function validMetadata(value, depth)
    if type(value) ~= 'table' or getmetatable(value) ~= nil or depth > metaCfg.maxDepth then return false end
    local count, isList = 0, nil
    for key, item in pairs(value) do
        count = count + 1
        if count > metaCfg.maxEntries then return false end
        if type(key) == 'string' then
            if isList == true then return false end
            isList = false
        elseif depth > 1 and mathType(key) == 'integer' and key >= 1 then
            if isList == false then return false end
            isList = true
        else
            return false
        end
        local kind = type(item)
        if kind == 'string' then
            if #item > metaCfg.maxStringLength then return false end
        elseif kind == 'number' then
            if item ~= item or item == HUGE or item == -HUGE then return false end
        elseif kind == 'table' then
            if not validMetadata(item, depth + 1) then return false end
        elseif kind ~= 'boolean' then
            return false
        end
    end
    if isList then
        for i = 1, count do
            if value[i] == nil then return false end
        end
    end
    return true
end

--- Vrai si la pile porte chaque clé du filtre avec la même valeur (sous-ensemble). Sans filtre : toujours vrai.
---@param metadata table
---@param filter table|nil
---@return boolean
local function matches(metadata, filter)
    if filter == nil then return true end
    if type(filter) ~= 'table' then return false end
    for key, value in pairs(filter) do
        if not deepEqual(metadata[key], value) then return false end
    end
    return true
end

---@param a vAvA.ItemInstance
---@param b vAvA.ItemInstance
---@return boolean
local function olderFirst(a, b)
    return a.id < b.id
end

--- Piles d'un objet répondant au filtre, de la plus ancienne à la plus récente : l'ordre de consommation ne dépend
--- pas du parcours d'une table.
---@param container vAvA.Container
---@param item string
---@param filter table|nil
---@return vAvA.ItemInstance[]
local function candidates(container, item, filter)
    local list = {}
    for _, instance in pairs(container.items) do
        if instance.item == item and matches(instance.metadata, filter) then list[#list + 1] = instance end
    end
    sort(list, olderFirst)
    return list
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
---@param deleted? vAvA.ItemInstance   l'objet parti, quand il n'existe plus (consommé, fusionné, retiré)
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
        if deleted then entry.deleted[#entry.deleted + 1] = deleted end
    end
end

---@param change table
local function publish(change)
    for _, container in ipairs(change.order) do
        local entry = change.entries[container]
        container.revision = container.revision + 1
        for _, instance in ipairs(entry.set) do persistence.touch(instance, container.persisted) end
        -- l'objet lui-même : il ne s'efface de la base que s'il a peut-être sa ligne (pas une pile née au catalogue)
        for _, instance in ipairs(entry.deleted) do persistence.forget(instance) end
        viewers.publish(container, entry.set, entry.removed)
        -- la pile tenue en main a quitté la besace : la main se vide (sync ne connaît que les besaces des joueurs)
        local src, previous = hands.sync(container)
        if src then
            hooks().runAfter(HOOK.HOLD, { source = src, instanceId = 0, previous = previous, reason = 'gone' })
        end
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
    if container.kind == KIND.DROP then return drops.inRange(src, container.id) end
    -- coffre, grenier, station : à portée de l'ancrage posé par le module qui l'a ouvert (sinon toujours vrai)
    return viewers.inRange(src, container.id)
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
    local container = containers.get(containerId)
    if container then hands.bind(src, characterId, container) end
end

---@param src integer
---@return vAvA.InventorySession|nil
function operations.unbind(src)
    local session = sessions[src]
    sessions[src] = nil
    hands.unbind(src)
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
        own = session.containerId, containers = list, hotbar = hotbarOf(session), hands = hands.heldId(src),
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
        if container and container.kind == KIND.DROP and drops.inRange(src, hintId) then
            viewers.add(hintId, src)
        end
    end
    operations.snapshot(src)
    return true
end

---@param anchor any
---@return boolean
local function validAnchor(anchor)
    if type(anchor) ~= 'table' then return false end
    for _, key in ipairs(ANCHOR_KEYS) do
        local value = anchor[key]
        if type(value) ~= 'number' or value ~= value or value == HUGE or value == -HUGE then return false end
    end
    return anchor.radius > 0 and anchor.radius <= cfg.anchor.maxRadius
end

--- Ouvre un conteneur pour un joueur, à la demande d'un module (coffre, grenier, station…). Le module a vérifié le
--- droit d'accès. Avec un ancrage `{ x, y, z, radius }` (1.4.0), la distance est vérifiée ici puis à chaque opération,
--- et le conteneur se ferme chez le joueur qui s'en éloigne.
---@param src integer
---@param container vAvA.Container
---@param anchor? vAvA.ContainerAnchor
---@return boolean ok
---@return string|nil code
function operations.openContainer(src, container, anchor)
    local session = sessions[src]
    if not session then return false, 'no_character' end
    if anchor ~= nil then
        if not validAnchor(anchor) then return false, 'invalid_anchor' end
        if not positions.within(src, anchor.x, anchor.y, anchor.z, anchor.radius) then return false, 'too_far' end
    end
    viewers.add(session.containerId, src)
    viewers.add(container.id, src)
    -- après l'ajout du spectateur : un ancrage sans spectateur serait aussitôt oublié
    if anchor ~= nil then viewers.anchor(container.id, anchor) end
    operations.snapshot(src)
    return true
end

---@param src integer
function operations.close(src)
    local session = sessions[src]
    viewers.removePlayer(src)
    if not session then return end
    -- écriture à la fermeture au plus une fois par flushIntervalMs et par joueur : un client qui alterne geste et
    -- fermeture ne force pas une transaction à chaque fois ; l'écriture groupée régulière rattrape le reste, et le
    -- déchargement du personnage écrit toujours tout
    local now = GetGameTimer()
    if session.closeFlushAt and now - session.closeFlushAt < cfg.flushIntervalMs then return end
    session.closeFlushAt = now
    persistence.flushSoon()
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
        note(change, from, nil, sourceId, source)
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
    if from.kind == KIND.DROP then return false, 'already_dropped' end

    local target = drops.near(src, cfg.drop.reuseDistance)
    local x, y, rotated
    if target and (target.maxWeight == 0 or target.weight + def.weight * quantity <= target.maxWeight) then
        x, y, rotated = grid.findSpace(target, def)
    end
    if not x then
        -- nouveau sac, compté au personnage (plafonds par personnage et du serveur) : refusé, l'objet reste où il est
        local session = sessions[src]
        if not session then return false, 'no_character' end
        local code
        target, code = drops.create(src, session.characterId)
        if not target then return false, code or 'drop_failed' end
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
    if not items.isUsable(def) then
        -- un objet qui se tient en main (outil, torche) sans autre usage : l'utiliser le prend ou le repose
        if def.held then return operations.hold(src, hands.heldId(src) == instanceId and 0 or instanceId) end
        return false, 'not_usable'
    end

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
    local consumed = false
    if consume == true and container.items[instanceId] == instance and containers.get(container.id) == container then
        containers.adjust(container, instance, def, -1)
        local change = newChange()
        if instance.quantity == 0 then
            containers.detach(container, instance, def)
            note(change, container, nil, instanceId, instance)
        else
            note(change, container, instance)
        end
        publish(change)
        consumed = true
    end
    -- ce qui a eu lieu, pas ce que la fonction voulait : objet jeté ou consommé par une autre demande pendant l'attente,
    -- aucune unité retirée, donc aucun effet (faim, soin) à appliquer
    payload.consumed = consumed
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

-- Mains ------------------------------------------------------------------------------------------------------------

--- Prend une pile de sa besace en main (son objet doit déclarer `held`), ou repose ce qu'on tient (0). Hook
--- `vava_inventory:hold` (before annulable : à terre, deux mains prises… ; after). `owner` : ressource à l'origine
--- de la demande, nil pour un geste du joueur.
---@param src integer
---@param instanceId integer  0 pour reposer
---@param owner? string
---@return boolean ok
---@return string|nil code
function operations.hold(src, instanceId, owner)
    local session = sessions[src]
    local container = session and containers.get(session.containerId)
    if not container then return false, 'no_character' end
    if mathType(instanceId) ~= 'integer' or instanceId < 0 then return false, 'invalid_request' end
    local previous = hands.heldId(src)
    local instance, def
    if instanceId ~= 0 then
        instance = container.items[instanceId]
        def = instance and items.get(instance.item)
        if not def then return false, 'not_found' end
        if not def.held then return false, 'not_holdable' end
    end
    if previous == instanceId then return true end

    local payload = { source = src, instanceId = instanceId, item = instance and instance.item or nil, previous = previous, owner = owner }
    local ok, code = guarded(HOOK.HOLD, payload, { container })
    if not ok then return false, code end
    ok, code = hands.set(src, instance, def)
    if not ok then return false, code end
    hooks().runAfter(HOOK.HOLD, payload)
    return true
end

-- Métadonnées (API des autres modules) ---------------------------------------------------------------------------

--- Écrit un nouveau bloc de métadonnées sur une pile (toutes ses unités) : hook before (annulable), écriture,
--- sauvegarde et publication aux spectateurs, hook after. `before` et `after` du payload sont des copies : un autre
--- module peut y protéger un objet signé (créateur, qualité) ou journaliser les objets de valeur.
---@param container vAvA.Container
---@param instance vAvA.ItemInstance
---@param metadata table
---@param owner string          ressource à l'origine de l'écriture
---@param reason 'set'|'patch'
---@return boolean ok
---@return string|nil code
local function writeMetadata(container, instance, metadata, owner, reason)
    local payload = {
        container = container.id, instanceId = instance.id, item = instance.item, owner = owner, reason = reason,
        before = copy(instance.metadata), after = copy(metadata),
    }
    local ok, code = guarded(HOOK.METADATA, payload, { container })
    if not ok then return false, code end
    instance.metadata = copy(metadata)
    local change = newChange()
    note(change, container, instance)
    publish(change)
    hooks().runAfter(HOOK.METADATA, payload)
    return true
end

--- Remplace les métadonnées d'un objet (numéro d'un registre, inscription…), décidé par un module.
---@param container vAvA.Container
---@param instanceId any
---@param metadata any  table (objet JSON), ou nil pour les retirer
---@param owner string
---@return boolean ok
---@return string|nil code
function operations.setMetadata(container, instanceId, metadata, owner)
    if mathType(instanceId) ~= 'integer' then return false, 'invalid_request' end
    if metadata ~= nil and not validMetadata(metadata, 1) then return false, 'invalid_metadata' end
    local instance = container.items[instanceId]
    if not instance then return false, 'not_found' end
    return writeMetadata(container, instance, metadata or {}, owner, 'set')
end

--- Modifie une partie des métadonnées d'un objet : `patch` écrit ou remplace des clés, `removed` en retire (une
--- clé absente d'une table Lua ne peut pas dire « retire-moi »). Le reste du bloc est conservé tel quel : une
--- réparation touche `durability` et `history` sans jamais pouvoir écraser le créateur. Depuis 1.4.0.
---@param container vAvA.Container
---@param instanceId any
---@param patch any    table de clés à écrire, ou nil
---@param removed any  liste de clés à retirer, ou nil
---@param owner string
---@return boolean ok
---@return string|nil code
function operations.patchMetadata(container, instanceId, patch, removed, owner)
    if mathType(instanceId) ~= 'integer' or (patch ~= nil and type(patch) ~= 'table') or (removed ~= nil and type(removed) ~= 'table') then
        return false, 'invalid_request'
    end
    local instance = container.items[instanceId]
    if not instance then return false, 'not_found' end
    local merged = copy(instance.metadata)
    if removed then
        for _, key in ipairs(removed) do
            if type(key) ~= 'string' then return false, 'invalid_request' end
            merged[key] = nil
        end
    end
    if patch then
        for key, value in pairs(patch) do merged[key] = type(value) == 'table' and copy(value) or value end
    end
    if not validMetadata(merged, 1) then return false, 'invalid_metadata' end
    return writeMetadata(container, instance, merged, owner, 'patch')
end

-- Échange tout ou rien (API des autres modules) ---------------------------------------------------------------

---@class vAvA.ItemRequest
---@field item? string          nom de l'objet (ajout : toujours ; retrait : avec `quantity`, filtré par `metadata`)
---@field quantity? integer     retrait par instance : toute la pile si absent
---@field metadata? table       ajout : métadonnées de la pile ; retrait : sous-ensemble que la pile doit porter
---@field instanceId? integer   retrait d'une pile précise (exclusif avec `item` et `metadata`)

---@param list any
---@return boolean
local function validRemovals(list)
    if type(list) ~= 'table' then return false end
    for _, request in ipairs(list) do
        if type(request) ~= 'table' then return false end
        if request.instanceId ~= nil then
            if mathType(request.instanceId) ~= 'integer' or request.item ~= nil or request.metadata ~= nil then return false end
            if request.quantity ~= nil and not isCount(request.quantity) then return false end
        else
            if not items.get(request.item) or not isCount(request.quantity) then return false end
            if request.metadata ~= nil and not validMetadata(request.metadata, 1) then return false end
        end
    end
    return true
end

---@param list any
---@return boolean
local function validAdditions(list)
    if type(list) ~= 'table' then return false end
    for _, request in ipairs(list) do
        if type(request) ~= 'table' or not items.get(request.item) or not isCount(request.quantity) then return false end
        if request.metadata ~= nil and not validMetadata(request.metadata, 1) then return false end
    end
    return true
end

--- Planifie un échange sans rien modifier : retraits, fusions dans les piles existantes, nouvelles piles.
--- Les retraits consomment les piles de la plus ancienne à la plus récente ; les ajouts complètent d'abord les piles
--- aux métadonnées identiques (même règle que la fusion par le joueur), les plus anciennes d'abord.
---@param container vAvA.Container
---@param removals vAvA.ItemRequest[]
---@param additions vAvA.ItemRequest[]
---@return table|nil plan
---@return string|nil code
local function plan(container, removals, additions)
    local takes, fills, places = {}, {}, {}
    local remaining, takeOf = {}, {}
    local weight = container.weight
    local view = { width = container.width, height = container.height, occupancy = {} }
    for index, owner in pairs(container.occupancy) do view.occupancy[index] = owner end

    -- une pile visée deux fois (par instance puis par filtre) n'a qu'une entrée de retrait
    local function take(instance, def, quantity)
        remaining[instance] = (remaining[instance] or instance.quantity) - quantity
        local entry = takeOf[instance]
        if entry then
            entry.quantity = entry.quantity + quantity
        else
            entry = { instance = instance, def = def, quantity = quantity }
            takeOf[instance] = entry
            takes[#takes + 1] = entry
        end
        weight = weight - def.weight * quantity
    end

    for _, request in ipairs(removals) do
        if request.instanceId then
            local instance = container.items[request.instanceId]
            local def = instance and items.get(instance.item)
            if not def then return nil, 'missing_items' end
            local available = remaining[instance] or instance.quantity
            local wanted = request.quantity or available
            if wanted > available then return nil, 'missing_items' end
            take(instance, def, wanted)
        else
            local def = items.get(request.item)
            local needed = request.quantity
            for _, instance in ipairs(candidates(container, request.item, request.metadata)) do
                if needed == 0 then break end
                local amount = min(remaining[instance] or instance.quantity, needed)
                if amount > 0 then
                    take(instance, def, amount)
                    needed = needed - amount
                end
            end
            if needed > 0 then return nil, 'missing_items' end
        end
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
        if def.stack > 1 then
            local wanted = request.metadata or EMPTY_METADATA
            for _, instance in ipairs(candidates(container, request.item, nil)) do
                if left == 0 then break end
                local current = remaining[instance] or instance.quantity
                if current > 0 and deepEqual(instance.metadata, wanted) then
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
    if not validRemovals(removals) or not validAdditions(additions) then return false, 'invalid_request' end
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
            note(change, container, nil, instance.id, instance)
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

--- Vrai si une pile répond au filtre d'un module : `{ item?, metadata? }`, `metadata` étant un sous-ensemble que la
--- pile doit porter. Sans filtre : toujours vrai.
---@param instance vAvA.ItemInstance
---@param filter table|nil
---@return boolean
function operations.matches(instance, filter)
    if filter == nil then return true end
    if filter.item ~= nil and instance.item ~= filter.item then return false end
    return matches(instance.metadata, filter.metadata)
end

--- Quantité totale d'un objet dans un conteneur (hors objets sans place), limitée aux piles portant `metadata`.
---@param container vAvA.Container
---@param item string
---@param metadata? table  sous-ensemble de métadonnées que les piles comptées doivent porter
---@return integer
function operations.count(container, item, metadata)
    local total = 0
    for _, instance in pairs(container.items) do
        if instance.item == item and matches(instance.metadata, metadata) then total = total + instance.quantity end
    end
    return total
end

--- Piles d'un conteneur répondant au filtre, de la plus ancienne à la plus récente.
---@param container vAvA.Container
---@param filter table|nil
---@return vAvA.ItemInstance[]
function operations.select(container, filter)
    local list = {}
    for _, instance in pairs(container.items) do
        if operations.matches(instance, filter) then list[#list + 1] = instance end
    end
    sort(list, olderFirst)
    return list
end
