--[[
    vava_voice/server/commands.lua
    Rôle : déclaration de la touche de portée et de la commande des zones de voix au registre `core:commands` du core
           (Codex, suggestions du chat).
    Dépendances : config.lua, server/core.lua
]]

local pairs, tostring = pairs, tostring
local format = string.format

local cfg = VavaVoice.config
local REGISTRY = 'core:commands'
local CHAPTER = 'Voix'

local commands = {}
VavaVoice.commands = commands

local function entries()
    return {
        [cfg.command] = { kind = 'key', scope = 'player', key = cfg.key, label = cfg.keyLabel },
        [cfg.zones.command] = { kind = 'command', scope = 'admin', permission = cfg.zones.permission, ui = true, label = 'Zones de voix',
            description = 'Créer, régler et supprimer les zones de voix du royaume (portée, effets).' },
    }
end

--- Déclare la touche et la commande du module. Appelée pendant le setup ; sans ce registre (core plus ancien), rien.
---@return boolean ok
---@return string|nil err
function commands.declare()
    local core = VavaVoice.core
    if not core.registry.exists(REGISTRY) then return true end
    for name, def in pairs(entries()) do
        def.module, def.chapter = VavaVoice.resource, CHAPTER
        local ok, err = core.registry.add(REGISTRY, name, def)
        if not ok then return false, format('%s : %s', name, tostring(err)) end
    end
    return true
end
