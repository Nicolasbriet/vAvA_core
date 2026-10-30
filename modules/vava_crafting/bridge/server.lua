--[[
    vava_crafting/bridge/server.lua
    Rôle : SEUL point de contact, côté serveur, entre l'artisanat et le core / les autres modules : personnage et
           compte, position lue côté serveur, joueurs à portée (leçons), santé (à terre), inventaire (objet en main,
           piles et leurs métadonnées, comptage par palier, échange atomique, écriture partielle des métadonnées,
           garde de la signature au hook des métadonnées, déclaration des objets), compétences (XP, niveau, rang,
           recette connue, leçon, registre des recettes), libellés des compétences, poinçon (champ de personnage),
           droits et journal du Conseil, notifications, chat, base.
           Chaque appel à une autre ressource est isolé.
    Dépendances : shared/constants.lua, config.lua, server/core.lua
]]

local type, pairs, ipairs, pcall, tostring, tonumber = type, pairs, ipairs, pcall, tostring, tonumber
local mathType = math.type
local pack, unpack, concat = table.pack, table.unpack, table.concat
local GetResourceState, TriggerClientEvent, IsPlayerAceAllowed, GetPlayers = GetResourceState, TriggerClientEvent, IsPlayerAceAllowed, GetPlayers
local GetPlayerPed, DoesEntityExist, GetEntityCoords = GetPlayerPed, DoesEntityExist, GetEntityCoords

local core = VavaCrafting.core
if not core then return end

local cfg = VavaCrafting.config
local EVENTS = VavaCrafting.EVENTS
local MARK_FIELD = VavaCrafting.MARK_FIELD
local CONSOLE = 0
local INVENTORY, SKILLS, ADMIN, CHAT, HEALTH = 'vava_inventory', 'vava_skills', 'vava_admin', 'vava_chat', 'vava_health'
local ITEMS_REGISTRY = 'vava_inventory:items'
local METADATA_HOOK = 'vava_inventory:metadata'
local SKILLS_REGISTRY = 'vava_skills:skills'
local SKILL_RECIPES_REGISTRY = 'vava_skills:recipes'

local Bridge = {}
VavaCrafting.bridge = Bridge

local function invoke(resource, fn, ...)
    local target = exports[resource]
    return target[fn](target, ...)
end

---@return boolean called
local function call(resource, fn, ...)
    if GetResourceState(resource) ~= 'started' then return false end
    local results = pack(pcall(invoke, resource, fn, ...))
    if not results[1] then
        VavaCrafting.log.warn('%s.%s en erreur : %s', resource, fn, tostring(results[2]))
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

--- Joueurs avec un personnage en jeu à moins de `radius` m du joueur (lui exclu).
---@param source integer
---@param radius number
---@return integer[]
function Bridge.PlayersNear(source, radius)
    local list = {}
    local x, y, z = Bridge.Position(source)
    if not x then return list end
    for _, id in ipairs(GetPlayers()) do
        local other = tonumber(id)
        if other and other ~= source and Bridge.GetCharacterId(other) then
            local ox, oy, oz = Bridge.Position(other)
            if ox then
                local dx, dy, dz = ox - x, oy - y, oz - z
                if dx * dx + dy * dy + dz * dz <= radius * radius then list[#list + 1] = other end
            end
        end
    end
    return list
end

-- Santé -----------------------------------------------------------------------------------------------------------

--- Vrai si le joueur est à terre (règle de vava_health) ; module absent ou en erreur : pas à terre.
---@param source integer
---@return boolean
function Bridge.IsDowned(source)
    local called, downed = call(HEALTH, 'isDowned', source)
    return called and downed == true
end

-- Inventaire ------------------------------------------------------------------------------------------------------

--- Pile tenue en main ({ id, item, quantity, metadata }) ou nil.
---@param source integer
---@return table|nil
function Bridge.Held(source)
    local called, instance = call(INVENTORY, 'held', source)
    return called and type(instance) == 'table' and instance or nil
end

--- Piles de la besace répondant au filtre `{ item?, metadata? }`.
---@param source integer
---@param filter table|nil
---@return table[]
function Bridge.Items(source, filter)
    local called, list = call(INVENTORY, 'getItems', source, filter)
    return (called and type(list) == 'table') and list or {}
end

--- Quantité d'un objet portant les métadonnées données (sous-ensemble).
---@param source integer
---@param item string
---@param metadata table|nil
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

--- Retire puis ajoute, tout ou rien.
---@return boolean ok
---@return string|nil code
function Bridge.Exchange(source, removals, additions)
    local called, ok, code = call(INVENTORY, 'exchange', source, removals, additions)
    if not called then return false, 'inventory_unavailable' end
    return ok == true, code
end

---@return boolean ok
---@return string|nil code
function Bridge.Remove(source, item, quantity, metadata)
    local called, ok, code = call(INVENTORY, 'remove', source, item, quantity, metadata)
    if not called then return false, 'inventory_unavailable' end
    return ok == true, code
end

-- Écritures de métadonnées de l'artisanat en cours (compteur : une écriture dont un hook d'un autre module céderait
-- la main ne doit pas faire tomber le drapeau d'une autre). Levé autour du seul appel à l'inventaire, protégé par pcall :
-- il retombe toujours.
local ownWrites = 0

--- Écrit ou remplace des clés de métadonnées, en retire d'autres. Seule écriture de métadonnées du module : la garde
--- (`Bridge.GuardMetadata`) la reconnaît comme interne.
---@return boolean ok
function Bridge.PatchMetadata(source, instanceId, patch, removed)
    ownWrites = ownWrites + 1
    local called, ok = call(INVENTORY, 'patchMetadata', source, instanceId, patch, removed)
    ownWrites = ownWrites - 1
    return called and ok == true
end

--- Abonne `check(payload, interne)` au hook `before` de `vava_inventory:metadata`. Une écriture est interne quand
--- l'inventaire l'attribue à cette ressource (`owner`, lu par lui avec `GetInvokingResource`) **et** qu'elle part de
--- `Bridge.PatchMetadata` : ni un autre module, ni un autre chemin du module ne passe pour l'artisanat.
---@param check fun(payload: table, internal: boolean): boolean|nil, string|nil
---@return integer|nil id
---@return string|nil err
function Bridge.GuardMetadata(check)
    return core.hooks.before(METADATA_HOOK, function(payload)
        local internal = type(payload) == 'table' and payload.owner == VavaCrafting.resource and ownWrites > 0
        return check(payload, internal)
    end)
end

---@param name string
---@param definition table
---@return boolean declared
function Bridge.DeclareItem(name, definition)
    local registry = core.registry
    if not registry.exists(ITEMS_REGISTRY) or registry.has(ITEMS_REGISTRY, name) then return false end
    local ok, err = registry.add(ITEMS_REGISTRY, name, definition)
    if not ok then VavaCrafting.log.warn("objet '%s' non déclaré : %s", name, tostring(err)) end
    return ok == true
end

--- Définition publique d'un objet connu de l'inventaire (label, stack, category…), ou nil.
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

---@return boolean
function Bridge.HasRank(source, skill, rank)
    local called, has = call(SKILLS, 'hasRank', source, skill, rank)
    return called and has == true
end

---@return boolean
function Bridge.KnowsRecipe(source, recipe)
    local called, knows = call(SKILLS, 'knowsRecipe', source, recipe)
    return called and knows == true
end

--- Le professeur vient de réaliser la recette devant l'élève.
---@return boolean ok
---@return table|string result
function Bridge.RecordLesson(teacher, student, recipe)
    local called, ok, result = call(SKILLS, 'recordLesson', teacher, student, recipe)
    if not called then return false, 'skills_unavailable' end
    return ok == true, result
end

--- Déclare une recette au registre des compétences (compétence, niveau, transmission, fragments).
---@return boolean ok
---@return string|nil err
function Bridge.DeclareSkillRecipe(id, data)
    local registry = core.registry
    if not registry.exists(SKILL_RECIPES_REGISTRY) then return false, 'registre des recettes de vava_skills absent' end
    if registry.has(SKILL_RECIPES_REGISTRY, id) then return true end
    return registry.add(SKILL_RECIPES_REGISTRY, id, data)
end

--- Libellé d'une compétence (registre de vava_skills), ou son identifiant.
---@param skill string
---@return string
function Bridge.SkillLabel(skill)
    local def = core.registry.exists(SKILLS_REGISTRY) and core.registry.get(SKILLS_REGISTRY, skill)
    return def and def.label or skill
end

-- Poinçon (champ de personnage) ---------------------------------------------------------------------------------------

---@return boolean ok
---@return string|nil err
function Bridge.DefineMarkField(schema)
    return core.characters.defineField(MARK_FIELD, { schema = schema, visibility = 'owner' })
end

---@param characterId integer
---@return string|nil
function Bridge.GetMark(characterId)
    local value = core.characters.get(characterId, MARK_FIELD)
    return type(value) == 'string' and value or nil
end

---@param characterId integer
---@param glyph string
---@return boolean ok
function Bridge.SetMark(characterId, glyph)
    return core.characters.set(characterId, MARK_FIELD, glyph) == true
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
        VavaCrafting.log.info('%s (par %d) : %s%s', label, source, concat(parts, ', '), called and (' — journal refusé : ' .. tostring(err)) or '')
    end
end

-- Messages --------------------------------------------------------------------------------------------------------

---@param source integer
---@param message string
---@param kind? string
function Bridge.Notify(source, message, kind)
    if source == CONSOLE then
        print(('[%s] %s'):format(VavaCrafting.resource, message))
        return
    end
    TriggerClientEvent(EVENTS.NOTIFY, source, message, kind or 'info')
end

---@param source integer
---@param text string
function Bridge.Chat(source, text)
    if source == CONSOLE then
        print(('[%s] %s'):format(VavaCrafting.resource, text))
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

Bridge.CONSOLE = CONSOLE
Bridge.INVENTORY = INVENTORY
Bridge.SKILLS = SKILLS
