--[[
    vava_health/server/api.lua
    Rôle : exports serveur pour les autres modules (médecin, combat, pièges, administration…). Cible : un joueur (son
           personnage actif). Vie de 0 à 1 : part de la vie au-dessus du seuil de mise à terre.
    Dépendances : shared/constants.lua, server/core.lua, server/life.lua
]]

local type = type
local mathType, huge = math.type, math.huge

local life = VavaHealth.life

---@param src any
---@return vAvA.HealthEntry|nil
---@return string|nil code
local function resolve(src)
    if not VavaHealth.ready then return nil, 'not_ready' end
    if mathType(src) ~= 'integer' then return nil, 'invalid_target' end
    local entry = life.entry(src)
    if not entry then return nil, 'no_character' end
    return entry
end

---@param value any
---@param low number
---@return boolean
local function isAmount(value, low)
    return type(value) == 'number' and value == value and value ~= huge and value >= low and value <= 1
end

--- { health, downed, downedFor } ; health est la vie actuelle (lue côté serveur).
exports('get', function(src)
    local entry, code = resolve(src)
    if not entry then return nil, code end
    return { health = life.currentHealth(src, entry), downed = entry.downed, downedFor = entry.downedFor }
end)

exports('isDowned', function(src)
    local entry = resolve(src)
    return entry ~= nil and entry.downed
end)

--- Fixe la vie d'un joueur debout (0 la fait tomber).
exports('setHealth', function(src, health)
    local entry, code = resolve(src)
    if not entry then return false, code end
    if not isAmount(health, 0) then return false, 'invalid_amount' end
    return life.setHealth(src, health)
end)

exports('heal', function(src, amount)
    local entry, code = resolve(src)
    if not entry then return false, code end
    if not isAmount(amount, 0) then return false, 'invalid_amount' end
    return life.adjust(src, amount)
end)

exports('damage', function(src, amount)
    local entry, code = resolve(src)
    if not entry then return false, code end
    if not isAmount(amount, 0) then return false, 'invalid_amount' end
    return life.adjust(src, -amount)
end)

--- Met à terre (cause libre pour les hooks : 'execution', 'piege'…).
exports('down', function(src, cause)
    local entry, code = resolve(src)
    if not entry then return false, code end
    if cause ~= nil and type(cause) ~= 'string' then return false, 'invalid_cause' end
    return life.down(src, 'api', cause)
end)

--- Relève sur place, avec la vie donnée (par défaut celle d'une réanimation).
exports('revive', function(src, health)
    local entry, code = resolve(src)
    if not entry then return false, code end
    if health ~= nil and not isAmount(health, 0.01) then return false, 'invalid_amount' end
    return life.revive(src, health or VavaHealth.config.assist.health, 'api')
end)
