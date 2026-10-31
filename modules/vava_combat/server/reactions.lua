--[[
    vava_combat/server/reactions.lua
    Rôle : ce qui suit un coup jugé par la chaîne de dégâts (docs/plan/specs/T-112.md § 7.6). Issue (règle pure
           weapons.outcome) envoyée aux SEULS joueurs à `reactions.radius` de la cible dans l'instance de l'attaquant
           (vava_combat:hit, un message par cible touchée) ; rien pour un coup refusé ou annulé avant la cible, seulement
           un avis à l'attaquant (combats coupés, lieu de paix, crochet), un par raison et par `notices.intervalMs`.
           Chancellement d'un coup `staggers` : la cible ne frappe plus pendant `stagger.durationMs`, son coup en cours
           est annulé, puis elle n'en reprend pas avant `timing.staggerImmunityMs` (pas d'enchaînement de contrôles).
           Mémoire bornée par le nombre de joueurs, oubliée au déchargement, au départ et à la mise à terre.
    Dépendances : shared/constants.lua, config_client.lua, config.lua, shared/weapons.lua, server/core.lua,
                  bridge/server.lua
]]

local type = type

local bridge = VavaCombat.bridge
local weapons = VavaCombat.weapons
local cfg = VavaCombat.config
local EVENTS = VavaCombat.EVENTS

local reactions = {}
VavaCombat.reactions = reactions

-- source → { at, untilMs, immuneUntil } : chancellement en cours ou immunité
local staggered = {}
-- source → { [clé du message] = instant du dernier avis }
local noticedAt = {}

--- Chancellement en cours : millisecondes avant de pouvoir frapper, ou nil.
---@param src integer
---@param now integer
---@return integer|nil
function reactions.staggeredLeft(src, now)
    local entry = staggered[src]
    if not entry or now >= entry.untilMs then return nil end
    return entry.untilMs - now
end

--- Vrai si le joueur a chancelé depuis `since` (son coup parti avant ne frappe plus).
---@param src integer
---@param since integer
---@return boolean
function reactions.staggeredSince(src, since)
    local entry = staggered[src]
    return entry ~= nil and entry.at >= since
end

--- Fait chanceler un joueur `ms` millisecondes (fendant ; T-113 : attaquant paré) : son coup en cours est annulé. Rend
--- faux s'il est encore immunisé.
---@param src integer
---@param ms integer
---@param now integer
---@return boolean
function reactions.stagger(src, ms, now)
    local entry = staggered[src]
    if entry and now < entry.immuneUntil then return false end
    staggered[src] = { at = now, untilMs = now + ms, immuneUntil = now + ms + cfg.timing.staggerImmunityMs }
    local swings = VavaCombat.swings
    if swings then swings.cancel(src, 'stagger') end
    return true
end

--- Avis à l'attaquant seul, un par raison et par `notices.intervalMs`.
---@param src integer
---@param key string  clé de config.messages
---@param now integer
local function notice(src, key, now)
    local seen = noticedAt[src]
    if not seen then
        seen = {}
        noticedAt[src] = seen
    end
    local last = seen[key]
    if last and now - last < cfg.notices.intervalMs then return end
    seen[key] = now
    bridge.Notify(src, cfg.messages[key], 'info')
end

--- Suite d'un coup porté par `swing` sur `target` (résultat de strike.run). Rend l'issue envoyée, ou nil.
---@param swing table   coup ({ source, def })
---@param target integer
---@param result table|nil
---@return string|nil outcome
function reactions.after(swing, target, result)
    if type(result) ~= 'table' then return nil end
    local src = swing.source
    local now = bridge.Timer()
    local outcome = weapons.outcome(result)
    if not outcome then
        local key = weapons.noticeOf(result)
        if key then notice(src, key, now) end
        return nil
    end
    if outcome == 'hit' and swing.def.staggers and reactions.stagger(target, cfg.stagger.durationMs, now) then
        outcome = 'stagger'
    end
    local x, y, z = bridge.Position(target)
    if not x then x, y, z = bridge.Position(src) end
    if not x then return outcome end
    bridge.SendNear(bridge.Bucket(src), { x = x, y = y, z = z }, cfg.reactions.radius, EVENTS.HIT, src, target, outcome)
    return outcome
end

--- Mise à terre : chancellement oublié.
---@param src integer
function reactions.onDowned(src)
    staggered[src] = nil
end

--- Déchargement, départ : tout est oublié.
---@param src integer
function reactions.forget(src)
    staggered[src], noticedAt[src] = nil, nil
end

--- Arrêt du module.
function reactions.stop()
    staggered, noticedAt = {}, {}
end
