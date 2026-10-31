--[[
    vava_health/shared/chain.lua
    Rôle : règles pures de la chaîne de dégâts (docs/plan/COMBAT_V1.md § 1, spec T-110 § 5.2 et § 7.2) :
      - contrôle d'une entrée du registre vava_health:modifiers (clé `<ressource>:<nom>`, étape, priorité, libellé,
        types, fonction) ;
      - ordre d'appel : rang de l'étape, puis priorité (0 à 99, défaut 50), puis clé ; toujours une copie triée ;
      - pas d'un résultat : ce que rend un modificateur (cancel, blocked, absorbed, resisted, added), borné ;
      - déroulé de la chaîne avec un invocateur, une horloge et des rapports injectés (le serveur y met pcall,
        GetGameTimer et la console) : un modificateur en erreur est ignoré pour ce coup, un lent est signalé, une
        annulation arrête la chaîne ;
      - source à terre : passent un effet qui dure, un renvoi, et un coup lancé debout depuis peu (`launched`, 1.4.0).
      Les motifs n'emploient que des classes ASCII explicites (jamais %w, qui dépend de la locale). Aucun état.
    Dépendances : shared/constants.lua
]]

local type, ipairs, pairs, getmetatable = type, ipairs, pairs, getmetatable
local mathType, huge, min = math.type, math.huge, math.min
local find = string.find
local sort = table.sort

local chain = {}
VavaHealth.chain = chain

local KEY_PATTERN = '^[A-Za-z0-9_]+:[A-Za-z0-9_%-]+$'
local KEY_MAX = 64
local REASON_PATTERN = '^[A-Za-z0-9_]+$'
local REASON_MAX = 32
local LABEL_MAX = 48
local DEFAULT_PRIORITY = 50
local PRIORITY_MAX = 99
-- raison d'une annulation mal formée
local CANCELLED = 'cancelled'
-- champs numériques d'un rendu, dans l'ordre où ils s'appliquent
local AMOUNT_FIELDS = { 'blocked', 'absorbed', 'resisted' }

chain.DEFAULT_PRIORITY = DEFAULT_PRIORITY

-- rang de chaque étape (1 : annulation … 6 : resistance)
local RANK = {}
for i, stage in ipairs(VavaHealth.STAGES) do RANK[stage] = i end
chain.RANK = RANK

---@param value any
---@return boolean
local function isFinite(value)
    return type(value) == 'number' and value == value and value ~= huge and value ~= -huge
end

--- Fonction, ou référence de fonction d'une autre ressource (table appelable).
---@param value any
---@return boolean
local function isCallable(value)
    if type(value) == 'function' then return true end
    if type(value) ~= 'table' then return false end
    local mt = getmetatable(value)
    return type(mt) == 'table' and mt.__call ~= nil
end

--- Raison d'annulation sûre : identifiant ASCII de 32 octets au plus, sinon 'cancelled'.
---@param reason any
---@return string
function chain.reason(reason)
    if type(reason) == 'string' and #reason >= 1 and #reason <= REASON_MAX and find(reason, REASON_PATTERN) then
        return reason
    end
    return CANCELLED
end

--- Contrôle d'une entrée du registre (validateur) : vrai, ou faux et la raison.
---@param key any
---@param data any
---@param kinds table<string, true>  types de dégâts admis (ensemble)
---@return boolean ok
---@return string|nil reason
function chain.checkEntry(key, data, kinds)
    if type(key) ~= 'string' or #key > KEY_MAX or not find(key, KEY_PATTERN) then
        return false, 'clé attendue au motif <ressource>:<nom> (64 octets au plus)'
    end
    if type(data) ~= 'table' then return false, 'entrée attendue (table)' end
    if type(data.stage) ~= 'string' or not RANK[data.stage] then return false, 'étape inconnue' end
    local priority = data.priority
    if priority ~= nil and (mathType(priority) ~= 'integer' or priority < 0 or priority > PRIORITY_MAX) then
        return false, 'priorité attendue : entier de 0 à 99'
    end
    if type(data.label) ~= 'string' or #data.label < 1 or #data.label > LABEL_MAX then
        return false, 'libellé attendu : 1 à 48 octets'
    end
    if data.kinds ~= nil then
        local list = data.kinds
        if type(list) ~= 'table' then return false, 'types attendus : liste' end
        local count, seen = 0, {}
        for index, kind in pairs(list) do
            if mathType(index) ~= 'integer' then return false, 'types attendus : liste' end
            if type(kind) ~= 'string' or not kinds[kind] then return false, 'type de dégâts inconnu' end
            if seen[kind] then return false, 'type de dégâts en double' end
            seen[kind] = true
            count = count + 1
        end
        if count < 1 or count ~= #list then return false, 'types attendus : liste de 1 à 11 valeurs' end
        local known = 0
        for _ in pairs(kinds) do known = known + 1 end
        if count > known then return false, 'types attendus : liste de 1 à 11 valeurs' end
    end
    if not isCallable(data.apply) then return false, 'fonction apply attendue' end
    return true
end

--- Ordre d'appel : étape, priorité, clé.
---@param a table
---@param b table
---@return boolean
local function before(a, b)
    local ra, rb = RANK[a.stage], RANK[b.stage]
    if ra ~= rb then return ra < rb end
    local pa, pb = a.priority or DEFAULT_PRIORITY, b.priority or DEFAULT_PRIORITY
    if pa ~= pb then return pa < pb end
    return a.key < b.key
end

--- Copie triée d'une liste d'entrées `{ key, stage, priority?, … }` (la liste donnée n'est jamais touchée).
---@param entries table[]
---@return table[]
function chain.sort(entries)
    local out = {}
    for i, entry in ipairs(entries) do out[i] = entry end
    sort(out, before)
    return out
end

---@class vAvA.HealthChainState
---@field amount number      montant courant
---@field base number        montant de départ
---@field blocked number
---@field absorbed number
---@field resisted number
---@field added number
---@field cancelled string|nil
---@field stage string|nil   étape de l'annulation

--- État de départ d'un coup.
---@param amount number
---@return vAvA.HealthChainState
function chain.newState(amount)
    return { amount = amount, base = amount, blocked = 0, absorbed = 0, resisted = 0, added = 0 }
end

--- Applique le rendu d'un modificateur à l'état. `nil` ou `true` : rien. Annulation : montant à 0, raison et étape
--- notées (le reste du rendu est ignoré). Sinon blocked, absorbed, resisted (retirés, au plus le montant courant) puis
--- added (ajouté, au plus `base`, total au plus maxAmount). Un nombre non fini, négatif, ou un rendu d'un autre type :
--- tout le rendu est ignoré.
---@param state vAvA.HealthChainState
---@param result any
---@param stage string
---@param maxAmount number
---@return boolean applied
---@return string|nil code  invalid_result
function chain.step(state, result, stage, maxAmount)
    if result == nil or result == true then return true end
    if type(result) ~= 'table' then return false, 'invalid_result' end
    if result.cancel ~= nil and result.cancel ~= false then
        state.amount, state.cancelled, state.stage = 0, chain.reason(result.cancel), stage
        return true
    end
    for _, field in ipairs(AMOUNT_FIELDS) do
        local value = result[field]
        if value ~= nil and (not isFinite(value) or value < 0) then return false, 'invalid_result' end
    end
    local added = result.added
    if added ~= nil and (not isFinite(added) or added < 0) then return false, 'invalid_result' end

    for _, field in ipairs(AMOUNT_FIELDS) do
        local value = result[field]
        if value then
            local taken = min(value, state.amount)
            state.amount = state.amount - taken
            state[field] = state[field] + taken
        end
    end
    if added then
        local extra = min(added, state.base, maxAmount - state.amount)
        if extra > 0 then
            state.amount = state.amount + extra
            state.added = state.added + extra
        end
    end
    return true
end

---@class vAvA.HealthChainOptions
---@field maxAmount number
---@field slowMs number
---@field clock fun(): number                          horloge en ms
---@field invoke fun(entry: table, ctx: table): boolean, any   appel isolé : vrai et le rendu, ou faux et l'erreur
---@field onError? fun(entry: table, err: any)
---@field onSlow? fun(entry: table, ms: number)
---@field onInvalid? fun(entry: table, result: any)

--- Déroule la chaîne : chaque entrée (dans l'ordre de la liste) dont les types conviennent reçoit le contexte avec le
--- montant courant et son étape ; arrêt à la première annulation.
---@param list table[]   entrées triées `{ key, stage, kinds? (ensemble), apply }`
---@param ctx table      contexte du coup (amount et stage réécrits avant chaque appel)
---@param state vAvA.HealthChainState
---@param options vAvA.HealthChainOptions
---@return vAvA.HealthChainState
function chain.run(list, ctx, state, options)
    for _, entry in ipairs(list) do
        if state.cancelled then break end
        if not entry.kinds or entry.kinds[ctx.kind] then
            ctx.amount, ctx.stage = state.amount, entry.stage
            local started = options.clock()
            local ok, result = options.invoke(entry, ctx)
            local elapsed = options.clock() - started
            if elapsed > options.slowMs and options.onSlow then options.onSlow(entry, elapsed) end
            if not ok then
                if options.onError then options.onError(entry, result) end
            elseif not chain.step(state, result, entry.stage, options.maxAmount) and options.onInvalid then
                options.onInvalid(entry, result)
            end
        end
    end
    return state
end

--- Un coup venu d'une source à terre passe-t-il quand même ? Oui pour un effet qui dure (`overTime`), un renvoi
--- (`reflected`), et un coup déjà lancé (`launched`) alors que la source était debout : lancé (`launchedAt`) avant sa
--- mise à terre (`downedAt`, nil : inconnue, à terre depuis avant), et depuis au plus `maxMs` (projectile en vol,
--- présage d'un sort). Un coup lancé à terre, ou trop vieux, ne passe pas.
---@param tags table<string, true>
---@param launchedAt integer|nil   instant du lancement (horloge du serveur, ms)
---@param downedAt integer|nil     instant de la mise à terre de la source
---@param now integer
---@param maxMs integer
---@return boolean
function chain.passesDownedSource(tags, launchedAt, downedAt, now, maxMs)
    if tags.overTime or tags.reflected then return true end
    if not tags.launched or mathType(launchedAt) ~= 'integer' or mathType(downedAt) ~= 'integer' then return false end
    local age = now - launchedAt
    return age >= 0 and age <= maxMs and downedAt > launchedAt
end
