--[[
    vava_needs/bridge/server.lua
    Rôle : SEUL point de contact, côté serveur, entre les besoins et les autres modules : santé (vava_health, facultatif)
           pour la perte de vie d'un besoin épuisé, passée par la chaîne de dégâts (export hit, type `privation`,
           vava_health 1.3.0) ; repli sur l'export damage avec un vava_health plus ancien. Chaque appel à une autre
           ressource est isolé : un module absent ou en erreur ne retire que la fonction concernée. Le core passe par
           server/core.lua ; l'inventaire par ses hooks (server/consume.lua), sans appel direct.
    Dépendances : shared/constants.lua, server/core.lua
]]

local pcall, tostring, type = pcall, tostring, type
local pack, unpack = table.pack, table.unpack
local GetResourceState = GetResourceState

if not VavaNeeds.core then return end

local HEALTH = 'vava_health'
-- type de dégâts de la faim et de la soif dans la chaîne (journal, modificateurs qui le filtrent)
local PRIVATION = 'privation'

local Bridge = {}
VavaNeeds.bridge = Bridge

local function invoke(resource, fn, ...)
    local target = exports[resource]
    return target[fn](target, ...)
end

--- Export d'une autre ressource, isolé. Renvoie `called` (appel réussi) puis ses valeurs.
---@return boolean called
local function call(resource, fn, ...)
    if GetResourceState(resource) ~= 'started' then return false end
    local results = pack(pcall(invoke, resource, fn, ...))
    if not results[1] then
        VavaNeeds.log.warn('%s.%s en erreur : %s', resource, fn, tostring(results[2]))
        return false
    end
    return true, unpack(results, 2, results.n)
end

-- Santé ---------------------------------------------------------------------------------------------------------

--- Vrai si vava_health tourne : la vie et la mise à terre sont alors tenues par le serveur.
---@return boolean
function Bridge.HealthRunning()
    return GetResourceState(HEALTH) == 'started'
end

--- Points d'une vie pleine selon vava_health (chaîne de dégâts), ou nil s'il n'a pas la chaîne (version plus
--- ancienne : pas d'export vocabulary, appel isolé et silencieux).
---@return number|nil
local function healthPoints()
    local probed, vocabulary = pcall(invoke, HEALTH, 'vocabulary')
    if probed and type(vocabulary) == 'table' and type(vocabulary.healthPoints) == 'number' then
        return vocabulary.healthPoints
    end
    return nil
end

--- Retire de la vie à un joueur par vava_health (part de la vie au-dessus du seuil de mise à terre, 0 à 1) : un coup
--- de type `privation` dans la chaîne de dégâts (vava_health 1.3.0), sinon l'export damage. Un coup annulé par la
--- chaîne est une décision, pas une erreur : rendu vrai, avec la raison (sauf à terre : faux, downed).
---@param source integer
---@param amount number
---@return boolean ok
---@return string|nil code  code de vava_health (downed, no_character, not_ready…) ou health_unavailable
function Bridge.Damage(source, amount)
    if not Bridge.HealthRunning() then return false, 'health_unavailable' end
    local points = healthPoints()
    if not points then
        local called, ok, code = call(HEALTH, 'damage', source, amount)
        if not called then return false, 'health_unavailable' end
        return ok == true, code
    end
    local called, result, code = call(HEALTH, 'hit', source, { amount = amount * points, kind = PRIVATION })
    if not called then return false, 'health_unavailable' end
    if type(result) ~= 'table' then return false, code end
    if result.cancelled == 'downed' then return false, 'downed' end
    return true, result.cancelled
end
