--[[
    vava_example/shared/limits.lua
    Rôle : plafond des notes par personnage, logique pure (testée dans tests/spec/examples_guard_spec.lua). Le
           serveur compte les notes gardées du personnage en base ; une note de plus n'est permise que sous le plafond.
           Une seule note à la fois par personnage (verrou du serveur) : deux appels rapprochés ne passent pas tous
           les deux sous le plafond.
    Dépendances : aucune
]]

local tonumber, tointeger = tonumber, math.tointeger

local limits = {}

--- Une note de plus est-elle permise ?
---@param count any        nombre de notes gardées (oxmysql peut le rendre en texte) ; illisible : refus
---@param cap integer      plafond par personnage (config `maxNotesPerCharacter`)
---@return boolean ok
---@return string|nil code  'count_unknown' ou 'too_many'
function limits.check(count, cap)
    local n = tointeger(tonumber(count))
    if not n or n < 0 then return false, 'count_unknown' end
    if n >= cap then return false, 'too_many' end
    return true
end

VavaExample.limits = limits
