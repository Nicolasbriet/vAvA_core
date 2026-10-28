--[[
    vava_magic/server/spells/trait_de_glace.lua
    Rôle : sort Trait de glace (projectile offensif, rapide), décidé par le serveur sur le noyau des projectiles
           (server/projectiles.lua). À l'impact validé : dégâts modestes à la cible, puis Ralenti (force et durée
           selon le niveau) et Mouillé ; bonus d'XP d'un sort qui touche. Aux niveaux 4 et 5, il s'incurve vers la
           cible verrouillée.
    Dépendances : shared/, config.lua, server/ (noyau, combat, states, projectiles)
]]

local tostring = tostring

local combat = VavaMagic.combat
local states = VavaMagic.states
local projectiles = VavaMagic.projectiles
local spellCfg = VavaMagic.config.spells.trait_de_glace
local NAME = 'trait_de_glace'

local ok, err = projectiles.register(NAME, spellCfg, {
    onImpact = function(launch, target)
        if target == 0 then return end
        local levelCfg = spellCfg.levels[launch.level]
        if not combat.damage(launch.source, target, NAME, levelCfg.damage, combat.KIND.IMPACT) then return end
        projectiles.bonus(launch)
        local slow = levelCfg.slow
        states.apply(target, 'slow', { durationMs = slow.durationMs, strength = slow.strength, caster = launch.source, spell = NAME })
        states.apply(target, 'wet', { durationMs = levelCfg.wetMs, caster = launch.source, spell = NAME })
    end,
})
if not ok then VavaMagic.log.error('Trait de glace non déclaré : %s', tostring(err)) end
