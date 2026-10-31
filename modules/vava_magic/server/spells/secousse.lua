--[[
    vava_magic/server/spells/secousse.lua
    Rôle : sort Secousse (zone visée, à retardement), décidé par le serveur.
      - Début : point visé revérifié (server/zones.lua : portée du niveau, hauteur, zones protégées), plafond des zones
        du royaume.
      - Fin : le sol se fend au point visé : une zone « présage » du rayon du niveau, vue des joueurs proches (anneau
        qui se resserre, poussière), le temps du `delayMs` du niveau : de quoi fuir.
      - Au terme du présage (pas s'il est nettoyé ou arrêté) : les joueurs proches voient le sol se soulever ; un sol
        mouillé sous le cercle devient de la boue (combinaison) ; ceux qui se tiennent alors dans le cercle (positions
        serveur, jamais le lanceur) perdent des points de vie et chancellent
        (ou sont renversés dès le niveau 4 : contrôles durs, protégés ensuite des autres). Si elle a touché quelqu'un
        et que le lancer a rapporté, le lanceur toujours là gagne le bonus d'XP du sort.
    Dépendances : shared/, config.lua, server/ (noyau, combat, states, zones, combos)
]]

local ipairs, tostring = ipairs, tostring

local world = VavaMagic.world
local spells = VavaMagic.spells
local combat = VavaMagic.combat
local states = VavaMagic.states
local zones = VavaMagic.zones
local combos = VavaMagic.combos
local sheets = VavaMagic.sheets
local experience = VavaMagic.experience
local cfg = VavaMagic.config
local spellCfg = cfg.spells.secousse
local EVENTS = VavaMagic.EVENTS
local NAME = 'secousse'
local KIND = 'quake'
local COORD = { type = 'number', min = -20000, max = 20000 }
-- hauteur ajoutée au rayon pour trouver les joueurs du cercle (m)
local HEIGHT = 2.5

---@param ctx table
local function begin(ctx, x, y, z)
    local point, code = zones.aimed(ctx, x, y, z, spellCfg.levels[ctx.level].reach, spellCfg.heightMargin)
    if not point then return false, code end
    if zones.count() >= cfg.zones.maxActive then return false, 'zone_limit' end
    return true, { point = point }
end

---@param ctx table
local function finish(ctx)
    local levelCfg = spellCfg.levels[ctx.level]
    local zone, code = zones.create({
        kind = KIND, spell = NAME, element = spellCfg.element, level = ctx.level, owner = ctx.source, shape = zones.CIRCLE,
        center = ctx.data.point, radius = levelCfg.radius, durationMs = levelCfg.delayMs,
        data = { damage = levelCfg.damage, control = levelCfg.control, controlMs = levelCfg.controlMs, rewarded = false },
    })
    if not zone then return false, code end
    return {
        success = true, result = { id = zone.id },
        rewarded = function(granted) zone.data.rewarded = granted end,
    }
end

--- Le sol se soulève : ceux qui sont dans le cercle sont frappés.
---@param zone table
local function strike(zone)
    local data = zone.data
    local center = zone.center
    world.broadcast(center, spellCfg.broadcastRadius, EVENTS.BURST, {
        spell = NAME, caster = zone.owner, x = center.x, y = center.y, z = center.z, radius = zone.radius, level = zone.level,
    })
    combos.quake(zone)
    local ownerSheet = sheets.get(zone.owner)
    local ownerHere = ownerSheet ~= nil and ownerSheet.characterId == zone.ownerCharacter
    local touched = 0
    for _, entry in ipairs(world.near(center, zone.radius + HEIGHT)) do
        local victim = entry.source
        if not (ownerHere and victim == zone.owner) and zones.contains(zone, entry.position)
            and combat.damage(zone.owner, victim, NAME, data.damage, combat.KIND.ZONE, zone.ownerCharacter, nil, zone.createdAt) then
            touched = touched + 1
            states.apply(victim, data.control, { durationMs = data.controlMs, caster = zone.owner, spell = NAME })
        end
    end
    if touched > 0 and data.rewarded and ownerHere then experience.bonus(zone.owner, NAME, spellCfg.hitXp or 0) end
end

zones.define(KIND, {
    onEnd = function(zone, reason)
        if reason == 'expired' then strike(zone) end
    end,
})

local ok, err = spells.register(NAME, {
    config = spellCfg,
    beginArgs = { COORD, COORD, COORD },
    finishArgs = {},
    begin = begin,
    finish = finish,
})
if not ok then VavaMagic.log.error('Secousse non déclarée : %s', tostring(err)) end
