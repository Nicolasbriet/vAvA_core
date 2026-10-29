--[[
    vava_inventory/server/characters.lua
    Rôle : inventaire du personnage, branché sur les hooks du core :
      created   → conteneur créé avec les objets de départ ;
      loaded    → conteneur chargé avant l'apparition (créé s'il manque : personnage antérieur au module), lié au
                  joueur s'il joue toujours ce personnage une fois les requêtes faites ;
      unloading → inventaire fermé (chez son porteur et chez ceux qui le regardaient), journal écrit, conteneur
                  libéré (aussi à la déconnexion).
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
    viewers.closeContainer(session.containerId)
    persistence.flush()
    containers.unload(session.containerId)
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
