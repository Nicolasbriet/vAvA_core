--[[
    vava_provisions/bridge/server.lua
    Rôle : SEUL point de contact, côté serveur, entre les vivres et le core / les autres modules : personnage actif,
           position du ped lue par le serveur, à terre (vava_health), inventaire (compte, piles et leur palier, échange
           atomique, ajout, déclaration d'un objet), besoins (soif lue et ajoutée, vava_needs), recette de l'outre (registres de
           vava_crafting et de vava_skills), zones du core des points d'eau, envoi au seul joueur concerné (core.net.send,
           compté ; repli TriggerClientEvent vers ce seul joueur), hooks émis, droits et journal du Conseil (vava_admin),
           chat (vava_chat), horloges. Chaque appel à une autre ressource est isolé : un module absent ou en erreur ne
           retire que la fonction concernée.
    Dépendances : shared/constants.lua, config.lua, server/core.lua (core.zones : vAvA_core 0.11.0)
]]

local type, pairs, pcall, tostring = type, pairs, pcall, tostring
local mathType = math.type
local pack, unpack, concat = table.pack, table.unpack, table.concat
local time = os.time
local GetResourceState, TriggerClientEvent, IsPlayerAceAllowed = GetResourceState, TriggerClientEvent, IsPlayerAceAllowed
local GetPlayerPed, DoesEntityExist, GetEntityCoords, GetGameTimer = GetPlayerPed, DoesEntityExist, GetEntityCoords, GetGameTimer

local core = VavaProvisions.core
if not core then return end

local cfg = VavaProvisions.config
local EVENTS = VavaProvisions.EVENTS
local CONSOLE = 0
local INVENTORY, NEEDS, HEALTH, ADMIN, CHAT = 'vava_inventory', 'vava_needs', 'vava_health', 'vava_admin', 'vava_chat'
local CRAFTING, SKILLS = 'vava_crafting', 'vava_skills'
local ITEMS_REGISTRY = 'vava_inventory:items'
local RECIPES_REGISTRY, STATIONS_REGISTRY = 'vava_crafting:recipes', 'vava_crafting:stations'
local SKILL_RECIPES_REGISTRY = 'vava_skills:recipes'

local Bridge = {}
VavaProvisions.bridge = Bridge

local function invoke(resource, fn, ...)
    local target = exports[resource]
    return target[fn](target, ...)
end

--- Export d'une autre ressource, isolé. Renvoie `called` (appel réussi) puis ses valeurs.
---@return boolean called
local function call(resource, fn, ...)
    if GetResourceState(resource) ~= 'started' then return false end
    local results = pack(pcall(invoke, resource, fn, ...))
    if not results[1] then
        VavaProvisions.log.warn('%s.%s en erreur : %s', resource, fn, tostring(results[2]))
        return false
    end
    return true, unpack(results, 2, results.n)
end

-- Personnage et monde ---------------------------------------------------------------------------------------------

--- Numéro du personnage actif d'un joueur (session active), ou nil. Ne cède pas la main.
---@param source integer
---@return integer|nil
function Bridge.ActiveCharacterId(source)
    local session = core.players.get(source)
    if not session or session.state ~= 'active' then return nil end
    local character = core.characters.getActive(source)
    return character and character.id or nil
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

--- Quantité d'un objet dans la besace (toutes métadonnées), ou nil si l'inventaire ne répond pas.
---@param source integer
---@param item string
---@return integer|nil
function Bridge.Count(source, item)
    local called, count = call(INVENTORY, 'count', source, item)
    if not called or mathType(count) ~= 'integer' then return nil end
    return count
end

--- Retire puis ajoute, tout ou rien. Ne cède pas la main.
---@return boolean ok
---@return string|nil code
function Bridge.Exchange(source, removals, additions)
    local called, ok, code = call(INVENTORY, 'exchange', source, removals, additions)
    if not called then return false, 'inventory_unavailable' end
    return ok == true, code
end

--- Piles d'un objet dans la besace, les plus anciennes d'abord : `{ { id, quantity, metadata } }`, ou nil si
--- l'inventaire ne répond pas. Lecture seule, ne cède pas la main (permise dans un hook `before` de l'inventaire).
---@param source integer
---@param item string
---@return table[]|nil
function Bridge.Piles(source, item)
    local called, list = call(INVENTORY, 'getItems', source, { item = item })
    if not called or type(list) ~= 'table' then return nil end
    return list
end

--- Ajoute des objets à la besace, tout ou rien ; `metadata` (facultatif) : celles de la pile (palier de l'outre).
---@return boolean ok
---@return string|nil code
function Bridge.Add(source, item, quantity, metadata)
    local called, ok, code = call(INVENTORY, 'add', source, item, quantity, metadata)
    if not called then return false, 'inventory_unavailable' end
    return ok == true, code
end

--- Vrai si le registre des objets existe (inventaire prêt).
---@return boolean
function Bridge.ItemsReady()
    return core.registry.exists(ITEMS_REGISTRY)
end

--- Vrai si l'objet est déjà connu de l'inventaire (déclaré par ce module ou un autre).
---@param name string
---@return boolean
function Bridge.HasItem(name)
    return core.registry.exists(ITEMS_REGISTRY) and core.registry.has(ITEMS_REGISTRY, name)
end

--- Déclare un objet à l'inventaire.
---@param name string
---@param definition table
---@return boolean ok
---@return string|nil err
function Bridge.AddItem(name, definition)
    if not core.registry.exists(ITEMS_REGISTRY) then return false, 'inventory_unavailable' end
    return core.registry.add(ITEMS_REGISTRY, name, definition)
end

-- Besoins ---------------------------------------------------------------------------------------------------------

--- Soif du joueur (0 à 100), ou nil si vava_needs ne répond pas.
---@param source integer
---@return number|nil
function Bridge.Thirst(source)
    local called, values = call(NEEDS, 'get', source)
    if not called or type(values) ~= 'table' or type(values.thirst) ~= 'number' then return nil end
    return values.thirst
end

--- Soif + `amount` (bornée par vava_needs).
---@param source integer
---@param amount integer
---@return boolean ok
function Bridge.AddThirst(source, amount)
    local called, ok = call(NEEDS, 'add', source, { thirst = amount })
    return called and ok == true
end

-- Artisanat (recette de l'outre) ------------------------------------------------------------------------------------

--- Ajoute la recette aux registres de vava_crafting (et de vava_skills, pour qu'un tanneur la connaisse). Rend `true`
--- si elle y est (déjà ou maintenant), sinon `false, raison`.
---@param recipe table  { id, label, skill, level, station, … }
---@return boolean ok
---@return string|nil err
function Bridge.DeclareRecipe(recipe)
    local registry = core.registry
    if not registry.exists(RECIPES_REGISTRY) or not registry.exists(STATIONS_REGISTRY) then
        return false, 'artisanat absent (vava_crafting)'
    end
    if not registry.has(STATIONS_REGISTRY, recipe.station) then
        return false, "station '" .. tostring(recipe.station) .. "' inconnue de l'artisanat"
    end
    if not registry.has(RECIPES_REGISTRY, recipe.id) then
        local data = {}
        for key, value in pairs(recipe) do
            if key ~= 'id' then data[key] = value end
        end
        local ok, err = registry.add(RECIPES_REGISTRY, recipe.id, data)
        if not ok then return false, tostring(err) end
    end
    return Bridge.DeclareSkillRecipe(recipe)
end

--- Déclare la recette au registre des compétences (sans quoi vava_crafting la refuse : « recette inconnue »).
---@param recipe table
---@return boolean ok
---@return string|nil err
function Bridge.DeclareSkillRecipe(recipe)
    local registry = core.registry
    if not registry.exists(SKILL_RECIPES_REGISTRY) then return false, 'compétences absentes (vava_skills)' end
    if registry.has(SKILL_RECIPES_REGISTRY, recipe.id) then return true end
    local ok, err = registry.add(SKILL_RECIPES_REGISTRY, recipe.id, {
        label = recipe.label, skill = recipe.skill, level = recipe.level, transmission = recipe.transmission == true,
    })
    if not ok then return false, 'compétences : ' .. tostring(err) end
    return true
end

-- Zones du core (vAvA_core 0.11.0) ------------------------------------------------------------------------------------
-- Une zone par point d'eau : le core l'envoie aux seuls joueurs proches (positions lues par le serveur). Son état est
-- public : rien de secret dedans (ni réserve, ni dernier puiseur).

local function zones()
    return core.zones
end

Bridge.Zones = {
    define = function(id, area, state)
        local z = zones()
        if not z then return false, 'zones_unavailable' end
        return z.define(id, area, state)
    end,
    move = function(id, area)
        local z = zones()
        if not z then return false, 'zones_unavailable' end
        return z.move(id, area)
    end,
    replace = function(id, state)
        local z = zones()
        if not z then return false, 'zones_unavailable' end
        return z.replace(id, state)
    end,
    remove = function(id)
        local z = zones()
        if not z then return false, 'zones_unavailable' end
        return z.remove(id)
    end,
}

-- Réseau et hooks -------------------------------------------------------------------------------------------------

--- Envoie un évènement du module au SEUL joueur `target` (jamais -1, jamais une liste) : core.net.send, fiable et compté
--- sous vava_provisions ; repli TriggerClientEvent vers ce même joueur si core.net manque.
---@param target integer
---@param event string
---@return boolean ok
---@return string|nil code
function Bridge.Send(target, event, ...)
    if mathType(target) ~= 'integer' or target <= 0 then return false, 'invalid_target' end
    local net = core.net
    if type(net) == 'table' and type(net.send) == 'function' then
        local ok, code = net.send(target, event, ...)
        if not ok then
            VavaProvisions.log.warn("envoi de '%s' au joueur %d refusé : %s", event, target, tostring(code))
            return false, code
        end
        return true
    end
    TriggerClientEvent(event, target, ...)
    return true
end

--- Hook `before` du module : `true`, ou `false, raison`.
---@param name string
---@param payload table
---@return boolean allowed
---@return any reason
function Bridge.RunBefore(name, payload)
    return core.hooks.runBefore(name, payload)
end

--- Hook `after` du module.
---@param name string
---@param payload table
function Bridge.RunAfter(name, payload)
    core.hooks.runAfter(name, payload)
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
        VavaProvisions.log.info('%s (par %d) : %s%s', label, source, concat(parts, ', '), called and (' — journal refusé : ' .. tostring(err)) or '')
    end
end

--- Réponse au seul membre du Conseil qui a tapé la commande : chat de vava_chat, sinon notification (évènement au seul
--- joueur) ; console : print.
---@param source integer
---@param text string
function Bridge.Chat(source, text)
    if source == CONSOLE then
        print(('[%s] %s'):format(VavaProvisions.resource, text))
        return
    end
    local called = call(CHAT, 'addMessage', source, { text = text })
    if not called then Bridge.Send(source, EVENTS.NOTIFY, text) end
end

-- Horloges ----------------------------------------------------------------------------------------------------------

--- Heure du serveur (secondes) : réserves.
---@return integer
function Bridge.Now()
    return time()
end

--- Horloge du jeu (millisecondes) : délais.
---@return integer
function Bridge.Timer()
    return GetGameTimer()
end

Bridge.CONSOLE = CONSOLE
Bridge.INVENTORY = INVENTORY
Bridge.CRAFTING = CRAFTING
Bridge.SKILLS = SKILLS
