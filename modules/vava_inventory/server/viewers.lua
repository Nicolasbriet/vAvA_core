--[[
    vava_inventory/server/viewers.lua
    Rôle : qui regarde quel conteneur. Seuls les joueurs qui ont ouvert un conteneur en reçoivent les différences,
           et uniquement les définitions d'objets qu'ils ne connaissent pas encore. Aucun envoi à tous les joueurs.
           Ancrages (depuis 1.4.0) : un module qui ouvre un coffre, un grenier, une station peut l'ancrer à un lieu ;
           la distance est alors revérifiée côté serveur à chaque opération, et un balayage lent, actif seulement tant
           qu'un conteneur ancré est ouvert, ferme le conteneur chez le joueur qui s'en éloigne.
    Dépendances : shared/constants.lua, config.lua, server/positions.lua, server/items.lua, server/containers.lua
]]

local pairs, ipairs, next = pairs, ipairs, next
local TriggerClientEvent, CreateThread, Wait = TriggerClientEvent, CreateThread, Wait

local positions = VavaInventory.positions
local items = VavaInventory.items
local containers = VavaInventory.containers
local EVENTS = VavaInventory.EVENTS
local anchorCfg = VavaInventory.config.anchor

local viewers = {}
VavaInventory.viewers = viewers

-- id de conteneur → { [source] = true }
local byContainer = {}
-- source → { containers = { [id] = true }, known = { [nom d'objet] = true } }
local bySource = {}
-- id de conteneur → { x, y, z, radius } : lieu auquel le module qui l'a ouvert a ancré le conteneur
local anchors = {}
local sweeping = false

---@class vAvA.ContainerAnchor
---@field x number
---@field y number
---@field z number
---@field radius number

--- Ferme un conteneur ancré chez ceux qui s'en sont éloignés. Boucle lente justifiée : une lecture de position par
--- spectateur de conteneur ancré toutes les sweepMs ; s'arrête d'elle-même quand plus aucun conteneur ancré n'est ouvert.
local function sweep()
    while next(anchors) ~= nil do
        Wait(anchorCfg.sweepMs)
        local far = {}
        for id, anchor in pairs(anchors) do
            local set = byContainer[id]
            if set then
                for src in pairs(set) do
                    if not positions.within(src, anchor.x, anchor.y, anchor.z, anchor.radius) then
                        far[#far + 1] = { id = id, src = src }
                    end
                end
            end
        end
        for _, entry in ipairs(far) do
            viewers.remove(entry.id, entry.src)
            TriggerClientEvent(EVENTS.CLOSED, entry.src, entry.id)
        end
    end
    sweeping = false
end

--- Ancre un conteneur à un lieu. L'ancrage disparaît avec son dernier spectateur.
---@param id integer
---@param anchor vAvA.ContainerAnchor
function viewers.anchor(id, anchor)
    anchors[id] = { x = anchor.x, y = anchor.y, z = anchor.z, radius = anchor.radius }
    if not sweeping then
        sweeping = true
        CreateThread(sweep)
    end
end

--- Vrai si la distance autorise le joueur à toucher au conteneur : aucun ancrage, ou joueur à portée.
---@param src integer
---@param id integer
---@return boolean
function viewers.inRange(src, id)
    local anchor = anchors[id]
    if not anchor then return true end
    return positions.within(src, anchor.x, anchor.y, anchor.z, anchor.radius)
end

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
        if next(set) == nil then
            byContainer[id] = nil
            anchors[id] = nil
        end
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
    anchors[id] = nil
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
