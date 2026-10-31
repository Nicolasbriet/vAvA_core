--[[
    vava_hud/client/core.lua
    Rôle : accès à l'API client du core (hooks du personnage), partagé par les fichiers du module.
    Dépendances : vAvA_core (API client v1), config_client.lua
]]

local core, apiErr = exports.vAvA_core:getApi(1)
if not core then
    print(('^1[%s] API vAvA indisponible : %s^7'):format(GetCurrentResourceName(), tostring(apiErr)))
    return
end

VavaHud.core = core
VavaHud.log = core.log
VavaHud.resource = GetCurrentResourceName()
