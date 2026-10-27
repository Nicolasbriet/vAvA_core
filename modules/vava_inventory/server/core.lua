--[[
    vava_inventory/server/core.lua
    Rôle : accès à l'API serveur du core, partagé par les fichiers du module.
    Dépendances : vAvA_core (API v1), shared/constants.lua
]]

local RESOURCE = GetCurrentResourceName()

local core, apiErr = exports.vAvA_core:getApi(1)
if not core then
    print(('^1[%s] API vAvA indisponible : %s^7'):format(RESOURCE, tostring(apiErr)))
    return
end

VavaInventory.core = core
VavaInventory.log = core.log
VavaInventory.resource = RESOURCE
-- vrai une fois le module démarré (identifiants d'objets initialisés) : l'API refuse tout appel avant
VavaInventory.ready = false
