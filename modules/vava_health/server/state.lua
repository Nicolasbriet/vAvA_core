--[[
    vava_health/server/state.lua
    Rôle : santé d'un personnage rangée dans un champ du core (sauvegardée avec lui, envoyée à son seul joueur) :
           vie de 0 à 1, à terre ou non, temps passé à terre. Écrite seulement quand quelque chose change.
    Dépendances : shared/constants.lua, config.lua, server/core.lua
]]

local type, mathType = type, math.type
local floor = math.floor

local cfg = VavaHealth.config
local FIELD = VavaHealth.FIELD
-- deux décimales : assez fin pour la vie, sans bruit de flottants dans la sauvegarde
local PRECISION = 100

local state = {}
VavaHealth.state = state

---@class vAvA.HealthState
---@field health number      0 à 1
---@field downed boolean
---@field downedFor integer  ms passées à terre

---@param value number
---@return number
local function ratio(value)
    if value < 0 then value = 0 elseif value > 1 then value = 1 end
    return floor(value * PRECISION + 0.5) / PRECISION
end
state.ratio = ratio

--- Définit le champ de personnage. Appelé pendant le setup du module.
---@return boolean ok
---@return string|nil err
function state.define()
    return VavaHealth.core.characters.defineField(FIELD, {
        schema = { type = 'table', fields = {
            health = { type = 'number', min = 0, max = 1 },
            downed = { type = 'boolean' },
            downedFor = { type = 'integer', min = 0, max = cfg.downed.autoRespawnMs },
        } },
        default = { health = cfg.initial, downed = false, downedFor = 0 },
        visibility = 'owner',
    })
end

--- Santé enregistrée d'un personnage chargé (valeurs sûres même si la sauvegarde est incomplète).
---@param characterId integer
---@return vAvA.HealthState
function state.read(characterId)
    local stored = VavaHealth.core.characters.get(characterId, FIELD)
    if type(stored) ~= 'table' then stored = {} end
    local health = type(stored.health) == 'number' and ratio(stored.health) or cfg.initial
    local downedFor = mathType(stored.downedFor) == 'integer' and stored.downedFor or 0
    return { health = health, downed = stored.downed == true, downedFor = downedFor }
end

---@param characterId integer
---@param value vAvA.HealthState
---@return boolean ok
---@return string|nil err
function state.write(characterId, value)
    local downedFor = value.downedFor
    if downedFor > cfg.downed.autoRespawnMs then downedFor = cfg.downed.autoRespawnMs end
    return VavaHealth.core.characters.set(characterId, FIELD, {
        health = ratio(value.health), downed = value.downed, downedFor = floor(downedFor),
    })
end
