--[[
    vava_appearance/client/apply.lua
    Rôle : application d'une apparence (complète ou par partie) à un ped, et lecture des limites réelles du modèle
           (nombre de coupes, de vêtements, de textures…) pour borner les interfaces.
    Appliquer une seule partie ne coûte que les natives de cette partie : c'est ce qui rend l'aperçu fluide.
    Dépendances : shared/constants.lua, config_client.lua, shared/appearance.lua
]]

local type, ipairs = type, ipairs
local mathType = math.type
local SetPedHeadBlendData, SetPedFaceFeature, SetPedComponentVariation = SetPedHeadBlendData, SetPedFaceFeature, SetPedComponentVariation
local SetPedHairColor, SetPedEyeColor, SetPedHeadOverlay, SetPedHeadOverlayColor = SetPedHairColor, SetPedEyeColor, SetPedHeadOverlay, SetPedHeadOverlayColor
local SetPedPropIndex, ClearPedProp, DoesEntityExist = SetPedPropIndex, ClearPedProp, DoesEntityExist
local GetNumberOfPedDrawableVariations, GetNumberOfPedTextureVariations = GetNumberOfPedDrawableVariations, GetNumberOfPedTextureVariations
local GetNumberOfPedPropDrawableVariations, GetNumberOfPedPropTextureVariations = GetNumberOfPedPropDrawableVariations, GetNumberOfPedPropTextureVariations
local GetPedHeadOverlayNum, GetNumHairColors, GetNumMakeupColors = GetPedHeadOverlayNum, GetNumHairColors, GetNumMakeupColors
local GetPedHairRgbColor, GetPedMakeupRgbColor = GetPedHairRgbColor, GetPedMakeupRgbColor

local cfg = VavaAppearance.config
local LIMITS = VavaAppearance.LIMITS
local HAIR = VavaAppearance.HAIR_COMPONENT
local NO_PROP = -1

-- id d'overlay → type de couleur
local OVERLAY_COLOR_TYPE = {}
for _, overlay in ipairs(VavaAppearance.OVERLAYS) do OVERLAY_COLOR_TYPE[overlay.id] = overlay.colorType end

local apply = {}
VavaAppearance.apply = apply

---@param value any
---@return boolean
local function isNumber(value)
    return type(value) == 'number' and value == value
end

---@param value any
---@return boolean
local function isInteger(value)
    return isNumber(value) and (mathType(value) == 'integer' or value % 1 == 0)
end

---@param ped integer
---@param heritage table
function apply.heritage(ped, heritage)
    -- le mélange de tête doit précéder les traits du visage : sans lui, ils ne s'appliquent pas
    SetPedHeadBlendData(ped, heritage.mother, heritage.father, 0, heritage.mother, heritage.father, 0,
        heritage.shapeMix + 0.0, heritage.skinMix + 0.0, 0.0, false)
end

---@param ped integer
---@param index integer  1 à 20
---@param value number   -1 à 1
function apply.feature(ped, index, value)
    SetPedFaceFeature(ped, index - 1, value + 0.0)
end

---@param ped integer
---@param features number[]
function apply.features(ped, features)
    for i = 1, LIMITS.features do
        SetPedFaceFeature(ped, i - 1, (features[i] or 0) + 0.0)
    end
end

---@param ped integer
---@param hair table
function apply.hair(ped, hair)
    SetPedComponentVariation(ped, HAIR, hair.style, hair.texture, 0)
    SetPedHairColor(ped, hair.color, hair.highlight)
end

---@param ped integer
---@param color integer
function apply.eyeColor(ped, color)
    SetPedEyeColor(ped, color)
end

---@param ped integer
---@param overlay table
function apply.overlay(ped, overlay)
    SetPedHeadOverlay(ped, overlay.id, overlay.style, overlay.opacity + 0.0)
    local colorType = OVERLAY_COLOR_TYPE[overlay.id]
    if colorType and colorType ~= VavaAppearance.COLOR_NONE then
        SetPedHeadOverlayColor(ped, overlay.id, colorType, overlay.color, overlay.color)
    end
end

---@param ped integer
---@param component table
function apply.component(ped, component)
    SetPedComponentVariation(ped, component.id, component.drawable, component.texture, 0)
end

---@param ped integer
---@param prop table
function apply.prop(ped, prop)
    if prop.drawable == NO_PROP then
        ClearPedProp(ped, prop.id)
    else
        SetPedPropIndex(ped, prop.id, prop.drawable, prop.texture, true)
    end
end

--- Applique une apparence complète (apparition, aléatoire, réinitialisation).
---@param ped integer
---@param appearance vAvA.Appearance
function apply.all(ped, appearance)
    apply.heritage(ped, appearance.heritage)
    apply.features(ped, appearance.features)
    apply.hair(ped, appearance.hair)
    apply.eyeColor(ped, appearance.eyeColor)
    for _, overlay in ipairs(appearance.overlays) do apply.overlay(ped, overlay) end
    for _, component in ipairs(appearance.components) do apply.component(ped, component) end
    for _, prop in ipairs(appearance.props) do apply.prop(ped, prop) end
end

-- Contrôle de forme d'une partie venant d'une autre ressource (interface) : une valeur mal formée est ignorée
-- plutôt que de provoquer une erreur de native.
local PART_CHECKS = {
    heritage = function(v)
        return type(v) == 'table' and isInteger(v.mother) and isInteger(v.father) and isNumber(v.shapeMix) and isNumber(v.skinMix)
    end,
    feature = function(v)
        return type(v) == 'table' and isInteger(v.index) and v.index >= 1 and v.index <= LIMITS.features and isNumber(v.value)
    end,
    hair = function(v)
        return type(v) == 'table' and isInteger(v.style) and isInteger(v.texture) and isInteger(v.color) and isInteger(v.highlight)
    end,
    eyeColor = isInteger,
    overlay = function(v)
        return type(v) == 'table' and isInteger(v.id) and isInteger(v.style) and isNumber(v.opacity) and isInteger(v.color)
    end,
    component = function(v)
        return type(v) == 'table' and isInteger(v.id) and isInteger(v.drawable) and isInteger(v.texture)
    end,
    prop = function(v)
        return type(v) == 'table' and isInteger(v.id) and isInteger(v.drawable) and isInteger(v.texture)
    end,
}

local PART_APPLY = {
    heritage = apply.heritage,
    feature = function(ped, v) apply.feature(ped, v.index, v.value) end,
    hair = apply.hair,
    eyeColor = apply.eyeColor,
    overlay = apply.overlay,
    component = apply.component,
    prop = apply.prop,
}

--- Applique une seule partie (aperçu en direct).
---@param ped integer
---@param part string
---@param value any
---@return boolean applied
function apply.part(ped, part, value)
    local check = PART_CHECKS[part]
    if not check or not DoesEntityExist(ped) then return false end
    value = VavaAppearance.normalize(value)
    if not check(value) then return false end
    PART_APPLY[part](ped, value)
    return true
end

--- Nombre de textures d'un vêtement, d'un accessoire ou d'une coupe pour un modèle donné.
---@param ped integer
---@param kind 'component'|'prop'|'hair'
---@param id integer
---@param drawable integer
---@return integer
function apply.textureCount(ped, kind, id, drawable)
    if not DoesEntityExist(ped) or not isInteger(id) or not isInteger(drawable) or drawable < 0 then return 0 end
    if kind == 'prop' then return GetNumberOfPedPropTextureVariations(ped, id, drawable) end
    if kind == 'hair' then return GetNumberOfPedTextureVariations(ped, HAIR, drawable) end
    return GetNumberOfPedTextureVariations(ped, id, drawable)
end

--- Limites réelles du modèle du ped : bornes de chaque contrôle d'une interface.
---@param ped integer
---@return table
function apply.limits(ped)
    local limits = {
        parents = LIMITS.parents + 1, features = LIMITS.features, eyeColors = LIMITS.eyeColors + 1,
        hairStyles = GetNumberOfPedDrawableVariations(ped, HAIR),
        hairColors = GetNumHairColors(), makeupColors = GetNumMakeupColors(),
        overlays = {}, components = {}, props = {},
    }
    for i, overlay in ipairs(VavaAppearance.OVERLAYS) do
        limits.overlays[i] = { id = overlay.id, styles = GetPedHeadOverlayNum(overlay.id), colorType = overlay.colorType }
    end
    for i, id in ipairs(cfg.components) do
        limits.components[i] = { id = id, drawables = GetNumberOfPedDrawableVariations(ped, id) }
    end
    for i, id in ipairs(cfg.props) do
        limits.props[i] = { id = id, drawables = GetNumberOfPedPropDrawableVariations(ped, id) }
    end
    return limits
end

--- Couleurs réelles des palettes du jeu (pour afficher des pastilles fidèles). Calculées une fois.
local palettes = nil

---@return { hair: integer[][], makeup: integer[][] }
function apply.palettes()
    if palettes then return palettes end
    local hair, makeup = {}, {}
    for i = 0, GetNumHairColors() - 1 do
        local r, g, b = GetPedHairRgbColor(i)
        hair[i + 1] = { r, g, b }
    end
    for i = 0, GetNumMakeupColors() - 1 do
        local r, g, b = GetPedMakeupRgbColor(i)
        makeup[i + 1] = { r, g, b }
    end
    palettes = { hair = hair, makeup = makeup }
    return palettes
end
