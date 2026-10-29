--[[
    vava_inventory/server/hands.lua
    Rôle : objet tenu en main par un personnage (1.4.0). C'est une référence vers une pile de sa besace (elle y garde
           sa place et son poids), publiée par le champ public `vava_inventory:hands` :
           { id, item, model, bone, offset, rotation }, dont chaque client fait un accessoire local sur le ped du
           porteur. La main se vide d'elle-même dès que la pile quitte la besace (jetée, déposée, consommée, retirée
           par un module) : operations.lua appelle `sync` après chaque modification d'un conteneur de personnage.
           Le statebag d'un joueur pouvant être écrit par son propre client, la liste des objets tenables (accessoire
           déclaré de chacun) est publiée dans GlobalState, que seul le serveur écrit : chaque client n'affiche que ce
           qui y correspond. Elle suit le registre des objets.
    Dépendances : shared/constants.lua, config.lua, server/core.lua, server/items.lua, server/containers.lua
]]

local type, pairs = type, pairs
local GlobalState = GlobalState

local items = VavaInventory.items
local containers = VavaInventory.containers
local cfg = VavaInventory.config.hands
local HANDS_FIELD = VavaInventory.HANDS_FIELD
local HELD_MODELS = VavaInventory.HELD_MODELS
local REGISTRY = VavaInventory.REGISTRY
local MAX_ID = VavaInventory.MAX_ID

-- accessoire sans décalage ni rotation
local ZERO = { 0.0, 0.0, 0.0 }
local VECTOR = { type = 'array', min = 3, max = 3, items = { type = 'number', min = -360, max = 360 } }

local hands = {}
VavaInventory.hands = hands

--- Schéma du champ public (validé par le core à chaque écriture) ; nil quand les mains sont vides.
hands.SCHEMA = {
    type = 'table', optional = true,
    fields = {
        id = { type = 'integer', min = 1, max = MAX_ID },
        item = { type = 'string', min = 1, max = 64 },
        model = { type = 'string', min = 1, max = 64 },
        bone = { type = 'integer', min = 0, max = 65535 },
        offset = VECTOR,
        rotation = VECTOR,
    },
}

---@class vAvA.HandsState
---@field characterId integer
---@field containerId integer
---@field instanceId integer  0 : mains vides

---@type table<integer, vAvA.HandsState>
local bySource = {}
---@type table<integer, integer>  id de conteneur de personnage → source
local byContainer = {}
---@type table<string, table>  objet tenable → accessoire déclaré { model, bone, offset, rotation } (liste publiée)
local declared = {}

local function characters()
    return VavaInventory.core.characters
end

--- Accessoire d'une déclaration `held`, valeurs par défaut comprises : modèle, os, décalage, rotation.
---@param held table
---@return table
local function propOf(held)
    return { model = held.model, bone = held.bone or cfg.defaultBone, offset = held.offset or ZERO, rotation = held.rotation or ZERO }
end

--- Valeur publiée pour une pile tenue : ce que chaque client a besoin de savoir pour montrer l'accessoire.
---@param instance vAvA.ItemInstance
---@param def vAvA.ItemDefinition
---@return table
local function describe(instance, def)
    local value = propOf(def.held)
    value.id, value.item = instance.id, instance.item
    return value
end

--- Déclare le champ de personnage. Appelé pendant le setup du module.
---@return boolean ok
---@return string|nil err
function hands.define()
    return characters().defineField(HANDS_FIELD, { schema = hands.SCHEMA, visibility = 'public' })
end

--- Objet ajouté (définition) ou retiré (nil) du registre : la liste n'est republiée que pour un objet tenable, ou
--- qui l'était.
---@param key string
---@param def table|nil
local function track(key, def)
    local prop = type(def) == 'table' and type(def.held) == 'table' and propOf(def.held) or nil
    if prop == nil and declared[key] == nil then return end
    declared[key] = prop
    GlobalState[HELD_MODELS] = declared
end

--- Publie les objets tenables déjà déclarés et suit le registre. Appelé pendant le setup du module, après items.define.
---@return boolean ok
---@return string|nil err
function hands.start()
    local core = VavaInventory.core
    declared = {}
    for key, def in pairs(core.registry.all(REGISTRY) or {}) do
        if type(def) == 'table' and type(def.held) == 'table' then declared[key] = propOf(def.held) end
    end
    GlobalState[HELD_MODELS] = declared
    local id, err = core.hooks.after('core:registry:added', function(payload)
        if payload.registry == REGISTRY then track(payload.key, core.registry.get(REGISTRY, payload.key)) end
    end)
    if not id then return false, err end
    id, err = core.hooks.after('core:registry:removed', function(payload)
        if payload.registry == REGISTRY then track(payload.key, nil) end
    end)
    if not id then return false, err end
    return true
end

--- Personnage arrivé : relit sa main. La pile doit encore être dans la besace et son objet se tenir en main (la
--- définition a pu changer, l'objet a pu être retiré hors ligne), sinon la main est vidée. Le champ suit toujours la
--- définition courante (modèle, os).
---@param src integer
---@param characterId integer
---@param container vAvA.Container
function hands.bind(src, characterId, container)
    local state = { characterId = characterId, containerId = container.id, instanceId = 0 }
    bySource[src] = state
    byContainer[container.id] = src
    local stored = characters().get(characterId, HANDS_FIELD)
    local instance = type(stored) == 'table' and container.items[stored.id]
    local def = instance and items.get(instance.item)
    if def and def.held then
        state.instanceId = instance.id
        characters().set(characterId, HANDS_FIELD, describe(instance, def))
    elseif stored ~= nil then
        characters().set(characterId, HANDS_FIELD, nil)
    end
end

---@param src integer
function hands.unbind(src)
    local state = bySource[src]
    if not state then return end
    bySource[src] = nil
    if byContainer[state.containerId] == src then byContainer[state.containerId] = nil end
end

--- Identifiant de la pile tenue, ou 0.
---@param src integer
---@return integer
function hands.heldId(src)
    local state = bySource[src]
    return state and state.instanceId or 0
end

--- Pile tenue, ou nil.
---@param src integer
---@return vAvA.ItemInstance|nil
function hands.instance(src)
    local state = bySource[src]
    if not state or state.instanceId == 0 then return nil end
    local container = containers.get(state.containerId)
    return container and container.items[state.instanceId] or nil
end

--- Écrit la main : une pile (dont l'objet se tient en main) ou nil pour la vider. Les hooks sont tenus par
--- operations.lua, qui a validé la demande.
---@param src integer
---@param instance vAvA.ItemInstance|nil
---@param def vAvA.ItemDefinition|nil
---@return boolean ok
---@return string|nil code
function hands.set(src, instance, def)
    local state = bySource[src]
    if not state then return false, 'no_character' end
    local ok, err = characters().set(state.characterId, HANDS_FIELD, instance and describe(instance, def) or nil)
    if not ok then return false, err end
    state.instanceId = instance and instance.id or 0
    return true
end

--- Après une modification d'un conteneur : si c'est la besace d'un personnage et que la pile tenue n'y est plus, la
--- main se vide. Renvoie le joueur et l'ancienne pile quand c'est le cas (pour le hook `after`), sinon nil.
---@param container vAvA.Container
---@return integer|nil src
---@return integer|nil previous
function hands.sync(container)
    local src = byContainer[container.id]
    local state = src and bySource[src]
    if not state or state.instanceId == 0 or container.items[state.instanceId] then return nil end
    local previous = state.instanceId
    hands.set(src, nil)
    return src, previous
end
