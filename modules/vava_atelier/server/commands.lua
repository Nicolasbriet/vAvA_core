--[[
    vava_atelier/server/commands.lua
    Rôle : déclaration de la commande et de la touche de l'Atelier au registre `core:commands` (lu par le Codex et
           les suggestions du chat) : visibles du Conseil qui a le droit d'ouvrir l'Atelier. Le bouton de la page
           Outils du Registre est reporté à une tâche qui touchera vava_admin. T-101 : /atelier_archives (état,
           original, archives), une permission par action (le droit d'un atelier est revérifié à l'exécution).
           T-102 : commande-touche de l'outil de placement (Ctrl+Z, touche Z réglable), sans interface.
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
    local staff = cfg.rights.allowed[#cfg.rights.allowed]
    local open = cfg.rights.open
    local L = cfg.texts.archives.labels
    local atelier = { name = 'atelier', type = 'list', list = 'ateliers' }
    local undo = cfg.placement.undoKey
    return {
        -- T-102 : Ctrl+Z de l'outil de placement (Z en commande-touche, avec Ctrl ; hors visée, rien)
        [undo.command] = {
            kind = 'key', scope = 'admin', permission = open, key = undo.key, keyDisplay = 'Ctrl ' .. undo.key,
            hold = true, ui = false, label = undo.label,
        },
        [cfg.command] = {
            kind = 'command', scope = 'admin', permission = cfg.rights.open, key = cfg.keys.open, ui = true,
            label = cfg.labels.open, description = cfg.texts.codex,
        },
        [cfg.archives.command] = {
            kind = 'command', scope = 'admin', permission = open, label = L.command,
            description = cfg.texts.archives.codex,
            actions = {
                { id = 'etat', label = L.etat, permission = open,
                    args = { { name = 'atelier', type = 'list', list = 'ateliers', optional = true } } },
                { id = 'original', label = L.original, permission = staff,
                    args = { atelier } },
                { id = 'original_fiche', label = L.original_fiche, permission = open,
                    args = { atelier, { name = 'type', type = 'text', max = 32 },
                        { name = 'fiche', type = 'text', max = 48 } } },
                { id = 'exporter', label = L.exporter, permission = staff,
                    args = { { name = 'atelier', type = 'text', max = 64, hint = L.exporterHint } } },
                { id = 'importer', label = L.importer, permission = staff,
                    args = { { name = 'fichier', type = 'text', max = 64, hint = L.importerHint } } },
                { id = 'confirmer', label = L.confirmer, permission = open },
            },
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
