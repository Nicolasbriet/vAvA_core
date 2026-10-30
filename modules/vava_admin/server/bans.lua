--[[
    vava_admin/server/bans.lua
    Rôle : bans par compte. Vérifiés à la connexion (hook core:player:connecting, avant toute création de données) :
           le joueur voit le motif, la fin et le numéro du ban. Vérifiés une seconde fois à l'arrivée en jeu (hook
           core:player:joined, compte alors toujours connu) : un compte banni pendant son chargement, ou à sa toute
           première venue, est expulsé. Au démarrage du module (redémarrage compris), chaque joueur déjà en jeu est
           relu de la même façon : rien n'échappe aux bans pendant que le module était absent. Base qui ne répond pas :
           la connexion est refusée avec un message clair ; à l'arrivée, seconde lecture puis `banRecheck.onError`.
           Table des bans illisible au démarrage : le module échoue (le core garde alors la porte fermée).
           Prononcer, lever, lister.
    Dépendances : config.lua, server/core.lua, server/ranks.lua, server/store.lua, server/audit.lua
]]

local tostring, tonumber, ipairs = tostring, tonumber, ipairs
local CreateThread, DropPlayer, Wait, GetPlayers = CreateThread, DropPlayer, Wait, GetPlayers
local DoesPlayerExist = DoesPlayerExist

local store = VavaAdmin.store
local cfg = VavaAdmin.config
local messages = cfg.messages
local recheckCfg = cfg.banRecheck

-- compte inexistant (les numéros commencent à 1) : lecture d'essai de la table des bans au démarrage
local PROBE_ACCOUNT = 0

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

--- Le joueur est-il toujours ce compte ? (parti entre-temps, ou numéro repris par un autre compte : non)
---@param src integer
---@param accountId integer
---@return boolean
local function stillThere(src, accountId)
    local info = VavaAdmin.core.players.get(src)
    return info ~= nil and info.accountId == accountId
end

--- Relit les bans d'un joueur en jeu et l'expulse s'il est banni. Base muette : seconde lecture après
--- `banRecheck.retryMs`, puis `banRecheck.onError` (keep, défaut : gardé, noté à la console ; kick : expulsé). Bloque
--- le thread courant.
---@param src integer
---@param accountId integer
---@param when string  moment, pour la console (« à son arrivée », « au démarrage du Registre »)
function bans.verify(src, accountId, when)
    local ban, err = store.activeBan(accountId)
    if err then
        Wait(recheckCfg.retryMs)
        if not stillThere(src, accountId) then return end
        ban, err = store.activeBan(accountId)
    end
    local verdict = decide(accountId, ban, err)
    if verdict == 'allow' or not stillThere(src, accountId) then return end
    if verdict == 'unavailable' then
        -- console seulement : le journal du Conseil est dans la même base, qui ne répond pas
        if recheckCfg.onError == 'kick' then
            VavaAdmin.log.error('compte n° %d expulsé %s : bans illisibles (%s)', accountId, when, tostring(err))
            DropPlayer(tostring(src), messages.banCheckUnavailable)
            return
        end
        -- keep (défaut, décision du 30 octobre 2026) : la lecture de la connexion avait réussi ; on garde le joueur
        VavaAdmin.log.error('compte n° %d %s : bans illisibles, joueur gardé (%s)', accountId, when, tostring(err))
        return
    end
    VavaAdmin.log.warn('compte n° %d banni (ban n° %d) expulsé %s', accountId, ban.id, when)
    DropPlayer(tostring(src), message(ban))
    local actor = { accountId = nil, label = messages.console, rank = VavaAdmin.ranks.CONSOLE }
    local target = { source = src, accountId = accountId, label = 'compte n° ' .. accountId }
    VavaAdmin.audit.record(actor, messages.logBanEnforced, target, { ban = ban.id, moment = when })
end
local verify = bans.verify

--- Hook after d'arrivée en jeu : second contrôle, hors du fil du core (les autres abonnés n'attendent pas la base).
--- Le joueur est encore en sélection de personnage ; banni (ou bans illisibles), il est expulsé avec le motif.
---@param payload table  { source, accountId }
local function recheck(payload)
    local src, accountId = payload.source, payload.accountId
    if not src or not accountId then return end
    CreateThread(function() verify(src, accountId, messages.whenJoined) end)
end

--- Joueurs déjà en jeu au démarrage du module (redémarrage du Registre ou du core) : chacun relu, l'un après
--- l'autre. Un joueur que le core n'a pas encore repris (core redémarré, reprise en cours) est relu au tour suivant,
--- `banRecheck.sweepAttempts` fois au plus. Bloque le thread courant.
function bans.sweep()
    local pending = {}
    for _, id in ipairs(GetPlayers()) do pending[#pending + 1] = tonumber(id) end
    for attempt = 1, recheckCfg.sweepAttempts do
        local rest = {}
        for _, src in ipairs(pending) do
            local info = VavaAdmin.core.players.get(src)
            if info and info.accountId then
                verify(src, info.accountId, messages.whenSwept)
            elseif DoesPlayerExist(src) then
                rest[#rest + 1] = src
            end
        end
        pending = rest
        if #pending == 0 then return end
        if attempt < recheckCfg.sweepAttempts then Wait(recheckCfg.sweepRetryMs) end
    end
    VavaAdmin.log.warn('%d joueur(s) sans session du core au démarrage du Registre : bans non relus', #pending)
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

--- Lit la table des bans une fois (table absente, migration manquante : le module échoue), puis branche les deux
--- vérifications (connexion, arrivée en jeu). Appelé pendant le setup du module ; la relecture des joueurs déjà en
--- jeu (`bans.sweep`) part une fois le module prêt.
---@return boolean ok
---@return string|nil err
function bans.start()
    local _, probeErr = store.activeBan(PROBE_ACCOUNT)
    if probeErr then return false, 'table des bans illisible : ' .. tostring(probeErr) end
    local hooks = VavaAdmin.core.hooks
    local id, err = hooks.before('core:player:connecting', check)
    if not id then return false, err end
    id, err = hooks.after('core:player:joined', recheck)
    if not id then return false, err end
    return true
end
