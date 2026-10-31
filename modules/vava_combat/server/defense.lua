--[[
    vava_combat/server/defense.lua
    Rôle : la défense tenue par le serveur (docs/plan/specs/T-113.md § 7) : refus d'un geste défensif en mémoire (garde
           brisée, parade ratée, pas de côté trop tôt), cache de la garde (part bloquée de l'arme et du bouclier au bras),
           geste accepté (fenêtre gardée en mémoire, SANS minuterie), garde abaissée (RPC `vava_combat:lower`), trois
           modificateurs de la chaîne de dégâts (esquive, parade, blocage) qui ne lisent que la mémoire du module et les
           positions lues par le serveur, rendent un résultat et notent leur décision ; suites dans le hook
           `vava_health:hit` after (attaquant paré qui chancelle, compteur provisoire et garde brisée, usure différée
           de l'arme qui pare ou du bouclier qui bloque, issue imposée à server/reactions.lua, hook
           `vava_combat:defended`) ; `defense.spend`, seul point que l'endurance (T-114) remplacera. Mémoire bornée par
           le nombre de joueurs (et `memoMax` pour les coups en cours), oubliée au déchargement, au départ, à l'arrêt.
    Dépendances : shared/constants.lua, config_client.lua, config.lua, shared/defense.lua, shared/weapons.lua,
                  shared/shield.lua, server/core.lua, bridge/server.lua, server/catalog.lua, server/wear.lua,
                  server/shields.lua, server/reactions.lua (server/swings.lua lu à l'appel)
]]

local type, pairs, ipairs = type, pairs, ipairs
local mathType, min = math.type, math.min
local SetTimeout = SetTimeout

local bridge = VavaCombat.bridge
local weapons = VavaCombat.weapons
local shield = VavaCombat.shield
local catalog = VavaCombat.catalog
local wear = VavaCombat.wear
local shields = VavaCombat.shields
local reactions = VavaCombat.reactions
local cfg = VavaCombat.config
local HOOKS = VavaCombat.HOOKS
-- modificateurs déclarés au registre vava_health:modifiers (étape → clé ; serveur seul, hors de shared/constants.lua)
local KEYS = { esquive = 'vava_combat:esquive', parade = 'vava_combat:parade', blocage = 'vava_combat:blocage' }
local EMPTY = {}
-- une ligne de console par minute au plus quand la mémoire des décisions est pleine
local WARN_MS = 60000

local defense = VavaCombat.defense

-- source → dernier geste défensif accepté (jamais une réservation)
local active = {}
-- source → dernière parade acceptée ; source → départ du dernier pas de côté
local lastParry, lastDodge = {}, {}
-- source → { value, at } : compteur provisoire de garde (T-114 le remplace)
local points = {}
-- source → fin de la garde brisée
local brokenUntil = {}
-- numéro du coup → décision d'un modificateur en attente de sa suite ; issue imposée en attente de reactions.after
local memo, memoCount = {}, 0
local outcomes, outcomeCount = {}, 0
local fullWarnAt = nil

-- Mémoire des décisions ---------------------------------------------------------------------------------------------

--- Oublie les décisions et issues plus vieilles que `memoMs` (coup tombé en erreur avant sa suite).
---@param now integer
local function purge(now)
    local maxAge = cfg.defense.memoMs
    for id, entry in pairs(memo) do
        if now - entry.at >= maxAge then
            memo[id], memoCount = nil, memoCount - 1
        end
    end
    for id, entry in pairs(outcomes) do
        if now - entry.at >= maxAge then
            outcomes[id], outcomeCount = nil, outcomeCount - 1
        end
    end
end

--- Note la décision d'un modificateur pour le coup `id`. Mémoire pleine même après la purge : faux (aucune défense pour
--- ce coup), une ligne de console par minute.
---@param id any
---@param entry table
---@param now integer
---@return boolean
local function remember(id, entry, now)
    if mathType(id) ~= 'integer' then return false end
    if memo[id] == nil then
        if memoCount >= cfg.defense.memoMax then purge(now) end
        if memoCount >= cfg.defense.memoMax then
            if not fullWarnAt or now - fullWarnAt >= WARN_MS then
                fullWarnAt = now
                VavaCombat.log.warn('défense : %d décisions en attente de leur suite, coup laissé sans défense', memoCount)
            end
            return false
        end
        memoCount = memoCount + 1
    end
    entry.at = now
    memo[id] = entry
    return true
end

--- Issue imposée au coup `id` pour server/reactions.lua (même tour).
---@param id integer
---@param outcome string
---@param now integer
local function impose(id, outcome, now)
    if outcomes[id] == nil then
        if outcomeCount >= cfg.defense.memoMax then purge(now) end
        if outcomeCount >= cfg.defense.memoMax then return end
        outcomeCount = outcomeCount + 1
    end
    outcomes[id] = { outcome = outcome, at = now }
end

--- Issue imposée par la défense au coup `id` (parry, block, break), retirée ; ou nil.
---@param id any
---@return string|nil
function defense.takeOutcome(id)
    local entry = id ~= nil and outcomes[id] or nil
    if not entry then return nil end
    outcomes[id], outcomeCount = nil, outcomeCount - 1
    return entry.outcome
end

-- Admission et acceptation ------------------------------------------------------------------------------------------

--- Garde brisée en cours : millisecondes restantes, ou nil.
---@param src integer
---@param now integer
---@return integer|nil
function defense.brokenLeft(src, now)
    local untilMs = brokenUntil[src]
    if not untilMs or now >= untilMs then return nil end
    return untilMs - now
end

--- Refus en mémoire d'un geste défensif (spec § 7.1, lignes 6 à 8) : `code, attente`, ou nil.
---@param src integer
---@param def table
---@param now integer
---@return string|nil code
---@return integer|nil wait
function defense.refusal(src, def, now)
    local kind = def.type
    if kind == 'blocage' or kind == 'parade' then
        local left = defense.brokenLeft(src, now)
        if left then return 'guard_broken', left end
    end
    if kind == 'parade' then
        local wait = defense.parryWait(lastParry[src], now, cfg)
        if wait then return 'parry_cooldown', wait end
    elseif kind == 'esquive' then
        local wait = defense.dodgeWait(lastDodge[src], now, cfg)
        if wait then return 'dodge_cooldown', wait end
    end
    return nil
end

--- Cache d'une garde, lu une fois à sa vérification : part bloquée et usure de l'arme tenue, bouclier accroché au bras
--- (mémoire du module, puis une lecture de sa pile pour sa solidité), arc protégé (+ `shieldArcBonus` au bouclier).
---@param src integer
---@param held table    pile tenue (lue par confirm)
---@param def table     technique de garde
---@param weapon table  fiche de l'arme tenue
---@return table guard
function defense.guardOf(src, held, def, weapon)
    local guard = { weaponBlock = weapon.block, weaponDull = weapons.durabilityOf(held.metadata, weapon).dull }
    local arc = def.hit.angle
    local hung = shields.hungOf(src)
    if hung and shield.position(held.item, cfg.weaponClasses, cfg.shield.armWith, cfg.shield.armWithEmptyHand)
        == shield.ARM then
        local fiche = catalog.weapon(hung.item)
        for _, pile in ipairs(fiche and bridge.Items(src, hung.item) or EMPTY) do
            if pile.id == hung.instanceId then
                guard.shieldInstanceId, guard.shieldItem, guard.shieldBlock = hung.instanceId, hung.item, fiche.block
                guard.shieldDull = weapons.durabilityOf(pile.metadata, fiche).dull
                arc = arc + cfg.defense.block.shieldArcBonus
                break
            end
        end
    end
    guard.arc = min(180, arc)
    return guard
end

--- Un geste vient d'être accepté (attaque ou défense) : une attaque ferme toute fenêtre défensive ; un geste défensif
--- devient la défense du joueur (parade et pas de côté retenus pour leurs délais ; garde dont l'abaissement a été demandé
--- pendant sa réservation : fermée aussitôt).
---@param src integer
---@param swing table
---@param now integer
function defense.onAccepted(src, swing, now)
    local kind = swing.def.type
    if kind ~= 'blocage' and kind ~= 'parade' and kind ~= 'esquive' then
        active[src] = nil
        return
    end
    active[src] = swing
    if kind == 'parade' then
        lastParry[src] = swing
    elseif kind == 'esquive' then
        lastDodge[src] = swing.startedAt
    elseif swing.lowerRequested then
        defense.close(swing, now)
    end
end

--- Handler du RPC `vava_combat:lower` : garde acceptée et ouverte → abaissée (tenue minimale, récupération) ; garde
--- réservée → abaissement noté (fermée à l'acceptation) ; sinon `false, 'no_guard'`. Ne cède jamais la main.
---@param src integer
---@return boolean ok
---@return string|nil code
function defense.lowerRpc(src)
    if not VavaCombat.ready then return false, 'not_ready' end
    local swing = VavaCombat.swings.of(src)
    if not defense.openGuard(swing) or swing.refused then return false, 'no_guard' end
    if swing.pending then
        swing.lowerRequested = true
        return true
    end
    defense.close(swing, bridge.Timer())
    return true
end

-- Modificateurs de la chaîne de dégâts --------------------------------------------------------------------------------

--- Tête commune : geste défensif du bon type, ouvert, même personnage, à pied, sans contrôle dur de la magie. Une seule
--- lecture de table si personne ne se défend.
---@param ctx table
---@param kind string
---@return table|nil swing
---@return integer|nil now
local function defending(ctx, kind)
    local target = ctx.target
    local swing = active[target]
    if not swing or swing.def.type ~= kind then return nil end
    local now = bridge.Timer()
    if not defense.open(swing, now) or swing.characterId ~= ctx.targetCharacter then return nil end
    if bridge.InVehicle(target) or bridge.MagicHardControl(target) then return nil end
    return swing, now
end

--- Attaquant de face, sur les positions et le cap lus par le serveur.
---@param target integer
---@param source integer
---@param angle number
---@return boolean
local function facing(target, source, angle)
    local tx, ty, tz = bridge.Position(target)
    local sx, sy, sz = bridge.Position(source)
    local heading = bridge.Heading(target)
    if not tx or not sx or not heading then return false end
    return defense.frontal({ x = tx, y = ty, z = tz }, heading, { x = sx, y = sy, z = sz }, angle, cfg)
end

---@param ctx table
---@return integer|nil
local function attackerOf(ctx)
    local source = ctx.source
    if mathType(source) ~= 'integer' or source == ctx.target then return nil end
    return source
end

local function dodgeModifier(ctx)
    local swing, now = defending(ctx, 'esquive')
    if not swing then return nil end
    local rules = cfg.defense.dodge
    if not defense.tagsMatch(ctx.tags, rules.tags, rules.never) then return nil end
    if not remember(ctx.id, { kind = 'dodge', target = ctx.target, source = attackerOf(ctx), swing = swing }, now) then
        return nil
    end
    return { cancel = 'esquive' }
end

local function parryModifier(ctx)
    local swing, now = defending(ctx, 'parade')
    if not swing or not ctx.tags.parryable or not defense.tagsMatch(ctx.tags, cfg.defense.parryTags, EMPTY) then
        return nil
    end
    local source = attackerOf(ctx)
    if not source or not facing(ctx.target, source, swing.def.hit.angle) then return nil end
    if not remember(ctx.id, { kind = 'parry', target = ctx.target, source = source, swing = swing }, now) then
        return nil
    end
    return { cancel = 'parade' }
end

local function blockModifier(ctx)
    local swing, now = defending(ctx, 'blocage')
    if not swing or not swing.guard or ctx.tags.unblockable
        or not defense.tagsMatch(ctx.tags, cfg.defense.block.tags, EMPTY) then
        return nil
    end
    local source = attackerOf(ctx)
    if not source or not facing(ctx.target, source, swing.guard.arc) then return nil end
    local hung = shields.hungOf(ctx.target)
    local factor, by = defense.blockFactor(swing.guard, hung and hung.instanceId, cfg.wear)
    local blocked = defense.blockedAmount(ctx.amount, factor)
    if blocked <= 0 then return nil end
    local entry = { kind = 'block', target = ctx.target, source = source, swing = swing, by = by,
        weight = defense.weightOf(catalog.technique(ctx.technique), cfg) }
    if not remember(ctx.id, entry, now) then return nil end
    return { blocked = blocked }
end

--- Déclare les trois modificateurs (au démarrage, et à chaque démarrage de vava_health). Rend le nombre déclaré.
---@return integer
function defense.declare()
    local priority, labels = cfg.defense.modifierPriority, cfg.messages.modifiers
    local function kinds()
        local out = {}
        for i, kind in ipairs(cfg.kinds) do out[i] = kind end
        return out
    end
    return bridge.DeclareModifiers({
        { key = KEYS.esquive, def = { stage = 'esquive', priority = priority, label = labels.esquive,
            apply = dodgeModifier } },
        { key = KEYS.parade, def = { stage = 'parade', priority = priority, label = labels.parade, kinds = kinds(),
            apply = parryModifier } },
        { key = KEYS.blocage, def = { stage = 'blocage', priority = priority, label = labels.blocage, kinds = kinds(),
            apply = blockModifier } },
    })
end

-- Suites d'une défense --------------------------------------------------------------------------------------------------

--- Coût d'un geste défensif. 1.3.0 : `block` passe par le compteur provisoire de garde ; `parry` et `dodge` rendent
--- toujours vrai (bornés par leurs délais). T-114 remplacera cette fonction (jauge d'endurance, refus `exhausted`).
---@param src integer
---@param action 'block'|'parry'|'dodge'
---@param ctx { technique: table, weight: integer, shield: boolean, now: integer }
---@return boolean ok
---@return boolean broken
function defense.spend(src, action, ctx)
    if action ~= 'block' then return true, false end
    local state, broken = defense.addPoints(points[src], ctx.weight, ctx.now, cfg, ctx.shield)
    points[src] = state
    return true, broken
end

--- Usure de l'arme qui pare ou de ce qui bloque, hors de la chaîne (SetTimeout 0) ; wear.apply relit la pile. Pièce
--- émoussée pendant la garde : cache mis à jour.
---@param target integer
---@param swing table
---@param instanceId integer
---@param item string
---@param which 'weapon'|'shield'
local function wearLater(target, swing, instanceId, item, which)
    SetTimeout(0, function()
        local fiche = catalog.weapon(item)
        if not fiche or not instanceId then return end
        local step = wear.apply(target, instanceId, item, fiche, swing.characterId)
        local guard = swing.guard
        if step and step.dulled and guard and active[target] == swing then
            if which == 'shield' then guard.shieldDull = true else guard.weaponDull = true end
        end
    end)
end

---@param target integer
---@param swing table
---@param outcome string
---@param attacker integer|nil
---@param payload table
local function announce(target, swing, outcome, attacker, payload)
    bridge.RunAfter(HOOKS.DEFENDED, {
        source = target, characterId = swing.characterId, outcome = outcome, technique = swing.id, attacker = attacker,
        attackerTechnique = payload.technique, hitId = payload.id,
    })
end

--- Hook `vava_health:hit` after : suite d'un coup qu'un modificateur de ce module a défendu (une lecture de table pour
--- tout autre coup du jeu). En mémoire seulement, sans attente.
---@param payload table
function defense.onHitAfter(payload)
    local id = type(payload) == 'table' and payload.id or nil
    local entry = id ~= nil and memo[id] or nil
    if not entry then return end
    memo[id], memoCount = nil, memoCount - 1
    local now = bridge.Timer()
    local target, swing, kind = entry.target, entry.swing, entry.kind
    local ours = payload.origin == VavaCombat.resource
    if kind == 'dodge' then
        if payload.stage == 'esquive' then announce(target, swing, 'dodge', entry.source, payload) end
    elseif kind == 'parry' then
        if payload.stage ~= 'parade' then return end
        local source = entry.source
        swing.parried = true
        VavaCombat.swings.cancel(source, 'parried')
        reactions.stagger(source, cfg.stagger.durationMs, now, true)
        wearLater(target, swing, swing.instanceId, swing.item, 'weapon')
        if ours then impose(id, 'parry', now) end
        announce(target, swing, 'parry', source, payload)
    elseif kind == 'block' then
        -- coup annulé plus loin, ou mise à terre : elle l'emporte, rien d'autre
        if payload.cancelled ~= nil or payload.downed then return end
        local byShield = entry.by == 'shield'
        local _, broken = defense.spend(target, 'block', { technique = swing.def, weight = entry.weight,
            shield = byShield, now = now })
        local guard = swing.guard
        if byShield then
            wearLater(target, swing, guard.shieldInstanceId, guard.shieldItem, 'shield')
        else
            wearLater(target, swing, swing.instanceId, swing.item, 'weapon')
        end
        local outcome = 'block'
        if broken then
            outcome = 'break'
            local ms = cfg.defense.guardBrokenMs
            VavaCombat.swings.cancel(target, 'broken')
            brokenUntil[target], points[target] = now + ms, nil
            reactions.stagger(target, ms, now, true)
        end
        if ours then impose(id, outcome, now) end
        announce(target, swing, outcome, entry.source, payload)
    end
end

-- Oubli ---------------------------------------------------------------------------------------------------------------

--- Mise à terre : plus aucune défense en cours.
---@param src integer
function defense.onDowned(src)
    active[src] = nil
end

--- Déchargement, départ : tout est oublié.
---@param src integer
function defense.forget(src)
    active[src], lastParry[src], lastDodge[src], points[src], brokenUntil[src] = nil, nil, nil, nil, nil
end

--- Arrêt du module.
function defense.stop()
    active, lastParry, lastDodge, points, brokenUntil = {}, {}, {}, {}, {}
    memo, memoCount, outcomes, outcomeCount, fullWarnAt = {}, 0, {}, 0, nil
end

--- Geste défensif en cours d'un joueur (lecture : essais, T-156), ou nil.
---@param src integer
---@return table|nil
function defense.activeOf(src)
    return active[src]
end

--- Décisions et issues en attente (essais).
---@return integer memo
---@return integer outcomes
function defense.memoSize()
    return memoCount, outcomeCount
end
