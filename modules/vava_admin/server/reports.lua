--[[
    vava_admin/server/reports.lua
    Rôle : signalements et demandes au Conseil (/signaler, et depuis 1.10.0 la bannière de vava_pause par l'export
           submitRequest), gardés en mémoire jusqu'à leur clôture (leur suite est au journal). Chaque demande a une
           nature (question, signalement d'un joueur, bug, autre), éventuellement la position de son auteur lue par le
           serveur, et pour un signalement de joueur ses témoins (joueurs proches, même instance). Les membres du
           Conseil qui les traitent sont prévenus ; seul l'auteur est tenu au courant de la prise en charge et de la
           clôture ; rien ne part vers les témoins ni vers aucun autre joueur. Le hook vava_admin:report tient le
           panneau web à jour. La dernière demande close d'un compte est gardée un temps, pour son suivi.
    Dépendances : shared/constants.lua, config.lua, shared/requests.lua, server/core.lua, server/staff.lua
]]

local pairs, ipairs, type = pairs, ipairs, type
local ceil = math.ceil
local sort = table.sort
local GetGameTimer, TriggerClientEvent = GetGameTimer, TriggerClientEvent
local GetPlayerPed, GetEntityCoords, DoesEntityExist = GetPlayerPed, GetEntityCoords, DoesEntityExist

local staff = VavaAdmin.staff
local rules = VavaAdmin.requestRules
local cfg = VavaAdmin.config
local messages = cfg.messages
local EVENTS = VavaAdmin.EVENTS
local HOOK_REPORT = VavaAdmin.HOOKS.REPORT
local PLAYER_KIND = 'player'
local DEFAULT_KIND = 'other'

local reports = {}
VavaAdmin.reports = reports

---@class vAvA.AdminReport
---@field id integer
---@field source integer|nil
---@field accountId integer
---@field author string
---@field message string
---@field at integer
---@field kind string                                  1.10.0 : question | player | bug | other
---@field position { x: integer, y: integer, z: integer }|nil
---@field witnesses { accountId: integer, name: string }[]
---@field claimedBy string|nil

---@type table<integer, vAvA.AdminReport>
local open = {}
local count = 0
local nextId = 0
---@type table<integer, integer>  compte → dernier signalement
local lastByAccount = {}
---@type table<integer, { id: integer, kind: string, at: integer }>  compte → dernière demande close (1.10.0)
local closedByAccount = {}

--- Prévient les abonnés (panneau web) qu'un signalement est né, pris en charge ou clos.
local function publish(action, report)
    VavaAdmin.core.hooks.runAfter(HOOK_REPORT, { action = action, id = report.id, author = report.author, kind = report.kind })
end

local function tell(src, text, kind)
    if src then TriggerClientEvent(EVENTS.NOTIFY, src, { text = text, kind = kind }) end
end

--- Réglages des demandes (1.10.0), ou nil si config.lua est d'avant 1.10.0 (gardé par une mise à jour).
---@return table|nil
local function settings()
    local value = cfg.requests
    return type(value) == 'table' and value or nil
end

--- Libellé d'une nature (tampon du Registre, alerte), ou la nature elle-même.
---@param kind string
---@return string
local function kindLabel(kind)
    local labels = messages.requestKinds
    return type(labels) == 'table' and labels[kind] or kind
end

--- Position de l'auteur lue par le serveur, arrondie au mètre, ou nil (ped introuvable).
---@param src integer
---@return table|nil
local function positionOf(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return rules.roundPosition(GetEntityCoords(ped))
end

--- Numéro de compte et nom du personnage d'un joueur en jeu.
---@param src integer
---@return integer|nil accountId
---@return string|nil name
local function identify(src)
    local session = VavaAdmin.core.players.get(src)
    if not session or not session.accountId then return nil end
    return session.accountId, staff.characterName(src)
end

--- Témoins d'un signalement de joueur : joueurs proches de la position, même instance, auteur exclu (core.net,
--- positions lues par le serveur) ; sans core.net : aucun.
---@param src integer
---@param position table
---@param options table  cfg.requests
---@return table[]
local function witnessesOf(src, position, options)
    local net = VavaAdmin.core.net
    if type(net) ~= 'table' or type(net.playersNear) ~= 'function' then return {} end
    local near = net.playersNear(position, options.witnessRadius, { from = src })
    return rules.witnesses(near, src, options.maxWitnesses, identify)
end

--- Nouvelle demande d'un joueur : RPC /signaler (ouvert à tous, débit limité, nature `other`) ou export submitRequest
--- (bannière, 1.10.0). `options.kind` (défaut `other`), `options.position` (joindre la position lue par le serveur ;
--- toujours jointe pour un signalement de joueur), `options.quiet` (aucune notification à l'auteur : la bannière
--- affiche elle-même la réponse). Rend `true, n°` ou `false, code[, secondes restantes]` : no_session, too_soon,
--- too_many (demandes ouvertes du compte, 1.10.0), full.
---@param src integer
---@param text string
---@param options? { kind?: string, position?: boolean, quiet?: boolean }
---@return boolean ok
---@return integer|string idOrCode
---@return integer|nil seconds
function reports.create(src, text, options)
    options = options or {}
    local quiet = options.quiet == true
    local kind = options.kind or DEFAULT_KIND
    local session = VavaAdmin.core.players.get(src)
    if not session or not session.accountId then return false, 'no_session' end
    local accountId = session.accountId
    local now = GetGameTimer()
    local last = lastByAccount[accountId]
    if last and now - last < cfg.reportCooldownMs then
        if not quiet then tell(src, messages.reportTooSoon, 'warning') end
        return false, 'too_soon', ceil((cfg.reportCooldownMs - (now - last)) / 1000)
    end
    local requests = settings()
    if requests and rules.openCount(open, accountId) >= requests.maxOpenPerAccount then
        if not quiet and messages.reportTooMany then tell(src, messages.reportTooMany, 'warning') end
        return false, 'too_many'
    end
    if count >= cfg.maxOpenReports then return false, 'full' end
    local position, witnesses = nil, {}
    if requests and (options.position == true or kind == PLAYER_KIND) then
        position = positionOf(src)
        if position and kind == PLAYER_KIND then witnesses = witnessesOf(src, position, requests) end
    end
    lastByAccount[accountId] = now
    nextId = nextId + 1
    count = count + 1
    local author = staff.characterName(src) or ('compte n° ' .. accountId)
    local report = {
        id = nextId, source = src, accountId = accountId, author = author, message = text, at = now, kind = kind,
        position = position, witnesses = witnesses,
    }
    open[nextId] = report
    VavaAdmin.log.info('demande n° %d (%s) du compte n° %d', nextId, kind, accountId)
    if not quiet then tell(src, messages.reportSent, 'info') end
    local alertText = messages.requestNew and messages.requestNew:format(kindLabel(kind), nextId, author)
        or messages.reportNew:format(nextId, author)
    local alert = { id = nextId, text = alertText }
    for _, member in ipairs(staff.onlineWith('reports')) do TriggerClientEvent(EVENTS.REPORT, member, alert) end
    publish('created', report)
    return true, nextId
end

--- Signalements ouverts, les plus récents d'abord : { id, source, accountId, author, message, ageMs, claimedBy, kind,
--- position, witnesses }.
---@return table[]
function reports.list()
    local now = GetGameTimer()
    local out = {}
    for _, report in pairs(open) do
        out[#out + 1] = {
            id = report.id, source = report.source, accountId = report.accountId, author = report.author,
            message = report.message, ageMs = now - report.at, claimedBy = report.claimedBy, kind = report.kind,
            position = report.position, witnesses = report.witnesses,
        }
    end
    sort(out, function(a, b) return a.id > b.id end)
    return out
end

---@param id integer
---@return vAvA.AdminReport|nil
function reports.get(id)
    return open[id]
end

--- État de la demande d'un compte pour la bannière (1.10.0) : { id, kind, state, age } ou nil.
---@param accountId integer
---@return table|nil
function reports.statusOf(accountId)
    local requests = settings()
    local memoryMs = requests and requests.closedMemoryMs or 0
    return rules.statusOf(open, closedByAccount[accountId], accountId, GetGameTimer(), memoryMs)
end

--- Prise en charge par un membre.
---@return boolean ok
---@return string|nil code
function reports.claim(actor, id)
    local report = open[id]
    if not report then return false, 'not_found' end
    report.claimedBy = actor.label
    tell(report.source, messages.reportClaimed, 'info')
    publish('claimed', report)
    return true
end

---@return boolean ok
---@return string|nil code
function reports.close(_, id)
    local report = open[id]
    if not report then return false, 'not_found' end
    open[id] = nil
    count = count - 1
    closedByAccount[report.accountId] = { id = report.id, kind = report.kind, at = GetGameTimer() }
    tell(report.source, messages.reportClosed, 'info')
    publish('closed', report)
    return true
end

--- Le joueur parti, son numéro de session ne le désigne plus (le signalement reste, lié à son compte). Les demandes
--- closes trop anciennes pour son suivi sont oubliées au passage.
---@param src integer
function reports.forget(src)
    for _, report in pairs(open) do
        if report.source == src then report.source = nil end
    end
    local requests = settings()
    local memoryMs = requests and requests.closedMemoryMs or 0
    local now = GetGameTimer()
    for accountId, closed in pairs(closedByAccount) do
        if now - closed.at >= memoryMs then closedByAccount[accountId] = nil end
    end
end
