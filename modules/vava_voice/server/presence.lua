--[[
    vava_voice/server/presence.lua
    Rôle : qui peut parler, décidé par le serveur. Micro coupé par FXServer (MumbleSetPlayerMuted, rien à contourner
           côté client) tant que le personnage n'est pas apparu : sélection, chargement, retour à la sélection.
           Limites de portée par raison (à terre, décision d'un module) : la plus basse s'applique et part au seul
           joueur concerné ; son client la respecte (la portée est réglée côté client, comme toute voix FiveM). Le
           client qui redémarre la redemande (avec la liste des zones) : celle du démarrage a pu lui échapper.
    Dépendances : shared/constants.lua, config.lua, server/core.lua
]]

local pairs = pairs
local TriggerClientEvent, MumbleSetPlayerMuted = TriggerClientEvent, MumbleSetPlayerMuted

local EVENTS = VavaVoice.EVENTS
local NO_LIMIT = VavaVoice.NO_LIMIT

local presence = {}
VavaVoice.presence = presence

---@type table<integer, true>
local active = {}
---@type table<integer, table<string, integer>>
local limits = {}

---@param src integer
---@return integer cap  portée maximale, NO_LIMIT sans limite
function presence.capOf(src)
    local cap = NO_LIMIT
    for _, maximum in pairs(limits[src] or {}) do
        if cap == NO_LIMIT or maximum < cap then cap = maximum end
    end
    return cap
end

---@param src integer
local function sendLimit(src)
    TriggerClientEvent(EVENTS.LIMIT, src, presence.capOf(src))
end

---@param src integer
---@return boolean
function presence.isActive(src)
    return active[src] == true
end

--- Le personnage est apparu : le joueur parle, avec ses limites du moment.
---@param src integer
function presence.enable(src)
    MumbleSetPlayerMuted(src, false)
    active[src] = true
    sendLimit(src)
end

--- Hors du jeu : micro coupé.
---@param src integer
function presence.disable(src)
    MumbleSetPlayerMuted(src, true)
    active[src] = nil
end

--- Joueur parti : plus rien à garder.
---@param src integer
function presence.forget(src)
    active[src] = nil
    limits[src] = nil
end

--- Pose (ou remplace) une limite de portée. `maximum` : numéro de la plus haute portée permise.
---@param src integer
---@param reason string
---@param maximum integer
function presence.limit(src, reason, maximum)
    local own = limits[src] or {}
    if own[reason] == maximum then return end
    own[reason] = maximum
    limits[src] = own
    if active[src] then sendLimit(src) end
end

---@param src integer
---@param reason string
function presence.release(src, reason)
    local own = limits[src]
    if not own or own[reason] == nil then return end
    own[reason] = nil
    if active[src] then sendLimit(src) end
end

--- Le client redemande son état (apparition, redémarrage du module) : la limite du moment lui est renvoyée s'il est en
--- jeu ; sinon, elle partira à son apparition.
---@param src integer
function presence.resend(src)
    if active[src] then sendLimit(src) end
end
