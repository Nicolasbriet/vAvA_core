--[[
    vava_cameras/server/commands.lua
    Rôle : déclaration de la commande du mur des caméras au registre `core:commands` du core (Codex, suggestions du chat).
    Dépendances : config_client.lua, config.lua, server/core.lua
]]

local pairs, tostring = pairs, tostring
local format = string.format

local cfg = VavaCameras.config
local REGISTRY = 'core:commands'
local CHAPTER = 'Caméras'

local commands = {}
VavaCameras.commands = commands

local function entries()
    return {
        [cfg.wall.command] = { kind = 'command', scope = 'admin', permission = cfg.permission, ui = true, label = 'Mur des caméras',
            description = 'Ouvrir le mur des écrans des joueurs en jeu.' },
    }
end

--- Déclare la commande du module. Appelée pendant le setup ; sans ce registre (core plus ancien), rien.
---@return boolean ok
---@return string|nil err
function commands.declare()
    local core = VavaCameras.core
    if not core.registry.exists(REGISTRY) then return true end
    for name, def in pairs(entries()) do
        def.module, def.chapter = VavaCameras.resource, CHAPTER
        local ok, err = core.registry.add(REGISTRY, name, def)
        if not ok then return false, format('%s : %s', name, tostring(err)) end
    end
    return true
end
