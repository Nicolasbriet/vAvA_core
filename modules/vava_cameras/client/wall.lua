--[[
    vava_cameras/client/wall.lua
    Rôle : mur des caméras en jeu, pour le Conseil, ouvert depuis l'outil du Registre ou par commande. Le serveur
           accorde l'ouverture (et l'inscrit au journal) puis revérifie chaque caméra demandée ; le client ne fait que
           relayer entre l'interface et le serveur. Mur ouvert : la liste des joueurs est relue à intervalle ; fermé,
           toutes ses caméras s'éteignent et plus rien ne tourne.
    Dépendances : shared/constants.lua, config.lua, client/core.lua, client/nui.lua
]]

local type, ipairs, tostring, tointeger = type, ipairs, tostring, math.tointeger
local CreateThread, Wait, RegisterNetEvent = CreateThread, Wait, RegisterNetEvent

local core = VavaCameras.core
if not core then return end

local nui = VavaCameras.nui
local isSession = VavaCameras.isSession
local cfg = VavaCameras.config
local EVENTS = VavaCameras.EVENTS
local RPC = VavaCameras.RPC
local SDP_MAX = cfg.limits.sdpMax

local QUALITIES = {}
for _, quality in ipairs(VavaCameras.QUALITIES) do QUALITIES[quality] = true end

local wall = {}
VavaCameras.wall = wall

local open = false
local opening = false
-- numéro d'ouverture : la relecture d'un mur fermé puis rouvert s'arrête d'elle-même
local generation = 0

---@return boolean
function wall.isOpen()
    return open
end

--- Résultat d'une RPC pour l'interface.
---@return table
local function answer(ok, success, result)
    if not ok then return { ok = false, error = tostring(success) } end
    if not success then return { ok = false, error = tostring(result) } end
    return { ok = true, result = result }
end

---@param current integer
local function refreshLoop(current)
    while open and generation == current do
        Wait(cfg.wall.refreshMs)
        if not open or generation ~= current then return end
        local ok, success, list = core.rpc.call(RPC.PLAYERS)
        if open and generation == current and ok and success and type(list) == 'table' then
            nui.send('wall:players', { players = list })
        end
    end
end

function wall.close()
    if not open then return end
    open = false
    generation = generation + 1
    core.rpc.emit(RPC.LEAVE)
    nui.send('wall:close')
    nui.setFocus(false)
end

--- Demande l'ouverture au serveur (rien ne se passe sans le droit de regarder).
function wall.open()
    if open or opening or not nui.isReady() or not core.characters.current() then return end
    opening = true
    local ok, success, data = core.rpc.call(RPC.WALL)
    opening = false
    if not ok or not success or type(data) ~= 'table' then return end
    open = true
    generation = generation + 1
    nui.send('wall:open', {
        players = data.players, layouts = data.layouts, defaultLayout = data.defaultLayout,
        iceServers = data.iceServers, staggerMs = cfg.wall.staggerMs,
    })
    nui.setFocus(true)
    local current = generation
    CreateThread(function() refreshLoop(current) end)
end

-- Interface -------------------------------------------------------------------------------------------------------

nui.on('wall:exit', function()
    wall.close()
    return { ok = true }
end)

nui.on('wall:watch', function(data)
    local target = tointeger(data.target)
    if not open then return { ok = false, error = 'closed' } end
    if not target or not QUALITIES[data.quality] then return { ok = false, error = 'invalid_args' } end
    return answer(core.rpc.call(RPC.WATCH, target, data.quality))
end)

nui.on('wall:answer', function(data)
    if open and isSession(data.session) and type(data.sdp) == 'string' and #data.sdp <= SDP_MAX then
        core.rpc.emit(RPC.ANSWER, data.session, data.sdp)
    end
    return { ok = true }
end)

nui.on('wall:close', function(data)
    if open and isSession(data.session) then core.rpc.emit(RPC.CLOSE, data.session) end
    return { ok = true }
end)

-- Serveur ---------------------------------------------------------------------------------------------------------

RegisterNetEvent(EVENTS.OFFER, function(payload)
    if open and type(payload) == 'table' and isSession(payload.session) and type(payload.sdp) == 'string' then
        nui.send('wall:offer', { session = payload.session, sdp = payload.sdp })
    end
end)

RegisterNetEvent(EVENTS.ENDED, function(payload)
    if open and type(payload) == 'table' and isSession(payload.session) then
        nui.send('wall:ended', { session = payload.session, reason = tostring(payload.reason) })
    end
end)
