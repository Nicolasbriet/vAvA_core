--[[
    vava_gathering/shared/catch.lua
    Rôle : règle pure de la prise d'un poisson, tirée par le serveur quand la ligne a tenu (la barre de tension ne peut
           que faire rater) : chance que le poisson se décroche, du débutant au maître de la Pêche, plus le supplément
           de la bande de la zone. Réglages lus dans config.fishing.catch ; une valeur invalide (absente, texte, NaN,
           infinie) compte pour 0, une chance est toujours ramenée dans [0, 1]. Aucun état.
    Dépendances : shared/constants.lua
]]

local type = type
local huge = math.huge

local catch = {}
VavaGathering.catch = catch

--- Nombre fini, sinon 0.
---@param value any
---@return number
local function finite(value)
    if type(value) ~= 'number' or value ~= value or value == huge or value == -huge then return 0 end
    return value
end

--- Ramène une part dans [0, 1].
---@param value number
---@return number
local function share(value)
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

--- Chance (0 à 1) que le poisson se décroche alors que la ligne a tenu : de `novice` au niveau 0 à `master` au niveau
--- `masterLevel` (linéaire entre les deux, au-delà : celle du maître), plus le supplément de la bande (`bands[band]`).
---@param level any                niveau de Pêche (0 à masterLevel)
---@param band any                 bande de vitalité de la zone (normal, reduced, depleted)
---@param rules table              config.fishing.catch : { novice, master, masterLevel, bands }
---@return number
function catch.escapeChance(level, band, rules)
    if type(rules) ~= 'table' then return 0 end
    local novice, master = share(finite(rules.novice)), share(finite(rules.master))
    local top = finite(rules.masterLevel)
    local progress = 1
    if top > 0 then
        progress = finite(level) / top
        if progress < 0 then progress = 0 elseif progress > 1 then progress = 1 end
    end
    local extra = type(rules.bands) == 'table' and finite(rules.bands[band]) or 0
    return share(novice + (master - novice) * progress + extra)
end

--- Le poisson se décroche-t-il ? `roll` est un tirage uniforme dans [0, 1[ fourni par l'appelant (math.random()).
---@param level any
---@param band any
---@param rules table
---@param roll number
---@return boolean
function catch.escapes(level, band, rules, roll)
    return finite(roll) < catch.escapeChance(level, band, rules)
end
