--[[
    vava_combat/server/reactions.lua
    Rôle : ce qui suit un coup jugé par la chaîne de dégâts (docs/plan/specs/T-112.md § 7.6). Issue (règle pure
           weapons.outcome, ou issue imposée par la défense : parry, block, break) envoyée aux SEULS joueurs à
           `reactions.radius` de la cible dans l'instance de l'attaquant (vava_combat:hit, un message par cible touchée,
           à la place de `hit`) ; rien pour un coup refusé ou annulé avant la cible, seulement un avis à l'attaquant
           (combats coupés, lieu de paix, crochet), un par raison et par `notices.intervalMs`.
           Chiffres des coups (T-155, `numbers`) : l'attaquant et la cible désignés reçoivent une 4e valeur, le montant
           du coup en dixièmes (weapons.wireAmount) ou `false` pour une issue sans montant ; les issues de
           `reactions.silent` (esquive, coup absorbé) ne partent qu'à eux ; les témoins reçoivent le message de 1.3.0.
           Destinataires d'une même charge réunis en une liste (core.net.send) : deux envois au plus par coup.
           `numbers.enabled = false` : comportement de 1.3.0 (un envoi de proximité, issues tues pour tous).
           Chancellement d'un coup `staggers` : la cible ne frappe plus pendant `stagger.durationMs`, son coup en cours
           est annulé, puis elle n'en reprend pas avant `timing.staggerImmunityMs` (pas d'enchaînement de contrôles) ;
           attaquant paré et garde brisée : chancellement forcé, qui renouvelle l'immunité (T-113).
           Mémoire bornée par le nombre de joueurs, oubliée au déchargement, au départ et à la mise à terre.
    Dépendances : shared/constants.lua, config_client.lua, config.lua, shared/weapons.lua, server/core.lua,
                  bridge/server.lua
]]

local type, ipairs = type, ipairs

local bridge = VavaCombat.bridge
local weapons = VavaCombat.weapons
local cfg = VavaCombat.config
local EVENTS = VavaCombat.EVENTS
local defense = VavaCombat.defense
-- issues qu'aucun témoin ne montre (ni réaction, ni effet, ni son) : jamais envoyées aux témoins (relecture réseau R-3
-- de T-112) ; aux seuls participants désignés depuis T-155
local SILENT = {}
for _, outcome in ipairs(cfg.reactions.silent) do SILENT[outcome] = true end

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

--- Fait chanceler un joueur `ms` millisecondes (fendant ; attaquant paré, garde brisée) : son coup en cours est annulé.
--- Rend faux s'il est encore immunisé, sauf `force` (interne : parade, garde brisée), qui passe outre et renouvelle
--- l'immunité.
---@param src integer
---@param ms integer
---@param now integer
---@param force? boolean
---@return boolean
function reactions.stagger(src, ms, now, force)
    local entry = staggered[src]
    if not force and entry and now < entry.immuneUntil then return false end
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
    local imposed = defense.takeOutcome(result.id, target)
    local outcome = result.downed == true and 'down' or imposed or weapons.outcome(result)
    if not outcome then
        local key = weapons.noticeOf(result)
        if key then notice(src, key, now) end
        return nil
    end
    if outcome == 'hit' and swing.def.staggers and reactions.stagger(target, cfg.stagger.durationMs, now) then
        outcome = 'stagger'
    end
    local numbers = cfg.numbers
    if SILENT[outcome] and not numbers.enabled then return outcome end
    local x, y, z = bridge.Position(target)
    if not x then x, y, z = bridge.Position(src) end
    if not x then return outcome end
    local coords = { x = x, y = y, z = z }
    if not numbers.enabled then
        bridge.SendNear(bridge.Bucket(src), coords, cfg.reactions.radius, EVENTS.HIT, src, target, outcome)
        return outcome
    end
    local silent = SILENT[outcome]
    -- participants désignés (et témoins si numbers.witnesses) : 4 valeurs ; les autres : 3, rien pour une issue tue
    local full, plain = {}, {}
    for _, id in ipairs(bridge.PlayersAround(bridge.Bucket(src), coords, cfg.reactions.radius)) do
        local designated
        if id == src or id == target then
            designated = (id == src and numbers.attacker) or (id == target and numbers.target)
        else
            designated = numbers.witnesses and not silent
        end
        if designated then
            full[#full + 1] = id
        elseif not silent then
            plain[#plain + 1] = id
        end
    end
    local amount = weapons.wireAmount(result, outcome)
    if #full > 0 then bridge.SendTo(full, EVENTS.HIT, src, target, outcome, amount or false) end
    if #plain > 0 then bridge.SendTo(plain, EVENTS.HIT, src, target, outcome) end
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
