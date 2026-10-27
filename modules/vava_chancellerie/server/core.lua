--[[
    vava_chancellerie/server/core.lua
    Rôle : accès à l'API serveur du core, partagé par les fichiers du module ; appel isolé des exports des autres
           modules.
    Dépendances : vAvA_core (API v1), shared/constants.lua
]]

local pcall, tostring = pcall, tostring
local pack, unpack = table.pack, table.unpack
local GetResourceState = GetResourceState

local RESOURCE = GetCurrentResourceName()

local core, apiErr = exports.vAvA_core:getApi(1)
if not core then
    print(('^1[%s] API vAvA indisponible : %s^7'):format(RESOURCE, tostring(apiErr)))
    return
end

VavaBridge.core = core
VavaBridge.log = core.log
VavaBridge.resource = RESOURCE
-- vrai une fois le module démarré
VavaBridge.ready = false

local function invoke(resource, fn, ...)
    local target = exports[resource]
    return target[fn](target, ...)
end

--- Export d'une autre ressource, isolé : called (appel réussi), puis ses valeurs.
---@return boolean called
function VavaBridge.call(resource, fn, ...)
    if GetResourceState(resource) ~= 'started' then return false end
    local results = pack(pcall(invoke, resource, fn, ...))
    if not results[1] then
        core.log.warn('%s.%s en erreur : %s', resource, fn, tostring(results[2]))
        return false
    end
    return true, unpack(results, 2, results.n)
end
