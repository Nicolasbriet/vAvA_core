--[[
    client/players/api.lua
    Rôle : bloc characters de l'API client v1 (ajout rétrocompatible via api.extend). Base d'un futur écran de
           sélection : chaque fonction est une intention envoyée au serveur, qui valide et décide.
    Retours des fonctions RPC : ok (transport), puis la réponse du serveur (succès, résultat ou code).
    Dépendances : shared/core/api.lua, client/core/rpc.lua, client/players/session.lua, client/players/spawn.lua
]]

local api = vAvA.api
local rpc = vAvA.rpc
local session = vAvA.session
local spawn = vAvA.spawn
local RPC = vAvA.CHARACTER_RPC

api.extend(1, 'characters', function()
    return {
        current = function() return session.current() end,
        awaitingSelection = function() return spawn.isHolding() end,
        list = function() return rpc.call(nil, RPC.LIST) end,
        create = function(firstName, lastName, sex) return rpc.call(nil, RPC.CREATE, firstName, lastName, sex) end,
        select = function(characterId) return rpc.call(nil, RPC.SELECT, characterId) end,
        unload = function() return rpc.call(nil, RPC.UNLOAD) end,
        delete = function(characterId) return rpc.call(nil, RPC.DELETE, characterId) end,
    }
end)
