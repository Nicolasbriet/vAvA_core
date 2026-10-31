--[[
    vava_magic/server/spells/projectile_de_roche.lua
    Rôle : sort Projectile de roche (projectile offensif, lent et lourd), décidé par le serveur sur le noyau des
           projectiles (server/projectiles.lua). À l'impact validé : gros dégâts à la cible et bonus d'XP d'un sort
           qui touche ; dès le niveau 3, la cible chancelle (contrôle dur : protégée ensuite des autres) ; au niveau 5,
           le bloc éclate et ses éclats blessent ceux qui entourent le point d'impact (jamais à travers un rempart).
    Dépendances : shared/, config.lua, server/ (noyau, combat, states, projectiles)
]]

local tostring = tostring

local combat = VavaMagic.combat
local states = VavaMagic.states
local projectiles = VavaMagic.projectiles
local spellCfg = VavaMagic.config.spells.projectile_de_roche
local NAME = 'projectile_de_roche'

local ok, err = projectiles.register(NAME, spellCfg, {
    onImpact = function(launch, target, point)
        local levelCfg = spellCfg.levels[launch.level]
        if target ~= 0
            and combat.damage(launch.source, target, NAME, levelCfg.damage, combat.KIND.IMPACT, nil, nil, launch.launchedAt) then
            projectiles.bonus(launch)
            if levelCfg.staggerMs > 0 then
                states.apply(target, 'stagger', { durationMs = levelCfg.staggerMs, caster = launch.source, spell = NAME })
            end
        end
        if levelCfg.aoeRadius > 0 then
            projectiles.splash(launch, point, target, levelCfg.aoeRadius, levelCfg.damage * levelCfg.aoeShare)
        end
    end,
})
if not ok then VavaMagic.log.error('Projectile de roche non déclaré : %s', tostring(err)) end
