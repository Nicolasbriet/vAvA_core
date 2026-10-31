--[[
    vava_health/shared/packet.lua
    Rôle : règles pures du paquet de dégât (argument de l'export hit) : validation d'un paquet venu d'un module et copie
           normalisée, sans jamais lever d'erreur. Le paquet est fermé : toute clé inconnue est refusée (`origin` et
           `id` sont posés par le serveur, jamais fournis par l'appelant). Les motifs n'emploient que des classes ASCII
           explicites (jamais %w, qui dépend de la locale du système). Aucun état.
    Dépendances : shared/constants.lua
]]

local type, pairs, ipairs = type, pairs, ipairs
local tointeger, huge = math.tointeger, math.huge
local find = string.find

local packet = {}
VavaHealth.packet = packet

-- identifiant d'objet, de technique ou de sort (forme des identifiants du core, `<éditeur>:<id>` de l'Atelier compris)
local REF_PATTERN = '^[A-Za-z0-9_%-%.:]+$'
local REF_MAX = 64
local SOURCE_MAX = 65535
local CHARACTER_MAX = 2147483647

-- champs admis et leur contrôle
local FIELDS = {
    amount = true, kind = true, source = true, sourceCharacter = true, part = true, weapon = true, technique = true,
    spell = true, tags = true,
}

---@class vAvA.HealthPacketLimits
---@field maxAmount number
---@field kinds table<string, true>
---@field parts table<string, true>
---@field tags table<string, true>
---@field maxTags integer

--- Limites prêtes à l'emploi (listes de la config changées en ensembles), à calculer une fois.
---@param chainCfg table  config.chain
---@return vAvA.HealthPacketLimits
function packet.compile(chainCfg)
    local function set(list)
        local out = {}
        for _, value in ipairs(list) do out[value] = true end
        return out
    end
    return {
        maxAmount = chainCfg.maxAmount, kinds = set(chainCfg.kinds), parts = set(chainCfg.parts),
        tags = set(chainCfg.tags), maxTags = chainCfg.maxTags,
    }
end

---@param value any
---@return boolean
local function isFinite(value)
    return type(value) == 'number' and value == value and value ~= huge and value ~= -huge
end

--- Entier (ou flottant de valeur entière, `3.0`) entre low et high, rendu en entier ; sinon nil.
---@param value any
---@param low integer
---@param high integer
---@return integer|nil
local function integerIn(value, low, high)
    if not isFinite(value) then return nil end
    local int = tointeger(value)
    if not int or int < low or int > high then return nil end
    return int
end

---@param value any
---@return boolean
local function isRef(value)
    return type(value) == 'string' and #value >= 1 and #value <= REF_MAX and find(value, REF_PATTERN) ~= nil
end

--- Étiquettes : map étiquette connue → true, sans clé entière, au plus maxTags. Rend une copie ou nil.
---@param raw any
---@param limits vAvA.HealthPacketLimits
---@return table|nil
local function copyTags(raw, limits)
    if raw == nil then return {} end
    if type(raw) ~= 'table' then return nil end
    local out, count = {}, 0
    for key, value in pairs(raw) do
        if type(key) ~= 'string' or not limits.tags[key] or value ~= true then return nil end
        count = count + 1
        if count > limits.maxTags then return nil end
        out[key] = true
    end
    return out
end

--- Valide un paquet et en rend une copie normalisée (`tags` toujours présent, map éventuellement vide), ou nil et un
--- code : invalid_packet, unknown_field, invalid_amount, invalid_kind, invalid_source, invalid_part, invalid_ref,
--- invalid_tags.
---@param raw any
---@param limits vAvA.HealthPacketLimits
---@return table|nil copy
---@return string|nil code
function packet.normalize(raw, limits)
    if type(raw) ~= 'table' then return nil, 'invalid_packet' end
    for key in pairs(raw) do
        if type(key) ~= 'string' or not FIELDS[key] then return nil, 'unknown_field' end
    end

    local amount = raw.amount
    if not isFinite(amount) or amount <= 0 or amount > limits.maxAmount then return nil, 'invalid_amount' end
    local kind = raw.kind
    if type(kind) ~= 'string' or not limits.kinds[kind] then return nil, 'invalid_kind' end

    local copy = { amount = amount, kind = kind }
    if raw.source ~= nil then
        copy.source = integerIn(raw.source, 1, SOURCE_MAX)
        if not copy.source then return nil, 'invalid_source' end
    end
    if raw.sourceCharacter ~= nil then
        copy.sourceCharacter = integerIn(raw.sourceCharacter, 1, CHARACTER_MAX)
        if not copy.sourceCharacter then return nil, 'invalid_source' end
    end
    if raw.part ~= nil then
        if type(raw.part) ~= 'string' or not limits.parts[raw.part] then return nil, 'invalid_part' end
        copy.part = raw.part
    end
    for _, field in ipairs({ 'weapon', 'technique', 'spell' }) do
        local value = raw[field]
        if value ~= nil then
            if not isRef(value) then return nil, 'invalid_ref' end
            copy[field] = value
        end
    end
    local tags = copyTags(raw.tags, limits)
    if not tags then return nil, 'invalid_tags' end
    copy.tags = tags
    return copy
end
