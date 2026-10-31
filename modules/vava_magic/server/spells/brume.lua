--[[
    vava_magic/server/spells/brume.lua
    Rôle : sort Brume (zone visée), décidé par le serveur.
      - Début : point visé revérifié (server/zones.lua : portée du niveau, hauteur, zones protégées), plafond des zones
        du royaume.
      - Fin : un disque de brume au point visé, du rayon et de la durée du niveau ; une nouvelle brume du même
        personnage dissipe la précédente (`maxPerCaster`). Ce que l'on y voit est l'affaire du client de chacun (voile
        à l'écran de qui s'y tient, nappes vues du dehors).
      - Dès le niveau 3 : qui s'y tient est Mouillé (reposé au plus toutes les `refreshMs`), et la brume laisse à sa
        fin un sol mouillé. Le premier mouillé (pas le lanceur) rapporte au lanceur le bonus d'XP, si le lancer a
        rapporté.
    Dépendances : shared/, config.lua, server/ (noyau, combat, states, zones, grounds)
]]

local tostring = tostring
local GetGameTimer = GetGameTimer

local spells = VavaMagic.spells
local combat = VavaMagic.combat
local states = VavaMagic.states
local zones = VavaMagic.zones
local grounds = VavaMagic.grounds
local sheets = VavaMagic.sheets
local experience = VavaMagic.experience
local cfg = VavaMagic.config
local spellCfg = cfg.spells.brume
local NAME = 'brume'
local KIND = 'mist'
local COORD = { type = 'number', min = -20000, max = 20000 }

---@param ctx table
local function begin(ctx, x, y, z)
    local point, code = zones.aimed(ctx, x, y, z, spellCfg.levels[ctx.level].reach, spellCfg.heightMargin)
    if not point then return false, code end
    if zones.count() >= cfg.zones.maxActive then return false, 'zone_limit' end
    return true, { point = point }
end

---@param ctx table
local function finish(ctx)
    local src = ctx.source
    local levelCfg = spellCfg.levels[ctx.level]
    local sheet = sheets.get(src)
    local own = sheet and zones.ofCharacter(sheet.characterId, KIND) or {}
    for i = 1, #own - spellCfg.maxPerCaster + 1 do zones.remove(own[i].id, 'replaced') end
    local zone, code = zones.create({
        kind = KIND, spell = NAME, element = spellCfg.element, level = ctx.level, owner = src, shape = zones.CIRCLE,
        center = ctx.data.point, radius = levelCfg.radius, durationMs = levelCfg.durationMs,
        data = { wetMs = levelCfg.wetMs, groundMs = levelCfg.groundMs, applied = {}, rewarded = false, bonus = false },
    })
    if not zone then return false, code end
    return {
        success = true, result = { id = zone.id },
        rewarded = function(granted) zone.data.rewarded = granted end,
    }
end

zones.define(KIND, {
    onTick = function(zone, victim)
        local data = zone.data
        if data.wetMs <= 0 then return end
        local now = GetGameTimer()
        if data.applied[victim] and now - data.applied[victim] < spellCfg.refreshMs then return end
        if not combat.affects(victim, zone.owner, zone.ownerCharacter) then return end
        data.applied[victim] = now
        if not states.apply(victim, 'wet', { durationMs = data.wetMs, caster = zone.owner, spell = NAME }) then return end
        -- bonus du premier mouillé, au lanceur toujours là (même personnage), jamais pour lui-même
        local ownerSheet = sheets.get(zone.owner)
        if victim ~= zone.owner and data.rewarded and not data.bonus and ownerSheet and ownerSheet.characterId == zone.ownerCharacter then
            data.bonus = true
            experience.bonus(zone.owner, NAME, spellCfg.hitXp or 0)
        end
    end,
    -- une brume qui s'achève d'elle-même laisse le sol mouillé (pas une brume dissipée ni nettoyée)
    onEnd = function(zone, reason)
        if reason ~= 'expired' or zone.data.groundMs <= 0 then return end
        grounds.wet({
            spell = NAME, level = zone.level, owner = zone.owner, center = zone.center, radius = zone.radius,
            durationMs = zone.data.groundMs,
        })
    end,
})

local ok, err = spells.register(NAME, {
    config = spellCfg,
    beginArgs = { COORD, COORD, COORD },
    finishArgs = {},
    begin = begin,
    finish = finish,
})
if not ok then VavaMagic.log.error('Brume non déclarée : %s', tostring(err)) end
