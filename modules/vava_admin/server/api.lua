--[[
    vava_admin/server/api.lua
    Rôle : exports serveur pour les autres modules (anti-triche, métiers, panneau web à venir) : savoir si un joueur
           siège au Conseil et avec quels droits, s'il est immobilisé par le Conseil, bannir ou expulser au nom d'un
           module (inscrit au journal), inscrire au journal une action faite par un membre dans un module ; depuis
           1.10.0, créer une demande au Conseil au nom d'un joueur et lire l'état de la sienne (bannière de vava_pause,
           seules les ressources de `requests.callers`) ; depuis 1.11.0, savoir si le Conseil le tient pour invulnérable.
    Dépendances : config.lua, server/core.lua, server/ranks.lua, server/staff.lua, server/players.lua,
                  server/actions.lua, server/audit.lua, server/reports.lua, server/invulnerability.lua
]]

local type, mathType, ipairs = type, math.type, ipairs
local GetInvokingResource, GetGameTimer = GetInvokingResource, GetGameTimer

local ranks = VavaAdmin.ranks
local staff = VavaAdmin.staff
local players = VavaAdmin.players
local actions = VavaAdmin.actions
local audit = VavaAdmin.audit
local reports = VavaAdmin.reports

local REFUSED_LOG_MS = 60000

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

--- Vrai si le Conseil tient ce joueur pour invulnérable (outil, vol libre, observation près de l'observé), même
--- jugement que le modificateur de la chaîne de vava_health (1.11.0). Lecture seule : pour qu'un module épargne aussi
--- ses effets sans dégâts (recul, renversement…) à un membre que la chaîne protège.
exports('isInvulnerable', function(src)
    if not VavaAdmin.ready or mathType(src) ~= 'integer' then return false end
    return VavaAdmin.invulnerability.isInvulnerable(src)
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

-- Demandes au Conseil (1.10.0, T-145) ---------------------------------------------------------------------------------

local lastRefusedAt = {}   -- ressource refusée → GetGameTimer() de sa dernière ligne de console

--- Vrai si la ressource appelante peut créer ou lire des demandes au nom d'un joueur (`requests.callers`) ; sinon une
--- ligne de console par minute et par ressource.
---@return boolean
local function trustedCaller()
    local caller = GetInvokingResource() or VavaAdmin.resource
    local requests = VavaAdmin.config.requests
    if type(requests) == 'table' and type(requests.callers) == 'table' then
        for _, name in ipairs(requests.callers) do
            if name == caller then return true end
        end
    end
    local now = GetGameTimer()
    if not lastRefusedAt[caller] or now - lastRefusedAt[caller] >= REFUSED_LOG_MS then
        lastRefusedAt[caller] = now
        VavaAdmin.log.warn('demande au Conseil refusée : la ressource %s n\'est pas dans requests.callers', caller)
    end
    return false
end

---@param kind any
---@return boolean
local function isKind(kind)
    local requests = VavaAdmin.config.requests
    if type(kind) ~= 'string' or type(requests) ~= 'table' or type(requests.kinds) ~= 'table' then return false end
    for _, name in ipairs(requests.kinds) do
        if name == kind then return true end
    end
    return false
end

--- Demande au Conseil au nom d'un joueur (bannière de vava_pause) : réservé aux ressources de `requests.callers`. Le
--- texte est déjà normalisé par l'appelant (500 octets au plus) ; la position, si demandée, est lue ici par le serveur.
--- Aucune notification au joueur : l'appelant affiche la réponse. Rend `true, { id, kind, state = 'sent', age = 0 }`
--- ou `false, code[, secondes]` : not_ready, not_allowed, invalid_kind, invalid_args, no_session, too_soon (+ secondes
--- restantes), too_many, full.
exports('submitRequest', function(src, kind, text, withPosition)
    if not VavaAdmin.ready then return false, 'not_ready' end
    if not trustedCaller() then return false, 'not_allowed' end
    if not isKind(kind) then return false, 'invalid_kind' end
    if mathType(src) ~= 'integer' or src <= 0 or not isText(text) or type(withPosition) ~= 'boolean' then
        return false, 'invalid_args'
    end
    local ok, id, seconds = reports.create(src, text, { kind = kind, position = withPosition, quiet = true })
    if not ok then return false, id, seconds end
    return true, { id = id, kind = kind, state = 'sent', age = 0 }
end)

--- État de la demande du compte d'un joueur : la plus récente ouverte (`sent` ou `claimed`), sinon la dernière close
--- depuis moins de `requests.closedMemoryMs` (`closed`) : { id, kind, state, age (secondes) }, ou nil. Réservé aux
--- ressources de `requests.callers`.
exports('requestOf', function(src)
    if not VavaAdmin.ready or not trustedCaller() or mathType(src) ~= 'integer' then return nil end
    local session = VavaAdmin.core.players.get(src)
    if not session or not session.accountId then return nil end
    return reports.statusOf(session.accountId)
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
