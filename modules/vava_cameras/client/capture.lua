--[[
    vava_cameras/client/capture.lua
    Rôle : caméra sur l'écran du joueur, à la demande du serveur. L'interface (invisible) filme l'image du jeu seule
           et l'envoie en WebRTC à chaque membre du Conseil qui regarde ; ce fichier ne fait que relayer : ordres du
           serveur vers l'interface (départ, réponse, fin, part du débit de chaque spectateur), offre et abandon de
           l'interface vers le serveur. Rien n'est filmé sans ordre du serveur, et tout s'arrête à son ordre ou à
           l'arrêt de la ressource.
    Dépendances : shared/constants.lua, config_client.lua, client/core.lua, client/nui.lua
]]

local type, ipairs, pairs, tointeger, min = type, ipairs, pairs, math.tointeger, math.min
local RegisterNetEvent = RegisterNetEvent

local core = VavaCameras.core
if not core then return end

local nui = VavaCameras.nui
local isSession = VavaCameras.isSession
local cfg = VavaCameras.config
local EVENTS = VavaCameras.EVENTS
local RPC = VavaCameras.RPC
local SDP_MAX = cfg.limits.sdpMax
-- parts du débit : une par spectateur au plus, jamais au-dessus du plus haut plafond
local RATES_MAX = cfg.limits.viewersPerPlayer
local KBPS_MAX = 0
for _, quality in pairs(cfg.qualities) do
    if quality.bitrateKbps > KBPS_MAX then KBPS_MAX = quality.bitrateKbps end
end

local FAILURES = {}
for _, reason in ipairs(VavaCameras.FAILURES) do FAILURES[reason] = true end

nui.on('capture:offer', function(data)
    if isSession(data.session) and type(data.sdp) == 'string' and #data.sdp <= SDP_MAX then
        core.rpc.emit(RPC.OFFER, data.session, data.sdp)
    end
    return { ok = true }
end)

nui.on('capture:failed', function(data)
    if isSession(data.session) and FAILURES[data.reason] then core.rpc.emit(RPC.FAILED, data.session, data.reason) end
    return { ok = true }
end)

RegisterNetEvent(EVENTS.START, function(payload)
    if type(payload) ~= 'table' or not isSession(payload.session) then return end
    nui.send('capture:start', {
        session = payload.session, iceServers = type(payload.iceServers) == 'table' and payload.iceServers or {},
        capture = payload.capture, quality = payload.quality,
    })
end)

RegisterNetEvent(EVENTS.ANSWER, function(payload)
    if type(payload) == 'table' and isSession(payload.session) and type(payload.sdp) == 'string' then
        nui.send('capture:answer', { session = payload.session, sdp = payload.sdp })
    end
end)

RegisterNetEvent(EVENTS.STOP, function(payload)
    if type(payload) == 'table' and isSession(payload.session) then nui.send('capture:stop', { session = payload.session }) end
end)

-- part du débit montant revue par le serveur (un spectateur arrivé ou parti) : appliquée sans renégocier
RegisterNetEvent(EVENTS.RATES, function(payload)
    if type(payload) ~= 'table' or type(payload.rates) ~= 'table' then return end
    local rates = {}
    for i = 1, min(#payload.rates, RATES_MAX) do
        local rate = payload.rates[i]
        local kbps = type(rate) == 'table' and tointeger(rate.kbps)
        if kbps and kbps >= 1 and kbps <= KBPS_MAX and isSession(rate.session) then
            rates[#rates + 1] = { session = rate.session, kbps = kbps }
        end
    end
    if #rates > 0 then nui.send('capture:rates', { rates = rates }) end
end)
