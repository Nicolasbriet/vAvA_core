--[[
    vava_cameras/server/sessions.lua
    Rôle : les caméras ouvertes. Chacune relie un joueur filmé et un spectateur : un membre du Conseil en jeu (son
           numéro de joueur) ou la Chancellerie (par son pont). Le serveur relaie la négociation WebRTC dans les deux
           sens et vérifie que chaque message vient du bon bout ; l'image, elle, va directement du jeu du joueur au
           spectateur. Limites : spectateurs par joueur, caméras en tout, durée maximale ; une seule offre par caméra
           (une renégociation passe par une nouvelle caméra). Une case de mur (qualité tile) n'est accordée à un membre
           en jeu que mur ouvert : c'est l'ouverture du mur qui l'inscrit au journal. Une caméra s'éteint quand le
           joueur filmé part ou revient à la sélection, quand son spectateur la ferme, part ou perd le droit de
           regarder.
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
---@field offered boolean

---@type table<string, vAvA.Camera>
local list = {}
local count = 0
-- membres en jeu dont le mur est ouvert : posé par l'ouverture du mur (inscrite au journal), levé quand il le ferme,
-- quitte le jeu ou perd le droit de regarder. Sans lui, aucune case de mur.
---@type table<integer, true>
local walls = {}

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
    if quality == 'tile' and viewer.kind == 'game' and not walls[viewer.source] then return false, 'wall_closed' end
    if not players.active(target) then return false, 'not_playing' end
    if count >= limits.sessions then return false, 'too_many_cameras' end
    if watchersOf(target) >= limits.viewersPerPlayer then return false, 'too_many_viewers' end
    local id = newId()
    list[id] = {
        id = id, target = target, viewer = viewer, quality = quality, startedAt = GetGameTimer(),
        answered = false, offered = false,
    }
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

--- Offre du joueur filmé (lui seul peut l'envoyer, une seule fois par caméra), relayée au spectateur.
---@param src integer
---@param id string
---@param sdp string
---@return boolean ok
---@return string|nil code
function sessions.offer(src, id, sdp)
    local camera = list[id]
    if not camera or camera.target ~= src then return false, 'unknown_session' end
    if camera.offered then return false, 'already_offered' end
    camera.offered = true
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

--- Un membre en jeu ouvre son mur (droit vérifié et ouverture inscrite au journal par l'appelant).
---@param src integer
function sessions.openWall(src)
    walls[src] = true
end

--- Le mur de ce membre est-il ouvert ?
---@param src integer
---@return boolean
function sessions.wallOpen(src)
    return walls[src] == true
end

--- Le joueur n'a plus d'image (départ, retour à la sélection) ou n'est plus là pour regarder : son mur se ferme.
---@param src integer
---@param reason string  raison donnée aux spectateurs de ses caméras
function sessions.forget(src, reason)
    walls[src] = nil
    for id, camera in pairs(list) do
        if camera.target == src then
            finish(id, reason, true)
        elseif camera.viewer.kind == 'game' and camera.viewer.source == src then
            finish(id, 'viewer_left', false)
        end
    end
end

--- Un membre en jeu ferme son mur : toutes ses caméras s'éteignent, plus aucune case sans le rouvrir.
---@param src integer
function sessions.closeViewer(src)
    walls[src] = nil
    for id, camera in pairs(list) do
        if camera.viewer.kind == 'game' and camera.viewer.source == src then finish(id, 'stopped', false) end
    end
end

--- Un membre en jeu n'a plus le droit de regarder (rang retiré) : ses caméras s'éteignent, son mur l'affiche et
--- devra être rouvert (nouvelle ligne au journal) pour regarder de nouveau.
---@param src integer
function sessions.revoke(src)
    walls[src] = nil
    for id, camera in pairs(list) do
        if camera.viewer.kind == 'game' and camera.viewer.source == src then finish(id, 'forbidden', true) end
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
