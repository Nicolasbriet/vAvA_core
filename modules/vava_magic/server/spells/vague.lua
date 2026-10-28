--[[
    vava_magic/server/spells/vague.lua
    Rôle : sort Vague (cône devant le lanceur), décidé par le serveur.
      - Début et fin : pas dans une zone protégée (position du lanceur lue côté serveur).
      - Fin : le cône part de la position du lanceur, dans la direction du regard envoyée par le client (normalisée ici
        ; c'est son choix de visée), de la portée et de l'ouverture du niveau. Les joueurs proches voient la vague.
        Les zones de feu qu'elle touche s'éteignent (`extinguishes`). Les joueurs en jeu dans le cône (sauf le lanceur,
        et pas à travers un rempart) que les sorts peuvent toucher sont repoussés (direction donnée par le serveur),
        Mouillés, leur Brûlure noyée, et Renversés dès le niveau 4 (contrôle dur : protégés ensuite des autres). Un
        sol mouillé reste devant le lanceur. Si elle a touché quelqu'un et que le lancer a rapporté, le lanceur gagne
        le bonus d'XP du sort.
    Dépendances : shared/, config.lua, server/ (noyau, combat, states, zones, grounds, obstacles)
]]

local ipairs, tostring, abs = ipairs, tostring, math.abs
local TriggerClientEvent = TriggerClientEvent

local world = VavaMagic.world
local spells = VavaMagic.spells
local combat = VavaMagic.combat
local states = VavaMagic.states
local zones = VavaMagic.zones
local grounds = VavaMagic.grounds
local obstacles = VavaMagic.obstacles
local experience = VavaMagic.experience
local geometry = VavaMagic.geometry
local spellCfg = VavaMagic.config.spells.vague
local EVENTS = VavaMagic.EVENTS
local NAME = 'vague'
local DIRECTION = { type = 'number', min = -1.01, max = 1.01 }
-- écart de hauteur permis entre le lanceur et ce que touche la vague (m)
local HEIGHT = 2.5
-- espacement des points d'une zone jugés pour l'éteindre (m)
local SAMPLE_SPACING = 1.0

---@param ctx table
local function begin(ctx)
    if combat.protected(ctx.origin) then return false, 'protected_zone' end
    return true, {}
end

--- Le point est-il dans le cône de la vague ?
local function inWave(point, apex, forward, levelCfg)
    return abs(point.z - apex.z) <= HEIGHT and geometry.inCone2d(point, apex, forward, levelCfg.range, levelCfg.halfAngle)
end

--- Éteint les zones de feu que la vague touche. Renvoie leur nombre.
local function extinguish(apex, forward, levelCfg)
    local count = 0
    for _, zone in ipairs(zones.list()) do
        if spellCfg.extinguishes[zone.kind] then
            for _, point in ipairs(zones.samples(zone, SAMPLE_SPACING)) do
                if inWave(point, apex, forward, levelCfg) then
                    zones.remove(zone.id, 'extinguished')
                    count = count + 1
                    break
                end
            end
        end
    end
    return count
end

---@param ctx table
local function finish(ctx, dx, dy)
    local src = ctx.source
    local position = world.position(src)
    if not position then return false, 'no_position' end
    if combat.protected(position) then return false, 'protected_zone' end
    local forward = geometry.direction2d({ x = 0, y = 0 }, { x = dx, y = dy })
    if not forward then return false, 'invalid' end
    local levelCfg = spellCfg.levels[ctx.level]
    world.broadcast(position, spellCfg.broadcastRadius, EVENTS.BURST, {
        spell = NAME, caster = src, x = position.x, y = position.y, z = position.z, dx = forward.x, dy = forward.y,
        range = levelCfg.range, angle = levelCfg.halfAngle, level = ctx.level,
    })
    local extinguished = extinguish(position, forward, levelCfg)
    local touched = 0
    for _, entry in ipairs(world.near(position, levelCfg.range + HEIGHT, src)) do
        local victim = entry.source
        if inWave(entry.position, position, forward, levelCfg) and not obstacles.blocked(position, entry.position)
            and combat.affects(victim) then
            touched = touched + 1
            combat.react(victim, NAME)
            states.remove(victim, 'burn')
            states.apply(victim, 'wet', { durationMs = levelCfg.wetMs, caster = src, spell = NAME })
            local away = geometry.direction2d(position, entry.position) or forward
            TriggerClientEvent(EVENTS.PUSH, victim, away.x, away.y, levelCfg.knockback)
            if levelCfg.knockdownMs > 0 then
                states.apply(victim, 'knockdown', { durationMs = levelCfg.knockdownMs, caster = src, spell = NAME })
            end
        end
    end
    if levelCfg.groundMs > 0 then
        local half = levelCfg.range / 2
        grounds.wet({
            spell = NAME, level = ctx.level, owner = src, radius = half, durationMs = levelCfg.groundMs,
            center = { x = position.x + forward.x * half, y = position.y + forward.y * half, z = position.z },
        })
    end
    return {
        success = true, result = { touched = touched, extinguished = extinguished },
        rewarded = function(granted)
            if granted and touched > 0 then experience.bonus(src, NAME, spellCfg.hitXp or 0) end
        end,
    }
end

local ok, err = spells.register(NAME, {
    config = spellCfg,
    beginArgs = {},
    finishArgs = { DIRECTION, DIRECTION },
    begin = begin,
    finish = finish,
})
if not ok then VavaMagic.log.error('Vague non déclarée : %s', tostring(err)) end
