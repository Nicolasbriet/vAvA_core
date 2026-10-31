--[[
    server/players/api.lua
    Rôle : blocs players et characters de l'API serveur v1 (ajout rétrocompatible via api.extend).
    Comme le reste de l'API, chaque fonction exige que le module appelant soit actif.
    Dépendances : shared/core/api.lua, server/players/accounts.lua, server/players/fields.lua,
                  server/players/characters.lua
]]

local api = vAvA.api
local accounts = vAvA.accounts
local fields = vAvA.fields
local characters = vAvA.characters

api.extend(1, 'players', function(_, context)
    local guard = context.guard
    return {
        get = guard(function(src) return accounts.describe(src) end),
        getByAccount = guard(function(accountId) return accounts.sourceOf(accountId) end),
    }
end)

api.extend(1, 'characters', function(owner, context)
    local guard = context.guard
    return {
        defineField = guard(function(name, options) return fields.define(owner, name, options) end),
        create = guard(function(src, identity, initialFields) return characters.create(src, identity, initialFields) end),
        getActive = guard(function(src) return characters.describeActive(src) end),
        playSeconds = guard(function(characterId) return characters.playSeconds(characterId) end),
        isSpawned = guard(function(src) return characters.isSpawned(src) end),
        get = guard(function(characterId, name) return characters.getField(characterId, name) end),
        set = guard(function(characterId, name, value) return characters.setField(characterId, name, value) end),
        unload = guard(function(src) return characters.unload(src, owner) end),
        spawn = guard(function(src, coords) return characters.spawn(src, coords) end),
    }
end)
