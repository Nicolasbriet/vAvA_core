--[[
    vava_chancellerie/server/main.lua
    Rôle : déclaration du module auprès du core : écoute HTTP du pont, évènements relayés à la Chancellerie
           (signalements, arrivées et départs des joueurs, offres et fins des caméras regardées depuis le web, arrêt du
           module des caméras, rang du Conseil changé : elle revérifie le droit de chaque compte qui regarde, pont
           prêt : elle applique alors les rangs des comptes reliés) ; commande de liaison d'un compte du panneau ;
           clé du pont demandée à la Chancellerie par la console (server/auth.lua).
    Dépendances : tous les fichiers server/ du module
]]

local ipairs, tostring, type = ipairs, tostring, type
local AddEventHandler, GetConvar, GetResourceMetadata = AddEventHandler, GetConvar, GetResourceMetadata

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

--- Rang du Conseil donné ou retiré (en jeu, à la console, ou pour un compte relié au panneau) : la Chancellerie
--- revérifie le droit de regarder de chaque compte dont les caméras sont ouvertes, avec son rang actuel.
---@param payload table
local function staffChanged(payload)
    if type(payload) == 'table' and VavaBridge.STAFF_ACTIONS[payload.action] then push.send({ type = 'camera', recheck = true }) end
end

local function setup()
    local declared, declareErr = VavaBridge.commands.declare()
    if not declared then return false, 'commandes : ' .. tostring(declareErr) end
    local loaded, loadErr = VavaBridge.links.load()
    if not loaded then return false, 'comptes reliés : ' .. tostring(loadErr) end
    -- adresse de la Chancellerie figée maintenant ; la commande qui reçoit la clé existe avant que le pont ne la demande
    local _, urlErr = auth.capture()
    if urlErr then
        core.log.warn('adresse de la Chancellerie refusée (%s : http://127.0.0.1:<port> seulement) : pont fermé',
            cfg.convars.url)
    end
    auth.listen()
    http.start()
    for _, def in ipairs({
        { VavaBridge.ADMIN_REPORT, function(payload) push.send({ type = 'report', action = payload.action, id = payload.id, author = payload.author }) end },
        { VavaBridge.CAMERAS_WEB, cameraEvent },
        { VavaBridge.ADMIN_ACTION, staffChanged },
        { 'core:player:joined', function() push.send({ type = 'players' }) end },
        { 'core:player:dropped', function() push.send({ type = 'players' }) end },
    }) do
        local id, err = core.hooks.after(def[1], def[2])
        if not id then return false, err end
    end
    VavaBridge.link.start()
    local whitelistOk, whitelistErr = VavaBridge.whitelist.start()
    if not whitelistOk then return false, whitelistErr end
    VavaBridge.ready = true
    if GetConvar(cfg.convars.legacyToken, '') ~= '' then
        core.log.warn('clé du pont passée sur la ligne de commande (%s) : ignorée ; mettez la Chancellerie à jour (1.6.0)',
            cfg.convars.legacyToken)
    end
    if not auth.expected() then
        core.log.info('serveur lancé sans la Chancellerie : le pont reste fermé')
    else
        -- dès que la clé arrive, la Chancellerie est prévenue : elle applique alors les rangs des comptes reliés
        -- (changés pendant que le serveur était arrêté) et dit si sa liste blanche est active
        auth.await(function()
            push.request({ type = 'ready' }, function(answer)
                VavaBridge.whitelist.setEnabled(answer and answer.whitelist)
            end)
        end)
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
    dependencies = { vava_admin = '1.3.0' },
    setup = setup,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end
