--[[
    vava_cameras/client/capture.lua
    Rôle : caméra sur l'écran du joueur, à la demande du serveur. L'interface (invisible) filme l'image du jeu seule
           et l'envoie en WebRTC à chaque membre du Conseil qui regarde ; ce fichier ne fait que relayer : ordres du
           serveur vers l'interface, offre et abandon de l'interface vers le serveur. Rien n'est filmé sans ordre du
           serveur, et tout s'arrête à son ordre ou à l'arrêt de la ressource.
    Dépendances : shared/constants.lua, config.lua, client/core.lua, client/nui.lua
]]

local type, ipairs = type, ipairs
local RegisterNetEvent = RegisterNetEvent

local core = VavaCameras.core
if not core then return end

local nui = VavaCameras.nui
local isSession = VavaCameras.isSession
local EVENTS = VavaCameras.EVENTS
local RPC = VavaCameras.RPC
local SDP_MAX = VavaCameras.config.limits.sdpMax

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
