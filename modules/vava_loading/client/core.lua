--[[
    vava_loading/client/core.lua
    Rôle : accès protégé à l'API client du core (absente : l'écran se ferme seul à l'arrivée de la session) et lecture
           protégée de l'export de l'écran de sélection (« est-il affiché ? »). Aucun appel ne lève d'erreur.
    Dépendances : vAvA_core (API client v1, facultative), shared/constants.lua, config.lua
]]

local pcall, print, tostring = pcall, print, tostring
local GetCurrentResourceName, GetResourceState = GetCurrentResourceName, GetResourceState
local GetResourceMetadata = GetResourceMetadata

local loading = VavaLoading
local cfg = loading.config
local CORE = loading.CORE_RESOURCE

loading.resource = GetCurrentResourceName()

--- API client du core, ou nil (core arrêté, absent, ou API refusée). L'appel d'un export d'une ressource absente
--- lève une erreur : il est isolé.
---@return table|nil core
---@return string|nil err
local function getApi()
    if GetResourceState(CORE) ~= 'started' then return nil, 'core_unavailable' end
    local ok, api, err = pcall(function() return exports[CORE]:getApi(1) end)
    if not ok then return nil, tostring(api) end
    if not api then return nil, tostring(err) end
    return api
end

local core, apiErr = getApi()
if core then
    loading.core = core
    loading.log = core.log
    -- core antérieur à spawn.loadingScreen : il ferme l'écran à la mise en attente (noir bref), on le dit une fois
    local version = GetResourceMetadata(CORE, 'version', 0)
    if not loading.versionAtLeast(version, cfg.coreVersion) then
        core.log.warn("vAvA_core %s < %s : le core ferme l'écran de chargement à la mise en attente (écran noir bref)",
            tostring(version), cfg.coreVersion)
    end
else
    print(('^3[%s] API vAvA indisponible (%s) : écran fermé à l\'ouverture de la session^7'):format(
        loading.resource, tostring(apiErr)))
end

--- Vrai si l'écran de sélection attendu se dit affiché (son export, lu sous pcall). Faux s'il ne tourne pas, s'il n'a
--- pas l'export ou si l'export échoue.
---@return boolean
function loading.selectionShown()
    local selection = cfg.selection
    if GetResourceState(selection.resource) ~= 'started' then return false end
    local ok, shown = pcall(function()
        local proxy = exports[selection.resource]
        return proxy[selection.isShownExport](proxy)
    end)
    return ok and shown == true
end
