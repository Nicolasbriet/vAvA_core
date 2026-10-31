--[[
    vava_pause/client/core.lua
    Rôle : accès à l'API client du core, partagé par les fichiers clients du module.
    Dépendances : vAvA_core (API client v1), shared/constants.lua
]]

local core, apiErr = exports.vAvA_core:getApi(1)
if not core then
    print(('^1[%s] API vAvA indisponible : %s^7'):format(GetCurrentResourceName(), tostring(apiErr)))
    return
end

VavaPause.core = core
VavaPause.log = core.log
VavaPause.resource = GetCurrentResourceName()
