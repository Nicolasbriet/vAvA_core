--[[
    vava_combat/server/core.lua
    Rôle : accès à l'API serveur du core, partagé par les fichiers du module (registres, hooks, champs, réseau), et
           journal de console du module.
    Dépendances : vAvA_core (API v1), shared/constants.lua
]]

local RESOURCE = GetCurrentResourceName()

local core, apiErr = exports.vAvA_core:getApi(1)
if not core then
    print(('^1[%s] API vAvA indisponible : %s^7'):format(RESOURCE, tostring(apiErr)))
    return
end

VavaCombat.core = core
VavaCombat.log = core.log
VavaCombat.resource = RESOURCE
-- vrai une fois le module démarré : les exports refusent tout appel avant
VavaCombat.ready = false
