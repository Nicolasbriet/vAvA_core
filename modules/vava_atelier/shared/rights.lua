--[[
    vava_atelier/shared/rights.lua
    Rôle : logique pure des droits de l'Atelier. Les droits permis (`config.rights.allowed`) vont du plus faible au
           plus fort ; un rang qui a le second a toujours le premier.
             - effective(id, droit déclaré, famille, réglages) : la surcharge du porteur du projet si elle est permise,
               sinon le plus fort du droit déclaré et du plancher de la famille ;
             - held(permis, can) : droits détenus par un membre (filtre du journal) ;
             - visible(ateliers, détenus) : ateliers ouverts à ce membre.
           Le serveur relit les droits auprès de vava_admin à chaque appel : rien n'est gardé ici.
           Testée : tests/spec/atelier_rights_spec.lua.
    Dépendances : shared/constants.lua
]]

local ipairs = ipairs

local rights = {}
VavaAtelier.rights = rights

--- Rang d'un droit dans la liste des droits permis (1 : le plus faible), ou nil s'il n'y est pas.
---@param allowed string[]
---@param right any
---@return integer|nil
function rights.rank(allowed, right)
    for i, value in ipairs(allowed) do
        if value == right then return i end
    end
    return nil
end
local rank = rights.rank

---@class vAvA.AtelierRightsSettings
---@field allowed string[]                  droits permis, du plus faible au plus fort
---@field overrides table<string, string>   éditeur → droit choisi par le porteur du projet
---@field floors table<string, string>      famille → droit plancher

--- Droit effectif d'un éditeur. Un droit déclaré inconnu (impossible après le validateur) donne le plus fort.
---@param id string  identifiant de l'éditeur
---@param declared string
---@param family string
---@param settings vAvA.AtelierRightsSettings
---@return string
function rights.effective(id, declared, family, settings)
    local allowed = settings.allowed
    local override = settings.overrides and settings.overrides[id]
    if override ~= nil and rank(allowed, override) then return override end
    local own = rank(allowed, declared)
    if not own then return allowed[#allowed] end
    local floor = rank(allowed, settings.floors and settings.floors[family])
    if floor and floor > own then return allowed[floor] end
    return allowed[own]
end

--- Droits détenus par un membre, dans l'ordre des droits permis : ceux pour lesquels `can` répond exactement true.
---@param allowed string[]
---@param can fun(right: string): boolean
---@return string[]
function rights.held(allowed, can)
    local out = {}
    for _, right in ipairs(allowed) do
        if can(right) == true then out[#out + 1] = right end
    end
    return out
end

--- Vrai si `right` fait partie des droits détenus.
---@param held string[]
---@param right string
---@return boolean
function rights.holds(held, right)
    for _, value in ipairs(held) do
        if value == right then return true end
    end
    return false
end

--- Identifiants des ateliers ouverts à un membre, dans l'ordre reçu.
---@param editors { id: string, right: string }[]
---@param held string[]
---@return string[]
function rights.visible(editors, held)
    local out = {}
    for _, editor in ipairs(editors) do
        if rights.holds(held, editor.right) then out[#out + 1] = editor.id end
    end
    return out
end
