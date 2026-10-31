--[[
    vava_health/server/chain.lua
    Rôle : la chaîne de dégâts commune (spec T-110 § 7.1) : tous les coups et les sorts passent par hits.hit. Dans
           l'ordre, sans céder la main entre la lecture de la vie et son écriture :
             1. module prêt, cible (personnage suivi ; aucune condition d'apparition) ;
             2. paquet validé et copié (shared/packet.lua) ; `origin` (ressource appelante), numéro et personnage de la
                source posés par le serveur ;
             3. garde-fous : type `monde` réservé à ce module, profondeur (renvois), débit par paire (cible, source) ;
             4. préconditions : cible à terre, combats entre joueurs coupés, source à terre hors `overTime` et
                `reflected` (résultat annulé, sans hook ni journal) ;
             5. hook vava_health:hit `before` (refus seul ; un abonné en erreur ne refuse pas : le coup passe) ;
             6. modificateurs du registre, dans l'ordre des étapes (shared/chain.lua), chacun isolé et chronométré ;
             7. application : cible relue, vie du serveur baissée, mise à terre aussitôt à 0 ;
             8. hook `after` (tout coup qui a atteint l'étape 5, annulé compris) et journal.
           Lignes de console limitées : modificateur en erreur (une par `chain.errorLogMs`), lent ou au rendu invalide
           (une par minute et par modificateur), coup lent, avalanche sur une cible (une par minute et par cible).
    Dépendances : shared/constants.lua, config.lua, shared/packet.lua, shared/chain.lua, server/core.lua,
                  server/journal.lua, server/life.lua, server/modifiers.lua
]]

local type, pairs, pcall, tostring = type, pairs, pcall, tostring
local mathType, min = math.type, math.min
local GetGameTimer = GetGameTimer

local cfg = VavaHealth.config.chain
local packet = VavaHealth.packet
local chain = VavaHealth.chain
local life = VavaHealth.life
local journal = VavaHealth.journal
local modifiers = VavaHealth.modifiers
local HOOK = VavaHealth.HOOKS.HIT
local LIMITS = packet.compile(cfg)
local HEALTH_POINTS = cfg.healthPoints
local WORLD_KIND = 'monde'
local WINDOW_MS = 1000
local LOG_MS = 60000
-- champs du paquet recopiés dans le contexte
local PACKET_FIELDS = { 'source', 'sourceCharacter', 'part', 'weapon', 'technique', 'spell' }

local hits = {}
VavaHealth.hits = hits

-- profondeur courante (un renvoi lancé par un hook after est un coup dans un coup)
local depth = 0
-- débit par paire (cible, source) : un joueur qui frappe une cible en rafale n'épuise pas le débit des autres ; les
-- coups sans source (le monde, la faim, une enveloppe damage) partagent la clé 0
---@type table<integer, table<integer, { count: integer, since: integer }>>
local rates = {}
local NO_SOURCE = 0
---@type table<string, integer>  clé de console → dernière ligne
local logged = {}

--- Ligne de console au plus une fois par intervalle et par clé.
---@param key string
---@param intervalMs integer
---@return boolean
local function due(key, intervalMs)
    local now = GetGameTimer()
    local last = logged[key]
    if last and now - last < intervalMs then return false end
    logged[key] = now
    return true
end

--- Débit par paire (cible, source) sur une seconde : vrai si le coup est admis.
---@param target integer
---@param source integer|nil
---@param now integer
---@return boolean
local function admit(target, source, now)
    local bySource = rates[target]
    if not bySource then
        bySource = {}
        rates[target] = bySource
    end
    local key = source or NO_SOURCE
    local rate = bySource[key]
    if not rate or now - rate.since >= WINDOW_MS then
        rate = { count = 0, since = now }
        bySource[key] = rate
    end
    rate.count = rate.count + 1
    return rate.count <= cfg.maxHitsPerSecond
end

--- Copie du contexte pour un modificateur (il ne reçoit jamais la table de la chaîne).
---@param ctx table
---@return table
local function copyContext(ctx)
    local out = {}
    for key, value in pairs(ctx) do out[key] = value end
    local tags = {}
    for tag in pairs(ctx.tags) do tags[tag] = true end
    out.tags = tags
    return out
end

local options = {
    maxAmount = cfg.maxAmount,
    slowMs = cfg.slowModifierMs,
    clock = GetGameTimer,
    invoke = function(entry, ctx)
        return pcall(entry.apply, copyContext(ctx))
    end,
    onError = function(entry, err)
        if due('error:' .. entry.key, cfg.errorLogMs) then
            VavaHealth.log.error("modificateur '%s' en erreur, ignoré pour ce coup : %s", entry.key, tostring(err))
        end
    end,
    onSlow = function(entry, ms)
        if due('slow:' .. entry.key, LOG_MS) then
            VavaHealth.log.warn("modificateur '%s' lent : %d ms (au-delà de %d)", entry.key, ms, cfg.slowModifierMs)
        end
    end,
    onInvalid = function(entry)
        if due('invalid:' .. entry.key, LOG_MS) then
            VavaHealth.log.warn("modificateur '%s' : rendu invalide (invalid_result), ignoré", entry.key)
        end
    end,
}

--- Résultat rendu à l'appelant.
---@param id integer
---@param state vAvA.HealthChainState
---@param applied number
---@param downed boolean
---@param health number
---@return table
local function resultOf(id, state, applied, downed, health)
    return {
        id = id, amount = state.amount, applied = applied, blocked = state.blocked, absorbed = state.absorbed,
        resisted = state.resisted, added = state.added, cancelled = state.cancelled, stage = state.stage,
        downed = downed, health = health,
    }
end

--- Le coup, une fois les garde-fous passés (appelé sous pcall : la profondeur est toujours rendue).
---@param target integer
---@param entry vAvA.HealthEntry
---@param p table      paquet normalisé
---@param origin string
---@return table result
local function process(target, entry, p, origin)
    local started = GetGameTimer()
    local id = VavaHealth.nextHitId()
    local core = VavaHealth.core
    -- personnage de la source : celui qui est en jeu prime sur celui du paquet
    if p.source then
        local character = core.characters.getActive(p.source)
        if character then p.sourceCharacter = character.id end
    end
    local state = chain.newState(p.amount)

    -- préconditions : rien n'a atteint la chaîne (ni hook, ni journal)
    if entry.downed then
        state.amount, state.cancelled = 0, 'downed'
        return resultOf(id, state, 0, false, 0)
    end
    if cfg.pvp == false and p.source and p.source ~= target then
        state.amount, state.cancelled = 0, 'pvp_off'
        return resultOf(id, state, 0, false, entry.health)
    end
    -- un joueur à terre ne frappe plus (un effet qui dure et un renvoi ne sont pas des gestes : ils passent)
    if p.source and p.source ~= target and not p.tags.overTime and not p.tags.reflected then
        local attacker = life.entry(p.source)
        if attacker and attacker.downed then
            state.amount, state.cancelled = 0, 'source_downed'
            return resultOf(id, state, 0, false, entry.health)
        end
    end

    local ctx = {
        id = id, target = target, targetCharacter = entry.characterId, origin = origin, kind = p.kind,
        amount = p.amount, tags = p.tags, health = entry.health * HEALTH_POINTS,
    }
    for i = 1, #PACKET_FIELDS do
        local field = PACKET_FIELDS[i]
        ctx[field] = p[field]
    end

    local allowed, reason = core.hooks.runBefore(HOOK, ctx)
    -- un abonné en erreur ne rend personne invulnérable : le coup passe (un refus volontaire reste un refus)
    if not allowed and reason == 'hook_error' then
        if due('before:error', LOG_MS) then
            VavaHealth.log.error('hook vava_health:hit before en erreur : coup laissé passer (console du core pour '
                .. 'l\'abonné en cause)')
        end
        allowed = true
    end
    ctx.base = p.amount
    local applied, downed = 0, false
    if not allowed then
        state.amount, state.cancelled, state.stage = 0, chain.reason(reason), 'before'
    else
        chain.run(modifiers.list(), ctx, state, options)
        if not state.cancelled then
            -- cible relue : un hook ou un modificateur a pu céder la main malgré le contrat
            local current = life.entry(target)
            if current ~= entry or entry.downed then
                state.amount, state.cancelled, state.stage = 0, 'downed', 'application'
            else
                applied = min(state.amount, entry.health * HEALTH_POINTS)
                if applied > 0 then life.applyLoss(target, applied / HEALTH_POINTS, true) end
                if entry.health <= 0 then
                    downed = life.down(target, 'hit', p.kind, p.source, { origin = origin, hitId = id }) == true
                end
            end
        end
    end

    local health = entry.downed and 0 or entry.health
    local result = resultOf(id, state, applied, downed, health)
    -- hook after : la charge du coup et son résultat
    ctx.stage = nil
    for key, value in pairs(result) do ctx[key] = value end
    core.hooks.runAfter(HOOK, ctx)

    if (p.source and p.source ~= target) or downed then
        journal.add({
            targetCharacter = entry.characterId, sourceCharacter = p.sourceCharacter, origin = origin, kind = p.kind,
            ref = p.technique or p.spell, weapon = p.weapon, amount = p.amount, applied = applied,
            blocked = state.blocked, absorbed = state.absorbed, resisted = state.resisted, cancelled = state.cancelled,
            downed = downed, position = life.positionOf(target),
        })
    end

    local elapsed = GetGameTimer() - started
    if elapsed > cfg.slowHitMs and due('slow:hit', LOG_MS) then
        VavaHealth.log.warn('coup lent : %d ms (au-delà de %d), %d modificateur(s)', elapsed, cfg.slowHitMs,
            #modifiers.list())
    end
    return result
end

--- Un coup sur un joueur (spec T-110 § 7.1). Ne lève jamais d'erreur.
---@param target any
---@param raw any       paquet (§ 5.1)
---@param origin string ressource appelante
---@return table|nil result
---@return string|nil code
function hits.hit(target, raw, origin)
    if not VavaHealth.ready then return nil, 'not_ready' end
    if mathType(target) ~= 'integer' then return nil, 'invalid_target' end
    local entry = life.entry(target)
    if not entry then return nil, 'no_character' end
    local p, code = packet.normalize(raw, LIMITS)
    if not p then return nil, code end
    origin = type(origin) == 'string' and origin or VavaHealth.resource
    -- `monde` : réservé aux pertes natives lues par ce module
    if p.kind == WORLD_KIND and origin ~= VavaHealth.resource then return nil, 'invalid_kind' end
    if depth >= cfg.maxDepth then return nil, 'too_deep' end
    local now = GetGameTimer()
    if not admit(target, p.source, now) then
        if due('rate:' .. target, LOG_MS) then
            VavaHealth.log.warn('joueur %d : plus de %d coups en une seconde d\'une même source, coups refusés '
                .. '(too_many_hits)', target, cfg.maxHitsPerSecond)
        end
        return nil, 'too_many_hits'
    end
    depth = depth + 1
    local ok, result = pcall(process, target, entry, p, origin)
    depth = depth - 1
    if not ok then
        VavaHealth.log.error('coup sur le joueur %d en erreur : %s', target, tostring(result))
        return nil, 'hit_error'
    end
    return result
end

--- Profondeur courante (tests).
---@return integer
function hits.depth()
    return depth
end

--- Oublie un joueur parti (débit, comme cible et comme source).
---@param src integer
function hits.forget(src)
    rates[src] = nil
    for _, bySource in pairs(rates) do bySource[src] = nil end
    logged['rate:' .. src] = nil
end
