--[[
    client/core/api.lua
    Rôle : surface client de l'API publique v1, liée à la ressource appelante.
    Accès : exports.vAvA_core:getApi(1) depuis un script client. Documentation : docs/api.md.
    Aucune donnée serveur n'est exposée ici : le client ne fait que logger, réagir à des hooks locaux et
    dialoguer avec le serveur par RPC.
    Dépendances : shared/core/api.lua, client/core/rpc.lua
]]

local api = vAvA.api
local rpc = vAvA.rpc

-- Côté client, pas de cycle de vie de module : chaque ressource cliente utilise l'API librement.
---@param fn function
---@return function
local function unguarded(fn)
    return fn
end

api.define(1, function(owner)
    local surface = {
        version = vAvA.version,
        apiVersion = 1,

        log = api.buildLog(owner),

        hooks = api.buildHooks(owner, unguarded),

        rpc = {
            call = function(name, ...) return rpc.call(nil, name, ...) end,
            callWith = function(options, name, ...) return rpc.call(options, name, ...) end,
            emit = function(name, ...) return rpc.emit(name, ...) end,
            register = function(name, handler) return rpc.register(owner, name, handler) end,
            unregister = function(name) return rpc.unregister(owner, name) end,
        },
    }
    return surface, { guard = unguarded }
end)
