--[[
    vava_admin/server/reports.lua
    Rôle : signalements des joueurs (/signaler), gardés en mémoire jusqu'à leur clôture (leur suite est au journal).
           Les membres du Conseil qui les traitent sont prévenus ; le joueur est tenu au courant de la prise en charge
           et de la clôture ; le hook vava_admin:report tient le panneau web à jour.
    Dépendances : shared/constants.lua, config.lua, server/core.lua, server/staff.lua
]]

local pairs, ipairs = pairs, ipairs
local sort = table.sort
local GetGameTimer, TriggerClientEvent = GetGameTimer, TriggerClientEvent

local staff = VavaAdmin.staff
local cfg = VavaAdmin.config
local messages = cfg.messages
local EVENTS = VavaAdmin.EVENTS
local HOOK_REPORT = VavaAdmin.HOOKS.REPORT

local reports = {}
VavaAdmin.reports = reports

---@class vAvA.AdminReport
---@field id integer
---@field source integer
---@field accountId integer
---@field author string
---@field message string
---@field at integer
---@field claimedBy string|nil

---@type table<integer, vAvA.AdminReport>
local open = {}
local count = 0
local nextId = 0
---@type table<integer, integer>  compte → dernier signalement
local lastByAccount = {}

---@param src integer|nil  nil : le joueur est parti
---@param text string
---@param kind string
--- Prévient les abonnés (panneau web) qu'un signalement est né, pris en charge ou clos.
local function publish(action, report)
    VavaAdmin.core.hooks.runAfter(HOOK_REPORT, { action = action, id = report.id, author = report.author })
end

local function tell(src, text, kind)
    if src then TriggerClientEvent(EVENTS.NOTIFY, src, { text = text, kind = kind }) end
end

--- Nouveau signalement d'un joueur (RPC ouvert à tous, débit limité).
---@param src integer
---@param text string
---@return boolean ok
---@return string|nil code
function reports.create(src, text)
    local session = VavaAdmin.core.players.get(src)
    if not session or not session.accountId then return false, 'no_session' end
    local now = GetGameTimer()
    local last = lastByAccount[session.accountId]
    if last and now - last < cfg.reportCooldownMs then
        tell(src, messages.reportTooSoon, 'warning')
        return false, 'too_soon'
    end
    if count >= cfg.maxOpenReports then return false, 'full' end
    lastByAccount[session.accountId] = now
    nextId = nextId + 1
    count = count + 1
    local author = staff.characterName(src) or ('compte n° ' .. session.accountId)
    open[nextId] = { id = nextId, source = src, accountId = session.accountId, author = author, message = text, at = now }
    tell(src, messages.reportSent, 'info')
    local alert = { id = nextId, text = messages.reportNew:format(nextId, author) }
    for _, member in ipairs(staff.onlineWith('reports')) do TriggerClientEvent(EVENTS.REPORT, member, alert) end
    publish('created', open[nextId])
    return true, nextId
end

--- Signalements ouverts, les plus récents d'abord : { id, source, accountId, author, message, ageMs, claimedBy }.
---@return table[]
function reports.list()
    local now = GetGameTimer()
    local out = {}
    for _, report in pairs(open) do
        out[#out + 1] = {
            id = report.id, source = report.source, accountId = report.accountId, author = report.author,
            message = report.message, ageMs = now - report.at, claimedBy = report.claimedBy,
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
function reports.close(actor, id)
    local report = open[id]
    if not report then return false, 'not_found' end
    open[id] = nil
    count = count - 1
    tell(report.source, messages.reportClosed, 'info')
    publish('closed', report)
    return true
end

--- Le joueur parti, son numéro de session ne le désigne plus (le signalement reste, lié à son compte).
---@param src integer
function reports.forget(src)
    for _, report in pairs(open) do
        if report.source == src then report.source = nil end
    end
end
