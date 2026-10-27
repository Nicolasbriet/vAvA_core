--[[
    vava_inventory/server/viewers.lua
    Rôle : qui regarde quel conteneur. Seuls les joueurs qui ont ouvert un conteneur en reçoivent les différences,
           et uniquement les définitions d'objets qu'ils ne connaissent pas encore. Aucun envoi à tous les joueurs.
    Dépendances : shared/constants.lua, server/items.lua, server/containers.lua
]]

local pairs, ipairs, next = pairs, ipairs, next
local TriggerClientEvent = TriggerClientEvent

local items = VavaInventory.items
local containers = VavaInventory.containers
local EVENTS = VavaInventory.EVENTS

local viewers = {}
VavaInventory.viewers = viewers

-- id de conteneur → { [source] = true }
local byContainer = {}
-- source → { containers = { [id] = true }, known = { [nom d'objet] = true } }
local bySource = {}

---@param src integer
local function sessionOf(src)
    local session = bySource[src]
    if not session then
        session = { containers = {}, known = {} }
        bySource[src] = session
    end
    return session
end

---@param id integer
---@param src integer
function viewers.add(id, src)
    local set = byContainer[id]
    if not set then
        set = {}
        byContainer[id] = set
    end
    set[src] = true
    sessionOf(src).containers[id] = true
end

---@param id integer
---@param src integer
function viewers.remove(id, src)
    local set = byContainer[id]
    if set then
        set[src] = nil
        if next(set) == nil then byContainer[id] = nil end
    end
    local session = bySource[src]
    if session then session.containers[id] = nil end
end

---@param src integer
---@param id integer
---@return boolean
function viewers.isViewing(src, id)
    local set = byContainer[id]
    return set ~= nil and set[src] == true
end

--- Conteneurs ouverts par un joueur.
---@param src integer
---@return integer[]
function viewers.containersOf(src)
    local list = {}
    local session = bySource[src]
    if session then
        for id in pairs(session.containers) do list[#list + 1] = id end
    end
    return list
end

--- Ferme tout ce qu'un joueur regardait (fermeture d'inventaire, déchargement, déconnexion).
---@param src integer
function viewers.removePlayer(src)
    local session = bySource[src]
    if not session then return end
    for id in pairs(session.containers) do viewers.remove(id, src) end
    bySource[src] = nil
end

--- Ferme un conteneur pour tous ses spectateurs (sac vidé ou expiré).
---@param id integer
function viewers.closeContainer(id)
    local set = byContainer[id]
    if not set then return end
    for src in pairs(set) do
        local session = bySource[src]
        if session then session.containers[id] = nil end
        TriggerClientEvent(EVENTS.CLOSED, src, id)
    end
    byContainer[id] = nil
end

--- Définitions des objets que le joueur ne connaît pas encore (marquées connues). `reset` : tout renvoyer.
---@param src integer
---@param instances table[]
---@param reset? boolean
---@return table<string, table>
function viewers.definitionsFor(src, instances, reset)
    local session = sessionOf(src)
    if reset then session.known = {} end
    local definitions = {}
    for _, instance in ipairs(instances) do
        local name = instance.item
        if not session.known[name] then
            local public = items.public(name)
            if public then
                definitions[name] = public
                session.known[name] = true
            end
        end
    end
    return definitions
end

--- Envoie les différences d'un conteneur à ses spectateurs.
---@param container vAvA.Container
---@param changed vAvA.ItemInstance[]
---@param removed integer[]
function viewers.publish(container, changed, removed)
    local set = byContainer[container.id]
    if not set then return end
    local wires = {}
    for i, instance in ipairs(changed) do wires[i] = containers.wire(instance) end
    for src in pairs(set) do
        TriggerClientEvent(EVENTS.DELTA, src, {
            container = container.id, revision = container.revision, weight = container.weight,
            set = wires, removed = removed, definitions = viewers.definitionsFor(src, changed),
        })
    end
end
