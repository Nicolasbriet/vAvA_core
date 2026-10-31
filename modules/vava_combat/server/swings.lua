--[[
    vava_combat/server/swings.lua
    Rôle : un coup de technique, décidé par le serveur (docs/plan/specs/T-112.md § 7.1, § 7.5). Handler du RPC
           `vava_combat:use(technique, cible)` : refus en mémoire d'abord (technique, type, chancellement, dégainer,
           admission : délai et enchaînement), exports ensuite (personnage, arme RÉELLEMENT tenue, style de l'arme, à
           terre, véhicule, contrôle de la magie, crochet `vava_combat:using`, position) ; puis la fenêtre de frappe
           est programmée par le serveur (préparation, puis un ou deux relevés pendant la frappe). À chaque relevé :
           attaquant toujours le même personnage, debout, à pied, pas chancelant, même pile en main, bond plausible
           depuis la demande ; candidats = joueurs proches de la même instance, jugés sur les positions et le cap LUS
           PAR LE SERVEUR (portée + bonus de l'arme + tolérance, demi-angle + tolérance, hauteur), triés (cible
           verrouillée d'abord, puis angle, distance, numéro), une cible touchée une fois par coup, `maxTargets` par
           coup ; chaque cible passe par strike.run (chaîne de dégâts, usure), puis server/reactions.lua. Rien n'est
           rendu au client que l'acceptation ou le refus : aucun résultat. Ne cède jamais la main (aucune attente, aucune
           base, aucun callClient).
    Dépendances : shared/constants.lua, config_client.lua, config.lua, shared/weapons.lua, shared/geometry.lua,
                  shared/techniques.lua, server/core.lua, bridge/server.lua, server/catalog.lua, server/strike.lua,
                  server/hands.lua, server/reactions.lua
]]

local type, pairs, ipairs, tostring = type, pairs, ipairs, tostring
local tointeger, floor = math.tointeger, math.floor
local SetTimeout = SetTimeout

local bridge = VavaCombat.bridge
local weapons = VavaCombat.weapons
local geometry = VavaCombat.geometry
local techniques = VavaCombat.techniques
local catalog = VavaCombat.catalog
local strike = VavaCombat.strike
local hands = VavaCombat.hands
local reactions = VavaCombat.reactions
local cfg = VavaCombat.config
local HOOKS = VavaCombat.HOOKS
local SHIELD = VavaCombat.SHIELD_CATEGORY
local MAX_PLAYER, MAX_REASON = VavaCombat.MAX_PLAYER, VavaCombat.MAX_REASON

-- une ligne de console par joueur et par minute au plus pour un bond invraisemblable
local MOVED_WARN_MS = 60000

local ATTACKS = {}
for _, kind in ipairs(VavaCombat.ATTACK_TYPES) do ATTACKS[kind] = true end

local swings = {}
VavaCombat.swings = swings

---@class vAvA.Swing
---@field seq integer
---@field source integer
---@field id string            technique
---@field def table
---@field style string
---@field item string
---@field instanceId integer
---@field characterId integer
---@field startedAt integer
---@field openAt integer
---@field closeAt integer
---@field endAt integer
---@field chainCount integer
---@field target integer       cible verrouillée annoncée (0 : aucune), ordre des candidats seulement
---@field origin table         position lue à la demande
---@field arc table            arc de la technique avec l'arme tenue
---@field hits table<integer, true>
---@field hitCount integer
---@field cancelled string|nil

---@type table<integer, vAvA.Swing>  source → dernier coup
local current = {}
local seq = 0
-- source → instant du dernier avertissement « bond »
local movedWarnAt = {}

--- Annule le coup en cours d'un joueur (ses relevés encore à venir ne frappent plus).
---@param src integer
---@param reason string  hands | stagger | downed | left | moved
function swings.cancel(src, reason)
    local swing = current[src]
    if swing and not swing.cancelled then swing.cancelled = reason end
end

--- Coup en cours d'un joueur (lecture : T-113), ou nil.
---@param src integer
---@return vAvA.Swing|nil
function swings.of(src)
    return current[src]
end

---@param src integer
---@param fmt string
local function warnMoved(src, fmt, ...)
    local now = bridge.Timer()
    local last = movedWarnAt[src]
    if last and now - last < MOVED_WARN_MS then return end
    movedWarnAt[src] = now
    VavaCombat.log.warn(fmt, ...)
end

--- Cible annoncée par le client : gardée seulement si c'est un autre joueur à personnage actif (sinon 0, sans erreur).
--- Elle ne sert qu'à l'ordre des candidats : elle n'allonge ni la portée ni l'angle.
---@param src integer
---@param target any
---@return integer
local function lockedTarget(src, target)
    local int = type(target) == 'number' and tointeger(target) or nil
    if not int or int <= 0 or int > MAX_PLAYER or int == src or not bridge.ActiveCharacterId(int) then return 0 end
    return int
end

--- Ligne de console d'un relevé (debug.logSamples).
local function logSample(swing, k, other, distance, angle, outcome)
    VavaCombat.log.info('coup %d %s relevé %d : %d d=%s a=%s portée %s → %s', swing.seq, swing.id, k, other,
        weapons.tenth(distance or 0), tostring(angle and floor(angle + 0.5) or '-'), weapons.tenth(swing.arc.reach),
        tostring(outcome))
end

--- Relevé `k` d'un coup, à l'ouverture (1) puis à la fin (2) de la frappe.
---@param swing vAvA.Swing
---@param k integer
local function sample(swing, k)
    if not VavaCombat.ready or swing.cancelled then return end
    local src = swing.source
    if bridge.ActiveCharacterId(src) ~= swing.characterId then
        swing.cancelled = 'left'
        return
    end
    if bridge.IsDowned(src) or bridge.InVehicle(src) or reactions.staggeredSince(src, swing.startedAt) then
        swing.cancelled = 'state'
        return
    end
    local held = bridge.Held(src)
    if not held or held.id ~= swing.instanceId then
        swing.cancelled = 'hands'
        return
    end
    local x, y, z = bridge.Position(src)
    local heading = bridge.Heading(src)
    if not x or not heading then
        swing.cancelled = 'left'
        return
    end
    local now = bridge.Timer()
    local position = { x = x, y = y, z = z }
    if not geometry.plausibleMove(swing.origin, now, swing.startedAt, position, cfg.lunge) then
        swing.cancelled = 'moved'
        warnMoved(src, 'joueur %d : bond invraisemblable pendant un coup (%s m en %d ms), coup annulé', src,
            tostring(weapons.tenth(geometry.flat(swing.origin, position) or 0)), now - swing.startedAt)
        return
    end
    local arc = swing.arc
    local logging = cfg.debug.logSamples
    local candidates = {}
    for _, other in ipairs(bridge.PlayersNear(position, arc.reach + cfg.geometry.searchMargin, src)) do
        if other ~= src and not swing.hits[other] and bridge.ActiveCharacterId(other) then
            local ox, oy, oz = bridge.Position(other)
            if ox then
                local inside, distance, angle = geometry.inArc(position, heading, { x = ox, y = oy, z = oz }, arc)
                if inside and not bridge.InVehicle(other) and not bridge.IsDowned(other) then
                    candidates[#candidates + 1] = { player = other, distance = distance, angle = angle }
                elseif logging then
                    logSample(swing, k, other, inside and distance or nil, inside and angle or nil,
                        inside and 'écarté' or distance)
                end
            end
        end
    end
    local room = cfg.geometry.maxTargets - swing.hitCount
    for index, entry in ipairs(geometry.order(candidates, swing.target ~= 0 and swing.target or nil)) do
        if index > room then break end
        local target = entry.player
        swing.hits[target] = true
        swing.hitCount = swing.hitCount + 1
        local result, code = strike.run(src, target, {
            technique = swing.id,
            damage = swing.def.damage,
            tags = swing.def.parryable and { parryable = true } or nil,
        }, { held = held, characterId = swing.characterId })
        local outcome = reactions.after(swing, target, result)
        if logging then logSample(swing, k, target, entry.distance, entry.angle, outcome or code or 'retenu') end
    end
end

--- Handler du RPC `vava_combat:use` (arguments déjà validés par le schéma). Rend `true` (coup accepté, fenêtre
--- programmée), `false, code`, `false, code, attente` (busy, chain_limit, drawing, staggered) ou
--- `false, 'refused', raison`.
---@param src integer
---@param id string
---@param target integer
---@return boolean ok
---@return string|nil code
---@return integer|string|nil detail
function swings.use(src, id, target)
    -- refus en mémoire d'abord
    if not VavaCombat.ready then return false, 'not_ready' end
    local def = catalog.technique(id)
    if not def then return false, 'unknown_technique' end
    if not ATTACKS[def.type] then return false, 'not_attack' end
    local now = bridge.Timer()
    local stagger = reactions.staggeredLeft(src, now)
    if stagger then return false, 'staggered', stagger end
    local drawing = hands.drawingLeft(src, now)
    if drawing then return false, 'drawing', drawing end
    local prev = current[src]
    if prev and prev.cancelled then prev = nil end
    local admitted, chainCount, wait = techniques.admit(prev, def, id, now, {
        earlyMs = cfg.timing.earlyMs, chainMax = cfg.timing.chainMax, styles = cfg.styles,
    })
    if not admitted then return false, chainCount, wait end

    -- exports ensuite
    local characterId = bridge.ActiveCharacterId(src)
    if not characterId then return false, 'no_character' end
    local held = bridge.Held(src)
    local item = held and held.item
    local weapon = catalog.weapon(item)
    if not weapon or weapon.category == SHIELD or not catalog.holdable(item) then return false, 'no_weapon' end
    local style = techniques.styleOf(cfg.weaponClasses[item])
    if not style or type(cfg.styles[style]) ~= 'table' then return false, 'no_style' end
    if def.style ~= style then return false, 'not_in_style' end
    if bridge.IsDowned(src) then return false, 'downed' end
    if bridge.InVehicle(src) then return false, 'vehicle' end
    if bridge.MagicHardControl(src) then return false, 'controlled' end
    target = lockedTarget(src, target)
    local allowed, reason = bridge.RunBefore(HOOKS.USING, {
        source = src, characterId = characterId, technique = id, item = item, target = target ~= 0 and target or nil,
    })
    if not allowed then return false, 'refused', weapons.reasonText(reason, MAX_REASON) end
    local x, y, z = bridge.Position(src)
    if not x then return false, 'no_character' end

    hands.noteHeld(src, item)
    seq = seq + 1
    local plan = techniques.plan(def, now)
    local swing = {
        seq = seq, source = src, id = id, def = def, style = style, item = item, instanceId = held.id,
        characterId = characterId, startedAt = plan.startedAt, openAt = plan.openAt, closeAt = plan.closeAt,
        endAt = plan.endAt, chainCount = chainCount, target = target, origin = { x = x, y = y, z = z },
        arc = geometry.arcOf(def, weapon, cfg), hits = {}, hitCount = 0, cancelled = nil,
    }
    -- le coup précédent n'est pas annulé : ses relevés encore à venir se font (une frappe ouverte va à son terme)
    current[src] = swing
    local phases = def.phases
    SetTimeout(phases.windup, function() sample(swing, 1) end)
    if cfg.timing.samples == 2 then
        SetTimeout(phases.windup + phases.active, function() sample(swing, 2) end)
    end
    return true
end

--- Mise à terre (hook vava_health:downed) : coup en cours annulé.
---@param src integer
function swings.onDowned(src)
    swings.cancel(src, 'downed')
end

--- Déchargement, départ : coup en cours annulé, tout est oublié.
---@param src integer
function swings.forget(src)
    swings.cancel(src, 'left')
    current[src], movedWarnAt[src] = nil, nil
end

--- Arrêt du module : chaque coup en cours est annulé.
function swings.stop()
    for src in pairs(current) do swings.cancel(src, 'left') end
    current, movedWarnAt = {}, {}
end
