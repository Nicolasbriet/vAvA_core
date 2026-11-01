--[[
    vava_combat/server/dummies.lua
    Rôle : mannequins d'entraînement côté serveur (spec T-156 § 7.3 à § 7.9). Liste chargée de la config (contrôlée au
           démarrage), candidat d'un relevé de technique (après les joueurs : même portée, angle, hauteur, instance), coup
           d'arme « à blanc » (même paquet qu'un coup sur un joueur, montant par vava_health:trial, rien d'appliqué),
           coup de sort confié par une ressource admise (export dummyHit), usure réduite (un coup sur quatre en moyenne),
           envois (vava_combat:dummy : issue et montant à l'attaquant seul ; balancement aux témoins à `witnessRadius` du
           mannequin dans son instance, au plus un par mannequin et par `witnessMinMs`), hook `vava_combat:trained`.
           Jamais strike.run, jamais hit, jamais reactions.after : un mannequin n'est pas un joueur. Aucune XP. Ne cède
           jamais la main. Plus tard, la liste viendra des définitions de l'Atelier (`dummies.replace`) : seule sa
           source changera.
    Dépendances : shared/constants.lua, config_client.lua, config.lua, shared/dummies.lua, shared/geometry.lua,
                  shared/weapons.lua, server/core.lua, bridge/server.lua, server/catalog.lua, server/wear.lua
]]

local type, ipairs, tostring = type, ipairs, tostring
local tointeger, sqrt = math.tointeger, math.sqrt
local sort = table.sort

local bridge = VavaCombat.bridge
local weapons = VavaCombat.weapons
local geometry = VavaCombat.geometry
local rules = VavaCombat.dummyRules
local catalog = VavaCombat.catalog
local wear = VavaCombat.wear
local cfg = VavaCombat.config
local EVENTS = VavaCombat.EVENTS
local HOOKS = VavaCombat.HOOKS
local SHIELD = VavaCombat.SHIELD_CATEGORY
local MAX_PLAYER = VavaCombat.MAX_PLAYER
-- une ligne de console par minute et par sujet
local WARN_MS = 60000

local dummies = {}
VavaCombat.dummies = dummies

---@type vAvA.CombatDummy[]
local list = {}
---@type table<string, vAvA.CombatDummy>
local byId = {}
-- mannequin → instant du dernier balancement envoyé aux témoins
---@type table<integer, integer>
local witnessAt = {}
-- ressources admises à l'export dummyHit
local callers = {}
-- sujet → instant de la dernière ligne de console
local warnedAt = {}

---@param key string
---@param fmt string
local function warnLimited(key, fmt, ...)
    local now = bridge.Timer()
    local last = warnedAt[key]
    if last and now - last < WARN_MS then return end
    warnedAt[key] = now
    VavaCombat.log.warn(fmt, ...)
end

---@param value any
---@return number|nil
local function finite(value)
    if type(value) ~= 'number' or value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end

--- Distance 3D entre deux points `{ x, y, z }`.
local function distance(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return sqrt(dx * dx + dy * dy + dz * dz)
end

--- Remplace la liste des mannequins (déjà contrôlée) : config en v1, définitions de l'Atelier plus tard.
---@param entries table[]
function dummies.replace(entries)
    local d = cfg.dummies
    list, byId = rules.index(entries, d.model, d.centerHeight, d.label)
    witnessAt = {}
end

--- Démarrage : mannequins contrôlés (weapons.checkDummies, au seul serveur), index, ressources admises. Rend `true`,
--- ou `false, raison` (le module refuse de démarrer).
---@return boolean ok
---@return string|nil err
function dummies.start()
    local ok, err = weapons.checkDummies(cfg.dummies)
    if not ok then return false, err end
    dummies.replace(cfg.dummies.list)
    callers = {}
    for _, name in ipairs(cfg.dummies.callers) do callers[name] = true end
    return true
end

--- Arrêt du module : tout est oublié.
function dummies.stop()
    list, byId, witnessAt, warnedAt = {}, {}, {}, {}
end

--- Nombre de mannequins chargés.
---@return integer
function dummies.count()
    return #list
end

--- Mannequin par numéro, ou nil.
---@param n any
---@return vAvA.CombatDummy|nil
function dummies.get(n)
    local int = type(n) == 'number' and tointeger(n) or nil
    return int and list[int] or nil
end

--- Meilleur mannequin dans l'arc d'un relevé (spec § 7.3) : même instance, centre à `arc.reach + searchMargin` au plus
--- (distance au carré, en mémoire), gardé par geometry.inArc ; le plus en face, puis le plus proche, puis le plus petit
--- numéro. L'instance n'est lue (une native) que si un mannequin est assez près. Rend le mannequin, sa distance et son
--- angle, ou nil.
---@param src integer
---@param position table   position de l'attaquant lue par le serveur
---@param heading number   son cap
---@param arc table        arc de la technique (geometry.arcOf)
---@return vAvA.CombatDummy|nil
---@return number|nil distance
---@return number|nil angle
function dummies.candidate(src, position, heading, arc)
    local radius = arc.reach + cfg.geometry.searchMargin
    local limit = radius * radius
    local bucket, found = nil, nil
    for n, d in ipairs(list) do
        local c = d.center
        local dx, dy, dz = c.x - position.x, c.y - position.y, c.z - position.z
        if dx * dx + dy * dy + dz * dz <= limit then
            bucket = bucket or bridge.Bucket(src)
            if d.bucket == bucket then
                local inside, flat, angle = geometry.inArc(position, heading, c, arc)
                if inside then
                    found = found or {}
                    found[#found + 1] = { player = n, distance = flat, angle = angle }
                end
            end
        end
    end
    if not found then return nil end
    local best = geometry.order(found, nil)[1]
    return list[best.player], best.distance, best.angle
end

--- Envois d'un coup qui atteint un mannequin (spec § 7.7) : à l'attaquant, issue (et montant, ou `false` pour une issue
--- sans montant, si les chiffres lui sont montrés) ; aux témoins de l'instance du mannequin à `witnessRadius`, sans
--- l'attaquant, le balancement seul, au plus un par mannequin et par `witnessMinMs`. Jamais -1, jamais une liste vide.
---@param d vAvA.CombatDummy
---@param src integer
---@param issue string
---@param tenths integer|nil
function dummies.send(d, src, issue, tenths)
    local numbers = cfg.numbers
    if numbers.enabled and numbers.attacker then
        bridge.SendTo({ src }, EVENTS.DUMMY, d.n, src, issue, tenths or false)
    else
        bridge.SendTo({ src }, EVENTS.DUMMY, d.n, src, issue)
    end
    local settings = cfg.dummies
    if settings.witnessRadius <= 0 then return end
    local now = bridge.Timer()
    local last = witnessAt[d.n]
    if last and now - last < settings.witnessMinMs then return end
    -- posé même sans témoin : la recherche des proches ne se refait pas avant le délai
    witnessAt[d.n] = now
    local witnesses = {}
    for _, id in ipairs(bridge.PlayersAround(d.bucket, d.center, settings.witnessRadius)) do
        if id ~= src then witnesses[#witnesses + 1] = id end
    end
    if #witnesses > 0 then bridge.SendTo(witnesses, EVENTS.DUMMY, d.n, src) end
end

--- Coup d'arme à blanc sur le mannequin `n` (spec § 7.4), appelé par un relevé qui vient de revérifier l'attaquant
--- (même personnage, debout, à pied, pas chancelant, sans contrôle dur, même pile en main, bond plausible) et de lire
--- sa position. Rend l'issue envoyée, ou nil (coup retenu, refusé, ou vava_health muet).
---@param swing table      coup en cours ({ source, id, def, characterId })
---@param n integer
---@param held table       pile tenue, lue dans ce relevé
---@param position table   position de l'attaquant, lue dans ce relevé
---@return string|nil issue
function dummies.strike(swing, n, held, position)
    if not VavaCombat.ready then return nil end
    local d = list[n]
    if not d then return nil end
    local src = swing.source
    if distance(position, d.center) > cfg.strike.maxDistance then return nil end
    local item = held.item
    local weapon = catalog.weapon(item)
    if not weapon or weapon.category == SHIELD or not catalog.holdable(item) then return nil end
    local options = weapons.options({
        technique = swing.id, damage = swing.def.damage, tags = swing.def.parryable and { parryable = true } or nil,
    }, cfg)
    if not options then return nil end
    local amount = weapons.amount(weapon, held.metadata, options.damage, cfg)
    -- le même paquet qu'un coup sur un joueur ; le lieu est le centre visé
    local result, code = bridge.Trial(weapons.packet(item, weapon, amount, src, options), d.center)
    if not result then
        warnLimited('trial:' .. tostring(code), "coup sur un mannequin refusé par vava_health : %s", tostring(code))
        return nil
    end
    local issue, tenths = weapons.trialOutcome(result, swing.def)
    if not issue then return nil end
    -- usure réduite : un coup qui userait l'arme ne l'use qu'une fois sur 1 / wearChance (paille)
    if weapons.shouldWear(result, cfg) and math.random() < cfg.dummies.wearChance then
        wear.apply(src, held.id, item, weapon, swing.characterId)
    end
    dummies.send(d, src, issue, tenths)
    bridge.RunAfter(HOOKS.TRAINED, {
        source = src, characterId = swing.characterId, dummy = d.id, n = d.n, kind = 'melee', technique = swing.id,
        item = item, amount = result.amount, outcome = issue,
    })
    return issue
end

--- Export dummyHit (spec § 7.9) : un coup de sort confié par une ressource admise. Rend `{ outcome, amount }` ou
--- `nil, code` : `not_allowed`, `not_ready`, `invalid_dummy`, `no_character`, `too_far`, codes de vava_health:trial,
--- `health_unavailable`.
---@param caller string|nil  ressource appelante
---@param n any
---@param packet any
---@return table|nil
---@return string|nil code
function dummies.spellHit(caller, n, packet)
    if not callers[caller] then
        local key = tostring(caller)
        warnLimited('caller:' .. key, "export dummyHit refusé à la ressource '%s' (absente de dummies.callers)", key)
        return nil, 'not_allowed'
    end
    if not VavaCombat.ready then return nil, 'not_ready' end
    local d = dummies.get(n)
    if not d then return nil, 'invalid_dummy' end
    if type(packet) ~= 'table' then return nil, 'no_character' end
    local src = type(packet.source) == 'number' and tointeger(packet.source) or nil
    if not src or src <= 0 or src > MAX_PLAYER then return nil, 'no_character' end
    local characterId = bridge.ActiveCharacterId(src)
    if not characterId then return nil, 'no_character' end
    local x, y, z = bridge.Position(src)
    if not x or bridge.Bucket(src) ~= d.bucket
        or distance({ x = x, y = y, z = z }, d.center) > cfg.dummies.spellMaxDistance then
        return nil, 'too_far'
    end
    -- paquet contrôlé par vava_health, tel quel (un code de trial est rendu tel quel)
    local result, code = bridge.Trial(packet, d.center)
    if not result then return nil, code end
    local issue, tenths = weapons.trialOutcome(result, nil)
    if not issue then return { outcome = nil, amount = result.amount } end
    dummies.send(d, src, issue, tenths)
    bridge.RunAfter(HOOKS.TRAINED, {
        source = src, characterId = characterId, dummy = d.id, n = d.n, kind = 'spell',
        spell = type(packet.spell) == 'string' and packet.spell or nil, amount = result.amount, outcome = issue,
    })
    return { outcome = issue, amount = result.amount }
end

--- Export dummiesNear (spec § 7.9) : au plus `nearMax` mannequins dont le centre est à `radius` du point (copies
--- `{ n, id, x, y, z, distance }`, centre visé, triées par distance puis numéro) ; point illisible, rayon hors de
--- ]0, nearMaxRadius] ou module pas prêt : `{}`.
---@param point any
---@param radius any
---@return table[]
function dummies.near(point, radius)
    local settings = cfg.dummies
    if not VavaCombat.ready or type(point) ~= 'table' then return {} end
    local px, py, pz = finite(point.x), finite(point.y), finite(point.z)
    radius = finite(radius)
    if not px or not py or not pz or not radius or radius <= 0 or radius > settings.nearMaxRadius then return {} end
    local at = { x = px, y = py, z = pz }
    local out = {}
    for n, d in ipairs(list) do
        local gap = distance(at, d.center)
        if gap <= radius then
            local c = d.center
            out[#out + 1] = { n = n, id = d.id, x = c.x, y = c.y, z = c.z, distance = gap }
        end
    end
    sort(out, function(a, b)
        if a.distance ~= b.distance then return a.distance < b.distance end
        return a.n < b.n
    end)
    for i = #out, settings.nearMax + 1, -1 do out[i] = nil end
    return out
end

--- Export dummies() : liste (copies) `{ n, id, label, x, y, z, heading, bucket, model }` (pied du mannequin).
---@return table[]
function dummies.view()
    local out = {}
    for n, d in ipairs(list) do
        out[n] = { n = n, id = d.id, label = d.label, x = d.x, y = d.y, z = d.z, heading = d.heading, bucket = d.bucket,
            model = d.model }
    end
    return out
end

--- Mannequin par identifiant (outils, T-121), ou nil.
---@param id any
---@return vAvA.CombatDummy|nil
function dummies.byId(id)
    return byId[id]
end
