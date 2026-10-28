--[[
    vava_magic/server/projectiles.lua
    Rôle : noyau commun des projectiles (boule de feu, trait de glace, projectile de roche), décidé par le serveur.
      - Début : impossible dans une zone protégée. Cible verrouillée (facultative) revérifiée : joueur en jeu, pas
        soi-même, à portée du niveau, hors zone protégée (positions serveur) ; elle seule est prévenue (un frisson).
      - Fin : vers la cible verrouillée, la direction est calculée ici (le client n'a pas son mot à dire) ; sans
        cible (ou si elle s'est échappée), celle de la caméra envoyée par le client, normalisée ici. Un sort peut
        échouer à ce moment (`fizzle`) ; sinon le lancer est noté (origine = position du lanceur lue côté serveur),
        annoncé aux seuls joueurs proches, qui en dessinent le vol ; il peut s'incurver vers la cible (`homing`).
      - Impact : signalé par le client du lanceur (rayon le long de la trajectoire), validé ici : lancer à lui, pas
        encore résolu ; point dans la portée et dans l'axe du lancer (virage permis compris) ; délai cohérent avec la
        vitesse ; cible réelle près du point annoncé ; un obstacle (rempart) sur le trajet arrête le projectile là où
        il se dresse. Les zones au sol traversées passent par les combinaisons (une boule de feu dissipe la brume,
        un trait de glace fait fumer un mur de flammes, une roche s'y embrase et emporte le feu jusqu'à l'impact).
        Le sort décide ensuite de l'effet (`onImpact`) : dégâts, états, éclats autour (jamais à travers un
        obstacle), bonus d'XP d'un sort qui touche ; puis l'effet emporté s'applique à la cible.
    Dépendances : shared/, config.lua, server/ (noyau, combat, states, zones, combos, obstacles)
]]

local ipairs, pairs, setmetatable = ipairs, pairs, setmetatable
local floor = math.floor
local GetGameTimer, SetTimeout, TriggerClientEvent, GetPlayerPing = GetGameTimer, SetTimeout, TriggerClientEvent, GetPlayerPing

local bridge = VavaMagic.bridge
local world = VavaMagic.world
local spells = VavaMagic.spells
local combat = VavaMagic.combat
local states = VavaMagic.states
local zones = VavaMagic.zones
local combos = VavaMagic.combos
local obstacles = VavaMagic.obstacles
local experience = VavaMagic.experience
local geometry = VavaMagic.geometry
local cfg = VavaMagic.config
local common = cfg.projectiles
local targetingCfg = cfg.targeting
local limits = cfg.rateLimits
local RPC = VavaMagic.RPC
local EVENTS = VavaMagic.EVENTS
local MS_PER_SECOND = 1000
-- en deçà, l'angle d'un point d'impact n'a pas de sens (contre le lanceur)
local ANGLE_MIN_DISTANCE = 2.0
-- au-delà, tout angle est possible
local MAX_ANGLE = 180
-- un impact annoncé contre la face d'un obstacle n'est pas « derrière » lui (demi-épaisseur d'un mur, en mètres)
local BLOCK_MARGIN = 0.75
local DIRECTION = { type = 'number', min = -1.01, max = 1.01 }
local COORD = { type = 'number', min = -20000, max = 20000 }
local LAUNCH_ID = { type = 'integer', min = 1, max = 0x7FFFFFFF }
local TARGET = { type = 'integer', min = 0, max = 65535 }

local projectiles = {}
VavaMagic.projectiles = projectiles

---@class vAvA.MagicLaunch
---@field id integer
---@field spell string
---@field source integer
---@field level integer
---@field origin table
---@field direction table
---@field speed number
---@field range number
---@field homing number     degrés par seconde dont il peut s'incurver vers sa cible
---@field target integer|nil
---@field launchedAt integer
---@field resolved boolean
---@field rewarded boolean  le lancer a rapporté de l'XP : un impact sur une cible rapporte le bonus
---@field bonus boolean     bonus déjà accordé
---@field carry table|nil   effet emporté par une combinaison sur le trajet (dégâts, brûlure)

---@type table<integer, vAvA.MagicLaunch>
local launches = {}
local nextLaunch = 0
---@type table<string, { config: table, hit: table, onImpact: function }>
local defs = {}

--- Contrôles du serveur d'un sort : ceux de `projectiles`, sauf ceux que le sort change dans son `hit`.
---@param spellCfg table
---@return table
local function hitOf(spellCfg)
    return setmetatable(spellCfg.hit or {}, { __index = common })
end

--- Position (torse) d'une cible verrouillée valable depuis ce point, ou nil : joueur en jeu, pas le lanceur, à portée
--- du niveau, hors zone protégée.
---@param src integer
---@param target integer
---@param from table
---@param levelCfg table
---@param hit table
---@return table|nil
local function lockedPosition(src, target, from, levelCfg, hit)
    if target == src or not bridge.GetCharacterId(target) then return nil end
    local position = world.position(target)
    if not position or combat.protected(position) then return nil end
    if geometry.distance(from, position) > levelCfg.range + targetingCfg.rangeMargin then return nil end
    return { x = position.x, y = position.y, z = position.z + hit.targetHeight }
end

--- Le point d'impact annoncé est-il possible pour ce lancer ?
---@param launch vAvA.MagicLaunch
---@param hit table
---@param point table
---@param src integer
---@return boolean
local function plausible(launch, hit, point, src)
    local distance = geometry.distance(launch.origin, point)
    if distance > launch.range + hit.rangeMargin then return false end
    local elapsed = GetGameTimer() - launch.launchedAt
    local earliest = distance / launch.speed * MS_PER_SECOND - hit.timeMarginMs
    local latest = launch.range / launch.speed * MS_PER_SECOND + hit.launchGraceMs + (GetPlayerPing(src) or 0)
    if elapsed < earliest or elapsed > latest then return false end
    if distance >= ANGLE_MIN_DISTANCE then
        -- un projectile qui s'incurve vers sa cible a pu tourner d'autant pendant son vol
        local turned = launch.homing * elapsed / MS_PER_SECOND
        local limit = hit.angleDeg + turned
        local angle = geometry.angle(launch.direction, launch.origin, point)
        if not angle or (limit < MAX_ANGLE and angle > limit) then return false end
    end
    return true
end

--- Le lancer a touché une cible : bonus d'XP du sort au lanceur, une fois, si le lancer a rapporté.
---@param launch vAvA.MagicLaunch
function projectiles.bonus(launch)
    if not launch.rewarded or launch.bonus then return end
    launch.bonus = true
    local def = defs[launch.spell]
    experience.bonus(launch.source, launch.spell, def and def.config.hitXp or 0)
end

--- Éclats d'un impact : blesse (part `points`) les joueurs à moins de `radius` du point, sauf le lanceur et la cible
--- directe, et pas à travers un obstacle. Renvoie les sources touchées.
---@param launch vAvA.MagicLaunch
---@param point table
---@param except integer   cible directe (0 : aucune)
---@param radius number
---@param points number
---@return integer[]
function projectiles.splash(launch, point, except, radius, points)
    local touched = {}
    for _, entry in ipairs(world.near(point, radius)) do
        local victim = entry.source
        if victim ~= launch.source and victim ~= except and not obstacles.blocked(point, entry.position) then
            local hit = combos.hit(launch.source, victim, launch.spell, points)
            if combat.damage(launch.source, victim, launch.spell, hit.damage, combat.KIND.ZONE) then touched[#touched + 1] = victim end
        end
    end
    return touched
end

--- Impact signalé par le client du lanceur : cible (0 = le décor) et point touché.
local function impact(src, id, target, x, y, z)
    local launch = launches[id]
    if not launch or launch.source ~= src or launch.resolved then return false, 'no_launch' end
    launch.resolved = true
    launches[id] = nil
    local def = defs[launch.spell]
    if not def then return false, 'no_launch' end
    local point = { x = x, y = y, z = z }
    if not plausible(launch, def.hit, point, src) then return false, 'invalid_impact' end
    -- un obstacle dressé sur le trajet arrête le projectile, quoi qu'annonce le client
    local wall = obstacles.blocked(launch.origin, point)
    if wall and geometry.distance(launch.origin, wall) + BLOCK_MARGIN < geometry.distance(launch.origin, point) then
        point, target = wall, 0
    end
    if target ~= 0 then
        local position = target ~= src and bridge.GetCharacterId(target) and world.position(target)
        if not position or geometry.distance(position, point) > def.hit.targetMargin then return false, 'invalid_impact' end
    end
    world.broadcast(point, def.hit.broadcastRadius, EVENTS.PROJECTILE_END, id, point.x, point.y, point.z, launch.spell)
    -- zones traversées en vol : combinaisons (l'effet emporté s'applique après celui du sort)
    for _, zone in ipairs(zones.crossedBy(launch.origin, point)) do
        local result = combos.zone({ caster = src, spell = launch.spell, point = point, projectile = launch }, zone)
        if result and result.carry then launch.carry = result.carry end
    end
    def.onImpact(launch, target, point)
    local carry = launch.carry
    if carry and target ~= 0 then
        local hit = combos.hit(src, target, launch.spell, carry.damage or 0, 'feu')
        if combat.damage(src, target, launch.spell, hit.damage, combat.KIND.IMPACT) and hit.burn and carry.burn then
            states.apply(target, 'burn', {
                durationMs = carry.burn.durationMs, tickMs = carry.burn.tickMs, damage = carry.burn.damage, caster = src, spell = launch.spell,
            })
        end
    end
    return true
end

--- Déclare un projectile. `handlers` : onImpact(launch, cible (0 : le décor), point) après validation ;
--- fizzle(ctx, levelCfg) facultatif, vrai si le projectile s'éteint entre les mains au lancer.
---@param name string
---@param spellCfg table
---@param handlers table
---@return boolean ok
---@return string|nil err
function projectiles.register(name, spellCfg, handlers)
    local hit = hitOf(spellCfg)
    defs[name] = { config = spellCfg, hit = hit, onImpact = handlers.onImpact }

    ---@param ctx table
    ---@param target integer|nil  cible verrouillée par le client
    local function begin(ctx, target)
        if combat.protected(ctx.origin) then return false, 'protected_zone' end
        if not target then return true, {} end
        if not lockedPosition(ctx.source, target, ctx.origin, spellCfg.levels[ctx.level], hit) then return false, 'invalid_target' end
        -- la cible sent la menace : elle a la durée de l'incantation pour réagir
        TriggerClientEvent(EVENTS.TARGETED, target)
        return true, { target = target }
    end

    ---@param ctx table
    local function finish(ctx, dx, dy, dz)
        local src = ctx.source
        local position = world.position(src)
        if not position then return false, 'no_position' end
        if combat.protected(position) then return false, 'protected_zone' end
        local levelCfg = spellCfg.levels[ctx.level]
        local origin = { x = position.x, y = position.y, z = position.z + hit.originHeight }
        -- cible verrouillée encore valable : direction décidée ici ; sinon, la visée libre du client
        local target = ctx.data.target
        local aimed = target and lockedPosition(src, target, origin, levelCfg, hit)
        local direction
        if aimed then
            direction = geometry.normalize(aimed.x - origin.x, aimed.y - origin.y, aimed.z - origin.z)
        else
            target = nil
            direction = geometry.normalize(dx, dy, dz)
        end
        if not direction then return false, 'invalid' end
        if handlers.fizzle and handlers.fizzle(ctx, levelCfg) then
            world.broadcast(position, hit.broadcastRadius, EVENTS.PROJECTILE, { id = 0, spell = name, caster = src, fizzle = true, level = ctx.level })
            return { success = false }
        end
        nextLaunch = nextLaunch % LAUNCH_ID.max + 1
        local launch = {
            id = nextLaunch, spell = name, source = src, level = ctx.level, origin = origin, direction = direction,
            speed = levelCfg.speed, range = levelCfg.range, homing = target and (levelCfg.homing or 0) or 0, target = target,
            launchedAt = GetGameTimer(), resolved = false, rewarded = false, bonus = false,
        }
        launches[launch.id] = launch
        local flightMs = floor(launch.range / launch.speed * MS_PER_SECOND)
        SetTimeout(flightMs + hit.launchGraceMs, function()
            if launches[launch.id] == launch then launches[launch.id] = nil end
        end)
        world.broadcast(origin, hit.broadcastRadius, EVENTS.PROJECTILE, {
            id = launch.id, spell = name, caster = src, dx = direction.x, dy = direction.y, dz = direction.z,
            speed = launch.speed, range = launch.range, level = ctx.level, fizzle = false,
            target = target or 0, homing = launch.homing,
        })
        return { success = true, result = { id = launch.id }, rewarded = function(granted) launch.rewarded = granted end }
    end

    return spells.register(name, {
        config = spellCfg,
        beginArgs = { { type = 'integer', min = 1, max = 65535, optional = true } },
        finishArgs = { DIRECTION, DIRECTION, DIRECTION },
        begin = begin,
        finish = finish,
    })
end

spells.addRpc(RPC.PROJECTILE_IMPACT, { LAUNCH_ID, TARGET, COORD, COORD, COORD }, limits.impact, impact)

spells.onLeave(function(src)
    for id, launch in pairs(launches) do
        if launch.source == src then launches[id] = nil end
    end
end)
