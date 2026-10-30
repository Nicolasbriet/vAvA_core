--[[
    vava_admin/server/bans.lua
    Rôle : bans par compte. Vérifiés à la connexion (hook core:player:connecting, avant toute création de données) :
           le joueur voit le motif, la fin et le numéro du ban. Vérifiés une seconde fois à l'arrivée en jeu (hook
           core:player:joined, compte alors toujours connu) : un compte banni pendant son chargement, ou à sa toute
           première venue, est expulsé. Base qui ne répond pas : la connexion est refusée avec un message clair, jamais
           accordée sans vérification. Prononcer, lever, lister.
    Dépendances : config.lua, server/core.lua, server/ranks.lua, server/store.lua, server/audit.lua
]]

local tostring = tostring
local CreateThread, DropPlayer = CreateThread, DropPlayer

local store = VavaAdmin.store
local messages = VavaAdmin.config.messages

local bans = {}
VavaAdmin.bans = bans

---@param ban table  { id, reason, until? }
---@return string
local function message(ban)
    local term = ban['until'] and messages.bannedUntil:format(ban['until']) or messages.bannedForever
    return messages.banned:format(ban.reason, term, ban.id)
end
bans.message = message

--- Verdict d'une vérification de ban (logique pure). Une base qui ne répond pas ne laisse jamais passer.
---@param accountId integer|nil  nil : première venue (aucun compte encore, donc aucun ban possible)
---@param ban table|nil          ban actif trouvé
---@param err any                erreur de la requête
---@return 'allow'|'banned'|'unavailable'
function bans.decide(accountId, ban, err)
    if not accountId then return 'allow' end
    if err then return 'unavailable' end
    if ban then return 'banned' end
    return 'allow'
end
local decide = bans.decide

--- Hook before de connexion : refuse un compte banni, ou tout compte connu quand les bans ne peuvent être lus.
---@param payload table  { source, license, name, accountId? }
local function check(payload)
    local accountId = payload.accountId
    if not accountId then return end
    local ban, err = store.activeBan(accountId)
    local verdict = decide(accountId, ban, err)
    if verdict == 'unavailable' then
        VavaAdmin.log.error('connexion du compte n° %d refusée : vérification de ban impossible (%s)',
            accountId, tostring(err))
        return false, messages.banCheckUnavailable
    end
    if verdict == 'banned' then return false, message(ban) end
end

--- Hook after d'arrivée en jeu : second contrôle, hors du fil du core (les autres abonnés n'attendent pas la base).
--- Le joueur est encore en sélection de personnage ; banni (ou bans illisibles), il est expulsé avec le motif.
---@param payload table  { source, accountId }
local function recheck(payload)
    local src, accountId = payload.source, payload.accountId
    if not src or not accountId then return end
    CreateThread(function()
        local ban, err = store.activeBan(accountId)
        local verdict = decide(accountId, ban, err)
        if verdict == 'allow' then return end
        -- parti entre-temps, ou numéro repris par un autre compte : rien à faire
        local info = VavaAdmin.core.players.get(src)
        if not info or info.accountId ~= accountId then return end
        if verdict == 'unavailable' then
            -- console seulement : le journal du Conseil est dans la même base, qui ne répond pas
            VavaAdmin.log.error('compte n° %d expulsé à son arrivée : vérification de ban impossible (%s)',
                accountId, tostring(err))
            DropPlayer(tostring(src), messages.banCheckUnavailable)
            return
        end
        VavaAdmin.log.warn('compte n° %d banni (ban n° %d) expulsé à son arrivée', accountId, ban.id)
        DropPlayer(tostring(src), message(ban))
        local actor = { accountId = nil, label = messages.console, rank = VavaAdmin.ranks.CONSOLE }
        local target = { source = src, accountId = accountId, label = 'compte n° ' .. accountId }
        VavaAdmin.audit.record(actor, messages.logBanEnforced, target, { ban = ban.id })
    end)
end

---@return integer|nil id
---@return string|nil err
function bans.ban(actor, accountId, targetLabel, hours, reason)
    return store.addBan(accountId, targetLabel, reason, actor.accountId, actor.label, hours)
end

---@return integer|nil revoked
---@return string|nil err
function bans.unban(actor, accountId)
    return store.revokeBans(accountId, actor.label)
end

function bans.active(accountId)
    return store.activeBan(accountId)
end

function bans.list(page, size)
    return store.activeBans(page, size)
end

--- Branche les deux vérifications (connexion, arrivée en jeu). Appelé pendant le setup du module.
---@return boolean ok
---@return string|nil err
function bans.start()
    local hooks = VavaAdmin.core.hooks
    local id, err = hooks.before('core:player:connecting', check)
    if not id then return false, err end
    id, err = hooks.after('core:player:joined', recheck)
    if not id then return false, err end
    return true
end
