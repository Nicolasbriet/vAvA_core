--[[
    vava_magic/server/grounds.lua
    Rôle : sols laissés par les sorts, décidés par le serveur (zones au sol en cercle, server/zones.lua) : sol mouillé
           (Vague, Brume) ; plus tard boue et vapeur. Qui se tient sur un sol mouillé est Mouillé, reposé au plus toutes
           les `wetGround.refreshMs` sur un même joueur (pas d'envoi à chaque vérification), lanceur compris : c'est le
           sol, pas le sort, qui mouille. Rien en zone protégée, ni si les sorts ne touchent personne (`combat.pvp`).
    Dépendances : shared/, config.lua, server/ (noyau, combat, states, zones)
]]

local GetGameTimer = GetGameTimer

local combat = VavaMagic.combat
local states = VavaMagic.states
local zones = VavaMagic.zones
local cfg = VavaMagic.config.wetGround

local grounds = {}
VavaMagic.grounds = grounds

grounds.WET = 'wet'

zones.define(grounds.WET, {
    onTick = function(zone, victim)
        local applied = zone.data.applied
        local now = GetGameTimer()
        if applied[victim] and now - applied[victim] < cfg.refreshMs then return end
        if not combat.affects(victim, zone.owner, zone.ownerCharacter) then return end
        applied[victim] = now
        states.apply(victim, 'wet', { durationMs = cfg.wetMs, caster = zone.owner, spell = zone.spell })
    end,
})

--- Laisse un sol mouillé. `def` : spell, level, owner, center, radius, durationMs. Renvoie la zone, ou nil et un code.
---@param def table
---@return table|nil zone
---@return string|nil code
function grounds.wet(def)
    return zones.create({
        kind = grounds.WET, spell = def.spell, element = 'eau', level = def.level, owner = def.owner, shape = zones.CIRCLE,
        center = def.center, radius = def.radius, durationMs = def.durationMs, data = { applied = {} },
    })
end
