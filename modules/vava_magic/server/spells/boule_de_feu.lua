--[[
    vava_magic/server/spells/boule_de_feu.lua
    Rôle : sort Boule de feu (projectile offensif), décidé par le serveur sur le noyau des projectiles
           (server/projectiles.lua : cible verrouillée, direction, vol, validation de l'impact, obstacles).
      - Au lancer : risque d'échec selon le niveau (elle s'éteint entre les mains).
      - À l'impact validé : combinaisons de la cible (séchage d'une cible mouillée : dégâts réduits, pas de
        brûlure), dégâts, bonus d'XP d'un sort qui touche ; éclats autour du point aux niveaux 3 à 5 ; Brûlure de la
        cible au niveau 4 (un état, server/states.lua). Aucune explosion GTA : particules et son côté clients, dégâts
        par le script. Aux niveaux 4 et 5, elle s'incurve vers la cible verrouillée.
    Dépendances : shared/, config.lua, server/ (noyau, combat, states, combos, projectiles)
]]

local tostring, random = tostring, math.random

local bridge = VavaMagic.bridge
local combat = VavaMagic.combat
local states = VavaMagic.states
local combos = VavaMagic.combos
local projectiles = VavaMagic.projectiles
local cfg = VavaMagic.config
local spellCfg = cfg.spells.boule_de_feu
local notify = cfg.texts.notify
local NAME = 'boule_de_feu'

--- La cible brûle : dégâts sur la durée (état Brûlure, vu des joueurs proches).
---@param caster integer
---@param target integer
---@param burnCfg table
---@param casterCharacter? integer
local function ignite(caster, target, burnCfg, casterCharacter)
    if states.apply(target, 'burn', {
        durationMs = burnCfg.durationMs, tickMs = burnCfg.tickMs, damage = burnCfg.damage, caster = caster,
        casterCharacter = casterCharacter, spell = NAME,
    }) then
        bridge.Notify(target, notify.burning, 'danger')
    end
end

local ok, err = projectiles.register(NAME, spellCfg, {
    fizzle = function(ctx, levelCfg)
        if random() >= levelCfg.fizzle then return false end
        bridge.Notify(ctx.source, notify.fizzle, 'warning')
        return true
    end,
    onImpact = function(launch, target, point)
        local levelCfg = spellCfg.levels[launch.level]
        if target ~= 0 then
            local hit = combos.hit(launch.source, target, NAME, levelCfg.damage, nil, launch.casterCharacter)
            if combat.damage(launch.source, target, NAME, hit.damage, combat.KIND.IMPACT, launch.casterCharacter, nil,
                launch.strikeLaunchedAt) then
                combos.commit(hit)
                projectiles.bonus(launch)
                if hit.burn and levelCfg.burn and spellCfg.burnEnabled then
                    ignite(launch.source, target, levelCfg.burn, launch.casterCharacter)
                end
            end
        end
        if levelCfg.aoeRadius > 0 then
            projectiles.splash(launch, point, target, levelCfg.aoeRadius, levelCfg.damage * levelCfg.aoeShare)
        end
    end,
})
if not ok then VavaMagic.log.error('Boule de feu non déclarée : %s', tostring(err)) end
