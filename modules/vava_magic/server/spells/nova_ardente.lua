--[[
    vava_magic/server/spells/nova_ardente.lua
    Rôle : sort Nova ardente (zone centrée sur le lanceur), décidé par le serveur.
      - Début et fin : pas dans une zone protégée (position du lanceur lue côté serveur).
      - Fin : les joueurs en jeu dans le rayon du niveau (positions serveur), sauf le lanceur et ceux qu'un rempart
        abrite, perdent des points de vie (un joueur mouillé sèche : dégâts réduits, pas de brûlure) ; au niveau 3, ils sont repoussés (le serveur donne la direction, depuis le lanceur, à la seule victime) ;
        au niveau 4, ils repartent en Brûlure. Les joueurs proches voient la nova ; si elle a touché quelqu'un et que
        le lancer a rapporté, le lanceur gagne le bonus d'XP du sort.
    Dépendances : shared/, config.lua, server/ (noyau, combat, states, combos, obstacles)
]]

local ipairs, tostring = ipairs, tostring
local TriggerClientEvent = TriggerClientEvent

local world = VavaMagic.world
local spells = VavaMagic.spells
local combat = VavaMagic.combat
local states = VavaMagic.states
local combos = VavaMagic.combos
local obstacles = VavaMagic.obstacles
local experience = VavaMagic.experience
local geometry = VavaMagic.geometry
local cfg = VavaMagic.config
local spellCfg = cfg.spells.nova_ardente
local EVENTS = VavaMagic.EVENTS
local NAME = 'nova_ardente'

---@param ctx table
local function begin(ctx)
    if combat.protected(ctx.origin) then return false, 'protected_zone' end
    return true, {}
end

---@param ctx table
local function finish(ctx)
    local src = ctx.source
    local position = world.position(src)
    if not position then return false, 'no_position' end
    if combat.protected(position) then return false, 'protected_zone' end
    local levelCfg = spellCfg.levels[ctx.level]
    world.broadcast(position, spellCfg.broadcastRadius, EVENTS.BURST, {
        spell = NAME, caster = src, x = position.x, y = position.y, z = position.z, radius = levelCfg.radius, level = ctx.level,
    })
    local touched = 0
    for _, entry in ipairs(world.near(position, levelCfg.radius, src)) do
        local victim = entry.source
        local hit = not obstacles.blocked(position, entry.position) and combos.hit(src, victim, NAME, levelCfg.damage)
        if hit and combat.damage(src, victim, NAME, hit.damage, combat.KIND.ZONE) then
            touched = touched + 1
            if levelCfg.knockback > 0 then
                local away = geometry.direction2d(position, entry.position) or { x = 1.0, y = 0.0 }
                TriggerClientEvent(EVENTS.PUSH, victim, away.x, away.y, levelCfg.knockback)
            end
            if levelCfg.burn and hit.burn then
                states.apply(victim, 'burn', {
                    durationMs = levelCfg.burn.durationMs, tickMs = levelCfg.burn.tickMs, damage = levelCfg.burn.damage,
                    caster = src, spell = NAME,
                })
            end
        end
    end
    return {
        success = true, result = { touched = touched },
        rewarded = function(granted)
            if granted and touched > 0 then experience.bonus(src, NAME, spellCfg.hitXp or 0) end
        end,
    }
end

local ok, err = spells.register(NAME, {
    config = spellCfg,
    beginArgs = {},
    finishArgs = {},
    begin = begin,
    finish = finish,
})
if not ok then VavaMagic.log.error('Nova ardente non déclarée : %s', tostring(err)) end
