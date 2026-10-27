--[[
    vava_appearance/client/main.lua
    Rôle : applique l'apparence du personnage à chaque apparition, écran encore noir (hook core:character:spawning),
           et publie les fonctions d'apparence pour les autres ressources (création, coiffeur, vêtements…).
    Dépendances : vAvA_core (API client v1), shared/, client/apply.lua
]]

local RESOURCE = GetCurrentResourceName()

local core, apiErr = exports.vAvA_core:getApi(1)
if not core then
    print(('^1[%s] API vAvA indisponible : %s^7'):format(RESOURCE, tostring(apiErr)))
    return
end

local PlayerPedId = PlayerPedId
local apply = VavaAppearance.apply
local FIELD = VavaAppearance.FIELD

local function applyCurrent()
    local character = core.characters.current()
    local appearance = character and character.fields[FIELD]
    if appearance then apply.all(PlayerPedId(), VavaAppearance.normalize(appearance)) end
end

core.hooks.after('core:character:spawning', applyCurrent)
core.hooks.after('core:character:fieldChanged', function(change)
    if change.field == FIELD then applyCurrent() end
end)

exports('defaultAppearance', function(sex) return VavaAppearance.default(sex) end)
exports('apply', function(ped, appearance) apply.all(ped, VavaAppearance.normalize(appearance)) end)
exports('applyPart', function(ped, part, value) return apply.part(ped, part, value) end)
exports('limits', function(ped) return apply.limits(ped) end)
exports('textureCount', function(ped, kind, id, drawable) return apply.textureCount(ped, kind, id, drawable) end)
exports('palettes', function() return apply.palettes() end)
