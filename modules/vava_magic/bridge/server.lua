--[[
    vava_magic/bridge/server.lua
    Rôle : SEUL point de contact, côté serveur, entre la magie et le core / les autres modules : personnage, droits du
           Conseil, notifications, objets de l'inventaire, sauvegarde de la fiche, base de données, santé (chaîne de
           dégâts de vava_health : coups des sorts, vie tenue par le serveur, hook des coups, modificateurs).
           Pour brancher la magie sur un autre core, réécrire les fonctions de ce fichier (et de bridge/client.lua) :
           le reste du module ne connaît qu'elles.
    Implémentation : vAvA_core (API documentée dans docs/api.md) et ses modules officiels. Chaque appel à une autre
           ressource est isolé : un module absent ou en erreur ne retire que la fonction concernée.
    Dépendances : shared/constants.lua, config.lua, server/core.lua
]]

local type, pairs, ipairs, pcall, tostring, tonumber = type, pairs, ipairs, pcall, tostring, tonumber
local mathType = math.type
local pack, unpack, concat = table.pack, table.unpack, table.concat
local GetResourceState, TriggerClientEvent, IsPlayerAceAllowed, CreateThread, GetPlayers =
    GetResourceState, TriggerClientEvent, IsPlayerAceAllowed, CreateThread, GetPlayers

local core = VavaMagic.core
if not core then return end

local cfg = VavaMagic.config
local LINKS = VavaMagic.LINKS
local EVENTS = VavaMagic.EVENTS
local FIELD = VavaMagic.SHEET_FIELD
local CONSOLE = 0

local Bridge = {}
VavaMagic.bridge = Bridge

local function invoke(resource, fn, ...)
    local target = exports[resource]
    return target[fn](target, ...)
end

--- Export d'une autre ressource, isolé. Renvoie ok (appel réussi) puis ses valeurs.
---@return boolean called
local function call(resource, fn, ...)
    if GetResourceState(resource) ~= 'started' then return false end
    local results = pack(pcall(invoke, resource, fn, ...))
    if not results[1] then
        VavaMagic.log.warn('%s.%s en erreur : %s', resource, fn, tostring(results[2]))
        return false
    end
    return true, unpack(results, 2, results.n)
end

-- Personnage ----------------------------------------------------------------------------------------------------

--- Identifiant unique du personnage actif du joueur, ou nil (en sélection, pas de personnage).
---@param source integer
---@return integer|nil
function Bridge.GetCharacterId(source)
    local session = core.players.get(source)
    if not session or session.state ~= 'active' then return nil end
    return session.characterId
end

--- Nom du personnage actif (prénom nom), pour les commandes du Conseil.
---@param source integer
---@return string|nil
function Bridge.GetCharacterName(source)
    local character = core.characters.getActive(source)
    if not character then return nil end
    return character.firstName .. ' ' .. character.lastName
end

--- Joueurs dont le personnage est en jeu (sources).
---@return integer[]
function Bridge.ActivePlayers()
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src and Bridge.GetCharacterId(src) then list[#list + 1] = src end
    end
    return list
end

-- Droits du Conseil --------------------------------------------------------------------------------------------

--- Commandes du Conseil permises ? La console du serveur l'est toujours ; sinon le droit vava_admin de la config,
--- ou la permission ACE `admin.ace` quand vava_admin n'est pas lancé.
---@param source integer
---@return boolean
function Bridge.IsAdmin(source)
    if source == CONSOLE then return true end
    if GetResourceState(LINKS.ADMIN) == 'started' then
        local called, allowed = call(LINKS.ADMIN, 'can', source, cfg.admin.permission)
        return called and allowed == true
    end
    return IsPlayerAceAllowed(source, cfg.admin.ace) == true
end

--- Inscrit une action du Conseil au journal du Registre (sans lui : la console du serveur la garde).
---@param source integer
---@param label string   32 signes au plus
---@param details table  { clé = texte ou nombre }, 8 au plus
function Bridge.AdminLog(source, label, details)
    local called, ok, err = false, nil, nil
    if source ~= CONSOLE then called, ok, err = call(LINKS.ADMIN, 'log', source, label, details) end
    if not called or ok ~= true then
        local parts = {}
        for key, value in pairs(details) do parts[#parts + 1] = key .. '=' .. tostring(value) end
        VavaMagic.log.info('%s (par %d) : %s%s', label, source, concat(parts, ', '), called and (' — journal refusé : ' .. tostring(err)) or '')
    end
end

--- Vrai si le Conseil a immobilisé ce joueur (Registre, vava_admin ≥ 1.6.0) : la fin d'un gel ne le libère pas.
--- vava_admin absent ou en erreur : non.
---@param source integer
---@return boolean
function Bridge.IsHeldByCouncil(source)
    local called, frozen = call(LINKS.ADMIN, 'isFrozen', source)
    return called and frozen == true
end

--- Prévient `handler` après chaque action du Conseil (hook `vava_admin:action` : { actor, action, target?, details }),
--- pour garder figé celui que la magie gèle quand « Libérer » du Registre relâche son ped.
---@param handler fun(payload: table)
---@return boolean ok
---@return string|nil err
function Bridge.OnCouncilAction(handler)
    local id, err = core.hooks.after(LINKS.ADMIN .. ':action', handler)
    if not id then return false, err end
    return true
end

-- Notifications ---------------------------------------------------------------------------------------------------

--- Message à un joueur ; nature : info (défaut), success, warning, danger.
---@param source integer
---@param message string
---@param kind? string
function Bridge.Notify(source, message, kind)
    if source == CONSOLE then
        print(('[%s] %s'):format(VavaMagic.resource, message))
        return
    end
    TriggerClientEvent(EVENTS.NOTIFY, source, message, kind or 'info')
end

-- Objets (vava_inventory) ------------------------------------------------------------------------------------------

---@param source integer
---@param item string
---@return boolean
function Bridge.HasItem(source, item)
    local called, count = call(LINKS.INVENTORY, 'count', source, item)
    return called and mathType(count) == 'integer' and count >= 1
end

---@param source integer
---@param item string
---@param count integer
---@param metadata? table
---@return boolean ok
---@return string|nil code
function Bridge.AddItem(source, item, count, metadata)
    local called, ok, code = call(LINKS.INVENTORY, 'add', source, item, count, metadata)
    if not called then return false, 'inventory_unavailable' end
    return ok == true, code
end

---@param source integer
---@param item string
---@param count integer
---@return boolean ok
---@return string|nil code
function Bridge.RemoveItem(source, item, count)
    local called, ok, code = call(LINKS.INVENTORY, 'remove', source, item, count)
    if not called then return false, 'inventory_unavailable' end
    return ok == true, code
end

--- Exemplaires d'un objet portés par le joueur, avec leurs métadonnées : { { instanceId, metadata } }.
---@param source integer
---@param item string
---@return table[]
function Bridge.GetItemMetadata(source, item)
    local list = {}
    local called, items = call(LINKS.INVENTORY, 'getItems', source)
    if not called or type(items) ~= 'table' then return list end
    for _, entry in ipairs(items) do
        if entry.item == item then
            list[#list + 1] = { instanceId = entry.id, metadata = type(entry.metadata) == 'table' and entry.metadata or {} }
        end
    end
    return list
end

--- Remplace les métadonnées d'un exemplaire porté par le joueur (vava_inventory 1.3.0).
---@param source integer
---@param instanceId integer
---@param metadata table
---@return boolean
function Bridge.SetItemMetadata(source, instanceId, metadata)
    local called, ok = call(LINKS.INVENTORY, 'setMetadata', source, instanceId, metadata)
    return called and ok == true
end

-- objets utilisables du module : (re)déclarés quand l'inventaire est prêt
local usable = {}

local function declare(name)
    local entry = usable[name]
    local registry = core.registry
    if not registry.exists(LINKS.ITEMS_REGISTRY) or registry.has(LINKS.ITEMS_REGISTRY, name) then return end
    local definition = {}
    for key, value in pairs(entry.definition) do
        if key ~= 'name' then definition[key] = value end
    end
    -- l'objet n'est jamais consommé : la fonction du module travaille dans son propre thread
    definition.onUse = function(source, instance)
        CreateThread(function()
            entry.callback(source, { instanceId = instance.id, metadata = type(instance.metadata) == 'table' and instance.metadata or {} })
        end)
        return false
    end
    local ok, err = registry.add(LINKS.ITEMS_REGISTRY, name, definition)
    if not ok then VavaMagic.log.warn("objet '%s' non déclaré : %s", name, tostring(err)) end
end

--- Objet utilisable : `callback(source, { instanceId, metadata })` à chaque usage (l'objet reste dans l'inventaire).
---@param item string
---@param definition table  champs d'un objet de vava_inventory (label, width, height, weight, stack, image…)
---@param callback fun(source: integer, instance: table)
function Bridge.RegisterUsableItem(item, definition, callback)
    usable[item] = { definition = definition, callback = callback }
    if VavaMagic.ready then declare(item) end
end

-- Fiche magie (persistance) -------------------------------------------------------------------------------------

--- Déclare le champ de personnage qui porte la fiche (privé : jamais envoyé au client).
---@param schema table
---@return boolean ok
---@return string|nil err
function Bridge.DefineSheet(schema)
    return core.characters.defineField(FIELD, { schema = schema, visibility = 'private' })
end

--- Fiche enregistrée du personnage, ou nil s'il n'en a jamais eu.
---@param characterId integer
---@return table|nil
function Bridge.LoadSheet(characterId)
    local value = core.characters.get(characterId, FIELD)
    return type(value) == 'table' and value or nil
end

--- Écrit la fiche dans le personnage : le core la sauvegarde en base avec le personnage (par lots, et au départ).
---@param characterId integer
---@param sheet table
---@return boolean ok
---@return string|nil err
function Bridge.SaveSheet(characterId, sheet)
    return core.characters.set(characterId, FIELD, sheet)
end

-- Base de données (tables du module, sql/) ---------------------------------------------------------------------

Bridge.db = {
    query = function(sql, params) return core.db.query(sql, params) end,
    single = function(sql, params) return core.db.single(sql, params) end,
    scalar = function(sql, params) return core.db.scalar(sql, params) end,
    insert = function(sql, params) return core.db.insert(sql, params) end,
    update = function(sql, params) return core.db.update(sql, params) end,
}

-- Santé et chaîne de dégâts (vava_health ≥ 1.3.0) -----------------------------------------------------------------

--- Coup porté par un sort : `exports.vava_health:hit(cible, paquet)` (paquet de shared/harm.lua). Rend le résultat de
--- la chaîne (`applied`, `absorbed`, `cancelled`…), ou nil et un code : celui de vava_health, ou `health_unavailable`
--- quand il est arrêté, en erreur ou sans chaîne (plus ancien que 1.3.0). Sans vava_health, aucun sort ne blesse
--- personne (plus aucun repli chez le client). Appel isolé et silencieux : combat.lua le signale, une fois par minute
--- (pas une ligne de console par coup).
---@param target integer
---@param packet table
---@return table|nil result
---@return string|nil code
function Bridge.Hit(target, packet)
    if GetResourceState(LINKS.HEALTH) ~= 'started' then return nil, 'health_unavailable' end
    local called, result, code = pcall(invoke, LINKS.HEALTH, 'hit', target, packet)
    if not called then return nil, 'health_unavailable' end
    if type(result) ~= 'table' then return nil, type(code) == 'string' and code or 'refused' end
    return result
end

--- Vie du joueur tenue par le serveur de vava_health (0 à 1, 0 à terre), ou nil (vava_health absent, personnage
--- non suivi). Jamais lue sur le ped : un client qui garde sa vie GTA au maximum n'y gagne rien.
---@param source integer
---@return number|nil
function Bridge.GetHealth(source)
    local called, state = call(LINKS.HEALTH, 'get', source)
    if not called or type(state) ~= 'table' or type(state.health) ~= 'number' then return nil end
    return state.health
end

---@param source integer
---@return boolean
function Bridge.IsDowned(source)
    local called, downed = call(LINKS.HEALTH, 'isDowned', source)
    return called and downed == true
end

--- Prévient `handler` après chaque coup de la chaîne et chaque perte native (hook `vava_health:hit` after :
--- { target, applied, … }). Le hook appartient au core : l'abonnement survit aux redémarrages de vava_health.
---@param handler fun(payload: table)
---@return boolean ok
---@return string|nil err
function Bridge.OnHit(handler)
    local id, err = core.hooks.after(LINKS.HEALTH_HIT, handler)
    if not id then return false, err end
    return true
end

-- modificateurs de la chaîne : clé → { stage, priority?, label, apply } ; (re)déclarés quand vava_health démarre
local modifiers = {}
-- points d'une vie pleine pour la chaîne (vocabulary), relus à chaque déclaration
local chainPoints = nil

local function declareModifiers()
    local registry = core.registry
    if not registry.exists(LINKS.HEALTH_MODIFIERS) then return end
    local called, vocabulary = call(LINKS.HEALTH, 'vocabulary')
    if called and type(vocabulary) == 'table' and type(vocabulary.healthPoints) == 'number' then
        chainPoints = vocabulary.healthPoints
    end
    for key, definition in pairs(modifiers) do
        if not registry.has(LINKS.HEALTH_MODIFIERS, key) then
            local ok, err = registry.add(LINKS.HEALTH_MODIFIERS, key, definition)
            if not ok then VavaMagic.log.warn("modificateur '%s' non déclaré : %s", key, tostring(err)) end
        end
    end
end

--- Modificateurs de la chaîne de dégâts tenus par la magie (au plus un par étape ; clés `vava_magic:…`) : déclarés au
--- registre `vava_health:modifiers` s'il existe, puis à chaque démarrage de vava_health (le registre disparaît avec
--- lui). Chaque `apply(ctx)` lit les données de la magie et rend un résultat, sans jamais céder la main.
---@param list table<string, table>
function Bridge.SetModifiers(list)
    modifiers = list
    if VavaMagic.ready then declareModifiers() end
end

--- Points d'une vie pleine pour la chaîne (vava_health `vocabulary().healthPoints`), nil s'ils ne sont pas connus.
---@return number|nil
function Bridge.ChainHealthPoints()
    return chainPoints
end

--- Déclare les objets et les modificateurs, et suit les redémarrages de l'inventaire et de vava_health. Appelé
--- pendant le setup du module.
---@return boolean ok
---@return string|nil err
function Bridge.start()
    for name in pairs(usable) do declare(name) end
    declareModifiers()
    local id, err = core.hooks.after('core:module:ready', function(payload)
        if payload.name == LINKS.INVENTORY then
            for name in pairs(usable) do declare(name) end
        elseif payload.name == LINKS.HEALTH then
            declareModifiers()
        end
    end)
    if not id then return false, err end
    return true
end
