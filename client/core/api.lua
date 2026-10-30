--[[
    client/core/api.lua
    Rôle : surface client de l'API publique v1, liée à la ressource appelante.
    Accès : exports.vAvA_core:getApi(1) depuis un script client. Documentation : docs/api.md.
    Aucune donnée serveur n'est exposée ici, hors l'état des zones que le serveur a choisi d'envoyer à ce joueur : le
    client logge, réagit à des hooks locaux, dialogue avec le serveur par RPC et lit les zones de son module.
    Dépendances : shared/core/api.lua, client/core/rpc.lua, client/core/zones.lua
]]

local api = vAvA.api
local rpc = vAvA.rpc
local zones = vAvA.zones

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

        -- zones suivies, décidées par le serveur (0.11.0) : celles du module seulement
        zones = {
            watch = function(handler) return zones.watch(owner, handler) end,
            get = function(id) return zones.get(owner, id) end,
            list = function() return zones.list(owner) end,
        },
    }
    return surface, { guard = unguarded }
end)
