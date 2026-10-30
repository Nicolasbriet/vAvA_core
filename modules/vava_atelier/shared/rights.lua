--[[
    vava_atelier/shared/rights.lua
    Rôle : logique pure des droits de l'Atelier. Les droits permis (`config.rights.allowed`) vont du plus faible au
           plus fort ; un rang qui a le second a toujours le premier.
             - effective(id, droit déclaré, famille, réglages) : la surcharge du porteur du projet si elle est permise,
               sinon le plus fort du droit déclaré et du plancher de la famille ;
             - held(permis, can) : droits détenus par un membre (filtre du journal) ;
             - visible(ateliers, détenus) : ateliers ouverts à ce membre ;
             - coversAll(permis, détenus) : tous les droits permis sont détenus (journal lu sans filtre de droit) ;
             - checkSettings(config) : planchers, surcharges et droit d'ouvrir sont des droits permis (setup).
           Le serveur relit les droits auprès de vava_admin à chaque appel : rien n'est gardé ici.
           Testée : tests/spec/atelier_rights_spec.lua.
    Dépendances : shared/constants.lua
]]

local type, ipairs, pairs, tostring = type, ipairs, pairs, tostring
local format = string.format
local concat, sort = table.concat, table.sort

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

--- Vrai si les droits détenus couvrent tous les droits permis (aucun filtre de droit à faire, ex. lecture du journal).
---@param allowed string[]
---@param held string[]
---@return boolean
function rights.coversAll(allowed, held)
    for _, right in ipairs(allowed) do
        if not rights.holds(held, right) then return false end
    end
    return true
end

--- Réglages de droits de la config : chaque plancher de famille, chaque surcharge et le droit d'ouvrir l'Atelier
--- doivent être des droits permis (sinon un atelier serait ouvert ou fermé à tort : refus de démarrer).
---@param config { families: { id: string, floor: any }[], rights: { allowed: any, open: any, overrides: any } }
---@return boolean ok
---@return string|nil err
function rights.checkSettings(config)
    local settings = type(config) == 'table' and config.rights
    if type(settings) ~= 'table' or type(settings.allowed) ~= 'table' or #settings.allowed == 0 then
        return false, 'rights.allowed : liste de droits attendue'
    end
    local allowed = settings.allowed
    for i, right in ipairs(allowed) do
        if type(right) ~= 'string' or right == '' then
            return false, format('rights.allowed[%d] : nom de droit attendu', i)
        end
    end
    local list = concat(allowed, ', ')
    if not rank(allowed, settings.open) then
        return false, format("rights.open = '%s' : pas un droit permis (%s)", tostring(settings.open), list)
    end
    for i, family in ipairs(type(config.families) == 'table' and config.families or {}) do
        if type(family) ~= 'table' or not rank(allowed, family.floor) then
            local id = type(family) == 'table' and tostring(family.id) or tostring(i)
            local floor = type(family) == 'table' and tostring(family.floor) or '?'
            return false, format("families['%s'].floor = '%s' : pas un droit permis (%s)", id, floor, list)
        end
    end
    if settings.overrides ~= nil and type(settings.overrides) ~= 'table' then
        return false, 'rights.overrides : table attendue'
    end
    -- surcharges refusées, triées : le message ne dépend pas de l'ordre de parcours de la table
    local wrong = {}
    for editor, right in pairs(settings.overrides or {}) do
        if not rank(allowed, right) then
            wrong[#wrong + 1] = format("rights.overrides['%s'] = '%s'", tostring(editor), tostring(right))
        end
    end
    if #wrong > 0 then
        sort(wrong)
        return false, format('%s : pas un droit permis (%s)', wrong[1], list)
    end
    return true
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
