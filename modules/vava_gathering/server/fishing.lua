--[[
    vava_gathering/server/fishing.lua
    Rôle : la pêche. La ligne lancée (harvest.begin), le serveur tire le moment de la touche et prévient le seul
           pêcheur, qui tient la barre de tension pendant la durée de la config puis dit s'il a tenu (reel). Le serveur
           ne croit le client que sur ce point déclaratif ; le moment de la touche, la durée, la distance, la charge,
           la vitalité, le rendement et l'XP sont siens. Une prise échappée (raté, retard) ne consomme rien.
    Dépendances : shared/constants.lua, config.lua, server/core.lua, bridge/server.lua, server/harvest.lua
]]

local random = math.random
local TriggerClientEvent, GetGameTimer, SetTimeout = TriggerClientEvent, GetGameTimer, SetTimeout

local bridge = VavaGathering.bridge
local harvest = VavaGathering.harvest
local cfg = VavaGathering.config.fishing
local messages = VavaGathering.config.messages
local EVENTS = VavaGathering.EVENTS

local fishing = {}
VavaGathering.fishing = fishing

--- Ligne lancée : la touche viendra entre biteMinMs et biteMaxMs, si la session est toujours là.
---@param session vAvA.HarvestSession
function fishing.cast(session)
    SetTimeout(random(cfg.biteMinMs, cfg.biteMaxMs), function()
        if harvest.session(session.source) ~= session then return end
        session.bitAt = GetGameTimer()
        TriggerClientEvent(EVENTS.BITE, session.source, { token = session.token, tension = cfg.tension })
    end)
end

--- Fin de la barre de tension. Bloque le thread courant en cas de prise (inventaire).
---@param src integer
---@param token any
---@param held any  vrai si la tension a été tenue assez longtemps (déclaratif)
---@return boolean ok
---@return table|string result
function fishing.reel(src, token, held)
    local session = harvest.session(src)
    if not session or session.token ~= token or session.kind ~= 'fishing' then return false, 'not_found' end
    if not session.bitAt then return false, 'too_soon' end
    local elapsed = GetGameTimer() - session.bitAt
    local duration = cfg.tension.durationMs
    if elapsed < duration - cfg.reelToleranceMs then return false, 'too_soon' end
    if elapsed > duration + cfg.reelGraceMs then
        harvest.drop(src)
        bridge.Notify(src, messages.escaped, 'info')
        return false, 'expired'
    end
    if held ~= true then
        harvest.drop(src)
        bridge.Notify(src, messages.escaped, 'info')
        return false, 'escaped'
    end
    return harvest.succeed(session)
end
