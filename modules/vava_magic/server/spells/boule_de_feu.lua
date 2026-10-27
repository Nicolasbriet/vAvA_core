--[[
    vava_magic/server/spells/boule_de_feu.lua
    Rôle : sort Boule de feu (offensif), décidé par le serveur.
      - Début : impossible dans une zone protégée.
      - Fin : direction de la caméra envoyée par le client (normalisée ici) ; risque d'échec selon le niveau (elle
        s'éteint) ; sinon lancer noté (origine = position du lanceur lue côté serveur), annoncé aux seuls joueurs
        proches, qui en dessinent le vol.
      - Impact : signalé par le client du lanceur (rayon le long de la trajectoire). Le serveur valide : lancer à lui,
        pas encore résolu ; point d'impact dans la portée et dans l'axe du lancer ; délai cohérent avec la vitesse ;
        cible réelle près du point annoncé (position serveur) ; zones protégées ; dégâts entre joueurs activés. Puis il
        fait appliquer les dégâts (jamais sur la seule parole d'un client), la zone d'effet et la brûlure selon le
        niveau. Aucune explosion GTA : particules et son côté clients, dégâts par le script.
    Dépendances : shared/, config.lua, server/ (noyau)
]]

local ipairs, pairs, tostring = ipairs, pairs, tostring
local floor, random = math.floor, math.random
local GetGameTimer, SetTimeout, TriggerClientEvent, GetPlayerPing = GetGameTimer, SetTimeout, TriggerClientEvent, GetPlayerPing

local bridge = VavaMagic.bridge
local world = VavaMagic.world
local spells = VavaMagic.spells
local combat = VavaMagic.combat
local geometry = VavaMagic.geometry
local cfg = VavaMagic.config
local spellCfg = cfg.spells.boule_de_feu
local hitCfg = spellCfg.hit
local notify = cfg.texts.notify
local limits = cfg.rateLimits
local RPC = VavaMagic.RPC
local EVENTS = VavaMagic.EVENTS
local STATES = VavaMagic.STATES
local NAME = 'boule_de_feu'
local MS_PER_SECOND = 1000
-- en deçà, l'angle d'un point d'impact n'a pas de sens (contre le lanceur)
local ANGLE_MIN_DISTANCE = 2.0
local DIRECTION = { type = 'number', min = -1.01, max = 1.01 }
local COORD = { type = 'number', min = -20000, max = 20000 }
local LAUNCH_ID = { type = 'integer', min = 1, max = 0x7FFFFFFF }
local TARGET = { type = 'integer', min = 0, max = 65535 }

---@class vAvA.Fireball
---@field id integer
---@field source integer
---@field level integer
---@field origin table
---@field direction table
---@field speed number
---@field range number
---@field launchedAt integer
---@field resolved boolean

---@type table<integer, vAvA.Fireball>
local launches = {}
---@type table<integer, integer>  cible → jeton de sa brûlure
local burns = {}
local nextLaunch = 0

--- Annonce aux joueurs proches d'un point.
---@param point table
---@param event string
local function broadcast(point, event, ...)
    for _, entry in ipairs(world.near(point, hitCfg.broadcastRadius)) do
        TriggerClientEvent(event, entry.source, ...)
    end
end

--- La cible brûle : dégâts sur la durée, flammes vues des joueurs proches.
---@param caster integer
---@param target integer
---@param burnCfg table
local function ignite(caster, target, burnCfg)
    local token = (burns[target] or 0) + 1
    burns[target] = token
    world.setState(target, STATES.BURN, true)
    bridge.Notify(target, notify.burning, 'danger')
    local ticks = floor(burnCfg.durationMs / burnCfg.tickMs)
    local function tick(count)
        SetTimeout(burnCfg.tickMs, function()
            if burns[target] ~= token then return end
            combat.damage(caster, target, NAME, burnCfg.damage, combat.KIND.BURN)
            if count < ticks then
                tick(count + 1)
            else
                burns[target] = nil
                world.setState(target, STATES.BURN, nil)
            end
        end)
    end
    tick(1)
end

---@param ctx table
local function begin(ctx)
    if combat.protected(ctx.origin) then return false, 'protected_zone' end
    return true, {}
end

---@param ctx table
local function finish(ctx, dx, dy, dz)
    local src = ctx.source
    local direction = geometry.normalize(dx, dy, dz)
    if not direction then return false, 'invalid' end
    local position = world.position(src)
    if not position then return false, 'no_position' end
    if combat.protected(position) then return false, 'protected_zone' end
    local levelCfg = spellCfg.levels[ctx.level]
    if random() < levelCfg.fizzle then
        broadcast(position, EVENTS.FIREBALL, { id = 0, caster = src, fizzle = true, level = ctx.level })
        bridge.Notify(src, notify.fizzle, 'warning')
        return { success = false }
    end
    nextLaunch = nextLaunch % LAUNCH_ID.max + 1
    local launch = {
        id = nextLaunch, source = src, level = ctx.level,
        origin = { x = position.x, y = position.y, z = position.z + hitCfg.originHeight },
        direction = direction, speed = levelCfg.speed, range = levelCfg.range, launchedAt = GetGameTimer(), resolved = false,
    }
    launches[launch.id] = launch
    local flightMs = floor(launch.range / launch.speed * MS_PER_SECOND)
    SetTimeout(flightMs + hitCfg.launchGraceMs, function()
        if launches[launch.id] == launch then launches[launch.id] = nil end
    end)
    broadcast(launch.origin, EVENTS.FIREBALL, {
        id = launch.id, caster = src, dx = direction.x, dy = direction.y, dz = direction.z,
        speed = launch.speed, range = launch.range, level = ctx.level, fizzle = false,
    })
    return { success = true, result = { id = launch.id } }
end

--- Le point d'impact annoncé est-il possible pour ce lancer ?
---@param launch vAvA.Fireball
---@param point table
---@param src integer
---@return boolean
local function plausible(launch, point, src)
    local distance = geometry.distance(launch.origin, point)
    if distance > launch.range + hitCfg.rangeMargin then return false end
    local elapsed = GetGameTimer() - launch.launchedAt
    local earliest = distance / launch.speed * MS_PER_SECOND - hitCfg.timeMarginMs
    local latest = launch.range / launch.speed * MS_PER_SECOND + hitCfg.launchGraceMs + (GetPlayerPing(src) or 0)
    if elapsed < earliest or elapsed > latest then return false end
    if distance >= ANGLE_MIN_DISTANCE then
        local angle = geometry.angle(launch.direction, launch.origin, point)
        if not angle or angle > hitCfg.angleDeg then return false end
    end
    return true
end

--- Impact signalé par le client du lanceur : cible (0 = le décor) et point touché.
local function impact(src, id, target, x, y, z)
    local launch = launches[id]
    if not launch or launch.source ~= src or launch.resolved then return false, 'no_launch' end
    launch.resolved = true
    launches[id] = nil
    local point = { x = x, y = y, z = z }
    if not plausible(launch, point, src) then return false, 'invalid_impact' end
    if target ~= 0 then
        local position = target ~= src and bridge.GetCharacterId(target) and world.position(target)
        if not position or geometry.distance(position, point) > hitCfg.targetMargin then return false, 'invalid_impact' end
    end
    broadcast(point, EVENTS.FIREBALL_END, id, x, y, z)

    local levelCfg = spellCfg.levels[launch.level]
    if target ~= 0 and combat.damage(src, target, NAME, levelCfg.damage, combat.KIND.IMPACT)
        and levelCfg.burn and spellCfg.burnEnabled then
        ignite(src, target, levelCfg.burn)
    end
    if levelCfg.aoeRadius > 0 then
        for _, entry in ipairs(world.near(point, levelCfg.aoeRadius)) do
            if entry.source ~= src and entry.source ~= target then
                combat.damage(src, entry.source, NAME, levelCfg.damage * levelCfg.aoeShare, combat.KIND.ZONE)
            end
        end
    end
    return true
end

spells.addRpc(RPC.FIREBALL_IMPACT, { LAUNCH_ID, TARGET, COORD, COORD, COORD }, limits.impact, impact)

spells.onLeave(function(src)
    if burns[src] then
        burns[src] = nil
        world.setState(src, STATES.BURN, nil)
    end
    for id, launch in pairs(launches) do
        if launch.source == src then launches[id] = nil end
    end
end)

local ok, err = spells.register(NAME, {
    config = spellCfg,
    beginArgs = {},
    finishArgs = { DIRECTION, DIRECTION, DIRECTION },
    begin = begin,
    finish = finish,
})
if not ok then VavaMagic.log.error('Boule de feu non déclarée : %s', tostring(err)) end
