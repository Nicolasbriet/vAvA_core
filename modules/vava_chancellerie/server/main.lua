--[[
    vava_chancellerie/server/main.lua
    Rôle : déclaration du module auprès du core : écoute HTTP du pont, évènements relayés à la Chancellerie
           (signalements, arrivées et départs des joueurs, offres et fins des caméras regardées depuis le web, arrêt du
           module des caméras).
    Dépendances : tous les fichiers server/ du module
]]

local ipairs, tostring, type = ipairs, tostring, type
local AddEventHandler = AddEventHandler

local core = VavaBridge.core
if not core then return end

local auth = VavaBridge.auth
local push = VavaBridge.push
local http = VavaBridge.http
local cfg = VavaBridge.config

--- Caméra regardée depuis le web : offre du joueur filmé, ou fin.
---@param payload table
local function cameraEvent(payload)
    if type(payload) ~= 'table' or type(payload.session) ~= 'string' then return end
    if payload.offer then
        push.send({ type = 'camera', session = payload.session, signal = { type = 'offer', sdp = payload.offer } })
    elseif payload.ended then
        push.send({ type = 'camera', session = payload.session, ended = tostring(payload.ended) })
    end
end

local function setup()
    http.start()
    for _, def in ipairs({
        { VavaBridge.ADMIN_REPORT, function(payload) push.send({ type = 'report', action = payload.action, id = payload.id, author = payload.author }) end },
        { VavaBridge.CAMERAS_WEB, cameraEvent },
        { 'core:player:joined', function() push.send({ type = 'players' }) end },
        { 'core:player:dropped', function() push.send({ type = 'players' }) end },
    }) do
        local id, err = core.hooks.after(def[1], def[2])
        if not id then return false, err end
    end
    VavaBridge.ready = true
    if not auth.enabled() then
        core.log.info('serveur lancé sans la Chancellerie : le pont reste fermé')
    end
    return true
end

-- module des caméras arrêté : ses caméras sont mortes avec lui
AddEventHandler('onResourceStop', function(resource)
    if resource == VavaBridge.CAMERAS and VavaBridge.ready then push.send({ type = 'camera', reset = true }) end
end)

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(VavaBridge.resource, 'version', 0),
    coreVersion = cfg.coreVersion,
    dependencies = { vava_admin = '1.2.0' },
    setup = setup,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end
