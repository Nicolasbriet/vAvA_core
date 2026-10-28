--[[
    vava_chancellerie/server/commands.lua
    Rôle : déclaration de la commande de liaison d'un compte à la Chancellerie au registre `core:commands` du core
           (Codex, suggestions du chat).
    Dépendances : config.lua, server/core.lua
]]

local pairs, tostring = pairs, tostring
local format = string.format

local cfg = VavaBridge.config
local REGISTRY = 'core:commands'
local CHAPTER = 'Chancellerie'

local commands = {}
VavaBridge.commands = commands

local function entries()
    return {
        [cfg.link.command] = { kind = 'command', scope = 'player', label = 'Lier son compte à la Chancellerie',
            description = 'Relie votre compte du jeu à votre compte du panneau web, avec le code que celui-ci affiche.',
            args = { { name = 'code', type = 'text', hint = 'code à 6 chiffres affiché par la Chancellerie' } } },
    }
end

--- Déclare la commande du module. Appelée pendant le setup ; sans ce registre (core plus ancien), rien.
---@return boolean ok
---@return string|nil err
function commands.declare()
    local core = VavaBridge.core
    if not core.registry.exists(REGISTRY) then return true end
    for name, def in pairs(entries()) do
        def.module, def.chapter = VavaBridge.resource, CHAPTER
        local ok, err = core.registry.add(REGISTRY, name, def)
        if not ok then return false, format('%s : %s', name, tostring(err)) end
    end
    return true
end
