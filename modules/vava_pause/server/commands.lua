--[[
    vava_pause/server/commands.lua
    Rôle : déclaration de la touche de la bannière (Échap ou P) au registre `core:commands` : elle apparaît dans le
           Codex (onglet Touches). Échap et P sont lus directement par le client : aucune liaison FiveM à régler.
    Dépendances : shared/constants.lua, config.lua, server/core.lua
]]

local tostring = tostring

local cfg = VavaPause.config
local REGISTRY = 'core:commands'

local commands = {}
VavaPause.commands = commands

--- Déclare la touche, si le registre existe (core plus ancien : rien n'est déclaré). Appelée en tête du setup.
---@return boolean ok
---@return string|nil err
function commands.declare()
    local core = VavaPause.core
    if not core.registry.exists(REGISTRY) then return true end
    local key = cfg.commands.key
    local ok, err = core.registry.add(REGISTRY, key.name, {
        kind = 'key', scope = 'player', module = VavaPause.resource, chapter = key.chapter, label = key.label,
        key = key.key, keyDisplay = key.keyDisplay,
    })
    if not ok then return false, key.name .. ' : ' .. tostring(err) end
    return true
end
