--[[
    vava_gathering/shared/season.lua
    Rôle : règle pure des facteurs de saison (vava_time) lus dans la config : un nombre fini, ramené dans [0, MAX] ;
           tout le reste (absent, texte, NaN, infini, négatif) compte pour 1, sans effet. Même règle que
           vava_farming/shared/growth.lua (growth.seasonFactor).
    Dépendances : shared/constants.lua
]]

local type = type
local huge = math.huge

local season = {}
VavaGathering.season = season

-- facteur le plus fort accepté : au-delà, une erreur de saisie ne remplit pas les nœuds d'un coup
season.MAX_FACTOR = 10

--- Facteur de saison contrôlé.
---@param value any
---@return number
function season.factor(value)
    if type(value) ~= 'number' or value ~= value or value < 0 or value == huge then return 1 end
    if value > season.MAX_FACTOR then return season.MAX_FACTOR end
    return value
end
