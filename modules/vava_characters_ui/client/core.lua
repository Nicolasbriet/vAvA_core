--[[
    vava_characters_ui/client/core.lua
    Rôle : accès aux API utilisées par l'interface : API client du core et exports de vava_appearance.
    Dépendances : vAvA_core (API client v1), vava_appearance, config_client.lua
]]

local RESOURCE = GetCurrentResourceName()

local core, apiErr = exports.vAvA_core:getApi(1)
if not core then
    print(('^1[%s] API vAvA indisponible : %s^7'):format(RESOURCE, tostring(apiErr)))
    return
end

VavaCharactersUi.core = core
VavaCharactersUi.appearance = exports[VavaCharactersUi.config.appearanceResource]
