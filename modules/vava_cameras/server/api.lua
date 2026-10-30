--[[
    vava_cameras/server/api.lua
    Rôle : exports serveur. Pour tous : nombre de caméras ouvertes. Pour la Chancellerie, par sa seule ressource-pont
           (le droit du compte et le journal sont vérifiés par le pont auprès du Registre) : joueurs regardables,
           caméra accordable, ouvrir, répondre, fermer une caméra. Offres et fins des caméras du web repartent par le hook
           vava_cameras:web, que le pont relaie à la Chancellerie.
    Dépendances : shared/constants.lua, config.lua, server/core.lua, server/players.lua, server/sessions.lua
]]

local mathType = math.type
local GetInvokingResource = GetInvokingResource

local players = VavaCameras.players
local sessions = VavaCameras.sessions
local cfg = VavaCameras.config

local WEB_VIEWER = { kind = 'web' }

---@param camera vAvA.Camera
---@return boolean
local function isWebViewer(camera)
    return camera.viewer.kind == 'web'
end

---@return boolean
local function fromBridge()
    return GetInvokingResource() == cfg.web.bridge
end

exports('count', function()
    return sessions.count()
end)

--- Joueurs connectés : liste { source, label, active }.
exports('webPlayers', function()
    if not VavaCameras.ready or not fromBridge() then return {} end
    return players.list()
end)

--- Une caméra pour le web serait-elle accordée maintenant (rien n'est ouvert) : true | false, code. Le pont la pose
--- avant de faire inscrire une vue en grand au journal, pour qu'une vue refusée (budget, retentée toutes les 10 s par
--- la Chancellerie) n'y laisse pas de ligne.
exports('webCheck', function(target, quality)
    if not VavaCameras.ready then return false, 'not_ready' end
    if not fromBridge() then return false, 'forbidden' end
    if mathType(target) ~= 'integer' or target < 1 then return false, 'invalid_args' end
    return sessions.check(WEB_VIEWER, target, quality)
end)

--- Ouvre une caméra pour le web : true, { session, label, iceServers } | false, code.
exports('webStart', function(target, quality)
    if not VavaCameras.ready then return false, 'not_ready' end
    if not fromBridge() then return false, 'forbidden' end
    if mathType(target) ~= 'integer' or target < 1 then return false, 'invalid_args' end
    local ok, result = sessions.start(WEB_VIEWER, target, quality)
    if not ok then return false, result end
    return true, { session = result, label = players.label(target), iceServers = cfg.iceServers }
end)

exports('webAnswer', function(id, sdp)
    if not VavaCameras.ready then return false, 'not_ready' end
    if not fromBridge() then return false, 'forbidden' end
    return sessions.answer(id, sdp, isWebViewer)
end)

exports('webStop', function(id)
    if not VavaCameras.ready then return false, 'not_ready' end
    if not fromBridge() then return false, 'forbidden' end
    return sessions.close(id, isWebViewer)
end)
