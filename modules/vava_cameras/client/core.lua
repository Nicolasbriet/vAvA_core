--[[
    vava_cameras/client/core.lua
    Rôle : accès à l'API client du core, partagé par les fichiers clients du module.
    Dépendances : vAvA_core (API client v1), shared/constants.lua
]]

local core, apiErr = exports.vAvA_core:getApi(1)
if not core then
    print(('^1[%s] API vAvA indisponible : %s^7'):format(GetCurrentResourceName(), tostring(apiErr)))
    return
end

VavaCameras.core = core
VavaCameras.log = core.log
VavaCameras.resource = GetCurrentResourceName()

local type = type

--- Identifiant de caméra bien formé ?
---@param value any
---@return boolean
function VavaCameras.isSession(value)
    return type(value) == 'string' and #value == VavaCameras.SESSION_LENGTH and value:find(VavaCameras.SESSION_PATTERN) ~= nil
end
