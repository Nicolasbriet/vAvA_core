--[[
    vava_magic/server/spells/mur_de_flammes.lua
    Rôle : sort Mur de flammes (zone visée), décidé par le serveur.
      - Début : pas dans une zone protégée ; point visé revérifié (portée du niveau depuis la position du lanceur lue
        côté serveur, écart de hauteur borné, hors zone protégée), plafond des zones du royaume.
      - Fin : la ligne est calculée ici, perpendiculaire à la direction lanceur → point visé, de la longueur et de la
        largeur du niveau ; ni ses bouts ni son centre dans une zone protégée. Au-delà de `maxPerCaster` murs, le plus
        ancien du lanceur s'éteint.
      - Tant qu'elle brûle : qui s'y tient ou la traverse (même en courant entre deux vérifications) perd des points de
        vie et repart en Brûlure, au plus une fois par `hitCooldownMs` ; jamais le lanceur ; un joueur mouillé sèche
        (combinaison : dégâts réduits, pas de brûlure). Le premier blessé rapporte au lanceur le bonus d'XP du sort,
        si le lancer a rapporté. L'eau (vague, trait de glace) l'éteint en vapeur (combinaison).
    Dépendances : shared/, config.lua, server/ (noyau, combat, states, zones, combos)
]]

local tostring = tostring
local GetGameTimer = GetGameTimer

local world = VavaMagic.world
local spells = VavaMagic.spells
local combat = VavaMagic.combat
local states = VavaMagic.states
local zones = VavaMagic.zones
local combos = VavaMagic.combos
local sheets = VavaMagic.sheets
local experience = VavaMagic.experience
local geometry = VavaMagic.geometry
local cfg = VavaMagic.config
local spellCfg = cfg.spells.mur_de_flammes
local NAME = 'mur_de_flammes'
local KIND = 'flames'
local COORD = { type = 'number', min = -20000, max = 20000 }

---@param point table
---@return boolean
local function protected(point)
    return combat.protected(point)
end

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
    local position = world.position(src)
    if not position then return false, 'no_position' end
    local levelCfg = spellCfg.levels[ctx.level]
    local point = ctx.data.point
    -- la ligne barre le chemin : perpendiculaire au regard du lanceur
    local segments = geometry.wallSegments(position, point, levelCfg.length) or geometry.wallSegments(ctx.origin, point, levelCfg.length)
    if not segments then return false, 'no_point' end
    local a, b = segments[1].a, segments[1].b
    if protected(a) or protected(b) or protected(point) then return false, 'protected_zone' end
    local sheet = sheets.get(src)
    local own = sheet and zones.ofCharacter(sheet.characterId, KIND) or {}
    for i = 1, #own - spellCfg.maxPerCaster + 1 do zones.remove(own[i].id, 'replaced') end
    local zone, code = zones.create({
        kind = KIND, spell = NAME, element = spellCfg.element, level = ctx.level, owner = src, shape = zones.LINE,
        a = a, b = b, width = levelCfg.width, durationMs = levelCfg.durationMs,
        data = { damage = levelCfg.damage, burn = levelCfg.burn, hits = {}, rewarded = false, bonus = false },
    })
    if not zone then return false, code end
    return {
        success = true, result = { id = zone.id },
        rewarded = function(granted) zone.data.rewarded = granted end,
    }
end

zones.define(KIND, {
    onTick = function(zone, victim)
        if victim == zone.owner and zone.ownerCharacter == (sheets.get(victim) or {}).characterId then return end
        local data = zone.data
        local now = GetGameTimer()
        if data.hits[victim] and now - data.hits[victim] < spellCfg.hitCooldownMs then return end
        data.hits[victim] = now
        local hit = combos.hit(zone.owner, victim, NAME, data.damage)
        if not combat.damage(zone.owner, victim, NAME, hit.damage, combat.KIND.AURA, zone.ownerCharacter) then return end
        if data.burn and hit.burn then
            states.apply(victim, 'burn', {
                durationMs = data.burn.durationMs, tickMs = data.burn.tickMs, damage = data.burn.damage,
                caster = zone.owner, spell = NAME,
            })
        end
        -- bonus du premier blessé, au lanceur toujours là (même personnage)
        local ownerSheet = sheets.get(zone.owner)
        if data.rewarded and not data.bonus and ownerSheet and ownerSheet.characterId == zone.ownerCharacter then
            data.bonus = true
            experience.bonus(zone.owner, NAME, spellCfg.hitXp or 0)
        end
    end,
})

local ok, err = spells.register(NAME, {
    config = spellCfg,
    beginArgs = { COORD, COORD, COORD },
    finishArgs = {},
    begin = begin,
    finish = finish,
})
if not ok then VavaMagic.log.error('Mur de flammes non déclaré : %s', tostring(err)) end
