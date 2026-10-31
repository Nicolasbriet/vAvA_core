--[[
    vava_gathering/bridge/server.lua
    Rôle : SEUL point de contact, côté serveur, entre la récolte et le core / les autres modules : personnage et compte,
           position lue côté serveur, santé (à terre), inventaire (objet en main, place, ajout, usure par métadonnées,
           déclaration des objets), compétences (XP, niveau), droits et journal du Conseil, notifications, chat, saison
           du royaume (vava_time, facultatif), zones du core (abonnements de zone, 1.6.0), base de données.
           T-102 : zone du core retirée, différence avec clés retirées, envoi à un seul joueur par core.net (essai de
           l'Atelier), registre des éditeurs de vava_atelier (déclaration de l'atelier « Récolte »).
           Chaque appel à une autre ressource est isolé : un module absent ou en erreur ne retire que la fonction
           concernée.
    Dépendances : shared/constants.lua, config.lua, server/core.lua
]]

local type, pairs, pcall, tostring, tonumber = type, pairs, pcall, tostring, tonumber
local mathType = math.type
local pack, unpack, concat = table.pack, table.unpack, table.concat
local GetResourceState, TriggerClientEvent, IsPlayerAceAllowed = GetResourceState, TriggerClientEvent, IsPlayerAceAllowed
local GetPlayerPed, DoesEntityExist, GetEntityCoords = GetPlayerPed, DoesEntityExist, GetEntityCoords
local GetGameTimer = GetGameTimer

local core = VavaGathering.core
if not core then return end

local cfg = VavaGathering.config
local EVENTS = VavaGathering.EVENTS
local CONSOLE = 0
local INVENTORY, SKILLS, ADMIN, CHAT, HEALTH = 'vava_inventory', 'vava_skills', 'vava_admin', 'vava_chat', 'vava_health'
local ITEMS_REGISTRY = 'vava_inventory:items'

local Bridge = {}
VavaGathering.bridge = Bridge

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
        VavaGathering.log.warn('%s.%s en erreur : %s', resource, fn, tostring(results[2]))
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

--- Position du joueur lue côté serveur, ou nil s'il n'a pas de ped.
---@param source integer
---@return number|nil x, number|nil y, number|nil z
function Bridge.Position(source)
    local ped = GetPlayerPed(source)
    if ped == 0 or not DoesEntityExist(ped) then return nil end
    local coords = GetEntityCoords(ped)
    return coords.x, coords.y, coords.z
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

---@return boolean ok
---@return string|nil code
function Bridge.CanCarry(source, item, quantity, metadata)
    local called, ok, code = call(INVENTORY, 'canCarry', source, item, quantity, metadata)
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

--- Écrit ou remplace des clés de métadonnées d'une pile du joueur (solidité d'un outil).
---@return boolean ok
function Bridge.PatchMetadata(source, instanceId, patch)
    local called, ok = call(INVENTORY, 'patchMetadata', source, instanceId, patch)
    return called and ok == true
end

--- Déclare un objet à l'inventaire s'il ne l'est pas déjà (le registre peut ne pas exister tant que l'inventaire
--- n'est pas prêt : rappelé à sa mise en route).
---@param name string
---@param definition table
---@return boolean declared
function Bridge.DeclareItem(name, definition)
    local registry = core.registry
    if not registry.exists(ITEMS_REGISTRY) or registry.has(ITEMS_REGISTRY, name) then return false end
    local ok, err = registry.add(ITEMS_REGISTRY, name, definition)
    if not ok then VavaGathering.log.warn("objet '%s' non déclaré : %s", name, tostring(err)) end
    return ok == true
end

--- Vrai si l'objet est connu de l'inventaire (déclaré par ce module ou un autre).
---@param name string
---@return boolean
function Bridge.ItemExists(name)
    return core.registry.exists(ITEMS_REGISTRY) and core.registry.has(ITEMS_REGISTRY, name)
end

-- Compétences -----------------------------------------------------------------------------------------------------

--- XP avec contexte ; `true, { gained, level, rank, leveledUp, blocked? }`.
---@return boolean ok
---@return table|string result
function Bridge.AddXp(source, ctx)
    local called, ok, result = call(SKILLS, 'addXp', source, ctx)
    if not called then return false, 'skills_unavailable' end
    return ok == true, result
end

--- Niveau d'une compétence (0 si inconnu).
---@param source integer
---@param skill string
---@return integer
function Bridge.GetLevel(source, skill)
    local called, level = call(SKILLS, 'getLevel', source, skill)
    return (called and mathType(level) == 'integer') and level or 0
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
        VavaGathering.log.info('%s (par %d) : %s%s', label, source, concat(parts, ', '), called and (' — journal refusé : ' .. tostring(err)) or '')
    end
end

-- Messages --------------------------------------------------------------------------------------------------------

---@param source integer
---@param message string
---@param kind? string
function Bridge.Notify(source, message, kind)
    if source == CONSOLE then
        print(('[%s] %s'):format(VavaGathering.resource, message))
        return
    end
    TriggerClientEvent(EVENTS.NOTIFY, source, message, kind or 'info')
end

---@param source integer
---@param text string
function Bridge.Chat(source, text)
    if source == CONSOLE then
        print(('[%s] %s'):format(VavaGathering.resource, text))
        return
    end
    local called = call(CHAT, 'addMessage', source, { text = text })
    if not called then Bridge.Notify(source, text) end
end

-- Saisons (vava_time, facultatif) ---------------------------------------------------------------------------------

local TIME = 'vava_time'
-- la saison change au plus une fois par jour : relue toutes les 5 s au plus (les nœuds sont relus toutes les 10 s)
local SEASON_CACHE_MS = 5000
local seasonId, seasonReadAt = nil, nil
-- états du module vava_time pendant lesquels il démarre (état relu en base) : la saison viendra
local TIME_STARTING = { declared = true, waiting = true, migrating = true, starting = true }

--- Vrai si vava_time est en train de démarrer : sa saison n'est pas encore connue mais le sera.
---@return boolean
local function timeStarting()
    local record = core.modules.get(TIME)
    return record ~= nil and TIME_STARTING[record.state] == true
end

--- Saison du royaume. nil : vava_time absent, arrêté ou en échec (aucun effet). false : vava_time démarre et ne connaît
--- pas encore la saison — rien ne doit repousser d'ici là (sinon tout le temps écoulé compterait sans saison) ; cet
--- état n'est jamais gardé en cache.
---@return string|false|nil
function Bridge.Season()
    local now = GetGameTimer()
    if seasonReadAt and now - seasonReadAt < SEASON_CACHE_MS then return seasonId end
    local called, season = call(TIME, 'getSeason')
    if called and type(season) == 'string' then
        seasonId, seasonReadAt = season, now
        return season
    end
    if called and season == nil and timeStarting() then
        seasonId, seasonReadAt = nil, nil
        return false
    end
    seasonId, seasonReadAt = nil, now
    return nil
end

--- Facteur de la saison pour une compétence (config.seasons) : `kind` = regen (repousse des charges) ou yield (unités
--- récoltées). 1 sans vava_time, sans saison ou sans réglage ; contrôlé par shared/season.lua (fini, dans [0, 10]).
--- false : saison en attente (vava_time démarre), voir Bridge.Season.
---@param kind 'regen'|'yield'
---@param skill string
---@return number|false
function Bridge.SeasonFactor(kind, skill)
    local season = Bridge.Season()
    if season == false then return false end
    local byKind = season and cfg.seasons and cfg.seasons[kind]
    local bySeason = byKind and byKind[season]
    return VavaGathering.season.factor(bySeason and bySeason[skill])
end

-- Zones du core (abonnements de zone, vAvA_core ≥ 0.11.0) ------------------------------------------------------------

--- Fonction de `core.zones`, isolée : rend ses valeurs, ou `false, code` si elle manque ou lève une erreur.
---@param fn string
---@return boolean|nil ok
---@return any code
local function zoneCall(fn, ...)
    local zones = core.zones
    local target = type(zones) == 'table' and zones[fn] or nil
    if not target then return false, 'unsupported' end
    local results = pack(pcall(target, ...))
    if not results[1] then
        VavaGathering.log.warn('core.zones.%s en erreur : %s', fn, tostring(results[2]))
        return false, 'error'
    end
    return unpack(results, 2, results.n)
end

--- Déclare une zone du module : `true, numéro` ou `false, code`.
function Bridge.ZoneDefine(id, area, state) return zoneCall('define', id, area, state) end
--- Déplace une zone (lieu, rayon, marge) : `true` ou `false, code`.
function Bridge.ZoneMove(id, area) return zoneCall('move', id, area) end
--- Change (et retire) des clés de l'état d'une zone (envoyées aux seuls abonnés, regroupées par tour) : `true` ou
--- `false, code`.
function Bridge.ZoneSet(id, changes, removed)
    if removed then return zoneCall('set', id, changes, removed) end
    return zoneCall('set', id, changes)
end
--- Retire une zone (ses abonnés reçoivent la sortie) : `true` ou `false, code`.
function Bridge.ZoneRemove(id) return zoneCall('remove', id) end

-- Envois ciblés (T-102) ---------------------------------------------------------------------------------------------

--- Envoi fiable au seul joueur `target` par core.net (une sérialisation dans le module ; repli `sendWith`).
---@param target integer
---@param event string
---@return boolean ok
---@return string|nil code
function Bridge.SendPacked(target, event, ...)
    local net = core.net
    if type(net) ~= 'table' then return false, 'unsupported' end
    if type(msgpack) == 'table' and type(msgpack.pack_args) == 'function' then
        local ok, code = net.sendPacked({ latent = 'never' }, target, event, msgpack.pack_args(...))
        if ok or code ~= 'unsupported' then return ok, code end
    end
    return net.sendWith({ latent = 'never' }, target, event, ...)
end

-- Atelier du Conseil (vava_atelier, facultatif ; T-102) -----------------------------------------------------------------

local ATELIER_REGISTRY = 'vava_atelier:editors'

--- Le registre des éditeurs de l'Atelier existe-t-il (vava_atelier démarré) ?
---@return boolean
function Bridge.AtelierExists()
    return core.registry.exists(ATELIER_REGISTRY) == true
end

--- L'atelier est-il déjà au registre ?
---@param key string
---@return boolean
function Bridge.AtelierHas(key)
    return Bridge.AtelierExists() and core.registry.has(ATELIER_REGISTRY, key) == true
end

--- Déclare un atelier au registre de l'Atelier : `true` ou `false, code` (refus du validateur avec son chemin).
---@param key string
---@param def table
---@return boolean ok
---@return string|nil err
function Bridge.AtelierDeclare(key, def)
    if not Bridge.AtelierExists() then return false, 'absent' end
    local called, ok, err = pcall(core.registry.add, ATELIER_REGISTRY, key, def)
    if not called then return false, tostring(ok) end
    return ok == true, err
end
--- Remplace tout l'état d'une zone : `true` ou `false, code`.
function Bridge.ZoneReplace(id, state) return zoneCall('replace', id, state) end

-- Base de données -------------------------------------------------------------------------------------------------

Bridge.db = {
    query = function(sql, params) return core.db.query(sql, params) end,
    single = function(sql, params) return core.db.single(sql, params) end,
    scalar = function(sql, params) return core.db.scalar(sql, params) end,
    insert = function(sql, params) return core.db.insert(sql, params) end,
    update = function(sql, params) return core.db.update(sql, params) end,
    transaction = function(queries) return core.db.transaction(queries) end,
}

--- Entier lu en base, ou `default`.
---@param value any
---@param default integer
---@return integer
function Bridge.Integer(value, default)
    local number = tonumber(value)
    if number == nil then return default end
    return math.tointeger(number) or default
end

--- Nombre lu en base (DECIMAL en texte), ou `default`.
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
