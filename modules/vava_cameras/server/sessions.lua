--[[
    vava_cameras/server/sessions.lua
    Rôle : les caméras ouvertes. Chacune relie un joueur filmé et un spectateur : un membre du Conseil en jeu (son
           numéro de joueur) ou la Chancellerie (par son pont). Le serveur relaie la négociation WebRTC dans les deux
           sens et vérifie que chaque message vient du bon bout ; l'image, elle, va directement du jeu du joueur au
           spectateur. Limites : spectateurs par joueur, caméras en tout, durée maximale. Une caméra s'éteint quand le
           joueur filmé part ou revient à la sélection, quand son spectateur la ferme ou part.
    Dépendances : shared/constants.lua, config.lua, server/core.lua, server/players.lua
]]

local pairs, type, random, format = pairs, type, math.random, string.format
local GetGameTimer, TriggerClientEvent, SetTimeout = GetGameTimer, TriggerClientEvent, SetTimeout

local players = VavaCameras.players
local cfg = VavaCameras.config
local limits = cfg.limits
local EVENTS = VavaCameras.EVENTS
local HOOK_WEB = VavaCameras.HOOKS.WEB
local ID_MASK = 0x7FFFFFFF

local sessions = {}
VavaCameras.sessions = sessions

---@class vAvA.CameraViewer
---@field kind string     game ou web
---@field source integer|nil

---@class vAvA.Camera
---@field id string
---@field target integer
---@field viewer vAvA.CameraViewer
---@field quality string
---@field startedAt integer
---@field answered boolean

---@type table<string, vAvA.Camera>
local list = {}
local count = 0

---@return string
local function newId()
    return format('%08x%08x%08x', GetGameTimer() & ID_MASK, random(0, ID_MASK), random(0, ID_MASK))
end

---@param target integer
---@return integer
local function watchersOf(target)
    local n = 0
    for _, camera in pairs(list) do
        if camera.target == target then n = n + 1 end
    end
    return n
end

--- Prévient le spectateur : offre à accepter, ou fin de la caméra.
---@param camera vAvA.Camera
---@param offer string|nil
---@param ended string|nil
local function tellViewer(camera, offer, ended)
    if camera.viewer.kind == 'game' then
        if offer then
            TriggerClientEvent(EVENTS.OFFER, camera.viewer.source, { session = camera.id, sdp = offer })
        else
            TriggerClientEvent(EVENTS.ENDED, camera.viewer.source, { session = camera.id, reason = ended })
        end
        return
    end
    VavaCameras.core.hooks.runAfter(HOOK_WEB, { session = camera.id, offer = offer, ended = ended })
end

---@param id string
---@param reason string
---@param notify boolean  prévenir le spectateur
local function finish(id, reason, notify)
    local camera = list[id]
    if not camera then return end
    list[id] = nil
    count = count - 1
    TriggerClientEvent(EVENTS.STOP, camera.target, { session = id })
    if notify then tellViewer(camera, nil, reason) end
end

--- Ouvre une caméra sur l'écran d'un joueur.
---@param viewer vAvA.CameraViewer
---@param target integer
---@param quality string  tile ou full
---@return boolean ok
---@return string result  identifiant ou code
function sessions.start(viewer, target, quality)
    local settings = cfg.qualities[quality]
    if not settings then return false, 'invalid_quality' end
    if not players.active(target) then return false, 'not_playing' end
    if count >= limits.sessions then return false, 'too_many_cameras' end
    if watchersOf(target) >= limits.viewersPerPlayer then return false, 'too_many_viewers' end
    local id = newId()
    list[id] = { id = id, target = target, viewer = viewer, quality = quality, startedAt = GetGameTimer(), answered = false }
    count = count + 1
    TriggerClientEvent(EVENTS.START, target, {
        session = id, iceServers = cfg.iceServers,
        capture = cfg.capture, quality = { scale = settings.scale, fps = settings.fps, bitrateKbps = settings.bitrateKbps },
    })
    -- spectateur parti sans répondre (page fermée, Chancellerie arrêtée) : la caméra ne reste pas ouverte pour rien
    SetTimeout(limits.answerMs, function()
        local camera = list[id]
        if camera and not camera.answered then finish(id, 'no_answer', true) end
    end)
    SetTimeout(limits.sessionMaxMs, function() finish(id, 'expired', true) end)
    return true, id
end

--- Offre du joueur filmé (lui seul peut l'envoyer), relayée au spectateur.
---@param src integer
---@param id string
---@param sdp string
---@return boolean ok
---@return string|nil code
function sessions.offer(src, id, sdp)
    local camera = list[id]
    if not camera or camera.target ~= src then return false, 'unknown_session' end
    tellViewer(camera, sdp, nil)
    return true
end

--- Réponse du spectateur, transmise au joueur filmé. `isViewer(camera)` dit si l'appel vient bien du spectateur.
---@param id any
---@param sdp any
---@param isViewer fun(camera: vAvA.Camera): boolean
---@return boolean ok
---@return string|nil code
function sessions.answer(id, sdp, isViewer)
    local camera = type(id) == 'string' and list[id]
    if not camera or not isViewer(camera) then return false, 'unknown_session' end
    if type(sdp) ~= 'string' or #sdp == 0 or #sdp > limits.sdpMax then return false, 'invalid_args' end
    if camera.answered then return false, 'already_answered' end
    camera.answered = true
    TriggerClientEvent(EVENTS.ANSWER, camera.target, { session = id, sdp = sdp })
    return true
end

--- Le spectateur ferme sa caméra.
---@return boolean ok
---@return string|nil code
function sessions.close(id, isViewer)
    local camera = type(id) == 'string' and list[id]
    if not camera or not isViewer(camera) then return false, 'unknown_session' end
    finish(id, 'stopped', false)
    return true
end

--- Le jeu du joueur filmé abandonne (capture impossible, connexion perdue).
---@return boolean ok
---@return string|nil code
function sessions.failed(src, id, reason)
    local camera = list[id]
    if not camera or camera.target ~= src then return false, 'unknown_session' end
    finish(id, reason, true)
    return true
end

--- Le joueur n'a plus d'image (départ, retour à la sélection) ou n'est plus là pour regarder.
---@param src integer
---@param reason string  raison donnée aux spectateurs de ses caméras
function sessions.forget(src, reason)
    for id, camera in pairs(list) do
        if camera.target == src then
            finish(id, reason, true)
        elseif camera.viewer.kind == 'game' and camera.viewer.source == src then
            finish(id, 'viewer_left', false)
        end
    end
end

--- Un membre en jeu ferme son mur : toutes ses caméras s'éteignent.
---@param src integer
function sessions.closeViewer(src)
    for id, camera in pairs(list) do
        if camera.viewer.kind == 'game' and camera.viewer.source == src then finish(id, 'stopped', false) end
    end
end

---@param id string
---@return vAvA.Camera|nil
function sessions.get(id)
    return list[id]
end

---@return integer
function sessions.count()
    return count
end
