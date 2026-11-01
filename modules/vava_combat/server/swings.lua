--[[
    vava_combat/server/swings.lua
    Rôle : un coup de technique, décidé par le serveur (docs/plan/specs/T-112.md § 7.1, § 7.5 ; geste défensif :
           T-113 § 7.1). Handler du RPC `vava_combat:use(technique, cible)` : refus en mémoire d'abord (technique, type,
           chancellement, dégainer, garde brisée, délais de la parade et du pas de côté, admission : délai,
           enchaînement, garde levée), puis le coup est RÉSERVÉ (il tient la place du coup en cours) avant
           tout appel qui pourrait céder la main : exports (personnage, arme RÉELLEMENT tenue, style de l'arme, à
           terre, véhicule, contrôle de la magie, crochet `vava_combat:using`, position) ; un refus rend la place au
           coup d'avant, tel quel ; deux demandes simultanées ne passent donc jamais toutes les deux, même si un
           crochet cède la main. Un coup annulé, quelle qu'en soit la cause (chancellement, à terre, main changée,
           véhicule, bond, départ), garde son cycle : récupération et compte d'enchaînement comptent comme s'il était
           allé au bout (s'annuler soi-même ne libère jamais plus tôt ; une garde annulée est fermée avec sa tenue
           minimale et sa récupération). Un geste défensif accepté n'a aucune minuterie : sa fenêtre est gardée par
           server/defense.lua. Pour une attaque, la fenêtre de frappe est programmée par le serveur (préparation, puis
           un ou deux relevés pendant la frappe). À chaque relevé : attaquant toujours le même personnage, debout, à
           pied, pas chancelant, sans contrôle dur de la magie, même pile en main, bond plausible
           depuis la demande ; candidats = joueurs proches de la même instance, jugés sur les positions et le cap LUS
           PAR LE SERVEUR (portée + bonus de l'arme + tolérance, demi-angle + tolérance, hauteur), triés (cible
           verrouillée d'abord, puis angle, distance, numéro), une cible touchée une fois par coup, `maxTargets` par
           coup ; chaque cible passe par strike.run (chaîne de dégâts, usure), puis server/reactions.lua. Quand aucun
           joueur n'a été frappé, un mannequin d'entraînement peut l'être (server/dummies.lua, T-156 : mêmes portée,
           angle, hauteur, instance ; une fois par coup ; il compte dans `maxTargets`). Rien n'est
           rendu au client que l'acceptation ou le refus : aucun résultat. N'attend jamais lui-même (aucune attente,
           aucune base, aucun callClient) ; s'il est repris après un crochet ou un export qui a cédé la main, il
           revérifie que sa réservation tient toujours.
    Dépendances : shared/constants.lua, config_client.lua, config.lua, shared/weapons.lua, shared/geometry.lua,
                  shared/techniques.lua, shared/admission.lua, shared/defense.lua, server/core.lua, bridge/server.lua,
                  server/catalog.lua, server/strike.lua, server/hands.lua, server/reactions.lua, server/dummies.lua,
                  server/defense.lua
]]

local type, pairs, ipairs, tostring, pcall = type, pairs, ipairs, tostring, pcall
local tointeger, floor, max = math.tointeger, math.floor, math.max
local SetTimeout = SetTimeout

local bridge = VavaCombat.bridge
local weapons = VavaCombat.weapons
local geometry = VavaCombat.geometry
local techniques = VavaCombat.techniques
local catalog = VavaCombat.catalog
local strike = VavaCombat.strike
local hands = VavaCombat.hands
local reactions = VavaCombat.reactions
local defense = VavaCombat.defense
local dummies = VavaCombat.dummies
local cfg = VavaCombat.config
local HOOKS = VavaCombat.HOOKS
local SHIELD = VavaCombat.SHIELD_CATEGORY
local MAX_PLAYER, MAX_REASON = VavaCombat.MAX_PLAYER, VavaCombat.MAX_REASON

-- une ligne de console par joueur et par minute au plus pour un bond invraisemblable
local MOVED_WARN_MS = 60000

local ATTACKS, USABLE = {}, {}
for _, kind in ipairs(VavaCombat.ATTACK_TYPES) do ATTACKS[kind] = true end
for _, kind in ipairs(VavaCombat.USABLE_TYPES) do USABLE[kind] = true end

-- réservation annulée pendant que la demande était en suspens → code du refus
local CANCEL_CODES = { stagger = 'staggered', downed = 'downed', hands = 'no_weapon', left = 'no_character',
    parried = 'staggered', broken = 'guard_broken' }

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
---@field dummyHits table<integer, true>|nil  mannequins déjà frappés par ce coup (T-156)
---@field hitCount integer
---@field cancelled string|nil   annulé : ses relevés ne frappent plus, son cycle compte toujours
---@field pending true|nil       réservé, pas encore accepté (demande en cours de vérification)
---@field refused true|nil       réservation refusée (jamais rendue par la restitution)
---@field prev vAvA.Swing|nil    coup d'avant, gardé tant que la réservation n'est pas jugée

---@type table<integer, vAvA.Swing>  source → dernier coup (annulé ou non : son cycle compte) ou coup réservé
local current = {}
local seq = 0
-- source → instant du dernier avertissement « bond »
local movedWarnAt = {}
-- instant du dernier avertissement « erreur dans la vérification d'un coup » (une ligne par minute au plus)
local errorWarnAt = nil

--- Annule le coup en cours d'un joueur (ses relevés encore à venir ne frappent plus). Son cycle reste compté :
--- l'admission suivante attend sa récupération comme s'il était allé au bout ; une garde ouverte est fermée (tenue
--- minimale, récupération). Pendant une réservation, le coup d'avant (celui que rendrait un refus) est annulé aussi :
--- `cancelled` est toujours fiable.
---@param src integer
---@param reason string  hands | stagger | downed | left | moved | state | parried | broken
function swings.cancel(src, reason)
    local swing = current[src]
    local now = swing and bridge.Timer()
    while swing do
        if not swing.cancelled then swing.cancelled = reason end
        defense.close(swing, now)
        if not swing.pending and not swing.refused then break end
        swing = swing.prev
    end
end

--- Premier coup non refusé en remontant depuis `swing` (restitution d'une réservation refusée), ou nil.
---@param swing vAvA.Swing|nil
---@return vAvA.Swing|nil
local function standing(swing)
    while swing and swing.refused do swing = swing.prev end
    return swing
end

--- Coup en cours d'un joueur (lecture : T-113), ou nil. `pending` : réservé, pas encore accepté ; `cancelled` : annulé.
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

--- Ligne de console d'un relevé (debug.logSamples) ; `other` : joueur, ou `d<n>` pour un mannequin.
local function logSample(swing, k, other, distance, angle, outcome)
    VavaCombat.log.info('coup %d %s relevé %d : %s d=%s a=%s portée %s → %s', swing.seq, swing.id, k, tostring(other),
        weapons.tenth(distance or 0), tostring(angle and floor(angle + 0.5) or '-'), weapons.tenth(swing.arc.reach),
        tostring(outcome))
end

--- Relevé `k` d'un coup, à l'ouverture (1) puis à la fin (2) de la frappe.
---@param swing vAvA.Swing
---@param k integer
local function sample(swing, k)
    if not VavaCombat.ready or swing.cancelled then return end
    -- assez d'adversaires touchés : plus rien à relever (le cycle du coup compte de toute façon, annulé ou non)
    if swing.hitCount >= cfg.geometry.maxTargets then return end
    local src = swing.source
    if bridge.ActiveCharacterId(src) ~= swing.characterId then
        swing.cancelled = 'left'
        return
    end
    if bridge.IsDowned(src) or bridge.InVehicle(src) or reactions.staggeredSince(src, swing.startedAt)
        or bridge.MagicHardControl(src) then
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
        if other ~= src and not swing.hits[other] then
            local ox, oy, oz = bridge.Position(other)
            if ox then
                -- jugé en mémoire d'abord ; les exports seulement pour qui est dans l'arc
                local inside, distance, angle = geometry.inArc(position, heading, { x = ox, y = oy, z = oz }, arc)
                if inside and bridge.ActiveCharacterId(other) and not bridge.InVehicle(other)
                    and not bridge.IsDowned(other) then
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
        -- coup paré (ou annulé) par la cible précédente : plus rien dans ce relevé (relecture S-3)
        if index > room or swing.cancelled then break end
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
    -- un mannequin, seulement si aucun joueur n'a été frappé (il ne protège personne et ne vole aucun coup)
    if dummies and not swing.cancelled and swing.hitCount < cfg.geometry.maxTargets and dummies.count() > 0 then
        local done = swing.dummyHits or {}
        swing.dummyHits = done
        local d, distance, angle = dummies.candidate(src, position, heading, arc, done)
        if d then
            done[d.n] = true
            swing.hitCount = swing.hitCount + 1
            local outcome = dummies.strike(swing, d.n, held, position)
            if logging then logSample(swing, k, 'd' .. d.n, distance, angle, outcome or 'retenu') end
        end
    end
end


--- Vérifications qui appellent d'autres ressources (exports, crochet `vava_combat:using`), le coup déjà réservé : l'un
--- de ces appels peut céder la main (un crochet qui attend, un export qui attend), d'où la réservation posée avant.
--- Complète `swing` et rend `true`, ou `false, code[, détail]`.
---@param src integer
---@param swing vAvA.Swing  coup réservé (`pending`)
---@param target any        cible annoncée par le client
---@return boolean ok
---@return string|nil code
---@return integer|string|nil detail
local function confirm(src, swing, target)
    local id, def = swing.id, swing.def
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
    -- geste défensif : aucune cible ; garde : part bloquée et bouclier au bras lus une fois
    local attack = ATTACKS[def.type]
    target = attack and lockedTarget(src, target) or 0
    if def.type == 'blocage' then swing.guard = defense.guardOf(src, held, def, weapon) end
    local allowed, reason = bridge.RunBefore(HOOKS.USING, {
        source = src, characterId = characterId, technique = id, item = item, target = target ~= 0 and target or nil,
        kind = def.type,
    })
    if not allowed then return false, 'refused', weapons.reasonText(reason, MAX_REASON) end
    -- le crochet a pu céder la main : un contrôle dur posé entre-temps refuse aussi (relecture S-1 de T-149)
    if bridge.MagicHardControl(src) then return false, 'controlled' end
    local x, y, z = bridge.Position(src)
    if not x then return false, 'no_character' end
    -- peut-être repris après avoir cédé la main : la réservation doit tenir (module arrêté, joueur oublié, place prise,
    -- coup annulé entre-temps : refus)
    if not VavaCombat.ready then return false, 'not_ready' end
    local holder = current[src]
    if holder ~= swing then return false, holder and 'busy' or 'no_character' end
    if swing.cancelled then
        local code = CANCEL_CODES[swing.cancelled] or 'busy'
        if code == 'staggered' then return false, code, reactions.staggeredLeft(src, bridge.Timer()) end
        if code == 'guard_broken' then return false, code, defense.brokenLeft(src, bridge.Timer()) end
        return false, code
    end
    swing.style, swing.item, swing.instanceId, swing.characterId = style, item, held.id, characterId
    swing.target, swing.origin = target, { x = x, y = y, z = z }
    if attack then swing.arc = geometry.arcOf(def, weapon, cfg) end
    return true
end

--- Handler du RPC `vava_combat:use` (arguments déjà validés par le schéma). Rend `true` (coup accepté, fenêtre
--- programmée ; geste défensif : fenêtre ouverte), `false, code`, `false, code, attente` (busy, chain_limit, drawing,
--- staggered, guard_broken, parry_cooldown, dodge_cooldown) ou `false, 'refused', raison`.
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
    if not USABLE[def.type] then return false, 'not_attack' end
    local now = bridge.Timer()
    local stagger = reactions.staggeredLeft(src, now)
    if stagger then return false, 'staggered', stagger end
    local drawing = hands.drawingLeft(src, now)
    if drawing then return false, 'drawing', drawing end
    local refusal, refusalWait = defense.refusal(src, def, now)
    if refusal then return false, refusal, refusalWait end
    -- le dernier coup compte même annulé (quelle qu'en soit la cause) : récupération et enchaînement comme s'il était
    -- allé au bout ; s'annuler soi-même (bond, véhicule, arme changée) ne libère jamais plus tôt
    local prev = current[src]
    local admitted, chainCount, wait = techniques.admit(prev, def, id, now, {
        earlyMs = cfg.timing.earlyMs, chainMax = cfg.timing.chainMax, styles = cfg.styles,
    })
    if not admitted then return false, chainCount, wait end

    -- réservation : le coup tient la place AVANT tout appel qui peut céder la main ; une seconde demande arrivée
    -- pendant ce temps est jugée contre lui (busy), jamais contre le coup d'avant
    seq = seq + 1
    local plan = techniques.plan(def, now)
    local swing = {
        seq = seq, source = src, id = id, def = def, startedAt = plan.startedAt, openAt = plan.openAt,
        closeAt = plan.closeAt, endAt = plan.endAt, chainCount = chainCount, target = 0, hits = {}, hitCount = 0,
        cancelled = nil, pending = true, prev = prev,
    }
    -- le coup précédent n'est pas annulé : ses relevés encore à venir se font (une frappe ouverte va à son terme)
    current[src] = swing
    -- exports ensuite (sous pcall : une erreur rend la place comme un refus)
    local called, ok, code, detail = pcall(confirm, src, swing, target)
    if not called then
        local now2 = bridge.Timer()
        if not errorWarnAt or now2 - errorWarnAt >= MOVED_WARN_MS then
            errorWarnAt = now2
            VavaCombat.log.warn('joueur %d : erreur dans la vérification d\'un coup : %s', src, tostring(ok))
        end
        ok, code, detail = false, 'error', nil
    end
    if not ok then
        -- refus : jamais rendu ; la place revient au premier coup d'avant non refusé, tel quel (si elle est encore à
        -- cette réservation : rien n'est rendu à un joueur oublié ni par-dessus une autre réservation)
        swing.pending, swing.refused = nil, true
        if current[src] == swing then current[src] = standing(swing.prev) end
        return false, code, detail
    end
    swing.pending, swing.prev = nil, nil
    hands.noteHeld(src, swing.item)
    local accepted = bridge.Timer()
    defense.onAccepted(src, swing, accepted)
    -- geste défensif : aucune minuterie, sa fenêtre est une paire d'instants comparée à l'horloge quand un coup arrive
    if not ATTACKS[def.type] then return true end
    -- le cycle part de l'arrivée de la demande : le temps passé en suspens (0 d'ordinaire) est déduit des minuteries
    local late = accepted - now
    local phases = def.phases
    SetTimeout(max(0, phases.windup - late), function() sample(swing, 1) end)
    if cfg.timing.samples == 2 then
        SetTimeout(max(0, phases.windup + phases.active - late), function() sample(swing, 2) end)
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
    current, movedWarnAt, errorWarnAt = {}, {}, nil
end
