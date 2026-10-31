--[[
    vava_admin/server/requests.lua
    Rôle : catalogue des demandes du Conseil, partagé par le Registre en jeu (RPC) et la Chancellerie (panneau web, par
           son pont). Chaque demande déclare son droit, le schéma de ses arguments, sa limite de débit en jeu et où elle
           a un sens : en jeu seulement (elle suppose le personnage du membre : rejoindre, amener à soi, observer,
           outils), au web seulement (déplacer vers un joueur ou un lieu, inventaire en lecture, écran du joueur), ou
           les deux. Les actions sur un joueur revérifient la cible connectée et le rang (jamais un rang égal ou
           supérieur) puis s'inscrivent au journal.
    Dépendances : shared/constants.lua, config.lua, server/core.lua, server/ranks.lua, server/staff.lua,
                  server/extensions.lua, server/audit.lua, server/bans.lua, server/reports.lua, server/players.lua,
                  server/actions.lua, server/invulnerability.lua, server/store.lua
]]

local ipairs, unpack = ipairs, table.unpack
local TriggerClientEvent = TriggerClientEvent

local ranks = VavaAdmin.ranks
local staff = VavaAdmin.staff
local audit = VavaAdmin.audit
local bans = VavaAdmin.bans
local reports = VavaAdmin.reports
local players = VavaAdmin.players
local actions = VavaAdmin.actions
local invulnerability = VavaAdmin.invulnerability
local store = VavaAdmin.store
local extensions = VavaAdmin.extensions
local cfg = VavaAdmin.config
local limits = cfg.rateLimits
local EVENTS = VavaAdmin.EVENTS

local GAME, WEB, BOTH = 'game', 'web', 'both'

local TARGET = { type = 'integer', min = 1, max = 65535 }
local ACCOUNT = { type = 'integer', min = 1, max = VavaAdmin.MAX_ID }
local TEXT = { type = 'string', min = 1, max = VavaAdmin.MAX_TEXT }
local HOURS = { type = 'integer', min = 0, max = 87600 }
local PAGE = { type = 'integer', min = 0, max = 100000 }
local ITEM = { type = 'string', min = 1, max = 64, pattern = '^[%w_%-%.:]+$' }
local QUANTITY = { type = 'integer', min = 1, max = 1000 }
local BOOL = { type = 'boolean' }
local REPORT_ID = { type = 'integer', min = 1, max = VavaAdmin.MAX_ID }
local COORD = { type = 'number', min = -VavaAdmin.MAX_COORD, max = VavaAdmin.MAX_COORD }
-- '' : révoquer
local RANK = { type = 'string', max = 32, pattern = '^[%w_]*$' }
local TOOL = { type = 'string', enum = { 'noclip', 'invisible', 'godmode', 'waypoint' } }
local MODULE_TOOL = { type = 'string', min = 3, max = VavaAdmin.TOOL_LIMITS.key, pattern = '^[%w_%-%.]+:[%w_%-%.]+$' }

---@class vAvA.AdminRequest
---@field name string
---@field permission string
---@field args table[]
---@field limit table
---@field where string   game, web ou both
---@field handler fun(actor: vAvA.AdminActor, ...): boolean, any
---@field release? fun(src: integer, ...): boolean, any   sans le droit (en jeu) : ce qui reste permis, couper seulement

---@type table<string, vAvA.AdminRequest>
local requests = {}
VavaAdmin.requests = requests

local function define(name, permission, args, limit, where, handler)
    requests[name] = { name = name, permission = permission, args = args, limit = limit, where = where, handler = handler }
end

--- La demande a-t-elle un sens à cet endroit ?
---@param request vAvA.AdminRequest
---@param place string  game ou web
---@return boolean
function VavaAdmin.requestAllowedIn(request, place)
    return request.where == BOTH or request.where == place
end

-- Actions sur un joueur : { nom, droit, arguments après la cible, fonction, sur soi-même, protégé par le rang, où }.
-- Les actions « protégées » ne visent jamais un membre de rang égal ou supérieur ; les autres l'aident (soin, objet).
local PLAYER_ACTIONS = {
    { 'reach', 'teleport', {}, actions.reach, false, false, GAME },
    { 'bring', 'teleport', {}, actions.bring, false, true, GAME },
    { 'sendBack', 'teleport', {}, actions.sendBack, true, true, BOTH },
    { 'moveToPlayer', 'teleport', { TARGET }, actions.moveToPlayer, true, true, WEB },
    { 'moveToCoords', 'teleport', { COORD, COORD, COORD }, actions.moveToCoords, true, true, WEB },
    { 'freeze', 'freeze', { BOOL }, actions.freeze, false, true, BOTH },
    { 'heal', 'heal', {}, actions.heal, true, false, BOTH },
    { 'feed', 'heal', {}, actions.feed, true, false, BOTH },
    { 'message', 'message', { TEXT }, actions.message, false, false, BOTH },
    { 'warn', 'warn', { TEXT }, actions.warn, false, true, BOTH },
    { 'kick', 'kick', { TEXT }, actions.kick, false, true, BOTH },
    { 'ban', 'ban', { HOURS, TEXT }, actions.ban, false, true, BOTH },
    { 'inventory', 'inventory', {}, actions.inventory, false, true, GAME },
    { 'inventoryView', 'inventory', {}, actions.inventoryView, true, true, WEB },
    { 'give', 'give', { ITEM, QUANTITY }, actions.give, true, false, BOTH },
    { 'spectate', 'spectate', {}, actions.spectate, false, true, GAME },
    -- l'écran des joueurs : tout le Conseil regarde tout le monde, sans règle de rang
    { 'watchScreen', 'watch', {}, actions.watchScreen, false, false, WEB },
}

for _, def in ipairs(PLAYER_ACTIONS) do
    local name, permission, extra, fn, allowSelf, protected, where = unpack(def)
    local args = { TARGET }
    for i, schema in ipairs(extra) do args[i + 1] = schema end
    define(name, permission, args, limits.action, where, function(actor, targetId, ...)
        local target, code = players.resolve(targetId)
        if not target then return false, code end
        if target.source == actor.source and not allowSelf then return false, 'self' end
        if protected and target.source ~= actor.source and not staff.outranks(actor, target.accountId) then
            return false, 'outranked'
        end
        local ok, result, details = fn(actor, target, ...)
        if not ok then return false, result end
        audit.record(actor, name, target, details)
        return true, result
    end)
end

--- Rang, droits et listes utiles à un panneau.
---@param actor vAvA.AdminActor
---@return table
local function sessionOf(actor)
    return {
        rank = { name = actor.rank.name, label = actor.rank.label, level = actor.rank.level },
        permissions = ranks.permissionsOf(actor.rank), ranks = ranks.list(),
        banDurations = ranks.banDurationsFor(actor.rank), pageSize = cfg.pageSize,
    }
end

-- Registre en jeu : sa session porte aussi le numéro du membre et les outils des modules.
define('open', 'view', {}, limits.read, GAME, function(actor)
    local session = sessionOf(actor)
    session.self, session.accountId, session.moduleTools = actor.source, actor.accountId, extensions.listFor(actor)
    return true, session
end)
define('session', 'view', {}, limits.read, WEB, function(actor) return true, sessionOf(actor) end)
define('players', 'view', {}, limits.read, BOTH, function() return true, players.list() end)
define('player', 'view', { TARGET }, limits.read, BOTH, function(actor, targetId)
    local target, code = players.resolve(targetId)
    if not target then return false, code end
    -- identifiants : panneau web seulement (il les affiche) ; jamais vers le jeu d'un membre
    return true, players.details(target, actor.web == true)
end)
define('reports', 'reports', {}, limits.read, BOTH, function() return true, reports.list() end)
define('reportClaim', 'reports', { REPORT_ID }, limits.action, BOTH, function(actor, id)
    local report = reports.get(id)
    local ok, code = reports.claim(actor, id)
    if ok then audit.record(actor, 'reportClaim', { accountId = report.accountId, label = report.author }, { signalement = id }) end
    return ok, code
end)
define('reportClose', 'reports', { REPORT_ID }, limits.action, BOTH, function(actor, id)
    local report = reports.get(id)
    local ok, code = reports.close(actor, id)
    if ok then audit.record(actor, 'reportClose', { accountId = report.accountId, label = report.author }, { signalement = id }) end
    return ok, code
end)
define('bans', 'bans', { PAGE }, limits.read, BOTH, function(_, page)
    local rows = bans.list(page, cfg.pageSize)
    if not rows then return false, 'db_error' end
    return true, rows
end)
define('unban', 'unban', { ACCOUNT }, limits.action, BOTH, function(actor, accountId)
    local revoked = bans.unban(actor, accountId)
    if not revoked then return false, 'db_error' end
    if revoked == 0 then return false, 'not_banned' end
    audit.record(actor, 'unban', { accountId = accountId, label = 'compte n° ' .. accountId }, nil)
    return true
end)
define('logs', 'logs', { PAGE }, limits.read, BOTH, function(_, page)
    local rows = store.logs(page, cfg.pageSize)
    if not rows then return false, 'db_error' end
    return true, rows
end)
define('staff', 'staff', {}, limits.read, BOTH, function() return true, staff.list() end)
define('staffSet', 'staff', { ACCOUNT, RANK }, limits.action, BOTH, function(actor, accountId, rankName)
    local ok, code = staff.set(actor, accountId, rankName ~= '' and rankName or nil)
    if not ok then return false, code end
    audit.record(actor, rankName ~= '' and 'staffGrant' or 'staffRevoke', { accountId = accountId, label = 'compte n° ' .. accountId },
        rankName ~= '' and { rang = rankName } or nil)
    return true
end)
define('announce', 'announce', { TEXT }, limits.action, BOTH, function(actor, text)
    -- seul envoi à tous les joueurs du module : c'est l'objet même d'une annonce
    TriggerClientEvent(EVENTS.ANNOUNCE, -1, { text = text, author = actor.rank.label })
    audit.record(actor, 'announce', nil, { message = text })
    return true
end)
-- outils du membre sur lui-même (aucune cible : la règle du rang ne s'y applique pas) ; l'invulnérabilité et le vol
-- libre sont tenus par le serveur (server/invulnerability.lua) avant d'être appliqués par le client
define('tool', 'tools', { TOOL, BOOL }, limits.action, GAME, function(actor, name, enabled)
    local ok, code = invulnerability.set(actor, name, enabled)
    if not ok then return false, code end
    audit.record(actor, 'tool', nil, { outil = name, actif = enabled and 'oui' or 'non' })
    return true
end)
-- couper un outil ne donne rien : permis sans le droit (rang abaissé ou révoqué, relecture S-3), sans journal ; rallumer
-- reste refusé
requests.tool.release = function(src, name, enabled)
    if enabled ~= false then return false, 'forbidden' end
    invulnerability.drop(src, name)
    return true
end
-- outil d'un module : le droit est celui que le module a déclaré ; le module revérifie chaque action
define('moduleTool', 'view', { MODULE_TOOL }, limits.read, GAME, function(actor, key)
    return extensions.check(actor, key)
end)
