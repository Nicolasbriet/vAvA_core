--[[
    vava_admin/server/rpc.lua
    Rôle : intentions du Registre en jeu, en RPC à schéma strict et à débit limité : chaque demande du catalogue qui
           a un sens en jeu devient une RPC réservée à son droit (le membre est retrouvé par son numéro de joueur, son
           rang relu à chaque appel). Le panneau n'affiche que ce que le rang permet, mais ce n'est qu'un confort.
           Plus deux intentions ouvertes à tous les joueurs : le signalement, et la fin d'une observation.
    Dépendances : shared/constants.lua, config.lua, server/core.lua, server/staff.lua, server/reports.lua,
                  server/spectate.lua, server/requests.lua
]]

local pairs = pairs

local staff = VavaAdmin.staff
local reports = VavaAdmin.reports
local spectate = VavaAdmin.spectate
local requests = VavaAdmin.requests
local limits = VavaAdmin.config.rateLimits
local PREFIX = VavaAdmin.PREFIX
local GAME = 'game'

local TEXT = { type = 'string', min = 1, max = VavaAdmin.MAX_TEXT }
local SESSION = { type = 'integer', min = 1, max = VavaAdmin.MAX_ID }   -- numéro d'une observation (server/spectate.lua)

local rpc = {}
VavaAdmin.rpc = rpc

---@param name string
---@param args table
---@param rateLimit table
---@param handler function
---@return boolean ok
---@return string|nil err
local function register(name, args, rateLimit, handler)
    return VavaAdmin.core.rpc.register(PREFIX .. name, { args = args, rateLimit = rateLimit }, handler)
end

--- Membre du Conseil ayant ce droit, ou nil.
---@param src integer
---@param permission string
---@return vAvA.AdminActor|nil
local function authorize(src, permission)
    local actor = staff.actorOf(src)
    if actor and staff.can(actor, permission) then return actor end
    return nil
end

--- Enregistre toutes les RPC. Appelé pendant le setup du module.
---@return boolean ok
---@return string|nil err
function rpc.start()
    for name, request in pairs(requests) do
        if VavaAdmin.requestAllowedIn(request, GAME) then
            local ok, err = register(name, request.args, request.limit, function(src, ...)
                local actor = authorize(src, request.permission)
                if not actor then return false, 'forbidden' end
                return request.handler(actor, ...)
            end)
            if not ok then return false, err end
        end
    end
    -- ouvert à tous les joueurs : fin de l'observation n° session (n'efface que la place gardée du personnage de
    -- l'appelant, et seulement pour sa dernière observation, même si son rang a changé entre-temps)
    local ok, err = register('spectateEnd', { SESSION }, limits.read, function(src, session) return spectate.finish(src, session) end)
    if not ok then return false, err end
    -- ouvert à tous les joueurs : /signaler (1.9.0 : demande de nature « autre », comme celles de la bannière)
    return register('report', { TEXT }, limits.report, function(src, text)
        return reports.create(src, text, { kind = 'other' })
    end)
end
