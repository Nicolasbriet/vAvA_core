--[[
    vava_cameras/server/links.lua
    Rôle : liens avec le Registre du Conseil (vava_admin), facultatif : droit de regarder (sans lui, personne ne
           regarde en jeu), journal, outil « Mur des caméras » ajouté au Registre (et rajouté s'il redémarre).
    Dépendances : shared/constants.lua, config_client.lua, config.lua, server/core.lua
]]

local tostring = tostring

local call = VavaCameras.call
local cfg = VavaCameras.config
local ADMIN = VavaCameras.ADMIN

local links = {}
VavaCameras.links = links

--- Membre du Conseil qui a le droit de regarder ?
---@param src integer
---@return boolean
function links.canWatch(src)
    local called, allowed = call(ADMIN.RESOURCE, 'can', src, cfg.permission)
    return called and allowed == true
end

--- Inscrit au journal du Registre ; sans lui, la console du serveur le garde.
---@param src integer
---@param label string
---@param details table
function links.record(src, label, details)
    local called, ok = call(ADMIN.RESOURCE, 'log', src, label, details)
    if not called or ok ~= true then VavaCameras.log.info('%s (joueur %d) : %s', label, src, tostring(details.joueur or '')) end
end

local function addTool()
    local registry = VavaCameras.core.registry
    if not registry.exists(ADMIN.REGISTRY) or registry.has(ADMIN.REGISTRY, ADMIN.TOOL) then return end
    local ok, err = registry.add(ADMIN.REGISTRY, ADMIN.TOOL, {
        label = cfg.wall.tool.label, hint = cfg.wall.tool.hint, permission = cfg.permission,
    })
    if not ok then VavaCameras.log.warn('outil du Registre non ajouté : %s', tostring(err)) end
end

--- Branche l'outil du Registre. Appelé pendant le setup du module.
---@return boolean ok
---@return string|nil err
function links.start()
    local id, err = VavaCameras.core.hooks.after(ADMIN.READY, addTool)
    if not id then return false, err end
    addTool()
    return true
end
