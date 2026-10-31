--[[
    vava_cameras/server/main.lua
    Rôle : déclaration du module auprès du core : intentions des clients en RPC à schéma strict et à débit limité
           (joueur filmé : offre, abandon ; membre du Conseil en jeu : mur, joueurs, caméra, réponse, fermeture), droit
           revérifié à chaque demande du membre et quand son rang change, journal (ouverture du mur, vue en grand ;
           pas de case de mur sans mur ouvert),
           caméras éteintes quand le joueur filmé ou son spectateur quitte le jeu, ou que le spectateur perd le droit.
    Dépendances : tous les fichiers server/ du module
]]

local ipairs, tostring, type = ipairs, tostring, type
local CreateThread = CreateThread

local core = VavaCameras.core
if not core then return end

local players = VavaCameras.players
local sessions = VavaCameras.sessions
local links = VavaCameras.links
local cfg = VavaCameras.config
local limits = cfg.rateLimits
local messages = cfg.messages
local RPC = VavaCameras.RPC
local ADMIN = VavaCameras.ADMIN

local LENGTH = VavaCameras.SESSION_LENGTH
local SESSION = { type = 'string', min = LENGTH, max = LENGTH, pattern = VavaCameras.SESSION_PATTERN }
local SDP = { type = 'string', min = 1, max = cfg.limits.sdpMax }
local FAILURE = { type = 'string', enum = VavaCameras.FAILURES }
local TARGET = { type = 'integer', min = 1, max = 65535 }
local QUALITY = { type = 'string', enum = VavaCameras.QUALITIES }

--- Handler réservé au droit de regarder : refus 'forbidden' sinon.
---@param handler function
local function guarded(handler)
    return function(src, ...)
        if not links.canWatch(src) then return false, 'forbidden' end
        return handler(src, ...)
    end
end

--- Le spectateur en jeu de cette caméra est-il ce joueur ?
---@param src integer
---@return fun(camera: vAvA.Camera): boolean
local function viewerIs(src)
    return function(camera)
        return camera.viewer.kind == 'game' and camera.viewer.source == src
    end
end

--- Joueurs regardables par ce membre (lui-même exclu).
---@param src integer
---@return table[]
local function watchable(src)
    local out = {}
    for _, player in ipairs(players.list()) do
        if player.source ~= src then out[#out + 1] = player end
    end
    return out
end

--- Ouverture du mur : inscrite au journal, elle seule ouvre droit aux cases (levée par leave, départ, droit retiré).
local function wall(src)
    sessions.openWall(src)
    links.record(src, messages.logWall, {})
    return true, {
        players = watchable(src), layouts = cfg.wall.layouts, defaultLayout = cfg.wall.defaultLayout,
        refreshMs = cfg.wall.refreshMs, iceServers = cfg.iceServers,
    }
end

local function watch(src, target, quality)
    if target == src then return false, 'self' end
    local ok, result = sessions.start({ kind = 'game', source = src }, target, quality)
    if not ok then return false, result end
    local label = players.label(target)
    -- journal : la vue en grand seulement (une case n'est accordée que mur ouvert, et l'ouverture du mur y est)
    if quality == 'full' then links.record(src, messages.logWatch, { joueur = label, numero = target }) end
    return true, { session = result, label = label }
end

--- Rang donné ou retiré (vava_admin) : si le membre visé n'a plus le droit de regarder, ses caméras s'éteignent
--- (sinon elles resteraient ouvertes jusqu'à leur durée maximale).
---@param payload table
local function adminAction(payload)
    if not ADMIN.STAFF_ACTIONS[payload.action] or type(payload.target) ~= 'table' then return end
    local src = payload.target.source
        or (payload.target.accountId and core.players.getByAccount(payload.target.accountId))
    if not src then return end
    -- relu au tick suivant : vava_admin a fini d'enregistrer le rang
    CreateThread(function()
        if not links.canWatch(src) then sessions.revoke(src) end
    end)
end

local function setup()
    -- T-132 : un config.lua d'avant 1.5.0 (gardé par une mise à jour) remplace la table de config_client.lua ; il
    -- contient tout ce que lit le serveur, le module démarre, mais un réglage client qu'on y change reste sans effet
    if cfg.clientFile ~= true then
        core.log.warn('config.lua garde la forme d\'avant 1.5.0 (il remplace la table de config_client.lua) : les '
            .. 'réglages lus par les joueurs sont dans config_client.lua ; reportez vos changements d\'après '
            .. 'config.lua.nouveau')
    end
    local declared, declareErr = VavaCameras.commands.declare()
    if not declared then return false, 'commandes : ' .. tostring(declareErr) end
    for _, def in ipairs({
        { RPC.OFFER, { SESSION, SDP }, limits.capture, sessions.offer },
        { RPC.FAILED, { SESSION, FAILURE }, limits.capture, sessions.failed },
        { RPC.WALL, {}, limits.wall, guarded(wall) },
        { RPC.PLAYERS, {}, limits.players, guarded(function(src) return true, watchable(src) end) },
        { RPC.WATCH, { TARGET, QUALITY }, limits.watch, guarded(watch) },
        { RPC.ANSWER, { SESSION, SDP }, limits.signal, guarded(function(src, id, sdp) return sessions.answer(id, sdp, viewerIs(src)) end) },
        { RPC.CLOSE, { SESSION }, limits.signal, function(src, id) return sessions.close(id, viewerIs(src)) end },
        { RPC.LEAVE, {}, limits.wall, function(src)
            sessions.closeViewer(src)
            return true
        end },
    }) do
        local ok, err = core.rpc.register(def[1], { args = def[2], rateLimit = def[3] }, def[4])
        if not ok then return false, err end
    end
    for _, def in ipairs({
        -- personnage déchargé (retour à la sélection, ou départ : le déchargement vient alors en premier)
        { 'core:character:unloading', function(payload) sessions.forget(payload.source, 'left_game') end },
        { 'core:player:dropped', function(payload) sessions.forget(payload.source, 'dropped') end },
        { ADMIN.ACTION, adminAction },
    }) do
        local id, err = core.hooks.after(def[1], def[2])
        if not id then return false, err end
    end
    local ok, err = links.start()
    if not ok then return false, err end
    VavaCameras.ready = true
    return true
end

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(VavaCameras.resource, 'version', 0),
    coreVersion = cfg.coreVersion,
    setup = setup,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end
