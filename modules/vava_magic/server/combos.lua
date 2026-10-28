--[[
    vava_magic/server/combos.lua
    Rôle : combinaisons entre éléments, décidées par le serveur d'après `config.combos` (déclencheur, résultat).
      - `combos.zone(ctx, zone)` : un sort (ou un projectile en vol) touche une zone au sol : la zone s'éteint, une
        autre naît à sa place (vapeur, boue), ou le projectile emporte l'effet jusqu'à l'impact (roche ardente).
      - `combos.hit(lanceur, cible, sort, dégâts)` : un sort touche un joueur dans un état : état posé (gel, soumis
        à l'immunité) ou retiré (séchage, extinction), dégâts réduits, brûlure empêchée ce coup-ci.
      - `combos.quake(zone)` : une secousse frappe : les sols mouillés qu'elle recouvre deviennent de la boue.
      - Zones nées des combinaisons : « steam » (légères brûlures à qui s'y tient, vue cachée côté client) et « mud »
        (ralenti fort tant qu'on y reste).
      - Une combinaison réussie s'inscrit dans le grimoire du lanceur la première fois (fiche), lui montre un mot bref
        (évènement ciblé), et se voit des joueurs proches (effet instantané).
    Dépendances : shared/, config.lua, server/ (noyau, sheets, states, zones, combat, world)
]]

local ipairs, pairs, sort = ipairs, pairs, table.sort
local GetGameTimer, TriggerClientEvent = GetGameTimer, TriggerClientEvent

local bridge = VavaMagic.bridge
local world = VavaMagic.world
local sheets = VavaMagic.sheets
local combat = VavaMagic.combat
local states = VavaMagic.states
local zones = VavaMagic.zones
local cfg = VavaMagic.config
local notify = cfg.texts.notify
local EVENTS = VavaMagic.EVENTS
-- genres de zone nés des combinaisons
local STEAM, MUD = 'steam', 'mud'
-- espacement des points d'une zone jugés contre une forme (m)
local SAMPLE_SPACING = 1.0

local combos = {}
VavaMagic.combos = combos

---@type table[]  combinaisons de la config, dans l'ordre du grimoire (id ajouté)
local list = {}
for id, combo in pairs(cfg.combos) do
    combo.id = id
    list[#list + 1] = combo
end
sort(list, function(a, b) return (a.order or 1000) < (b.order or 1000) end)

---@return table[]
function combos.all()
    return list
end

---@param id string
---@return table|nil
function combos.get(id)
    return cfg.combos[id]
end

--- Une combinaison réussie : grimoire du lanceur, mot bref, effet vu des joueurs proches.
---@param combo table
---@param caster integer
---@param point table|nil
---@param target? integer
local function trigger(combo, caster, point, target)
    if bridge.GetCharacterId(caster) then
        if sheets.discover(caster, combo.id) then bridge.Notify(caster, notify.comboDiscovered:format(combo.label), 'success') end
        TriggerClientEvent(EVENTS.COMBO, caster, combo.id)
    end
    if combo.fx and point then
        world.broadcast(point, cfg.effects.maxDistance, EVENTS.BURST, {
            spell = 'combo', combo = combo.id, caster = caster, x = point.x, y = point.y, z = point.z, target = target or 0,
        })
    end
end

--- Le déclencheur accepte-t-il ce sort ?
---@param triggerCfg table
---@param spell string
---@param element string|nil
---@return boolean
local function matches(triggerCfg, spell, element)
    if triggerCfg.spell then return triggerCfg.spell == spell end
    return triggerCfg.element ~= nil and triggerCfg.element == element
end

---@param spell string
---@return string|nil
local function elementOf(spell)
    local def = VavaMagic.spells.get(spell)
    return def and def.config.element or nil
end

--- Zone née d'une combinaison, à la place de la zone touchée (même centre, même enveloppe).
---@param combo table
---@param result table
---@param touched table
---@param caster integer
local function replace(combo, result, touched, caster)
    local data = {}
    if result.zone == STEAM then
        data = { damage = result.damage or 0, tickMs = result.tickMs or 1000, hits = {} }
    elseif result.zone == MUD then
        data = { slow = result.slow }
    end
    zones.create({
        kind = result.zone, spell = combo.id, element = result.element or 'eau', level = 1, owner = caster, shape = zones.CIRCLE,
        center = touched.center, radius = touched.radius, durationMs = result.durationMs or 5000, data = data,
    })
end

--- Un sort touche une zone au sol. `ctx` : caster, spell, point, projectile (le lancer, pour un projectile en vol).
--- Renvoie le résultat de la combinaison déclenchée (dont `carry` pour un projectile), ou nil.
---@param ctx table
---@param zone table
---@return table|nil
function combos.zone(ctx, zone)
    local element = elementOf(ctx.spell)
    for _, combo in ipairs(list) do
        local t = combo.trigger
        if t.on == 'zone' and t.zone == zone.kind and matches(t, ctx.spell, element) and (not t.projectile or ctx.projectile) then
            local result = combo.result
            if result.remove then zones.remove(zone.id, 'combo') end
            if result.zone then replace(combo, result, zone, ctx.caster) end
            trigger(combo, ctx.caster, ctx.point or zone.center)
            return result
        end
    end
    return nil
end

--- Un sort touche un joueur : combinaisons avec ses états. Renvoie { damage (ajustés), burn (brûlure permise),
--- frozen (la cible vient d'être gelée) }. `element` remplace celui du sort (projectile qui emporte le feu).
---@param caster integer
---@param target integer
---@param spell string
---@param damage number
---@param element? string
---@return table
function combos.hit(caster, target, spell, damage, element)
    local outcome = { damage = damage, burn = true, frozen = false }
    local position = combat.affects(target)
    if not position then return outcome end
    element = element or elementOf(spell)
    for _, combo in ipairs(list) do
        local t = combo.trigger
        if t.on == 'target' and matches(t, spell, element) and states.has(target, t.state) then
            local result = combo.result
            local applied = true
            if result.state then
                applied = states.apply(target, result.state, { durationMs = result.durationMs, caster = caster, spell = spell })
            end
            if applied then
                if result.consume then states.remove(target, result.consume) end
                if result.damageShare then outcome.damage = outcome.damage * result.damageShare end
                if result.noBurn then outcome.burn = false end
                if result.state == 'frozen' then outcome.frozen = true end
                trigger(combo, caster, position, target)
            end
        end
    end
    return outcome
end

--- Une secousse frappe : les zones qu'elle recouvre passent par les combinaisons (sol mouillé → boue).
---@param quake table  zone « quake » au terme de son présage
function combos.quake(quake)
    for _, zone in ipairs(zones.touching(quake.center, quake.radius)) do
        if zone.id ~= quake.id then
            combos.zone({ caster = quake.owner, spell = quake.spell, point = zone.center }, zone)
        end
    end
end

--- Une vague balaie : les zones dont un point est dans le cône passent par les combinaisons.
---@param caster integer
---@param spell string
---@param inside fun(point: table): boolean
---@return integer  zones éteintes ou transformées
function combos.sweep(caster, spell, inside)
    local count = 0
    for _, zone in ipairs(zones.list()) do
        for _, point in ipairs(zones.samples(zone, SAMPLE_SPACING)) do
            if inside(point) then
                if combos.zone({ caster = caster, spell = spell, point = point }, zone) then count = count + 1 end
                break
            end
        end
    end
    return count
end

-- Zones nées des combinaisons ---------------------------------------------------------------------------------------

zones.define(STEAM, {
    onTick = function(zone, victim)
        local data = zone.data
        local now = GetGameTimer()
        if data.hits[victim] and now - data.hits[victim] < data.tickMs then return end
        data.hits[victim] = now
        combat.damage(zone.owner, victim, zone.spell, data.damage, combat.KIND.ZONE, zone.ownerCharacter)
    end,
})

zones.define(MUD, {
    onTick = function(zone, victim)
        local slow = zone.data.slow
        if not slow or not combat.affects(victim) then return end
        states.apply(victim, 'slow', { durationMs = slow.durationMs, strength = slow.strength, caster = zone.owner, spell = zone.spell })
    end,
})
