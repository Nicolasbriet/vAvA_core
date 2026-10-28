--[[
    vava_health/server/commands.lua
    Rôle : déclaration des touches de la santé (relever, rendre l'âme) au registre `core:commands` du core (Codex).
    Dépendances : config.lua, server/core.lua, client/keys.lua (noms des commandes liées aux touches)
]]

local pairs, tostring = pairs, tostring
local format = string.format

local cfg = VavaHealth.config
local REGISTRY = 'core:commands'
local CHAPTER = 'Santé'
-- mêmes noms que client/keys.lua
local ASSIST_COMMAND = 'vava_health_assist'
local GIVE_UP_COMMAND = 'vava_health_giveup'

local commands = {}
VavaHealth.commands = commands

local function entries()
    return {
        [ASSIST_COMMAND] = { kind = 'key', scope = 'player', key = cfg.keys.assist, label = cfg.labels.assist },
        [GIVE_UP_COMMAND] = { kind = 'key', scope = 'player', key = cfg.keys.giveUp, label = cfg.labels.giveUp, hold = true },
    }
end

--- Déclare les touches du module. Appelée pendant le setup ; sans ce registre (core plus ancien), rien.
---@return boolean ok
---@return string|nil err
function commands.declare()
    local core = VavaHealth.core
    if not core.registry.exists(REGISTRY) then return true end
    for name, def in pairs(entries()) do
        def.module, def.chapter = VavaHealth.resource, CHAPTER
        local ok, err = core.registry.add(REGISTRY, name, def)
        if not ok then return false, format('%s : %s', name, tostring(err)) end
    end
    return true
end
