--[[
    vava_magic/client/spells/brume.lua
    Rôle : sort Brume côté client : clic gauche en visant le sol (mode magie) = incantation, le point visé part au
           début (aperçu au sol : le disque du niveau) ; sans visée, ou trop loin, rien ne part. Sa zone « mist » est
           une nuée (client/clouds.lua) : nappes vues du dehors, voile et flou à l'écran de qui s'y tient, plus épais
           selon le niveau.
    Dépendances : shared/, config.lua, client/ (noyau, controls, clouds)
]]

local controls = VavaMagic.controls
local clouds = VavaMagic.clouds
local spellCfg = VavaMagic.config.spells.brume
local NAME = 'brume'

clouds.define('mist', {
    fx = spellCfg.fx,
    timecycle = spellCfg.screen.timecycle,
    density = function(zone) return (spellCfg.levels[zone.level] or spellCfg.levels[1]).density end,
    scale = function(zone) return spellCfg.levelScale[zone.level] or 1.0 end,
})

controls.registerPoint(NAME)
