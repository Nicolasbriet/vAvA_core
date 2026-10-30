--[[
    vava_atelier/bridge/server.lua
    Rôle : SEUL point de contact, côté serveur, entre l'Atelier et le core / les autres modules : personnage et compte
           d'un joueur, Registre du Conseil (vava_admin : prêt ?, droits, rang, nom au journal, recopie au journal),
           objets du royaume (registre vava_inventory:items, gardé en mémoire et tenu à jour par les hooks du
           registre), envois ciblés par core.net, appels des fonctions des éditeurs (isolés, chronométrés). Chaque appel
           à une autre ressource est isolé : un module absent ou en erreur ne retire que la fonction concernée.
    Dépendances : shared/constants.lua, config.lua, shared/text.lua, server/core.lua
]]

local type, pairs, pcall, tostring, tonumber, select = type, pairs, pcall, tostring, tonumber, select
local pack, unpack, sort = table.pack, table.unpack, table.sort
local find, match, sub = string.find, string.match, string.sub
local GetResourceState, GetGameTimer = GetResourceState, GetGameTimer

-- blancs ASCII de fin, écrits octet par octet : `%s` dépend de la locale du système et couperait le « à » final d'un
-- nom (octet 0xA0)
local TRAILING = '[\t-\r ]+$'

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local text = VavaAtelier.text
local OUT = VavaAtelier.OUT
local ITEMS = VavaAtelier.ITEMS_REGISTRY
local ITEM_PATTERN, MAX_ITEM = VavaAtelier.ITEM_PATTERN, VavaAtelier.MAX_ITEM
local ADMIN = 'vava_admin'
local CONSOLE = 0

local Bridge = {}
VavaAtelier.bridge = Bridge

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
        VavaAtelier.log.warn('%s.%s en erreur : %s', resource, fn, tostring(results[2]))
        return false
    end
    return true, unpack(results, 2, results.n)
end

-- Personnage ------------------------------------------------------------------------------------------------------

--- Personnage actif d'un joueur ({ id, accountId, firstName, lastName, … }), seulement si sa session est `active`.
---@param source integer
---@return table|nil
function Bridge.Character(source)
    local session = core.players.get(source)
    if not session or session.state ~= 'active' then return nil end
    return core.characters.getActive(source)
end

--- Compte d'un joueur en jeu, ou nil.
---@param source integer
---@return integer|nil
function Bridge.AccountId(source)
    local session = core.players.get(source)
    return session and session.accountId or nil
end

-- Registre du Conseil ------------------------------------------------------------------------------------------------

--- Version `a` au moins égale à `b` (« 1.10.0 » ≥ « 1.8.0 ») ; une version illisible ne l'est jamais.
---@param a any
---@param b string
---@return boolean
local function atLeast(a, b)
    if type(a) ~= 'string' then return false end
    local ma, na, pa = match(a, '^(%d+)%.(%d+)%.(%d+)')
    local mb, nb, pb = match(b, '^(%d+)%.(%d+)%.(%d+)')
    if not ma or not mb then return false end
    ma, na, pa, mb, nb, pb = tonumber(ma), tonumber(na), tonumber(pa), tonumber(mb), tonumber(nb), tonumber(pb)
    if ma ~= mb then return ma > mb end
    if na ~= nb then return na > nb end
    return pa >= pb
end

-- version de vava_admin déjà signalée trop ancienne (une ligne par version vue)
local warnedVersion = nil

--- vava_admin démarré, prêt (module `ready`) et assez récent (`adminVersion`) : sans lui, l'Atelier refuse de s'ouvrir.
---@return boolean
function Bridge.AdminReady()
    if GetResourceState(ADMIN) ~= 'started' then return false end
    local module = core.modules.get(ADMIN)
    if module == nil or module.state ~= 'ready' then return false end
    if not atLeast(module.version, cfg.adminVersion) then
        if warnedVersion ~= module.version then
            warnedVersion = module.version
            VavaAtelier.log.error('vava_admin %s trop ancien : %s au moins attendu', tostring(module.version),
                cfg.adminVersion)
        end
        return false
    end
    return true
end

--- Droit du Conseil, relu auprès de vava_admin à chaque appel (seule une réponse exactement vraie compte).
---@param source integer
---@param right string
---@return boolean
function Bridge.Can(source, right)
    local called, allowed = call(ADMIN, 'can', source, right)
    return called and allowed == true
end

--- Libellé du rang d'un membre (« Sénéchal »), ou nil.
---@param source integer
---@return string|nil
function Bridge.RankLabel(source)
    local called, rank = call(ADMIN, 'rankOf', source)
    if not called or type(rank) ~= 'table' or type(rank.label) ~= 'string' then return nil end
    return rank.label
end

--- Nom d'un membre au journal : « Sénéchal Aldric Morn » (comme le Registre), borné ; nil sans rang ni personnage.
---@param source integer
---@return string|nil
function Bridge.ActorLabel(source)
    local rank = Bridge.RankLabel(source)
    local character = core.characters.getActive(source)
    if not rank or not character then return nil end
    local name = (tostring(character.firstName or '') .. ' ' .. tostring(character.lastName or '')):gsub(TRAILING, '')
    return text.truncate(rank .. ' ' .. name, OUT.actor)
end

--- Recopie d'une ligne au journal du Registre (libellé de 32 caractères, détails bornés par vava_admin).
---@param source integer
---@param label string
---@param details table
---@return boolean
function Bridge.MirrorLog(source, label, details)
    if source == CONSOLE then return false end
    local called, ok, code = call(ADMIN, 'log', source, label, details)
    if called and not ok then VavaAtelier.log.warn('recopie au journal du Registre refusée : %s', tostring(code)) end
    return called and ok == true
end

-- Envois ------------------------------------------------------------------------------------------------------------

--- Envoi fiable au seul joueur `target` (une sérialisation, mesurée par core.net ; repli `sendWith`, aussi pour un
--- évènement sans charge).
---@param target integer
---@param event string
---@return boolean ok
---@return string|nil code
function Bridge.Send(target, event, ...)
    if select('#', ...) > 0 and type(msgpack) == 'table' and type(msgpack.pack_args) == 'function' then
        local ok, code = core.net.sendPacked({ latent = 'never' }, target, event, msgpack.pack_args(...))
        if ok or code ~= 'unsupported' then return ok, code end
    end
    return core.net.sendWith({ latent = 'never' }, target, event, ...)
end

-- Fonctions des éditeurs ---------------------------------------------------------------------------------------------

--- Appelle une fonction d'un éditeur (fonction d'une autre ressource), isolée et chronométrée : une erreur, ou la
--- ressource arrêtée pendant l'appel, rend `false` et une ligne d'erreur en console ; au-delà de
--- `limits.slowCallbackMs`, une ligne d'avertissement.
---@param editorId string
---@param name string  nom de la fonction (index, read, validate…)
---@param fn any
---@return boolean called
function Bridge.CallEditor(editorId, name, fn, ...)
    local started = GetGameTimer()
    local results = pack(pcall(fn, ...))
    local elapsed = GetGameTimer() - started
    if elapsed > cfg.limits.slowCallbackMs then
        VavaAtelier.log.warn('%s.%s lente : %d ms (au-delà de %d ms)', editorId, name, elapsed,
            cfg.limits.slowCallbackMs)
    end
    if not results[1] then
        VavaAtelier.log.error('%s.%s en erreur : %s', editorId, name, tostring(results[2]))
        return false
    end
    return true, unpack(results, 2, results.n)
end

-- Objets du royaume -------------------------------------------------------------------------------------------------

-- nom → { label, image?, category } ; nil : pas encore lu (relu à la demande)
local items = nil
-- liste triée par libellé normalisé, refaite après un changement
local sorted = nil

---@param name string
---@param def any
---@return table|nil
local function slim(name, def)
    if type(def) ~= 'table' or type(name) ~= 'string' or #name > MAX_ITEM or not find(name, ITEM_PATTERN) then
        return nil
    end
    local label = type(def.label) == 'string' and text.isUtf8(def.label) and def.label or name
    local image = def.image
    if type(image) ~= 'string' or #image > OUT.image or sub(image, 1, 6) ~= 'nui://' then image = nil end
    return {
        value = name, label = text.truncate(label, OUT.optionLabel), image = image,
        category = type(def.category) == 'string' and def.category or '',
        search = text.normalize(label .. ' ' .. name),
    }
end

local function loadItems()
    items, sorted = {}, nil
    for name, def in pairs(core.registry.all(ITEMS) or {}) do
        items[name] = slim(name, def)
    end
end

--- Le registre des objets existe-t-il (vava_inventory démarré) ?
---@return boolean
function Bridge.ItemsReady()
    return core.registry.exists(ITEMS)
end

--- Objet du royaume : { value, label, image?, category }, ou nil ; nil, 'unavailable' sans registre des objets.
---@param name string
---@return table|nil
---@return string|nil err
function Bridge.Item(name)
    if not core.registry.exists(ITEMS) then return nil, 'unavailable' end
    if not items then loadItems() end
    return items[name]
end

--- Objets du royaume triés par libellé (liste partagée : ne pas la modifier), ou nil sans registre des objets.
---@return table[]|nil
function Bridge.Items()
    if not core.registry.exists(ITEMS) then return nil end
    if not items then loadItems() end
    if not sorted then
        sorted = {}
        for _, item in pairs(items) do sorted[#sorted + 1] = item end
        sort(sorted, function(a, b)
            if a.search ~= b.search then return a.search < b.search end
            return a.value < b.value
        end)
    end
    return sorted
end

--- Hooks du registre des objets : entrée ajoutée ou retirée, registre disparu (vava_inventory arrêté).
---@param kind 'added'|'removed'|'dropped'
---@param key? string
function Bridge.ItemsChanged(kind, key)
    if not items then return end
    sorted = nil
    if kind == 'dropped' then
        items = nil
    elseif kind == 'removed' then
        items[key] = nil
    elseif kind == 'added' then
        items[key] = slim(key, core.registry.get(ITEMS, key))
    end
end
