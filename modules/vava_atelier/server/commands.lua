--[[
    vava_atelier/server/commands.lua
    Rôle : déclaration de la commande et de la touche de l'Atelier au registre `core:commands` (lu par le Codex et
           les suggestions du chat) : visibles du Conseil qui a le droit d'ouvrir l'Atelier. Le bouton de la page
           Outils du Registre est reporté à une tâche qui touchera vava_admin.
    Dépendances : shared/constants.lua, config.lua, server/core.lua
]]

local pairs, tostring = pairs, tostring
local format = string.format

local cfg = VavaAtelier.config
local REGISTRY = VavaAtelier.COMMANDS_REGISTRY
local CHAPTER = 'Atelier'

local commands = {}
VavaAtelier.commands = commands

local function entries()
    return {
        [cfg.command] = {
            kind = 'command', scope = 'admin', permission = cfg.rights.open, key = cfg.keys.open, ui = true,
            label = cfg.labels.open, description = cfg.texts.codex,
        },
    }
end

--- Déclare la commande du module. Appelée pendant le setup ; sans ce registre (core trop ancien), refus.
---@return boolean ok
---@return string|nil err
function commands.declare()
    local core = VavaAtelier.core
    if not core.registry.exists(REGISTRY) then return false, 'registre ' .. REGISTRY .. ' absent (core trop ancien)' end
    for name, def in pairs(entries()) do
        def.module, def.chapter = VavaAtelier.resource, CHAPTER
        local ok, err = core.registry.add(REGISTRY, name, def)
        if not ok then return false, format('%s : %s', name, tostring(err)) end
    end
    return true
end
