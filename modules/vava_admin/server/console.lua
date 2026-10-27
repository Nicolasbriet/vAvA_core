--[[
    vava_admin/server/console.lua
    Rôle : commandes de la console serveur (amorçage et dépannage), refusées en jeu. Elles agissent au nom de la
           console, au-dessus de tous les rangs, et passent par le journal comme les autres :
      vava_conseil <compte> <rang|aucun>   nommer ou révoquer un membre du Conseil (le premier ne se nomme qu'ici) ;
      vava_ban <compte> <heures|0> <motif> bannir un compte (0 = définitif), connecté ou non ;
      vava_unban <compte>                  lever les bans d'un compte ;
      vava_kick <id> <motif>               expulser un joueur connecté.
    Dépendances : config.lua, server/core.lua, server/staff.lua, server/bans.lua, server/actions.lua, server/audit.lua
]]

local tonumber, tostring, pairs, concat = tonumber, tostring, pairs, table.concat
local math_type, tointeger = math.type, math.tointeger
local RegisterCommand, CreateThread = RegisterCommand, CreateThread

local staff = VavaAdmin.staff
local bans = VavaAdmin.bans
local actions = VavaAdmin.actions
local audit = VavaAdmin.audit
local players = VavaAdmin.players
local log = VavaAdmin.log

local REMOVE = 'aucun'
local CONSOLE_SOURCE = 0

local console = {}
VavaAdmin.console = console

---@param value string|nil
---@return integer|nil
local function integer(value)
    local number = tointeger(tonumber(value))
    return number and number > 0 and number or nil
end

---@param args string[]
---@param from integer
---@return string|nil
local function rest(args, from)
    local text = concat(args, ' ', from)
    return #text > 0 and text or nil
end

--- Compte connecté (numéro de session), s'il l'est.
---@param accountId integer
---@return integer|nil
local function sourceOf(accountId)
    return VavaAdmin.core.players.getByAccount(accountId)
end

local COMMANDS = {
    vava_conseil = function(args)
        local accountId, rankName = integer(args[1]), args[2]
        if not accountId or not rankName then return log.info('usage : vava_conseil <compte> <rang|%s>', REMOVE) end
        local actor = staff.console()
        local ok, code = staff.set(actor, accountId, rankName ~= REMOVE and rankName or nil)
        if not ok then return log.warn('Conseil : refusé (%s)', tostring(code)) end
        audit.record(actor, rankName ~= REMOVE and 'staffGrant' or 'staffRevoke', { accountId = accountId, label = 'compte n° ' .. accountId },
            rankName ~= REMOVE and { rang = rankName } or nil)
        log.info('compte n° %d : %s', accountId, rankName ~= REMOVE and rankName or 'révoqué')
    end,
    vava_ban = function(args)
        local accountId, hours, reason = integer(args[1]), tonumber(args[2]), rest(args, 3)
        if not accountId or not hours or math_type(hours) ~= 'integer' or hours < 0 or not reason then
            return log.info('usage : vava_ban <compte> <heures|0> <motif>')
        end
        local actor = staff.console()
        local src = sourceOf(accountId)
        local target = src and players.resolve(src) or { accountId = accountId, label = 'compte n° ' .. accountId }
        local ok, id, details = actions.banAccount(actor, accountId, target.label, hours, reason, src)
        if not ok then return log.warn('ban refusé (%s)', tostring(id)) end
        audit.record(actor, 'ban', target, details)
        log.info('ban n° %d prononcé contre le compte n° %d', id, accountId)
    end,
    vava_unban = function(args)
        local accountId = integer(args[1])
        if not accountId then return log.info('usage : vava_unban <compte>') end
        local actor = staff.console()
        local revoked = bans.unban(actor, accountId)
        if not revoked or revoked == 0 then return log.warn('aucun ban actif pour le compte n° %d', accountId) end
        audit.record(actor, 'unban', { accountId = accountId, label = 'compte n° ' .. accountId }, nil)
        log.info('bans du compte n° %d levés', accountId)
    end,
    vava_kick = function(args)
        local src, reason = integer(args[1]), rest(args, 2)
        if not src or not reason then return log.info('usage : vava_kick <id> <motif>') end
        local target = players.resolve(src)
        if not target then return log.warn('joueur %d introuvable', src) end
        local actor = staff.console()
        actions.kick(actor, target, reason)
        audit.record(actor, 'kick', target, { motif = reason })
        log.info('joueur %d expulsé', src)
    end,
}

--- Enregistre les commandes. Appelé pendant le setup du module.
function console.start()
    for name, handler in pairs(COMMANDS) do
        RegisterCommand(name, function(source, args)
            -- console uniquement : en jeu, la commande n'existe pas pour le joueur
            if source ~= CONSOLE_SOURCE then return end
            CreateThread(function() handler(args) end)
        end, true)
    end
end
