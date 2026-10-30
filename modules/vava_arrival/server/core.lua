--[[
    vava_arrival/server/core.lua
    Rôle : accès à l'API serveur du core, partagé par les fichiers du module (RPC, hooks, registres, base, journal).
    Dépendances : vAvA_core (API v1), shared/constants.lua
]]

local RESOURCE = GetCurrentResourceName()

local core, apiErr = exports.vAvA_core:getApi(1)
if not core then
    print(('^1[%s] API vAvA indisponible : %s^7'):format(RESOURCE, tostring(apiErr)))
    return
end

VavaArrival.core = core
VavaArrival.log = core.log
VavaArrival.resource = RESOURCE
-- vrai une fois le module démarré
VavaArrival.ready = false
