--[[
    vava_arrival/bridge/server.lua
    Rôle : SEUL point de contact, côté serveur, entre l'arrivée et le core / les autres modules : personnage actif et
           compte, inventaire (échange atomique, objet connu, déclaration d'un objet), envoi au seul joueur concerné
           (core.net.send, compté ; repli TriggerClientEvent vers ce seul joueur), hook émis, droits et journal du
           Conseil, chat, horloge, base de données. Chaque appel à une autre ressource est isolé : un module absent ou
           en erreur ne retire que la fonction concernée.
    Dépendances : shared/constants.lua, config.lua, server/core.lua
]]

local type, pairs, ipairs, pcall, tostring, tonumber = type, pairs, ipairs, pcall, tostring, tonumber
local mathType, tointeger = math.type, math.tointeger
local pack, unpack, concat = table.pack, table.unpack, table.concat
local time = os.time
local GetResourceState, TriggerClientEvent, IsPlayerAceAllowed, GetPlayers = GetResourceState, TriggerClientEvent, IsPlayerAceAllowed, GetPlayers

local core = VavaArrival.core
if not core then return end

local cfg = VavaArrival.config
local EVENTS = VavaArrival.EVENTS
local CONSOLE = 0
local INVENTORY, ADMIN, CHAT = 'vava_inventory', 'vava_admin', 'vava_chat'
local ITEMS_REGISTRY = 'vava_inventory:items'

local Bridge = {}
VavaArrival.bridge = Bridge

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
        VavaArrival.log.warn('%s.%s en erreur : %s', resource, fn, tostring(results[2]))
        return false
    end
    return true, unpack(results, 2, results.n)
end

-- Personnage ----------------------------------------------------------------------------------------------------

--- Personnage actif d'un joueur ({ id, accountId, firstName, lastName, playSeconds }) ou nil.
---@param source integer
---@return table|nil
function Bridge.GetCharacter(source)
    local session = core.players.get(source)
    if not session or session.state ~= 'active' then return nil end
    return core.characters.getActive(source)
end

--- Numéro du personnage actif d'un joueur, ou nil. Ne cède pas la main.
---@param source integer
---@return integer|nil
function Bridge.ActiveCharacterId(source)
    local character = Bridge.GetCharacter(source)
    return character and character.id or nil
end

---@param source integer
---@return integer|nil
function Bridge.GetAccountId(source)
    if source == CONSOLE then return nil end
    local session = core.players.get(source)
    return session and session.accountId or nil
end

---@param source integer
---@return string|nil
function Bridge.GetCharacterName(source)
    local character = Bridge.GetCharacter(source)
    return character and (character.firstName .. ' ' .. character.lastName) or nil
end

--- Numéros des joueurs connectés (adoption au démarrage du module).
---@return integer[]
function Bridge.Players()
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tointeger(tonumber(id))
        if src then list[#list + 1] = src end
    end
    return list
end

-- Inventaire ------------------------------------------------------------------------------------------------------

--- Échange atomique de vava_inventory (tout ou rien). Ne cède pas la main.
---@param source integer
---@param removals table
---@param additions table
---@return boolean ok
---@return string|nil code
function Bridge.Exchange(source, removals, additions)
    local called, ok, code = call(INVENTORY, 'exchange', source, removals, additions)
    if not called then return false, 'inventory_unavailable' end
    return ok == true, code
end

--- Vrai si l'objet est connu de l'inventaire (déclaré par ce module ou un autre).
---@param name string
---@return boolean
function Bridge.ItemExists(name)
    return core.registry.exists(ITEMS_REGISTRY) and core.registry.has(ITEMS_REGISTRY, name)
end

--- Déclare un objet à l'inventaire s'il ne l'est pas déjà (le registre n'existe pas tant que l'inventaire n'est pas
--- prêt : rappelé à sa mise en route).
---@param name string
---@param definition table
---@return boolean declared
function Bridge.DeclareItem(name, definition)
    local registry = core.registry
    if not registry.exists(ITEMS_REGISTRY) or registry.has(ITEMS_REGISTRY, name) then return false end
    local ok, err = registry.add(ITEMS_REGISTRY, name, definition)
    if not ok then VavaArrival.log.warn("objet '%s' non déclaré : %s", name, tostring(err)) end
    return ok == true
end

-- Réseau ----------------------------------------------------------------------------------------------------------

--- Envoie un évènement du module au SEUL joueur `target` (jamais -1, jamais une liste) : core.net.send, fiable et compté
--- sous vava_arrival ; repli TriggerClientEvent vers ce même joueur si core.net manque.
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
            VavaArrival.log.warn("envoi de '%s' au joueur %d refusé : %s", event, target, tostring(code))
            return false, code
        end
        return true
    end
    TriggerClientEvent(event, target, ...)
    return true
end

--- Hook du module (phase after).
---@param name string
---@param payload table
function Bridge.Emit(name, payload)
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
        VavaArrival.log.info('%s (par %d) : %s%s', label, source, concat(parts, ', '), called and (' — journal refusé : ' .. tostring(err)) or '')
    end
end

-- Messages --------------------------------------------------------------------------------------------------------

--- Réponse au seul membre du Conseil qui a tapé la commande : chat de vava_chat, sinon notification ; console : print.
---@param source integer
---@param text string
function Bridge.Chat(source, text)
    if source == CONSOLE then
        print(('[%s] %s'):format(VavaArrival.resource, text))
        return
    end
    local called = call(CHAT, 'addMessage', source, { text = text })
    if not called then Bridge.Send(source, EVENTS.NOTIFY, text) end
end

-- Horloge et base de données ----------------------------------------------------------------------------------------

--- Heure du serveur (secondes).
---@return integer
function Bridge.Now()
    return time()
end

Bridge.db = {
    single = function(sql, params) return core.db.single(sql, params) end,
    scalar = function(sql, params) return core.db.scalar(sql, params) end,
    insert = function(sql, params) return core.db.insert(sql, params) end,
    update = function(sql, params) return core.db.update(sql, params) end,
}

Bridge.CONSOLE = CONSOLE
Bridge.INVENTORY = INVENTORY
