--[[
    vava_chancellerie/server/routes.lua
    Rôle : ce que la Chancellerie peut demander au pont. Les demandes du Conseil passent telles quelles au Registre
           (vava_admin.webRequest : droit du rang, schéma, cible, journal) ; les zones de voix sont lues, modifiées et
           supprimées auprès de vava_voice, après vérification du droit auprès du Registre, qui les inscrit à son
           journal ; les caméras sont ouvertes auprès de vava_cameras une fois le droit de regarder accordé : la vue en
           grand par la demande « écran du joueur » du Registre (cible vérifiée, au journal), les cases d'un mur sur
           le seul droit, l'ouverture du mur étant inscrite au journal. D'autres fichiers du pont ajoutent leurs
           demandes à `routes.requests` (ciel et heure : server/time.lua).
    Dépendances : shared/constants.lua, config.lua, server/core.lua
]]

local type, tostring, tointeger = type, tostring, math.tointeger
local GetResourceMetadata = GetResourceMetadata

local call = VavaBridge.call
local messages = VavaBridge.config.messages
local CAMERAS_CFG = VavaBridge.config.cameras
local ADMIN, VOICE, CAMERAS = VavaBridge.ADMIN, VavaBridge.VOICE, VavaBridge.CAMERAS
-- droits du Registre pour lire et pour modifier les zones de voix
local ZONES_READ, ZONES_WRITE = 'view', 'tools'
local QUALITIES = { tile = true, full = true }

local routes = {}
VavaBridge.routes = routes

-- Demandes du panneau tenues par d'autres fichiers du pont (ciel et heure : server/time.lua), comme les zones de voix :
-- nom → fun(actor, args): table. Le pont y vérifie lui-même le droit auprès du Registre.
---@type table<string, fun(actor: table, args: table): table>
routes.requests = {}

---@type table<string, fun(body: table): table>
local list = {}

local function define(method, path, handler)
    list[method .. ' ' .. path] = handler
end

---@param method string
---@param path string
---@return function|nil
function routes.find(method, path)
    return list[method .. ' ' .. path]
end

local function failure(code)
    return { ok = false, error = tostring(code) }
end

--- Le rang de ce compte du panneau a-t-il ce droit ?
local function can(actor, permission)
    local called, allowed = call(ADMIN, 'webCan', actor, permission)
    return called and allowed == true
end

-- Zones de voix ---------------------------------------------------------------------------------------------------

local ZONE_REQUESTS = {
    zones = function(actor)
        if not can(actor, ZONES_READ) then return failure('forbidden') end
        local called, zones = call(VOICE, 'getZones')
        if not called then return failure('voice_unavailable') end
        return { ok = true, result = zones }
    end,
    zoneUpdate = function(actor, args)
        if not can(actor, ZONES_WRITE) then return failure('forbidden') end
        local called, ok, zone, details = call(VOICE, 'webUpdateZone', args[1], args[2], args[3], args[4], args[5])
        if not called then return failure('voice_unavailable') end
        if not ok then return failure(zone) end
        call(ADMIN, 'webLog', actor, messages.logZoneUpdate, details)
        return { ok = true, result = zone }
    end,
    zoneDelete = function(actor, args)
        if not can(actor, ZONES_WRITE) then return failure('forbidden') end
        local called, ok, code, details = call(VOICE, 'webDeleteZone', args[1])
        if not called then return failure('voice_unavailable') end
        if not ok then return failure(code) end
        call(ADMIN, 'webLog', actor, messages.logZoneDelete, details)
        return { ok = true }
    end,
}

-- Routes ------------------------------------------------------------------------------------------------------------

define('GET', '/ping', function()
    local called, cameras = call(CAMERAS, 'count')
    return { ok = true, version = GetResourceMetadata(VavaBridge.resource, 'version', 0), cameras = called and cameras or 0 }
end)

define('GET', '/ranks', function()
    local called, ranks = call(ADMIN, 'webRanks')
    if not called then return failure('admin_unavailable') end
    return { ok = true, ranks = ranks }
end)

define('POST', '/request', function(body)
    local name, args = body.name, type(body.args) == 'table' and body.args or {}
    local zone = type(name) == 'string' and (ZONE_REQUESTS[name] or routes.requests[name])
    if zone then return zone(body.actor, args) end
    local called, ok, result = call(ADMIN, 'webRequest', body.actor, name, args)
    if not called then return failure('admin_unavailable') end
    if not ok then return failure(result) end
    return { ok = true, result = result }
end)

-- Comptes reliés ------------------------------------------------------------------------------------------------------

-- Rangs des comptes de jeu reliés à un compte du panneau : { members = { { accountId, rank ('' : aucun), label } } }.
-- Le panneau est la source : chaque rang est appliqué tel quel par le Registre, et inscrit à son journal s'il change.
-- Défense en profondeur : un rang n'est donné qu'à un compte que le pont a lui-même vu relié en jeu (server/links.lua) ;
-- qui détiendrait la clé ne peut pas nommer Souverain un compte de son choix. Retirer un rang reste toujours permis.
local SYNC_MAX = 100
local rules, links = VavaBridge.rules, VavaBridge.links

define('POST', '/staff/sync', function(body)
    local members = type(body.members) == 'table' and body.members or {}
    if #members > SYNC_MAX then return failure('invalid_args') end
    local results = {}
    for i = 1, #members do
        local member = members[i]
        if type(member) ~= 'table' then
            results[i] = { ok = false, error = 'invalid_args' }
        else
            local accountId = tointeger(member.accountId)
            local allowed, refusal = rules.canSync(member.rank, links.known(accountId))
            if not allowed then
                VavaBridge.log.warn('rang refusé au compte n° %s : jamais relié en jeu par un code de la Chancellerie',
                    tostring(accountId))
                results[i] = { ok = false, error = refusal }
            else
                local called, ok, changed = call(ADMIN, 'webSyncStaff', member.accountId, member.rank, member.label)
                if not called then return failure('admin_unavailable') end
                results[i] = { ok = ok == true, changed = ok and changed or nil, error = not ok and tostring(changed) or nil }
            end
        end
    end
    return { ok = true, results = results }
end)

-- Caméras -----------------------------------------------------------------------------------------------------------

--- Joueurs regardables ; `logged` : ouverture du mur, inscrite au journal.
local function wallPlayers(actor, logged)
    if not can(actor, CAMERAS_CFG.permission) then return failure('forbidden') end
    local called, players = call(CAMERAS, 'webPlayers')
    if not called then return failure('cameras_unavailable') end
    if logged then call(ADMIN, 'webLog', actor, messages.logWall, {}) end
    return { ok = true, players = players }
end

define('POST', '/cameras/wall', function(body) return wallPlayers(body.actor, true) end)
define('POST', '/cameras/players', function(body) return wallPlayers(body.actor, false) end)

define('POST', '/camera/start', function(body)
    local target, quality = tointeger(body.target), body.quality
    if not target or not QUALITIES[quality] then return failure('invalid_args') end
    if quality == 'full' then
        -- vue en grand : droit, joueur en jeu et journal par le Registre
        local called, ok, result = call(ADMIN, 'webRequest', body.actor, CAMERAS_CFG.fullRequest, { target })
        if not called then return failure('admin_unavailable') end
        if not ok then return failure(result) end
    elseif not can(body.actor, CAMERAS_CFG.permission) then
        return failure('forbidden')
    end
    local called, ok, result = call(CAMERAS, 'webStart', target, quality)
    if not called then return failure('cameras_unavailable') end
    if not ok then return failure(result) end
    return { ok = true, session = result.session, label = result.label, iceServers = result.iceServers }
end)

define('POST', '/camera/answer', function(body)
    local called, ok, code = call(CAMERAS, 'webAnswer', body.session, body.sdp)
    if not called then return failure('cameras_unavailable') end
    if not ok then return failure(code) end
    return { ok = true }
end)

define('POST', '/camera/stop', function(body)
    local called, ok, code = call(CAMERAS, 'webStop', body.session)
    if not called then return failure('cameras_unavailable') end
    if not ok then return failure(code) end
    return { ok = true }
end)
