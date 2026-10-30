--[[
    vava_gathering/server/fishing.lua
    Rôle : la pêche. La ligne lancée (harvest.begin), le serveur tire le moment de la touche et prévient le seul
           pêcheur, qui tient la barre de tension pendant la durée de la config puis dit s'il a tenu (reel). Ce que dit
           le client ne peut que faire rater : ligne relâchée, la prise s'échappe ; ligne tenue, le serveur tire encore
           la prise selon le niveau de Pêche et la bande de la zone (shared/catch.lua). Le moment de la touche, la
           durée, la distance, la charge, la vitalité, le rendement et l'XP sont siens. Une prise échappée (raté,
           retard, poisson décroché) ne consomme rien.
    Dépendances : shared/constants.lua, config.lua, shared/catch.lua, server/core.lua, bridge/server.lua,
                  server/zones.lua, server/harvest.lua
]]

local random = math.random
local TriggerClientEvent, GetGameTimer, SetTimeout = TriggerClientEvent, GetGameTimer, SetTimeout

local bridge = VavaGathering.bridge
local harvest = VavaGathering.harvest
local zones = VavaGathering.zones
local catch = VavaGathering.catch
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

--- Bande de vitalité actuelle de la zone du nœud pêché.
---@param session vAvA.HarvestSession
---@return string|nil
local function bandOf(session)
    local zone = session.node.zone
    local state = zones.state(zone.id)
    if not state then return nil end
    zones.refresh(zone, state)
    return zones.band(state)
end

--- La prise s'échappe : session oubliée, rien n'est consommé.
---@param src integer
---@param message string
---@param code string
---@return boolean ok
---@return string code
local function escape(src, message, code)
    harvest.drop(src)
    bridge.Notify(src, message, 'info')
    return false, code
end

--- Fin de la barre de tension. Bloque le thread courant en cas de prise (inventaire).
---@param src integer
---@param token any
---@param held any  vrai si la tension a été tenue assez longtemps (déclaratif : seul un refus est cru)
---@return boolean ok
---@return table|string result
function fishing.reel(src, token, held)
    local session = harvest.session(src)
    if not session or session.token ~= token or session.kind ~= 'fishing' then return false, 'not_found' end
    if not session.bitAt then return false, 'too_soon' end
    local elapsed = GetGameTimer() - session.bitAt
    local duration = cfg.tension.durationMs
    if elapsed < duration - cfg.reelToleranceMs then return false, 'too_soon' end
    if elapsed > duration + cfg.reelGraceMs then return escape(src, messages.escaped, 'expired') end
    if held ~= true then return escape(src, messages.escaped, 'escaped') end
    -- la ligne a tenu : le serveur tire la prise (niveau lu au lancer, bande de la zone maintenant)
    if catch.escapes(session.level, bandOf(session), cfg.catch, random()) then
        return escape(src, messages.slipped, 'escaped')
    end
    return harvest.succeed(session)
end
