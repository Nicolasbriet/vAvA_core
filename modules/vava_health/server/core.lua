--[[
    vava_health/server/core.lua
    Rôle : accès à l'API serveur du core, partagé par les fichiers du module ; envoi d'un évènement au seul joueur
           concerné (core.net.send : compté dans /vava_reseau) ; numéro des coups de la chaîne de dégâts.
    Dépendances : vAvA_core (API v1, core.net : 0.10.0), shared/constants.lua
]]

local RESOURCE = GetCurrentResourceName()
-- numéro de coup : entier croissant, repart à 1 au-delà
local MAX_HIT_ID = 2147483647

local core, apiErr = exports.vAvA_core:getApi(1)
if not core then
    print(('^1[%s] API vAvA indisponible : %s^7'):format(RESOURCE, tostring(apiErr)))
    return
end

VavaHealth.core = core
VavaHealth.log = core.log
VavaHealth.resource = RESOURCE
-- vrai une fois le module démarré : l'API refuse tout appel avant
VavaHealth.ready = false

--- Envoie un évènement du module au seul joueur `target` (jamais à tous, jamais une liste), compté par core.net.
---@param target integer
---@param event string
---@return boolean ok
---@return string|nil code
function VavaHealth.send(target, event, ...)
    local ok, code = core.net.send(target, event, ...)
    if ok then return true end
    return false, code
end

local lastHitId = 0

--- Numéro du coup suivant (chaîne de dégâts et pertes natives).
---@return integer
function VavaHealth.nextHitId()
    lastHitId = lastHitId >= MAX_HIT_ID and 1 or lastHitId + 1
    return lastHitId
end
