--[[
    server/core/ratelimit.lua
    Rôle : limitation de débit par joueur et par clé (token bucket à recharge calculée à l'accès : aucune boucle).
    Les clés sont choisies par le serveur (noms de RPC enregistrés), jamais par le client : la mémoire ne peut
    pas grossir au gré d'un attaquant. Tout l'état d'un joueur est supprimé à sa déconnexion.
    Dépendances : config/server.lua, shared/core/logger.lua, shared/core/hooks.lua
]]

local type, pairs = type, pairs
local mathType = math.type
local format = string.format
local GetGameTimer = GetGameTimer

local logger = vAvA.logger
local hooks = vAvA.hooks
local cfg = vAvA.config.server.rateLimit
local log = logger.create('ratelimit')

local HOOK_EXCEEDED = 'core:ratelimit:exceeded'

local ratelimit = {}
vAvA.ratelimit = ratelimit

---@class vAvA.RateRule
---@field capacity integer         rafale maximale
---@field refillPerSecond number   jetons rendus par seconde

---@class vAvA.NormalizedRateRule
---@field capacity integer
---@field refillPerMs number

---@class vAvA.RateBucket
---@field tokens number
---@field updatedAt integer

---@type table<integer, table<string, vAvA.RateBucket>>
local players = {}

--- Valide une règle et la convertit dans sa forme interne (division faite une fois, pas à chaque appel).
---@param rule any
---@return vAvA.NormalizedRateRule|nil
---@return string|nil err
function ratelimit.normalizeRule(rule)
    if type(rule) ~= 'table' then
        return nil, 'règle de rate limit invalide (table { capacity, refillPerSecond } attendue)'
    end
    local bounds = cfg.bounds
    local capacity, refill = rule.capacity, rule.refillPerSecond
    if mathType(capacity) ~= 'integer' or capacity < bounds.minCapacity or capacity > bounds.maxCapacity then
        return nil, format('capacity doit être un entier de %d à %d', bounds.minCapacity, bounds.maxCapacity)
    end
    if type(refill) ~= 'number' or refill ~= refill or refill < bounds.minRefillPerSecond or refill > bounds.maxRefillPerSecond then
        return nil, format('refillPerSecond doit être compris entre %s et %s', bounds.minRefillPerSecond, bounds.maxRefillPerSecond)
    end
    return { capacity = capacity, refillPerMs = refill / 1000 }
end

--- Consomme un jeton. En cas de dépassement : log et hook core:ratelimit:exceeded, limités à un par intervalle
--- et par (joueur, clé) pour qu'un flood ne se transforme pas en flood de la console.
---@param source integer
---@param key string   clé contrôlée par le serveur
---@param rule vAvA.NormalizedRateRule
---@return boolean allowed
function ratelimit.consume(source, key, rule)
    local buckets = players[source]
    if not buckets then
        buckets = {}
        players[source] = buckets
    end

    local now = GetGameTimer()
    local bucket = buckets[key]
    if not bucket then
        bucket = { tokens = rule.capacity, updatedAt = now }
        buckets[key] = bucket
    else
        local elapsed = now - bucket.updatedAt
        if elapsed > 0 then
            local tokens = bucket.tokens + elapsed * rule.refillPerMs
            bucket.tokens = tokens < rule.capacity and tokens or rule.capacity
            bucket.updatedAt = now
        end
    end

    if bucket.tokens >= 1 then
        bucket.tokens = bucket.tokens - 1
        return true
    end

    local allowed, suppressed = logger.throttle(bucket)
    if allowed then
        log.warn('joueur %d : limite dépassée sur %s%s', source, key, logger.suppressedNote(suppressed))
        hooks.runAfter(HOOK_EXCEEDED, { source = source, key = key, suppressed = suppressed })
    end
    return false
end

--- Supprime tout l'état d'un joueur (déconnexion).
---@param source integer
function ratelimit.purgePlayer(source)
    players[source] = nil
end

--- Supprime une clé pour tous les joueurs (RPC désenregistré).
---@param key string
function ratelimit.purgeKey(key)
    for _, buckets in pairs(players) do
        buckets[key] = nil
    end
end
