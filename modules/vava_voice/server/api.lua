--[[
    vava_voice/server/api.lua
    Rôle : exports serveur pour les autres modules : savoir si un joueur parle (personnage en jeu), limiter sa portée
           pour une raison (bâillon, scène, sort…) puis lever la limite, lire les zones de voix ; modifier et supprimer
           une zone depuis le panneau web (par sa seule ressource-pont). Les raisons sont préfixées par la ressource
           appelante : deux modules ne lèvent jamais la limite l'un de l'autre.
    Dépendances : shared/constants.lua, config.lua, server/core.lua, server/presence.lua, server/zones.lua
]]

local type, ipairs, mathType = type, ipairs, math.type
local GetInvokingResource = GetInvokingResource

local presence = VavaVoice.presence
local zones = VavaVoice.zones
local RANGES = #VavaVoice.config.ranges
local ZONES = VavaVoice.config.zones
local WEB = VavaVoice.config.web
local REASON_PATTERN = '^[%w_%-]+$'
local REASON_MAX = 32

---@param reason any
---@return string|nil
local function reasonOf(reason)
    if type(reason) ~= 'string' or #reason == 0 or #reason > REASON_MAX or not reason:find(REASON_PATTERN) then return nil end
    return (GetInvokingResource() or VavaVoice.resource) .. ':' .. reason
end

---@param src any
---@return boolean
local function isPlayer(src)
    return mathType(src) == 'integer' and src > 0
end

--- Vrai si le personnage du joueur est en jeu (micro ouvert).
exports('isActive', function(src)
    return VavaVoice.ready and isPlayer(src) and presence.isActive(src)
end)

--- Limite la portée d'un joueur : `maximum` = numéro de la plus haute portée permise (1 = Chuchoter).
exports('limitRange', function(src, reason, maximum)
    if not VavaVoice.ready then return false, 'not_ready' end
    local key = reasonOf(reason)
    if not isPlayer(src) or not key or mathType(maximum) ~= 'integer' or maximum < 1 or maximum > RANGES then
        return false, 'invalid_args'
    end
    presence.limit(src, key, maximum)
    return true
end)

exports('releaseRange', function(src, reason)
    if not VavaVoice.ready then return false, 'not_ready' end
    local key = reasonOf(reason)
    if not isPlayer(src) or not key then return false, 'invalid_args' end
    presence.release(src, key)
    return true
end)

--- Zones de voix : liste { id, label, x, y, z, radius, height, multiplier }.
exports('getZones', function()
    if not VavaVoice.ready then return {} end
    return zones.all()
end)

-- Panneau web, par sa seule ressource-pont (droit et journal vérifiés par le pont auprès de vava_admin) ----------

---@param value any
---@param bounds { min: number, max: number }
---@return boolean
local function within(value, bounds)
    return type(value) == 'number' and value == value and value >= bounds.min and value <= bounds.max
end

---@param value any
---@return boolean
local function isMultiplier(value)
    for _, allowed in ipairs(ZONES.multipliers) do
        if value == allowed then return true end
    end
    return false
end

--- Modifie une zone (nom, rayon, hauteur, effet) : true, zone, détails pour le journal | false, code.
exports('webUpdateZone', function(id, label, radius, height, multiplier)
    if not VavaVoice.ready then return false, 'not_ready' end
    if GetInvokingResource() ~= WEB.bridge then return false, 'forbidden' end
    if mathType(id) ~= 'integer' or type(label) ~= 'string' or #label == 0 or #label > ZONES.labelMax or label:find('%c')
        or not within(radius, ZONES.radius) or not within(height, ZONES.height) or not isMultiplier(multiplier) then
        return false, 'invalid_args'
    end
    return zones.webUpdate(id, label, radius, height, multiplier)
end)

--- Supprime une zone : true, nil, détails pour le journal | false, code.
exports('webDeleteZone', function(id)
    if not VavaVoice.ready then return false, 'not_ready' end
    if GetInvokingResource() ~= WEB.bridge then return false, 'forbidden' end
    if mathType(id) ~= 'integer' then return false, 'invalid_args' end
    return zones.webRemove(id)
end)
