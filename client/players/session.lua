--[[
    client/players/session.lua
    Rôle : cache local du personnage actif du joueur (identité + champs owner/public, rien d'autre : le serveur
           n'envoie jamais les données d'un autre joueur ni les champs privés) et hooks client associés.
    Dépendances : shared/init.lua, shared/core/hooks.lua
]]

local type, pairs = type, pairs
local mathType = math.type
local RegisterNetEvent = RegisterNetEvent

local EVENTS = vAvA.EVENTS
local hooks = vAvA.hooks

local HOOK_LOADED = 'core:character:loaded'
local HOOK_FIELD_CHANGED = 'core:character:fieldChanged'
local HOOK_UNLOADED = 'core:character:unloaded'

local session = {}
vAvA.session = session

---@class vAvA.LocalCharacter
---@field id integer
---@field firstName string
---@field lastName string
---@field sex string
---@field fields table<string, any>

---@type vAvA.LocalCharacter|nil
local current = nil

--- Personnage actif du joueur, ou nil (en sélection).
---@return vAvA.LocalCharacter|nil
function session.current()
    return current
end

--- Branche les events du serveur. Appelé par client/init.lua.
function session.start()
    RegisterNetEvent(EVENTS.CHARACTER_LOADED, function(payload)
        if type(payload) ~= 'table' or mathType(payload.id) ~= 'integer' then return end
        if type(payload.fields) ~= 'table' then payload.fields = {} end
        current = payload
        hooks.runAfter(HOOK_LOADED, payload)
    end)

    RegisterNetEvent(EVENTS.CHARACTER_FIELDS, function(values, cleared)
        if not current then return end
        if type(values) == 'table' then
            for name, value in pairs(values) do
                current.fields[name] = value
                hooks.runAfter(HOOK_FIELD_CHANGED, { field = name, value = value })
            end
        end
        if type(cleared) == 'table' then
            for i = 1, #cleared do
                current.fields[cleared[i]] = nil
                hooks.runAfter(HOOK_FIELD_CHANGED, { field = cleared[i] })
            end
        end
    end)

    RegisterNetEvent(EVENTS.CHARACTER_UNLOADED, function(characterId)
        if not current or current.id ~= characterId then return end
        current = nil
        hooks.runAfter(HOOK_UNLOADED, { id = characterId })
    end)
end
