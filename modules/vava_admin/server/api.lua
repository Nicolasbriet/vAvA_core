--[[
    vava_admin/server/api.lua
    Rôle : exports serveur pour les autres modules (anti-triche, métiers, panneau web à venir) : savoir si un joueur
           siège au Conseil et avec quels droits, s'il est immobilisé par le Conseil, bannir ou expulser au nom d'un
           module (inscrit au journal), inscrire au journal une action faite par un membre dans un module.
    Dépendances : config.lua, server/core.lua, server/ranks.lua, server/staff.lua, server/players.lua,
                  server/actions.lua, server/audit.lua
]]

local type, mathType = type, math.type
local GetInvokingResource = GetInvokingResource

local ranks = VavaAdmin.ranks
local staff = VavaAdmin.staff
local players = VavaAdmin.players
local actions = VavaAdmin.actions
local audit = VavaAdmin.audit

---@param text any
---@return boolean
local function isText(text)
    return type(text) == 'string' and #text > 0 and #text <= VavaAdmin.MAX_TEXT
end

--- Acteur d'un module : au journal sous son nom, avec les droits de la console (code serveur de confiance).
---@return vAvA.AdminActor
local function moduleActor()
    return { source = nil, accountId = nil, rank = ranks.CONSOLE, label = 'module ' .. (GetInvokingResource() or VavaAdmin.resource) }
end

exports('isStaff', function(src)
    return VavaAdmin.ready and staff.actorOf(src) ~= nil
end)

exports('can', function(src, permission)
    local actor = VavaAdmin.ready and staff.actorOf(src)
    return actor ~= nil and actor ~= false and staff.can(actor, permission)
end)

--- Rang d'un joueur : { name, label, level }, ou nil.
exports('rankOf', function(src)
    local actor = VavaAdmin.ready and staff.actorOf(src)
    if not actor then return nil end
    return { name = actor.rank.name, label = actor.rank.label, level = actor.rank.level }
end)

--- Vrai si le Conseil a immobilisé ce joueur (Registre → Immobiliser). Lecture seule : un module qui fige et libère
--- un ped (gel d'un sort…) ne rend pas libre celui que le Conseil retient.
exports('isFrozen', function(src)
    return players.frozen[src] == true
end)

--- Bannit un compte (0 heure = définitif). Un joueur connecté sur ce compte est expulsé.
exports('ban', function(accountId, hours, reason)
    if not VavaAdmin.ready then return false, 'not_ready' end
    if mathType(accountId) ~= 'integer' or mathType(hours) ~= 'integer' or hours < 0 or not isText(reason) then
        return false, 'invalid_args'
    end
    local actor = moduleActor()
    local src = VavaAdmin.core.players.getByAccount(accountId)
    local target = src and players.resolve(src) or { accountId = accountId, label = 'compte n° ' .. accountId }
    local ok, id, details = actions.banAccount(actor, accountId, target.label, hours, reason, src)
    if not ok then return false, id end
    audit.record(actor, 'ban', target, details)
    return true, id
end)

--- Inscrit au journal du Registre une action faite par un membre du Conseil dans un module (zone de voix créée…).
--- `label` : libellé lu tel quel dans le journal (32 caractères) ; `details` : { clé = texte ou nombre } (8 au plus).
exports('log', function(src, label, details)
    if not VavaAdmin.ready then return false, 'not_ready' end
    local actor = staff.actorOf(src)
    if not actor then return false, 'not_staff' end
    local clean = audit.clean(label, details)
    if not clean then return false, 'invalid_args' end
    audit.record(actor, label, nil, clean)
    return true
end)

exports('kick', function(src, reason)
    if not VavaAdmin.ready then return false, 'not_ready' end
    if not isText(reason) then return false, 'invalid_args' end
    local target, code = players.resolve(src)
    if not target then return false, code end
    local actor = moduleActor()
    actions.kick(actor, target, reason)
    audit.record(actor, 'kick', target, { motif = reason })
    return true
end)
