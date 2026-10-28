--[[
    vava_farming/bridge/server.lua
    Rôle : SEUL point de contact, côté serveur, entre l'agriculture et le core / les autres modules : personnage et
           compte, position lue côté serveur, inventaire (objet en main, piles, comptage, échange atomique, ajout, retrait,
           métadonnées, conteneurs conservés et leur ouverture ancrée, déclaration des objets), compétences (XP, niveau),
           artisanat (type de station, recette et station du composteur), droits et journal du Conseil, notifications,
           chat, base. Chaque appel à une autre ressource est isolé.
    Dépendances : shared/constants.lua, config.lua, server/core.lua
]]

local type, pairs, pcall, tostring, tonumber = type, pairs, pcall, tostring, tonumber
local mathType = math.type
local pack, unpack, concat = table.pack, table.unpack, table.concat
local GetResourceState, TriggerClientEvent, IsPlayerAceAllowed = GetResourceState, TriggerClientEvent, IsPlayerAceAllowed
local GetPlayerPed, DoesEntityExist, GetEntityCoords = GetPlayerPed, DoesEntityExist, GetEntityCoords

local core = VavaFarming.core
if not core then return end

local cfg = VavaFarming.config
local EVENTS = VavaFarming.EVENTS
local CONSOLE = 0
local INVENTORY, SKILLS, CRAFTING, ADMIN, CHAT = 'vava_inventory', 'vava_skills', 'vava_crafting', 'vava_admin', 'vava_chat'
local ITEMS_REGISTRY = 'vava_inventory:items'
local STATIONS_REGISTRY = 'vava_crafting:stations'
local RECIPES_REGISTRY = 'vava_crafting:recipes'

local Bridge = {}
VavaFarming.bridge = Bridge

local function invoke(resource, fn, ...)
    local target = exports[resource]
    return target[fn](target, ...)
end

---@return boolean called
local function call(resource, fn, ...)
    if GetResourceState(resource) ~= 'started' then return false end
    local results = pack(pcall(invoke, resource, fn, ...))
    if not results[1] then
        VavaFarming.log.warn('%s.%s en erreur : %s', resource, fn, tostring(results[2]))
        return false
    end
    return true, unpack(results, 2, results.n)
end

-- Personnage ----------------------------------------------------------------------------------------------------

---@param source integer
---@return table|nil
function Bridge.GetCharacter(source)
    local session = core.players.get(source)
    if not session or session.state ~= 'active' then return nil end
    return core.characters.getActive(source)
end

---@param source integer
---@return integer|nil
function Bridge.GetCharacterId(source)
    local character = Bridge.GetCharacter(source)
    return character and character.id or nil
end

---@param source integer
---@return integer|nil
function Bridge.GetAccountId(source)
    local session = core.players.get(source)
    return session and session.accountId or nil
end

---@param source integer
---@return string|nil
function Bridge.GetCharacterName(source)
    local character = Bridge.GetCharacter(source)
    return character and (character.firstName .. ' ' .. character.lastName) or nil
end

---@param source integer
---@return number|nil x, number|nil y, number|nil z
function Bridge.Position(source)
    local ped = GetPlayerPed(source)
    if ped == 0 or not DoesEntityExist(ped) then return nil end
    local coords = GetEntityCoords(ped)
    return coords.x, coords.y, coords.z
end

-- Inventaire ------------------------------------------------------------------------------------------------------

---@param source integer
---@return table|nil
function Bridge.Held(source)
    local called, instance = call(INVENTORY, 'held', source)
    return called and type(instance) == 'table' and instance or nil
end

---@param source integer
---@param filter table|nil
---@return table[]
function Bridge.Items(source, filter)
    local called, list = call(INVENTORY, 'getItems', source, filter)
    return (called and type(list) == 'table') and list or {}
end

---@return integer
function Bridge.Count(source, item, metadata)
    local called, count = call(INVENTORY, 'count', source, item, metadata)
    return (called and mathType(count) == 'integer') and count or 0
end

---@return boolean ok
---@return string|nil code
function Bridge.CanCarry(source, item, quantity, metadata)
    local called, ok, code = call(INVENTORY, 'canCarry', source, item, quantity, metadata)
    if not called then return false, 'inventory_unavailable' end
    return ok == true, code
end

---@return boolean ok
---@return string|nil code
function Bridge.Exchange(source, removals, additions)
    local called, ok, code = call(INVENTORY, 'exchange', source, removals, additions)
    if not called then return false, 'inventory_unavailable' end
    return ok == true, code
end

---@return boolean ok
---@return string|nil code
function Bridge.Add(source, item, quantity, metadata)
    local called, ok, code = call(INVENTORY, 'add', source, item, quantity, metadata)
    if not called then return false, 'inventory_unavailable' end
    return ok == true, code
end

---@return boolean ok
function Bridge.PatchMetadata(source, instanceId, patch, removed)
    local called, ok = call(INVENTORY, 'patchMetadata', source, instanceId, patch, removed)
    return called and ok == true
end

--- Crée un conteneur conservé (grenier). Bloque le thread courant.
---@return integer|nil id
---@return string|nil code
function Bridge.CreateContainer(spec)
    local called, id, code = call(INVENTORY, 'createContainer', spec)
    if not called then return nil, 'inventory_unavailable' end
    if mathType(id) ~= 'integer' then return nil, code or 'create_failed' end
    return id
end

--- Ouvre un conteneur au joueur, ancré à un lieu.
---@return boolean ok
---@return string|nil code
function Bridge.OpenContainer(source, containerId, anchor)
    local called, ok, code = call(INVENTORY, 'open', source, containerId, anchor)
    if not called then return false, 'inventory_unavailable' end
    return ok == true, code
end

---@param name string
---@param definition table
---@return boolean declared
function Bridge.DeclareItem(name, definition)
    local registry = core.registry
    if not registry.exists(ITEMS_REGISTRY) or registry.has(ITEMS_REGISTRY, name) then return false end
    local ok, err = registry.add(ITEMS_REGISTRY, name, definition)
    if not ok then VavaFarming.log.warn("objet '%s' non déclaré : %s", name, tostring(err)) end
    return ok == true
end

---@param name string
---@return table|nil
function Bridge.ItemDefinition(name)
    if not core.registry.exists(ITEMS_REGISTRY) then return nil end
    return core.registry.get(ITEMS_REGISTRY, name)
end

-- Compétences -----------------------------------------------------------------------------------------------------

---@return boolean ok
---@return table|string result
function Bridge.AddXp(source, ctx)
    local called, ok, result = call(SKILLS, 'addXp', source, ctx)
    if not called then return false, 'skills_unavailable' end
    return ok == true, result
end

---@param source integer
---@param skill string
---@return integer
function Bridge.GetLevel(source, skill)
    local called, level = call(SKILLS, 'getLevel', source, skill)
    return (called and mathType(level) == 'integer') and level or 0
end

-- Artisanat (composteur) ----------------------------------------------------------------------------------------------

--- Déclare le type de station et la recette du composteur aux registres de l'artisanat, puis place la station.
---@param composter table  config.composter
---@return boolean ok
---@return string|nil err
function Bridge.DeclareComposter(composter)
    local registry = core.registry
    if not registry.exists(STATIONS_REGISTRY) or not registry.exists(RECIPES_REGISTRY) then return false, 'registres de vava_crafting absents' end
    local kind = composter.type
    if not registry.has(STATIONS_REGISTRY, kind.id) then
        local ok, err = registry.add(STATIONS_REGISTRY, kind.id, { label = kind.label, skills = kind.skills, anim = kind.anim, prop = kind.prop })
        if not ok then return false, 'type de station : ' .. tostring(err) end
    end
    local recipe = composter.recipe
    if not registry.has(RECIPES_REGISTRY, recipe.id) then
        local data = {}
        for key, value in pairs(recipe) do
            if key ~= 'id' then data[key] = value end
        end
        local ok, err = registry.add(RECIPES_REGISTRY, recipe.id, data)
        if not ok then return false, 'recette : ' .. tostring(err) end
    end
    local station = composter.station
    local called, ok, code = call(CRAFTING, 'addStation', { id = station.id, type = kind.id, label = station.label, x = station.x, y = station.y, z = station.z, heading = station.heading, quality = station.quality })
    if not called then return false, 'vava_crafting indisponible' end
    if ok ~= true and code ~= 'duplicate' then return false, 'station : ' .. tostring(code) end
    return true
end

-- Conseil ---------------------------------------------------------------------------------------------------------

---@param source integer
---@param permission string
---@return boolean
function Bridge.IsAllowed(source, permission)
    if source == CONSOLE then return true end
    if GetResourceState(ADMIN) == 'started' then
        local called, allowed = call(ADMIN, 'can', source, permission)
        return called and allowed == true
    end
    return IsPlayerAceAllowed(source, cfg.admin.ace) == true
end

---@param source integer
---@param label string
---@param details table
function Bridge.AdminLog(source, label, details)
    local called, ok, err = false, nil, nil
    if source ~= CONSOLE then called, ok, err = call(ADMIN, 'log', source, label, details) end
    if not called or ok ~= true then
        local parts = {}
        for key, value in pairs(details) do parts[#parts + 1] = key .. '=' .. tostring(value) end
        VavaFarming.log.info('%s (par %d) : %s%s', label, source, concat(parts, ', '), called and (' — journal refusé : ' .. tostring(err)) or '')
    end
end

-- Messages --------------------------------------------------------------------------------------------------------

---@param source integer
---@param message string
---@param kind? string
function Bridge.Notify(source, message, kind)
    if source == CONSOLE then
        print(('[%s] %s'):format(VavaFarming.resource, message))
        return
    end
    TriggerClientEvent(EVENTS.NOTIFY, source, message, kind or 'info')
end

---@param source integer
---@param text string
function Bridge.Chat(source, text)
    if source == CONSOLE then
        print(('[%s] %s'):format(VavaFarming.resource, text))
        return
    end
    local called = call(CHAT, 'addMessage', source, { text = text })
    if not called then Bridge.Notify(source, text) end
end

-- Base de données -------------------------------------------------------------------------------------------------

Bridge.db = {
    query = function(sql, params) return core.db.query(sql, params) end,
    single = function(sql, params) return core.db.single(sql, params) end,
    scalar = function(sql, params) return core.db.scalar(sql, params) end,
    insert = function(sql, params) return core.db.insert(sql, params) end,
    update = function(sql, params) return core.db.update(sql, params) end,
    transaction = function(queries) return core.db.transaction(queries) end,
}

---@param value any
---@param default integer
---@return integer
function Bridge.Integer(value, default)
    local number = tonumber(value)
    if number == nil then return default end
    return math.tointeger(number) or default
end

---@param value any
---@param default number
---@return number
function Bridge.Number(value, default)
    local number = tonumber(value)
    if number == nil then return default end
    return number
end

Bridge.CONSOLE = CONSOLE
Bridge.INVENTORY = INVENTORY
Bridge.CRAFTING = CRAFTING
