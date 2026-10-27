--[[
    shared/core/api.lua
    Rôle : mécanique commune de l'API publique, client et serveur : versions majeures, cache par ressource,
           export unique getApi, et blocs partagés (log, hooks) des surfaces d'API.
    Chaque surface est liée à la ressource appelante une seule fois (GetInvokingResource) : tout ce qu'elle
    enregistre porte ce propriétaire et est purgé à son arrêt.
    Dépendances : shared/init.lua, shared/lib/table.lua, shared/lib/string.lua, shared/core/logger.lua, shared/core/hooks.lua
]]

local type, tostring = type, tostring
local mathType = math.type
local format = string.format
local concat = table.concat
local GetInvokingResource = GetInvokingResource

local tbl = vAvA.lib.table
local str = vAvA.lib.string
local logger = vAvA.logger
local hooks = vAvA.hooks
local log = logger.create('api')

local api = {}
vAvA.api = api

---@type table<integer, fun(owner: string): table, table>
local builders = {}
---@type table<integer, { key: string, builder: fun(owner: string, context: table): table }[]>
local extensions = {}
---@type table<string, table<integer, table>>
local cache = {}

--- Déclare la surface d'une version majeure de l'API.
--- Le builder renvoie la surface et son contexte ({ guard }), transmis aux extensions.
---@param major integer
---@param builder fun(owner: string): table, table
function api.define(major, builder)
    builders[major] = builder
end

--- Ajoute un bloc à une version de l'API (domaine du core : joueurs, personnages…), sans que la surface
--- de base connaisse les domaines. Ajouter un bloc est rétrocompatible : la version majeure ne change pas.
---@param major integer
---@param key string
---@param builder fun(owner: string, context: table): table
function api.extend(major, key, builder)
    local list = extensions[major]
    if not list then
        list = {}
        extensions[major] = list
    end
    list[#list + 1] = { key = key, builder = builder }
end

---@param major integer
---@param owner string
---@return table
local function build(major, owner)
    local surface, context = builders[major](owner)
    local list = extensions[major]
    if list then
        for i = 1, #list do
            local extension = list[i]
            if surface[extension.key] == nil then
                surface[extension.key] = extension.builder(owner, context)
            else
                log.error("extension d'API '%s' ignorée : la clé existe déjà en v%d", extension.key, major)
            end
        end
    end
    return surface
end

--- Point d'entrée unique, exporté sous le nom getApi.
---@param major integer
---@return table|nil surface
---@return string|nil err
local function getApi(major)
    local owner = GetInvokingResource()
    if not owner then
        return nil, 'getApi doit être appelé depuis une autre ressource'
    end
    local builder = mathType(major) == 'integer' and builders[major]
    if not builder then
        return nil, format("version d'API '%s' non supportée (disponibles : %s)",
            tostring(major), concat(tbl.sortedKeys(builders), ', '))
    end
    local perOwner = cache[owner]
    if not perOwner then
        perOwner = {}
        cache[owner] = perOwner
    end
    local surface = perOwner[major]
    if not surface then
        surface = build(major, owner)
        perOwner[major] = surface
    end
    return surface
end

--- Bloc log : messages préfixés par le nom de la ressource appelante.
---@param owner string
---@return vAvA.ScopedLogger
function api.buildLog(owner)
    return logger.create(owner)
end

--- Bloc hooks. Une ressource s'abonne à n'importe quel hook, mais ne déclenche que ceux de son espace "<owner>:".
---@param owner string
---@param guard fun(fn: function): function  contrôle d'accès appliqué à chaque fonction
---@return table
function api.buildHooks(owner, guard)
    local namespace = owner .. ':'

    local function outsideNamespace(name)
        if type(name) == 'string' and str.hasPrefix(name, namespace) then return nil end
        return format("hook '%s' hors de l'espace de noms '%s*'", tostring(name), namespace)
    end

    return {
        before = guard(function(name, handler, priority)
            return hooks.subscribe(owner, 'before', name, handler, priority)
        end),
        after = guard(function(name, handler, priority)
            return hooks.subscribe(owner, 'after', name, handler, priority)
        end),
        off = guard(function(id)
            return hooks.unsubscribe(owner, id)
        end),
        runBefore = guard(function(name, payload)
            local err = outsideNamespace(name)
            if err then return false, err end
            return hooks.runBefore(name, payload)
        end),
        runAfter = guard(function(name, payload)
            local err = outsideNamespace(name)
            if err then return false, err end
            hooks.runAfter(name, payload)
            return true
        end),
    }
end

--- Publie l'export getApi. Appelé par init.lua (les fichiers core/ n'ont aucun effet de bord au chargement).
function api.register()
    exports('getApi', getApi)
end

--- Oublie les surfaces construites pour une ressource arrêtée.
---@param owner string
function api.forget(owner)
    cache[owner] = nil
end
