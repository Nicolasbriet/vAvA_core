--[[
    vava_needs/bridge/server.lua
    Rôle : SEUL point de contact, côté serveur, entre les besoins et les autres modules : santé (vava_health, facultatif)
           pour la perte de vie d'un besoin épuisé. Chaque appel à une autre ressource est isolé : un module absent ou
           en erreur ne retire que la fonction concernée. Le core passe par server/core.lua ; l'inventaire par ses hooks
           (server/consume.lua), sans appel direct.
    Dépendances : shared/constants.lua, server/core.lua
]]

local pcall, tostring = pcall, tostring
local pack, unpack = table.pack, table.unpack
local GetResourceState = GetResourceState

if not VavaNeeds.core then return end

local HEALTH = 'vava_health'

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

--- Retire de la vie à un joueur par vava_health (part de la vie au-dessus du seuil de mise à terre, 0 à 1).
---@param source integer
---@param amount number
---@return boolean ok
---@return string|nil code  code de vava_health (downed, not_spawned, no_character…) ou health_unavailable
function Bridge.Damage(source, amount)
    local called, ok, code = call(HEALTH, 'damage', source, amount)
    if not called then return false, 'health_unavailable' end
    return ok == true, code
end
