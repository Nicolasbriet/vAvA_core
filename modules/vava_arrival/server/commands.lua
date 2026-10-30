--[[
    vava_arrival/server/commands.lua
    Rôle : déclaration de la commande du Conseil (/accueil) au registre `core:commands` du core (Codex, suggestions du
           chat), chapitre « Accueil ».
    Dépendances : shared/constants.lua, config.lua, server/core.lua
]]

local tostring = tostring
local format = string.format

local cfg = VavaArrival.config
local REGISTRY = 'core:commands'
local CHAPTER = 'Accueil'

local commands = {}
VavaArrival.commands = commands

--- Déclare la commande du module. Appelée en tête du setup ; sans ce registre (core plus ancien), rien.
---@return boolean ok
---@return string|nil err
function commands.declare()
    local core = VavaArrival.core
    if not core.registry.exists(REGISTRY) then return true end
    local admin = cfg.admin
    local player = { name = 'joueur', type = 'player' }
    local ok, err = core.registry.add(REGISTRY, admin.command, {
        kind = 'command', module = VavaArrival.resource, chapter = CHAPTER,
        label = 'Accueil des nouveaux venus',
        description = 'État de la dotation et de l\'accueil d\'un personnage, dotation redonnée, accueil rejoué.',
        scope = 'admin', permission = admin.permission, ace = admin.ace,
        actions = {
            { id = 'etat', label = 'État de l\'accueil', args = { player } },
            { id = 'redoter', label = 'Redonner la dotation', description = 'Donne de nouveau la dotation de départ, sans limite du compte.',
                args = { player } },
            { id = 'rejouer', label = 'Rejouer l\'accueil', description = 'Le mot d\'accueil et le Codex s\'ouvrent de nouveau chez le joueur.',
                args = { player } },
        },
    })
    if not ok then return false, format('%s : %s', admin.command, tostring(err)) end
    return true
end
