--[[
    server/core/api.lua
    Rôle : surface serveur de l'API publique v1, liée à la ressource appelante.
    Accès : exports.vAvA_core:getApi(1). Documentation : docs/api.md.
    Hors log, modules et version, chaque fonction exige que le module soit actif (pendant setup ou prêt) :
    un module refusé ou non déclaré ne peut rien enregistrer.
    Dépendances : shared/core/api.lua, server/core/database.lua, server/core/net.lua, server/core/rpc.lua,
                  server/core/registry.lua, server/core/modules.lua
]]

local format = string.format

local api = vAvA.api
local modules = vAvA.modules
local registry = vAvA.registry
local net = vAvA.net
local rpc = vAvA.rpc
local database = vAvA.database

api.define(1, function(owner)
    local inactiveError = format("module '%s' inactif : utilisez l'API depuis setup(), après un modules.register() accepté", owner)

    ---@param fn function
    ---@return function
    local function guard(fn)
        return function(...)
            if not modules.isActive(owner) then return nil, inactiveError end
            return fn(...)
        end
    end

    local surface = {
        version = vAvA.version,
        apiVersion = 1,

        log = api.buildLog(owner),

        modules = {
            register = function(def) return modules.declare(owner, def) end,
            get = function(name) return modules.get(name) end,
            list = function() return modules.list() end,
        },

        hooks = api.buildHooks(owner, guard),

        registry = {
            define = guard(function(name, options) return registry.define(owner, name, options) end),
            add = guard(function(name, key, data) return registry.add(owner, name, key, data) end),
            remove = guard(function(name, key) return registry.remove(owner, name, key) end),
            get = guard(function(name, key) return registry.get(name, key) end),
            has = guard(function(name, key) return registry.has(name, key) end),
            exists = guard(function(name) return registry.exists(name) end),
            all = guard(function(name) return registry.all(name) end),
        },

        rpc = {
            register = guard(function(name, options, handler) return rpc.register(owner, name, options, handler) end),
            unregister = guard(function(name) return rpc.unregister(owner, name) end),
            callClient = guard(function(target, name, ...) return rpc.callClient(owner, nil, target, name, ...) end),
            callClientWith = guard(function(options, target, name, ...) return rpc.callClient(owner, options, target, name, ...) end),
        },

        -- envois serveur → client mesurés et comptés (0.10.0) : jamais -1, évènement préfixé par la ressource
        net = {
            send = guard(function(target, event, ...) return net.send(owner, nil, target, event, ...) end),
            sendWith = guard(function(options, target, event, ...)
                return net.send(owner, options, target, event, ...)
            end),
            sendNear = guard(function(coords, radius, event, ...)
                return net.sendNear(owner, nil, coords, radius, event, ...)
            end),
            sendNearWith = guard(function(options, coords, radius, event, ...)
                return net.sendNear(owner, options, coords, radius, event, ...)
            end),
            playersNear = guard(function(coords, radius, options) return net.playersNear(coords, radius, options) end),
            stats = guard(function(options) return net.stats(options) end),
        },

        db = {
            query = guard(function(sql, params) return database.query(owner, sql, params) end),
            single = guard(function(sql, params) return database.single(owner, sql, params) end),
            scalar = guard(function(sql, params) return database.scalar(owner, sql, params) end),
            insert = guard(function(sql, params) return database.insert(owner, sql, params) end),
            update = guard(function(sql, params) return database.update(owner, sql, params) end),
            transaction = guard(function(queries) return database.transaction(owner, queries) end),
        },
    }
    return surface, { guard = guard }
end)
