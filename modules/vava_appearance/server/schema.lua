--[[
    vava_appearance/server/schema.lua
    Rôle : schéma de validation d'une apparence, utilisé pour le champ de personnage et pour l'argument réseau
           de la création. Strict : aucune clé inconnue, bornes sur chaque nombre et chaque liste.
    Dépendances : shared/constants.lua, config.lua
]]

local cfg = VavaAppearance.config
local LIMITS = VavaAppearance.LIMITS

local UNIT = { type = 'number', min = 0, max = 1 }

---@param max integer
---@return table
local function index(max)
    return { type = 'integer', min = 0, max = max }
end

VavaAppearance.SCHEMA = {
    type = 'table',
    fields = {
        heritage = {
            type = 'table',
            fields = { mother = index(LIMITS.parents), father = index(LIMITS.parents), shapeMix = UNIT, skinMix = UNIT },
        },
        features = {
            type = 'array', min = LIMITS.features, max = LIMITS.features,
            items = { type = 'number', min = -1, max = 1 },
        },
        hair = {
            type = 'table',
            fields = {
                style = index(cfg.maxDrawable), texture = index(cfg.maxTexture),
                color = index(LIMITS.colors), highlight = index(LIMITS.colors),
            },
        },
        eyeColor = index(LIMITS.eyeColors),
        overlays = {
            type = 'array', max = #VavaAppearance.OVERLAYS,
            items = {
                type = 'table',
                fields = { id = index(LIMITS.overlayId), style = index(LIMITS.overlayNone), opacity = UNIT, color = index(LIMITS.colors) },
            },
        },
        components = {
            type = 'array', max = LIMITS.componentId + 1,
            items = {
                type = 'table',
                fields = { id = index(LIMITS.componentId), drawable = index(cfg.maxDrawable), texture = index(cfg.maxTexture) },
            },
        },
        props = {
            type = 'array', max = LIMITS.propId + 1,
            items = {
                type = 'table',
                fields = {
                    id = index(LIMITS.propId),
                    drawable = { type = 'integer', min = -1, max = cfg.maxDrawable },
                    texture = index(cfg.maxTexture),
                },
            },
        },
    },
}
