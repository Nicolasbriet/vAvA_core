--[[
    vava_combat/bridge/server.lua
    Rôle : SEUL point de contact, côté serveur, entre les armes et le core / les autres modules : personnage actif et
           joueurs en jeu, position du ped lue par le serveur, à terre (vava_health), objet tenu en main, piles de la
           besace, besace d'un joueur, patchMetadata (vava_inventory), déclarations aux registres (objets, recettes de
           l'artisanat et des compétences), versions des modules, coup par la chaîne de dégâts (vava_health:hit) et
           vocabulaire, champ privé du bouclier accroché, hooks émis, droits et journal du Conseil (vava_admin), chat
           (vava_chat), envoi au seul joueur concerné (core.net.send, compté). Chaque appel à une autre ressource est
           isolé (pcall) : un module absent ou en erreur ne retire que la fonction concernée.
    Dépendances : shared/constants.lua, config.lua, server/core.lua
]]

local type, pairs, ipairs, pcall, tostring, tonumber = type, pairs, ipairs, pcall, tostring, tonumber
local mathType = math.type
local pack, unpack, concat, sort = table.pack, table.unpack, table.concat, table.sort
local GetResourceState, IsPlayerAceAllowed, GetPlayers = GetResourceState, IsPlayerAceAllowed, GetPlayers
local GetPlayerPed, DoesEntityExist, GetEntityCoords, GetGameTimer = GetPlayerPed, DoesEntityExist, GetEntityCoords, GetGameTimer

local core = VavaCombat.core
if not core then return end

local cfg = VavaCombat.config
local EVENTS = VavaCombat.EVENTS
local SHIELD_FIELD = VavaCombat.SHIELD_FIELD
local CONSOLE = 0
local INVENTORY, HEALTH, ADMIN, CHAT = 'vava_inventory', 'vava_health', 'vava_admin', 'vava_chat'
local CRAFTING, SKILLS = 'vava_crafting', 'vava_skills'
local ITEMS_REGISTRY = 'vava_inventory:items'
local RECIPES_REGISTRY = 'vava_crafting:recipes'
local SKILL_RECIPES_REGISTRY = 'vava_skills:recipes'
local READY = 'ready'

local Bridge = {}
VavaCombat.bridge = Bridge

local function invoke(resource, fn, ...)
    local target = exports[resource]
    return target[fn](target, ...)
end

--- Export d'une autre ressource, isolé. Renvoie `called` (appel abouti) puis ses valeurs.
---@return boolean called
local function call(resource, fn, ...)
    if GetResourceState(resource) ~= 'started' then return false end
    local results = pack(pcall(invoke, resource, fn, ...))
    if not results[1] then
        VavaCombat.log.warn('%s.%s en erreur : %s', resource, fn, tostring(results[2]))
        return false
    end
    return true, unpack(results, 2, results.n)
end

-- Personnage et monde ---------------------------------------------------------------------------------------------

--- Numéro du personnage actif d'un joueur (session active), ou nil. Ne cède pas la main.
---@param source integer
---@return integer|nil
function Bridge.ActiveCharacterId(source)
    if mathType(source) ~= 'integer' or source <= 0 then return nil end
    local session = core.players.get(source)
    if not session or session.state ~= 'active' then return nil end
    local character = core.characters.getActive(source)
    return character and character.id or nil
end

--- Joueurs connectés qui ont un personnage actif, dans l'ordre croissant des numéros.
---@return integer[]
function Bridge.ActivePlayers()
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        local source = tonumber(id)
        source = source and math.tointeger(source)
        if source and Bridge.ActiveCharacterId(source) then out[#out + 1] = source end
    end
    sort(out)
    return out
end

--- Position du ped du joueur, lue par le serveur (pas de ped : nil).
---@param source integer
---@return number|nil x, number|nil y, number|nil z
function Bridge.Position(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    local coords = GetEntityCoords(ped)
    return coords.x, coords.y, coords.z
end

--- Vrai si le joueur est à terre (règle de vava_health) ; module absent ou en erreur : pas à terre.
---@param source integer
---@return boolean
function Bridge.IsDowned(source)
    local called, downed = call(HEALTH, 'isDowned', source)
    return called and downed == true
end

-- Inventaire ------------------------------------------------------------------------------------------------------

--- Pile tenue en main (`{ id, item, quantity, metadata, … }`), ou nil (rien en main, inventaire absent).
---@param source integer
---@return table|nil
function Bridge.Held(source)
    local called, instance = call(INVENTORY, 'held', source)
    if not called or type(instance) ~= 'table' or type(instance.item) ~= 'string' then return nil end
    return instance
end

--- Piles d'un objet dans la besace du joueur, ou nil si l'inventaire ne répond pas (arrêté, en erreur, refus).
---@param source integer
---@param item string
---@return table[]|nil
function Bridge.Items(source, item)
    local called, list = call(INVENTORY, 'getItems', source, { item = item })
    if not called or type(list) ~= 'table' then return nil end
    return list
end

--- Numéro du conteneur porté par le personnage actif (sa besace), ou nil.
---@param source integer
---@return integer|nil
function Bridge.ContainerOf(source)
    local called, id = call(INVENTORY, 'containerOf', source)
    if not called or mathType(id) ~= 'integer' then return nil end
    return id
end

--- Écrit des clés de métadonnées sur une pile de la besace (le reste est conservé).
---@return boolean ok
---@return string|nil code
function Bridge.PatchMetadata(source, instanceId, patch)
    local called, ok, code = call(INVENTORY, 'patchMetadata', source, instanceId, patch)
    if not called then return false, 'inventory_unavailable' end
    return ok == true, code
end

--- Vrai si le registre des objets existe (inventaire prêt).
---@return boolean
function Bridge.ItemsReady()
    return core.registry.exists(ITEMS_REGISTRY)
end

---@param name string
---@return boolean
function Bridge.HasItem(name)
    return core.registry.exists(ITEMS_REGISTRY) and core.registry.has(ITEMS_REGISTRY, name)
end

--- Définition d'un objet déclaré à l'inventaire (copie), ou nil.
---@param name string
---@return table|nil
function Bridge.ItemDefinition(name)
    if not core.registry.exists(ITEMS_REGISTRY) then return nil end
    return core.registry.get(ITEMS_REGISTRY, name)
end

---@param name string
---@param definition table
---@return boolean ok
---@return string|nil err
function Bridge.AddItem(name, definition)
    if not core.registry.exists(ITEMS_REGISTRY) then return false, 'inventory_unavailable' end
    return core.registry.add(ITEMS_REGISTRY, name, definition)
end

-- Modules ---------------------------------------------------------------------------------------------------------

--- Version d'un module prêt (`ready`), ou nil s'il est absent, arrêté, en démarrage ou en échec.
---@param name string
---@return string|nil
function Bridge.ModuleVersion(name)
    local info = core.modules.get(name)
    if type(info) ~= 'table' or info.state ~= READY or type(info.version) ~= 'string' then return nil end
    return info.version
end

-- Artisanat et compétences ------------------------------------------------------------------------------------------

---@return boolean
function Bridge.RecipesReady()
    return core.registry.exists(RECIPES_REGISTRY)
end

--- Recette de l'artisanat (copie), ou nil.
---@param id string
---@return table|nil
function Bridge.Recipe(id)
    if not core.registry.exists(RECIPES_REGISTRY) then return nil end
    return core.registry.get(RECIPES_REGISTRY, id)
end

---@param id string
---@param data table
---@return boolean ok
---@return string|nil err
function Bridge.AddRecipe(id, data)
    if not core.registry.exists(RECIPES_REGISTRY) then return false, 'artisanat absent (vava_crafting)' end
    if core.registry.has(RECIPES_REGISTRY, id) then return false, 'recette déjà déclarée par une autre ressource' end
    return core.registry.add(RECIPES_REGISTRY, id, data)
end

---@return boolean
function Bridge.SkillRecipesReady()
    return core.registry.exists(SKILL_RECIPES_REGISTRY)
end

---@param id string
---@param data table  { label, skill, level, transmission }
---@return boolean ok
---@return string|nil err
function Bridge.AddSkillRecipe(id, data)
    if not core.registry.exists(SKILL_RECIPES_REGISTRY) then return false, 'compétences absentes (vava_skills)' end
    if core.registry.has(SKILL_RECIPES_REGISTRY, id) then return false, 'recette déjà déclarée par une autre ressource' end
    return core.registry.add(SKILL_RECIPES_REGISTRY, id, data)
end

--- Vrai si la recette est au registre des compétences (déclarée par ce module ou un autre).
---@param id string
---@return boolean
function Bridge.HasSkillRecipe(id)
    return core.registry.exists(SKILL_RECIPES_REGISTRY) and core.registry.has(SKILL_RECIPES_REGISTRY, id)
end

-- Chaîne de dégâts ----------------------------------------------------------------------------------------------------

--- Coup par la chaîne de dégâts commune. Rend le résultat de `hit`, ou `nil, code` (`health_unavailable` si vava_health
--- ne répond pas). Ne cède pas la main.
---@param target integer
---@param packet table
---@return table|nil result
---@return string|nil code
function Bridge.Hit(target, packet)
    local called, result, code = call(HEALTH, 'hit', target, packet)
    if not called then return nil, 'health_unavailable' end
    if type(result) ~= 'table' then return nil, type(code) == 'string' and code or 'hit_error' end
    return result
end

--- Types de dégâts connus de vava_health, ou nil s'il ne répond pas.
---@return string[]|nil
function Bridge.HealthKinds()
    local called, vocabulary = call(HEALTH, 'vocabulary')
    if not called or type(vocabulary) ~= 'table' or type(vocabulary.kinds) ~= 'table' then return nil end
    return vocabulary.kinds
end

-- Champ du bouclier accroché ------------------------------------------------------------------------------------------

---@return boolean ok
---@return string|nil err
function Bridge.DefineShieldField()
    return core.characters.defineField(SHIELD_FIELD, {
        schema = { type = 'integer', min = 1, max = VavaCombat.MAX_ID, optional = true },
        visibility = 'private',
    })
end

--- Numéro de pile du bouclier accroché retenu pour un personnage chargé, ou nil.
---@param characterId integer
---@return integer|nil
function Bridge.ShieldField(characterId)
    local value = core.characters.get(characterId, SHIELD_FIELD)
    return mathType(value) == 'integer' and value or nil
end

---@param characterId integer
---@param value integer|nil
function Bridge.SetShieldField(characterId, value)
    local ok, err = core.characters.set(characterId, SHIELD_FIELD, value)
    if not ok then VavaCombat.log.warn('personnage %s : bouclier accroché non retenu (%s)', tostring(characterId), tostring(err)) end
end

-- Hooks -------------------------------------------------------------------------------------------------------------

---@return boolean allowed
---@return any reason
function Bridge.RunBefore(name, payload)
    return core.hooks.runBefore(name, payload)
end

function Bridge.RunAfter(name, payload)
    core.hooks.runAfter(name, payload)
end

-- Réseau ------------------------------------------------------------------------------------------------------------

--- Envoie un évènement du module au SEUL joueur `target` (jamais -1, jamais une liste) : core.net.send, compté sous
--- vava_combat.
---@param target integer
---@param event string
---@return boolean ok
---@return string|nil code
function Bridge.Send(target, event, ...)
    if mathType(target) ~= 'integer' or target <= 0 then return false, 'invalid_target' end
    local ok, code = core.net.send(target, event, ...)
    if not ok then
        VavaCombat.log.warn("envoi de '%s' au joueur %d refusé : %s", event, target, tostring(code))
        return false, code
    end
    return true
end

--- Notification au seul joueur (affichée par vava_hud, sinon par le jeu).
---@param source integer
---@param text string
---@param kind? string  info | warning | danger
function Bridge.Notify(source, text, kind)
    Bridge.Send(source, EVENTS.NOTIFY, text, kind or 'info')
end

-- Conseil ---------------------------------------------------------------------------------------------------------

--- Droit du Conseil, revérifié à chaque appel : vava_admin, sinon ACE ; la console a tous les droits.
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

--- Journal du Registre du Conseil ; console, ou Registre absent : ligne de console.
---@param source integer
---@param label string
---@param details table
function Bridge.AdminLog(source, label, details)
    local called, ok, err = false, nil, nil
    if source ~= CONSOLE then called, ok, err = call(ADMIN, 'log', source, label, details) end
    if not called or ok ~= true then
        local parts = {}
        for key, value in pairs(details) do parts[#parts + 1] = key .. '=' .. tostring(value) end
        sort(parts)
        VavaCombat.log.info('%s (par %d) : %s%s', label, source, concat(parts, ', '),
            called and (' — journal refusé : ' .. tostring(err)) or '')
    end
end

--- Réponse au seul membre du Conseil qui a tapé la commande : chat de vava_chat, sinon notification ; console : print.
---@param source integer
---@param text string
function Bridge.Chat(source, text)
    if source == CONSOLE then
        print(('[%s] %s'):format(VavaCombat.resource, text))
        return
    end
    local called = call(CHAT, 'addMessage', source, { text = text })
    if not called then Bridge.Notify(source, text, 'info') end
end

-- Horloge -----------------------------------------------------------------------------------------------------------

--- Horloge du jeu (millisecondes) : délais.
---@return integer
function Bridge.Timer()
    return GetGameTimer()
end

Bridge.CONSOLE = CONSOLE
Bridge.INVENTORY = INVENTORY
Bridge.HEALTH = HEALTH
Bridge.CRAFTING = CRAFTING
Bridge.SKILLS = SKILLS
