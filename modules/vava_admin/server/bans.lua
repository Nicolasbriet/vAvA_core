--[[
    vava_admin/server/bans.lua
    Rôle : bans par compte. Vérifiés à la connexion (hook core:player:connecting, avant toute création de données) :
           le joueur voit le motif, la fin et le numéro du ban. Prononcer, lever, lister.
    Dépendances : config.lua, server/core.lua, server/store.lua
]]

local tostring = tostring

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

--- Hook before de connexion : refuse un compte banni.
---@param payload table  { source, license, name, accountId? }
local function check(payload)
    if not payload.accountId then return end
    local ban, err = store.activeBan(payload.accountId)
    if err then
        -- la connexion échouera de toute façon au chargement du compte si la base est indisponible
        VavaAdmin.log.error('vérification de ban impossible pour le compte n° %d : %s', payload.accountId, tostring(err))
        return
    end
    if ban then return false, message(ban) end
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

--- Branche la vérification à la connexion. Appelé pendant le setup du module.
---@return boolean ok
---@return string|nil err
function bans.start()
    local id, err = VavaAdmin.core.hooks.before('core:player:connecting', check)
    if not id then return false, err end
    return true
end
