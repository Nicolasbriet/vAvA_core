--[[
    vava_appearance/shared/appearance.lua
    Rôle : modèle de données de l'apparence : apparence par défaut d'un sexe et normalisation des nombres.
    Format (listes pures et tables à clés nommées uniquement : sérialisation msgpack/JSON sans perte) :
      { heritage = { mother, father, shapeMix, skinMix },
        features = { 20 nombres de -1 à 1 },
        hair = { style, texture, color, highlight }, eyeColor,
        overlays = { { id, style, opacity, color }, ... },
        components = { { id, drawable, texture }, ... },
        props = { { id, drawable (-1 = aucun), texture }, ... } }
    Dépendances : shared/constants.lua, config.lua
]]

local ipairs, pairs, type = ipairs, pairs, type
local tointeger = math.tointeger

local cfg = VavaAppearance.config
local LIMITS = VavaAppearance.LIMITS

---@class vAvA.Appearance
---@field heritage { mother: integer, father: integer, shapeMix: number, skinMix: number }
---@field features number[]
---@field hair { style: integer, texture: integer, color: integer, highlight: integer }
---@field eyeColor integer
---@field overlays { id: integer, style: integer, opacity: number, color: integer }[]
---@field components { id: integer, drawable: integer, texture: integer }[]
---@field props { id: integer, drawable: integer, texture: integer }[]

---@param source table
---@return table
local function copy(source)
    local result = {}
    for key, value in pairs(source) do result[key] = value end
    return result
end

--- Apparence de départ d'un sexe ('m' ou 'f').
---@param sex string
---@return vAvA.Appearance
function VavaAppearance.default(sex)
    local base = cfg.defaults[sex] or cfg.defaults.m
    local features = {}
    for i = 1, LIMITS.features do features[i] = 0.0 end

    local overlays = {}
    for i, overlay in ipairs(VavaAppearance.OVERLAYS) do
        local preset = base.overlays[overlay.id]
        overlays[i] = {
            id = overlay.id,
            style = preset and preset.style or LIMITS.overlayNone,
            opacity = preset and preset.opacity or 1.0,
            color = preset and preset.color or 0,
        }
    end

    local components = {}
    for i, id in ipairs(cfg.components) do
        components[i] = { id = id, drawable = base.components[id] or 0, texture = 0 }
    end

    local props = {}
    for i, id in ipairs(cfg.props) do
        props[i] = { id = id, drawable = -1, texture = 0 }
    end

    return {
        heritage = copy(base.heritage), features = features, hair = copy(base.hair), eyeColor = base.eyeColor,
        overlays = overlays, components = components, props = props,
    }
end

--- Convertit en entiers les nombres entiers arrivés en flottants (JSON de l'interface, base de données), en place.
--- Les champs continus (mélanges, traits, opacités) restent des flottants.
---@param value any
---@return any
function VavaAppearance.normalize(value)
    if type(value) ~= 'table' then return value end
    for key, item in pairs(value) do
        if type(item) == 'table' then
            VavaAppearance.normalize(item)
        elseif type(item) == 'number' and key ~= 'shapeMix' and key ~= 'skinMix' and key ~= 'opacity' and type(key) == 'string' then
            value[key] = tointeger(item) or item
        end
    end
    return value
end
