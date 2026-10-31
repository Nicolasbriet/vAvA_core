--[[
    vava_admin/server/core.lua
    Rôle : accès à l'API serveur du core, partagé par les fichiers du module ; seuls appels vers d'autres ressources
           (exports, registre d'un autre module), isolés.
    Dépendances : vAvA_core (API v1), shared/constants.lua
]]

local RESOURCE = GetCurrentResourceName()

local core, apiErr = exports.vAvA_core:getApi(1)
if not core then
    print(('^1[%s] API vAvA indisponible : %s^7'):format(RESOURCE, tostring(apiErr)))
    return
end

VavaAdmin.core = core
VavaAdmin.log = core.log
VavaAdmin.resource = RESOURCE
-- vrai une fois le module démarré : l'API refuse tout appel avant
VavaAdmin.ready = false

local pcall, tostring, pack, unpack = pcall, tostring, table.pack, table.unpack
local GetResourceState = GetResourceState

local function invoke(resource, fn, ...)
    local target = exports[resource]
    return target[fn](target, ...)
end

--- exports.<resource>:<fn>(...), isolé : les modules administrés (santé, besoins, inventaire) restent facultatifs.
--- Renvoie vrai puis les valeurs de l'export, ou faux, 'unavailable'.
function VavaAdmin.call(resource, fn, ...)
    if GetResourceState(resource) ~= 'started' then return false, 'unavailable' end
    local results = pack(pcall(invoke, resource, fn, ...))
    if not results[1] then
        core.log.warn('%s.%s en erreur : %s', resource, fn, tostring(results[2]))
        return false, 'unavailable'
    end
    return true, unpack(results, 2, results.n)
end

local function addEntry(registry, key, data)
    local api = core.registry
    if not api.exists(registry) then return false, 'absent' end
    if api.has(registry, key) then return true, 'present' end
    local ok, err = api.add(registry, key, data)
    if not ok then return false, err end
    return true, 'added'
end

--- Entrée du registre d'un autre module (vava_health:modifiers), isolée : ce registre disparaît avec son module, à
--- tout moment. Renvoie vrai et 'added' ou 'present' (déjà là), ou faux et 'absent' (registre inexistant) ou la raison
--- du refus.
---@param registry string
---@param key string
---@param data table
---@return boolean ok
---@return string state
function VavaAdmin.declare(registry, key, data)
    local called, ok, state = pcall(addEntry, registry, key, data)
    if not called then return false, tostring(ok) end
    return ok, tostring(state)
end
