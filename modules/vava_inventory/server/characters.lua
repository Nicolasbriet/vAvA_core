--[[
    vava_inventory/server/characters.lua
    Rôle : inventaire du personnage, branché sur les hooks du core :
      created   → conteneur créé avec les objets de départ ;
      loaded    → conteneur chargé avant l'apparition (créé s'il manque : personnage antérieur au module), lié au
                  joueur s'il joue toujours ce personnage une fois les requêtes faites ;
      unloading → inventaire fermé (chez son porteur et chez ceux qui le regardaient), journal écrit — y compris ce
                  qu'un module a noté pendant cette écriture —, conteneur libéré (aussi à la déconnexion).
    Dépendances : shared/, config.lua, server/core.lua, server/persistence.lua, server/containers.lua,
                  server/viewers.lua, server/operations.lua
]]

local tostring, tonumber, pairs, ipairs = tostring, tonumber, pairs, ipairs
local GetPlayers = GetPlayers

local persistence = VavaInventory.persistence
local containers = VavaInventory.containers
local viewers = VavaInventory.viewers
local operations = VavaInventory.operations
local cfg = VavaInventory.config
local KIND = VavaInventory.KIND

local OWNER_TYPE = 'character'
-- écritures tentées au déchargement tant que le conteneur a des objets en attente (une base en panne ne bloque pas)
local MAX_UNLOAD_FLUSHES = 3

local characters = {}
VavaInventory.characters = characters

---@param characterId integer
---@return vAvA.Container|nil
---@return string|nil err
local function createFor(characterId)
    local own = cfg.character
    local container, err = containers.create({
        kind = KIND.CHARACTER, ownerType = OWNER_TYPE, ownerId = characterId,
        width = own.width, height = own.height, maxWeight = own.maxWeight, label = own.label,
    })
    if not container then return nil, err end
    if #cfg.startingItems > 0 then
        local ok, code = operations.exchange(container, {}, cfg.startingItems, VavaInventory.resource)
        if not ok then VavaInventory.log.warn('objets de départ non donnés au personnage #%d : %s', characterId, tostring(code)) end
    end
    return container
end

local function onCreated(payload)
    local container, err = createFor(payload.characterId)
    if not container then
        VavaInventory.log.error('inventaire du personnage #%d non créé : %s', payload.characterId, tostring(err))
        return
    end
    -- le personnage n'est pas encore joué : écrit puis libéré, rechargé à sa sélection
    persistence.flush()
    containers.unload(container.id)
end

local function onLoaded(payload)
    local id, err = containers.findOwned(KIND.CHARACTER, OWNER_TYPE, payload.characterId)
    if err then
        VavaInventory.log.error('inventaire du personnage #%d introuvable : %s', payload.characterId, tostring(err))
        return
    end
    local container
    if id then
        container, err = containers.load(id)
    else
        container, err = createFor(payload.characterId)
    end
    if not container then
        VavaInventory.log.error('inventaire du personnage #%d non chargé : %s', payload.characterId, tostring(err))
        return
    end
    -- parti pendant les requêtes : son déchargement est déjà passé sans rien trouver à délier, et ce numéro de joueur
    -- ne doit pas garder une besace (un nouveau venu pourrait le recevoir). Le conteneur reste en mémoire, repris tel
    -- quel au prochain chargement du personnage.
    local character = VavaInventory.core.characters.getActive(payload.source)
    if not character or character.id ~= payload.characterId then return end
    operations.bind(payload.source, payload.characterId, container.id)
end

local function onUnloading(payload)
    local session = operations.unbind(payload.source)
    if not session then return end
    -- fermé aussi chez ceux qui le regardaient (Conseil, fouille) avant l'écriture, qui cède la main : rien n'en sort
    -- pendant qu'il quitte la mémoire, et un rechargement ne leur rend pas l'accès
    local id = session.containerId
    viewers.closeContainer(id)
    -- l'écriture cède la main : un module peut encore toucher au conteneur par son numéro pendant qu'elle part (objet
    -- retiré…). Ce qui a été noté entre-temps part aussi avant le déchargement : sinon un retour du personnage dans
    -- les 3 s relirait la base d'avant ce geste, et l'objet retiré reviendrait
    local passes = 0
    repeat
        persistence.flush()
        passes = passes + 1
    until not persistence.pendingFor(id) or passes >= MAX_UNLOAD_FLUSHES
    if persistence.pendingFor(id) then
        VavaInventory.log.warn('conteneur #%d déchargé avec des écritures encore en attente après %d passes', id, passes)
    end
    containers.unload(id)
end

--- Reprend les personnages déjà joués (module redémarré en cours de partie). Bloque le thread courant.
function characters.adoptActive()
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local character = src and VavaInventory.core.characters.getActive(src)
        if character and not operations.ownContainer(src) then
            onLoaded({ source = src, characterId = character.id })
        end
    end
end

--- Branche les hooks du core. Appelé pendant le setup du module.
---@return boolean ok
---@return string|nil err
function characters.start()
    local hooks = VavaInventory.core.hooks
    for hook, handler in pairs({
        ['core:character:created'] = onCreated,
        ['core:character:loaded'] = onLoaded,
        ['core:character:unloading'] = onUnloading,
    }) do
        local id, err = hooks.after(hook, handler)
        if not id then return false, err end
    end
    return true
end
