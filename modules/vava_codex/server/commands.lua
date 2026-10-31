--[[
    vava_codex/server/commands.lua
    Rôle : déclaration de la touche et de la commande du Codex lui-même, et de sa commande de console
           `vava_codex_pages` (1.5.0), au registre `core:commands`.
    Dépendances : shared/constants.lua, config.lua, server/core.lua
]]

local pairs, tostring = pairs, tostring
local format = string.format

local cfg = VavaCodex.config
local REGISTRY = VavaCodex.REGISTRY
local CHAPTER = 'Codex'

local commands = {}
VavaCodex.commands = commands

local function entries()
    return {
        [cfg.command] = { kind = 'command', scope = 'player', key = cfg.keys.open, ui = true, label = 'Ouvrir le Codex',
            description = 'Toutes les commandes et les touches qui vous sont ouvertes, à chercher, composer et lancer.' },
        -- 1.5.0 : enregistrée par server/reading.lua, ne répond qu'à la console (lecture seule dans le Codex du Conseil)
        [cfg.pagesCommand] = { kind = 'command', scope = 'console', label = 'Bilan des pages de lecture',
            description = 'Poids de chaque page, touches et commandes citées introuvables (console du serveur).' },
    }
end

--- Déclare la commande du module. Appelée pendant le setup.
---@return boolean ok
---@return string|nil err
function commands.declare()
    local core = VavaCodex.core
    if not core.registry.exists(REGISTRY) then return false, 'registre ' .. REGISTRY .. ' absent (core trop ancien)' end
    for name, def in pairs(entries()) do
        def.module, def.chapter = VavaCodex.resource, CHAPTER
        local ok, err = core.registry.add(REGISTRY, name, def)
        if not ok then return false, format('%s : %s', name, tostring(err)) end
    end
    return true
end
