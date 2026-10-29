--[[
    vava_admin/server/web.lua
    Rôle : entrée de la Chancellerie (panneau web) dans le Registre, par sa seule ressource-pont (config.web.bridge) :
           un compte du panneau agit comme un membre du Conseil du rang que lui a donné le compte maître, sans
           personnage dans le monde. Mêmes demandes (celles qui ont un sens au web), mêmes droits, mêmes contrôles de
           cible et de rang, même journal (« Chancellerie : <compte> »). Les arguments sont revalidés ici avec le
           schéma de la demande : ce qui arrive du web n'est jamais tenu pour sûr.
    Dépendances : shared/constants.lua, config.lua, server/core.lua, server/ranks.lua, server/staff.lua,
                  server/audit.lua, server/requests.lua
]]

local type, ipairs, tostring, pcall, mathType, tointeger = type, ipairs, tostring, pcall, math.type, math.tointeger
local unpack, huge = table.unpack, math.huge
local GetInvokingResource = GetInvokingResource

local ranks = VavaAdmin.ranks
local staff = VavaAdmin.staff
local audit = VavaAdmin.audit
local requests = VavaAdmin.requests
local cfg = VavaAdmin.config.web
local WEB = 'web'
local LABEL_MAX = 40
local MAX_ARGS = 8

---@param value any
---@param schema table
---@return boolean ok
---@return any value  valeur normalisée (entier venu en nombre à virgule)
local function check(value, schema)
    local kind = schema.type
    if kind == 'boolean' then return type(value) == 'boolean', value end
    if kind == 'integer' then
        if mathType(value) == 'float' then value = tointeger(value) end
        if mathType(value) ~= 'integer' then return false end
    elseif kind == 'number' then
        if type(value) ~= 'number' or value ~= value or value == huge or value == -huge then return false end
    elseif kind == 'string' then
        if type(value) ~= 'string' then return false end
        if schema.pattern and not value:find(schema.pattern) then return false end
        if (schema.min and #value < schema.min) or (schema.max and #value > schema.max) then return false end
    else
        return false
    end
    if kind ~= 'string' and ((schema.min and value < schema.min) or (schema.max and value > schema.max)) then return false end
    if schema.enum then
        local found = false
        for _, allowed in ipairs(schema.enum) do
            if allowed == value then found = true end
        end
        if not found then return false end
    end
    return true, value
end

---@param args any
---@param schemas table[]
---@return table|nil
local function validate(args, schemas)
    if args == nil then args = {} end
    if type(args) ~= 'table' or #args > MAX_ARGS or #args ~= #schemas then return nil end
    local out = {}
    for i, schema in ipairs(schemas) do
        local ok, value = check(args[i], schema)
        if not ok then return nil end
        out[i] = value
    end
    return out
end

--- Appel venu de la ressource-pont ?
---@return boolean
local function fromBridge()
    return GetInvokingResource() == cfg.bridge
end

--- Acteur d'un compte du panneau : { label, rank } → membre du Conseil sans personnage, ou nil.
---@param spec any
---@return vAvA.AdminActor|nil
local function actorOf(spec)
    if type(spec) ~= 'table' or type(spec.label) ~= 'string' or #spec.label == 0 or #spec.label > LABEL_MAX then return nil end
    local rank = type(spec.rank) == 'string' and ranks.get(spec.rank)
    if not rank then return nil end
    return { source = nil, accountId = nil, rank = rank, label = cfg.actorLabel:format(spec.label), web = true }
end

--- Demande du panneau : (acteur, nom, arguments) → true, résultat | false, code.
exports('webRequest', function(spec, name, args)
    if not VavaAdmin.ready then return false, 'not_ready' end
    if not fromBridge() then return false, 'forbidden' end
    local actor = actorOf(spec)
    if not actor then return false, 'invalid_actor' end
    local request = type(name) == 'string' and requests[name]
    if not request or not VavaAdmin.requestAllowedIn(request, WEB) then return false, 'unknown_request' end
    if not staff.can(actor, request.permission) then return false, 'forbidden' end
    local values = validate(args, request.args)
    if not values then return false, 'invalid_args' end
    local called, ok, result = pcall(request.handler, actor, unpack(values, 1, #request.args))
    if not called then
        VavaAdmin.log.error('demande web %s en erreur : %s', name, tostring(ok))
        return false, 'server_error'
    end
    return ok, result
end)

--- Le rang d'un compte du panneau a-t-il ce droit ? (outils des autres modules faits depuis le web)
exports('webCan', function(spec, permission)
    if not VavaAdmin.ready or not fromBridge() then return false end
    local actor = actorOf(spec)
    return actor ~= nil and type(permission) == 'string' and staff.can(actor, permission)
end)

--- Rangs du Conseil, pour le panneau : liste { name, label, level }.
exports('webRanks', function()
    if not VavaAdmin.ready or not fromBridge() then return {} end
    return ranks.list()
end)

--- Rang d'un compte de jeu relié à un compte du panneau : celui du panneau s'applique en jeu ('' : aucun, révoqué).
--- `label` : le compte du panneau, nom de l'acteur au journal. Renvoie true et ce qui a changé, ou false et un code.
exports('webSyncStaff', function(accountId, rankName, label)
    if not VavaAdmin.ready then return false, 'not_ready' end
    if not fromBridge() then return false, 'forbidden' end
    if mathType(accountId) == 'float' then accountId = tointeger(accountId) end
    if mathType(accountId) ~= 'integer' or accountId < 1 or accountId > VavaAdmin.MAX_ID then return false, 'invalid_args' end
    if type(rankName) ~= 'string' or #rankName > 32 then return false, 'invalid_args' end
    if type(label) ~= 'string' or #label == 0 or #label > LABEL_MAX then return false, 'invalid_args' end
    local ok, changed = staff.force(accountId, rankName ~= '' and rankName or nil)
    if not ok then return false, changed end
    if changed then
        local actor = { source = nil, accountId = nil, rank = ranks.CONSOLE, label = cfg.actorLabel:format(label) }
        audit.record(actor, changed == 'granted' and 'staffGrant' or 'staffRevoke', { accountId = accountId, label = 'compte n° ' .. accountId },
            changed == 'granted' and { rang = rankName, origine = 'compte relié' } or { origine = 'compte relié' })
    end
    return true, changed
end)

--- Inscrit au journal une action d'un compte du panneau faite dans un autre module (zone de voix…).
exports('webLog', function(spec, label, details)
    if not VavaAdmin.ready then return false, 'not_ready' end
    if not fromBridge() then return false, 'forbidden' end
    local actor = actorOf(spec)
    if not actor then return false, 'invalid_actor' end
    local clean = audit.clean(label, details)
    if not clean then return false, 'invalid_args' end
    audit.record(actor, label, nil, clean)
    return true
end)
