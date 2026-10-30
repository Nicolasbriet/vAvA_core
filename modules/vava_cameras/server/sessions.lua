--[[
    vava_cameras/server/sessions.lua
    Rôle : les caméras ouvertes. Chacune relie un joueur filmé et un spectateur : un membre du Conseil en jeu (son
           numéro de joueur) ou la Chancellerie (par son pont). Le serveur relaie la négociation WebRTC dans les deux
           sens et vérifie que chaque message vient du bon bout ; l'image, elle, va directement du jeu du joueur au
           spectateur. Limites : spectateurs par joueur, caméras en tout, durée maximale ; une seule offre par caméra
           (une renégociation passe par une nouvelle caméra). Budget du débit montant du joueur filmé
           (shared/budget.lua) : un spectateur qui n'y tient pas est refusé, et la part de chacun est revue à chaque
           arrivée ou départ, annoncée au seul joueur filmé (sans nouvelle offre). Une case de mur (qualité tile) n'est
           accordée à un membre en jeu que mur ouvert : c'est l'ouverture du mur qui l'inscrit au journal. Une caméra
           s'éteint quand le joueur filmé part ou revient à la sélection, quand son spectateur la ferme, part ou perd
           le droit de regarder.
    Dépendances : shared/constants.lua, shared/budget.lua, config.lua, server/core.lua, server/players.lua
]]

local pairs, type, random, format = pairs, type, math.random, string.format
local GetGameTimer, TriggerClientEvent, SetTimeout = GetGameTimer, TriggerClientEvent, SetTimeout
local TriggerLatentClientEvent = TriggerLatentClientEvent

local players = VavaCameras.players
local budget = VavaCameras.budget
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
---@field kbps integer|nil   part du débit montant du joueur filmé

---@type table<string, vAvA.Camera>
local list = {}
local count = 0
-- membres en jeu dont le mur est ouvert → heure d'ouverture : posée par l'ouverture du mur (inscrite au journal),
-- levée quand il le ferme, quitte le jeu ou perd le droit de regarder, et caduque après wall.maxOpenMs (une
-- réouverture, donc une nouvelle ligne au journal, est alors demandée). Sans elle, aucune case de mur.
---@type table<integer, integer>
local walls = {}

---@param src integer
---@return boolean
local function hasWall(src)
    local openedAt = walls[src]
    return openedAt ~= nil and GetGameTimer() - openedAt < cfg.wall.maxOpenMs
end

---@return string
local function newId()
    return format('%08x%08x%08x', GetGameTimer() & ID_MASK, random(0, ID_MASK), random(0, ID_MASK))
end

--- Spectateurs de ce joueur filmé : nombre, et nombre par qualité.
---@param target integer
---@return integer total
---@return table<string, integer> counts
local function watchersOf(target)
    local n, counts = 0, {}
    for _, camera in pairs(list) do
        if camera.target == target then
            n = n + 1
            counts[camera.quality] = (counts[camera.quality] or 0) + 1
        end
    end
    return n, counts
end

--- Part du débit de chaque caméra de ce joueur filmé, revue après une arrivée ou un départ. Seules les parts
--- changées partent, au seul joueur filmé, qui les applique à ses encodeurs sans renégocier ; `opened` : la caméra
--- qui s'ouvre, dont l'ordre de départ porte la part.
---@param target integer
---@param opened string|nil
local function rebalance(target, opened)
    local _, counts = watchersOf(target)
    local rates = budget.rates(counts, cfg.qualities, cfg.budget.uplinkKbps)
    local changed = {}
    for id, camera in pairs(list) do
        if camera.target == target and camera.kbps ~= rates[camera.quality] then
            camera.kbps = rates[camera.quality]
            if id ~= opened then changed[#changed + 1] = { session = id, kbps = camera.kbps } end
        end
    end
    if #changed > 0 then TriggerClientEvent(EVENTS.RATES, target, { rates = changed }) end
end

--- Prévient le spectateur : offre à accepter, ou fin de la caméra. L'offre (jusqu'à limits.sdpMax octets) part en
--- envoi latent à débit borné : elle ne bouche pas la voie fiable du jeu du membre (un mur 4 × 4 en reçoit seize).
---@param camera vAvA.Camera
---@param offer string|nil
---@param ended string|nil
local function tellViewer(camera, offer, ended)
    if camera.viewer.kind == 'game' then
        if offer then
            TriggerLatentClientEvent(EVENTS.OFFER, camera.viewer.source, limits.offerBytesPerSecond,
                { session = camera.id, sdp = offer })
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
---@param leaving boolean|nil  le joueur filmé s'en va : pas de nouvelle part pour ses autres caméras, qui s'éteignent
local function finish(id, reason, notify, leaving)
    local camera = list[id]
    if not camera then return end
    list[id] = nil
    count = count - 1
    TriggerClientEvent(EVENTS.STOP, camera.target, { session = id })
    if notify then tellViewer(camera, nil, reason) end
    -- débit rendu aux spectateurs qui restent
    if not leaving then rebalance(camera.target) end
end

--- Cette caméra serait-elle accordée maintenant ? Rien n'est ouvert ni envoyé.
---@param viewer vAvA.CameraViewer
---@param target integer
---@param quality string  tile ou full
---@return boolean ok
---@return string|nil code
function sessions.check(viewer, target, quality)
    if not cfg.qualities[quality] then return false, 'invalid_quality' end
    if quality == 'tile' and viewer.kind == 'game' and not hasWall(viewer.source) then return false, 'wall_closed' end
    if not players.active(target) then return false, 'not_playing' end
    if count >= limits.sessions then return false, 'too_many_cameras' end
    local watchers, counts = watchersOf(target)
    if watchers >= limits.viewersPerPlayer then return false, 'too_many_viewers' end
    -- débit montant du joueur filmé : une seule vue en grand, planchers de tous sous le budget
    if not budget.admits(counts, quality, cfg.qualities, cfg.budget) then return false, 'budget' end
    return true
end

--- Ouvre une caméra sur l'écran d'un joueur.
---@param viewer vAvA.CameraViewer
---@param target integer
---@param quality string  tile ou full
---@return boolean ok
---@return string result  identifiant ou code
function sessions.start(viewer, target, quality)
    local admitted, code = sessions.check(viewer, target, quality)
    if not admitted then return false, code end
    local settings = cfg.qualities[quality]
    local id = newId()
    list[id] = {
        id = id, target = target, viewer = viewer, quality = quality, startedAt = GetGameTimer(),
        answered = false, offered = false,
    }
    count = count + 1
    -- les parts des autres baissent avant que la nouvelle caméra ne parte : le total reste sous le budget
    rebalance(target, id)
    TriggerClientEvent(EVENTS.START, target, {
        session = id, iceServers = cfg.iceServers,
        capture = cfg.capture, quality = { scale = settings.scale, fps = settings.fps, bitrateKbps = list[id].kbps },
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
    walls[src] = GetGameTimer()
end

--- Le mur de ce membre est-il ouvert (et depuis moins de wall.maxOpenMs) ?
---@param src integer
---@return boolean
function sessions.wallOpen(src)
    return hasWall(src)
end

--- Le joueur n'a plus d'image (départ, retour à la sélection) ou n'est plus là pour regarder : son mur se ferme.
---@param src integer
---@param reason string  raison donnée aux spectateurs de ses caméras
function sessions.forget(src, reason)
    walls[src] = nil
    for id, camera in pairs(list) do
        if camera.target == src then
            finish(id, reason, true, true)
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
