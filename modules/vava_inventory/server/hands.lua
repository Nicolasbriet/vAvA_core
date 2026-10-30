--[[
    vava_inventory/server/hands.lua
    Rôle : objet tenu en main par un personnage (1.4.0). C'est une référence vers une pile de sa besace (elle y garde
           sa place et son poids), notée { id, item } dans le champ `owner` `vava_inventory:hands` (envoyé au seul
           joueur, gardé en base) et publiée sur le statebag du ped du porteur (server/pedstate.lua, 1.7.0), dont
           chaque client qui voit ce ped fait un accessoire local. La main se vide d'elle-même dès que la pile quitte
           la besace (jetée, déposée, consommée, retirée par un module) : operations.lua appelle `sync` après chaque
           modification d'un conteneur de personnage. Une pile tenue gardée à part au chargement faute de définition
           est attendue, puis rendue à la main à son retour (`restore`, 1.6.3).
           Le placement de chaque accessoire (modèle, os, décalage, rotation) n'est jamais publié avec la main : la
           liste des objets tenables est publiée dans GlobalState, que seul le serveur écrit, une fois par tick au plus,
           et chaque client n'affiche qu'un objet qui y figure. Elle suit le registre des objets.
    Dépendances : shared/constants.lua, shared/held.lua, config.lua, server/core.lua, server/items.lua,
                  server/containers.lua, server/pedstate.lua
]]

local type, pairs, ipairs, tonumber = type, pairs, ipairs, tonumber
local GlobalState, SetTimeout, GetPlayers, Player = GlobalState, SetTimeout, GetPlayers, Player

local items = VavaInventory.items
local containers = VavaInventory.containers
local held = VavaInventory.held
local pedState = VavaInventory.pedState
local cfg = VavaInventory.config.hands
local HANDS_FIELD = VavaInventory.HANDS_FIELD
local HELD_MODELS = VavaInventory.HELD_MODELS
local REGISTRY = VavaInventory.REGISTRY
local MAX_ID = VavaInventory.MAX_ID

-- accessoire sans décalage ni rotation
local ZERO = { 0.0, 0.0, 0.0 }

local hands = {}
VavaInventory.hands = hands

--- Schéma du champ (validé par le core à chaque écriture) ; nil quand les mains sont vides. Les valeurs écrites en base
--- avant 1.7.0 portaient aussi le placement : seul `id` en est relu au chargement.
hands.SCHEMA = {
    type = 'table', optional = true,
    fields = {
        id = { type = 'integer', min = 1, max = MAX_ID },
        item = { type = 'string', min = 1, max = 64 },
    },
}

---@class vAvA.HandsState
---@field characterId integer
---@field containerId integer
---@field instanceId integer  0 : mains vides
---@field awaitedId? integer  pile tenue gardée à part au chargement, faute de définition : rendue à la main à son retour

---@type table<integer, vAvA.HandsState>
local bySource = {}
---@type table<integer, integer>  id de conteneur de personnage → source
local byContainer = {}
---@type table<string, table>  objet tenable → accessoire déclaré { model, bone, offset, rotation } (liste publiée)
local declared = {}
-- vrai tant qu'une publication de la liste attend la fin du tick
local declaredDirty = false

local function characters()
    return VavaInventory.core.characters
end

--- Accessoire d'une déclaration `held`, valeurs par défaut comprises : modèle, os, décalage, rotation.
---@param declaration table
---@return table
local function propOf(declaration)
    return { model = declaration.model, bone = declaration.bone or cfg.defaultBone, offset = declaration.offset or ZERO,
        rotation = declaration.rotation or ZERO }
end

--- Valeur publiée pour une pile tenue : { id, item }. Le placement se lit dans la liste des objets tenables.
---@param instance vAvA.ItemInstance
---@return table
local function describe(instance)
    return held.value(instance.id, instance.item)
end

--- Écrit la main : champ du personnage (le joueur, la base) puis statebag de son ped (les joueurs qui le voient).
---@param src integer
---@param characterId integer
---@param value table|nil
---@return boolean ok
---@return string|nil err
local function publish(src, characterId, value)
    local ok, err = characters().set(characterId, HANDS_FIELD, value)
    if not ok then return false, err end
    pedState.set(src, value)
    return true
end

--- Déclare le champ de personnage. Appelé pendant le setup du module.
---@return boolean ok
---@return string|nil err
function hands.define()
    return characters().defineField(HANDS_FIELD, { schema = hands.SCHEMA, visibility = 'owner' })
end

local function publishDeclared()
    declaredDirty = false
    GlobalState[HELD_MODELS] = declared
end

--- Objet ajouté (définition) ou retiré (nil) du registre : la liste n'est republiée que pour un objet tenable, ou
--- qui l'était, et une seule fois pour toutes les déclarations d'un même tick (un module qui déclare vingt objets
--- tenables au démarrage : une écriture, non vingt).
---@param key string
---@param def table|nil
local function track(key, def)
    local prop = type(def) == 'table' and type(def.held) == 'table' and propOf(def.held) or nil
    if prop == nil and declared[key] == nil then return end
    declared[key] = prop
    if declaredDirty then return end
    declaredDirty = true
    SetTimeout(0, publishDeclared)
end

--- Jusqu'en 1.6.x, la main était un champ public, écrit dans le statebag du joueur (répliqué à tous). Après une mise à
--- jour sans redémarrage du serveur, cette ancienne valeur y resterait : elle est effacée une fois, là où elle existe.
local function clearLegacy()
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local state = src and Player(src).state
        if state and state[HANDS_FIELD] ~= nil then state:set(HANDS_FIELD, nil, true) end
    end
end

--- Publie les objets tenables déjà déclarés et suit le registre. Appelé pendant le setup du module, après items.define
--- et hands.define.
---@return boolean ok
---@return string|nil err
function hands.start()
    local core = VavaInventory.core
    declared = {}
    for key, def in pairs(core.registry.all(REGISTRY) or {}) do
        if type(def) == 'table' and type(def.held) == 'table' then declared[key] = propOf(def.held) end
    end
    declaredDirty = false
    GlobalState[HELD_MODELS] = declared
    local ok, err = pedState.start()
    if not ok then return false, err end
    clearLegacy()
    local id
    id, err = core.hooks.after('core:registry:added', function(payload)
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
--- définition a pu changer, l'objet a pu être retiré hors ligne), sinon la main est vidée. Le champ est réécrit au
--- format courant ({ id, item }) et la main publiée sur le ped du joueur. Exception (1.6.3) : une pile gardée à part
--- faute de définition (module qui ne l'a pas encore redéclarée après un redémarrage de l'inventaire) existe
--- toujours ; la main l'attend, champ inchangé, rien de publié sur le ped (aucun client ne pourrait en montrer
--- l'accessoire tant que l'objet n'est pas déclaré tenable), et la reprend à son retour.
---@param src integer
---@param characterId integer
---@param container vAvA.Container
function hands.bind(src, characterId, container)
    local state = { characterId = characterId, containerId = container.id, instanceId = 0 }
    bySource[src] = state
    byContainer[container.id] = src
    local stored = characters().get(characterId, HANDS_FIELD)
    local storedId = type(stored) == 'table' and stored.id
    local instance = storedId and container.items[storedId]
    local def = instance and items.get(instance.item)
    if def and def.held then
        state.instanceId = instance.id
        publish(src, characterId, describe(instance))
        return
    end
    local aside = storedId and not instance and containers.aside(container, storedId)
    if aside and not items.get(aside.item) then
        state.awaitedId = aside.id
        -- un ped qui porterait encore une main d'avant (module redémarré) est vidé
        pedState.set(src, nil)
    else
        if stored ~= nil then characters().set(characterId, HANDS_FIELD, nil) end
        pedState.set(src, nil)
    end
end

--- Définition arrivée pour des piles gardées à part dans une besace (voir containers.returnAside) : la main qui
--- attendait l'une d'elles la reprend si elle est replacée et se tient toujours en main ; sinon elle se vide, comme au
--- chargement (pile restée à part faute de place alors que son objet est connu, objet qui ne se tient plus en main).
--- Elle n'attend encore que si la définition de sa pile manque toujours. Le champ écrit repart vers les clients.
---@param container vAvA.Container
function hands.restore(container)
    local src = byContainer[container.id]
    local state = src and bySource[src]
    if not state or not state.awaitedId then return end
    local instance = container.items[state.awaitedId]
    if not instance then
        local aside = containers.aside(container, state.awaitedId)
        if aside and not items.get(aside.item) then return end
        -- toujours à part faute de place : aucun client ne doit montrer un accessoire que le serveur ne tient pas
        hands.set(src, nil)
        return
    end
    local def = items.get(instance.item)
    -- hands.set efface l'attente une fois le champ écrit
    hands.set(src, def and def.held and instance or nil)
end

--- Personnage déchargé (retour à la sélection, départ) : sa main n'est plus montrée sur le ped du joueur. Le champ
--- garde sa valeur en base, relue au prochain chargement.
---@param src integer
function hands.unbind(src)
    local state = bySource[src]
    if not state then return end
    bySource[src] = nil
    if byContainer[state.containerId] == src then byContainer[state.containerId] = nil end
    pedState.set(src, nil)
    pedState.forget(src)
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
---@return boolean ok
---@return string|nil code
function hands.set(src, instance)
    local state = bySource[src]
    if not state then return false, 'no_character' end
    local ok, err = publish(src, state.characterId, instance and describe(instance) or nil)
    if not ok then return false, err end
    state.instanceId = instance and instance.id or 0
    -- une main écrite n'attend plus rien
    state.awaitedId = nil
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
