--[[
    vava_magic/server/zones.lua
    Rôle : zones au sol des sorts (mur de flammes, brume, sol mouillé, présage d'une secousse ; plus tard boue,
           vapeur), décidées par le serveur : genre, élément, forme (ligne avec une largeur, ou cercle), lanceur, fin.
      - Tant qu'il en existe, le serveur vérifie toutes les `zones.tickMs` les joueurs en jeu proches : dedans, ou qui
        ont traversé une ligne depuis la vérification précédente (un joueur qui court ne passe pas entre deux), et
        appelle le genre de la zone (`zones.define`), qui décide de l'effet (dégâts, état…) ; un genre peut n'agir
        qu'à la fin de sa zone (présage). Une vérification en erreur (un effet qui lève) est notée en console, au
        plus une fois par minute, et la suivante a lieu quand même : les zones ne cessent jamais d'agir pour de bon.
      - Chaque zone n'est envoyée qu'aux joueurs à moins de `zones.syncRadius`, y compris à ceux qui s'en approchent
        après sa naissance ; sa fin n'est envoyée qu'à ceux qui la connaissent. Jamais à tout le serveur.
      - Plafond pour tout le royaume ; nettoyage d'urgence du Conseil ; départ d'un joueur oublié de toutes les zones.
      - Pour les combinaisons : zones touchées par un trajet (projectile), zones recouvertes par un cercle (secousse).
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua, server/world.lua, server/spells.lua,
                  server/combat.lua
]]

local pairs, ipairs, abs, max, floor, sin, cos, pi, sort = pairs, ipairs, math.abs, math.max, math.floor, math.sin, math.cos, math.pi, table.sort
local GetGameTimer, SetTimeout, TriggerClientEvent = GetGameTimer, SetTimeout, TriggerClientEvent
local pcall, tostring = pcall, tostring

local bridge = VavaMagic.bridge
local world = VavaMagic.world
local spells = VavaMagic.spells
local combat = VavaMagic.combat
local geometry = VavaMagic.geometry
local cfg = VavaMagic.config.zones
local moveMargin = VavaMagic.config.casting.moveMargin
local EVENTS = VavaMagic.EVENTS
-- hauteur au-dessus et au-dessous de la zone où un joueur compte comme dedans (m)
local HEIGHT = 2.5
-- points d'un cercle pris pour juger s'il touche une autre forme (sur son bord)
local CIRCLE_SAMPLES = 8
-- au plus une ligne de console par minute pour une vérification en erreur
local ERROR_LOG_MS = 60000
local errorLoggedAt = nil

local zones = {}
VavaMagic.zones = zones

zones.LINE, zones.CIRCLE = 'line', 'circle'

---@class vAvA.MagicZone
---@field id integer
---@field kind string
---@field spell string
---@field element string
---@field level integer
---@field owner integer           source du lanceur (peut être parti)
---@field ownerCharacter integer
---@field shape string            'line' (a, b, width) ou 'circle' (center, radius)
---@field a table|nil
---@field b table|nil
---@field width number|nil
---@field center table
---@field radius number           rayon de l'enveloppe (cercle : son rayon)
---@field expiresAt integer
---@field createdAt integer    instant de la naissance (horloge du serveur) : lancement d'un présage
---@field viewers table<integer, true>
---@field last table<integer, table>  dernière position vue de chaque joueur proche
---@field data table              propre au sort (dégâts, brûlure…)

---@type table<integer, vAvA.MagicZone>
local active = {}
local count, lastId = 0, 0
local ticking = false
---@type table<string, { onTick?: fun(zone: vAvA.MagicZone, src: integer, position: table), onEnd?: fun(zone: vAvA.MagicZone, reason: string) }>
local kinds = {}

--- Genre de zone : `onTick(zone, joueur, position)` pour chaque joueur dedans à une vérification (facultatif),
--- `onEnd(zone, raison)` à sa fin (expired, replaced, extinguished, cleanup, stopped, removed…).
---@param kind string
---@param handlers table
function zones.define(kind, handlers)
    kinds[kind] = handlers
end

--- Ce que les clients reçoivent d'une zone (table à clés nommées seulement).
---@param zone vAvA.MagicZone
---@return table
local function public(zone)
    local payload = {
        id = zone.id, kind = zone.kind, spell = zone.spell, element = zone.element, level = zone.level, shape = zone.shape,
        ms = max(0, zone.expiresAt - GetGameTimer()),
    }
    if zone.shape == zones.LINE then
        payload.x, payload.y, payload.z = zone.a.x, zone.a.y, zone.a.z
        payload.x2, payload.y2, payload.z2 = zone.b.x, zone.b.y, zone.b.z
        payload.width = zone.width
    else
        payload.x, payload.y, payload.z = zone.center.x, zone.center.y, zone.center.z
        payload.radius = zone.radius
    end
    return payload
end

--- Le point est-il dans la zone ?
---@param zone vAvA.MagicZone
---@param point table
---@return boolean
function zones.contains(zone, point)
    if zone.shape == zones.LINE then
        local z = (zone.a.z + zone.b.z) / 2
        return abs(point.z - z) <= HEIGHT and geometry.segmentDistance2d(point, zone.a, zone.b) <= zone.width / 2
    end
    return abs(point.z - zone.center.z) <= HEIGHT and geometry.distance2d(point, zone.center) <= zone.radius
end

--- Le trajet [from, to] traverse-t-il la ligne de la zone ? (un cercle se juge à l'arrivée)
---@param zone vAvA.MagicZone
---@param from table
---@param to table
---@return boolean
function zones.crossed(zone, from, to)
    if zone.shape ~= zones.LINE then return false end
    local z = (zone.a.z + zone.b.z) / 2
    if abs(to.z - z) > HEIGHT then return false end
    return geometry.segmentsCross2d(from, to, zone.a, zone.b)
end

--- Zones qu'un trajet [from, to] touche (ligne traversée ou un bout dedans ; cercle à moins de son rayon du trajet),
--- de la plus ancienne à la plus récente.
---@param from table
---@param to table
---@return vAvA.MagicZone[]
function zones.crossedBy(from, to)
    local found = {}
    local z = (from.z + to.z) / 2
    for _, zone in pairs(active) do
        if abs(z - zone.center.z) <= HEIGHT then
            local touched
            if zone.shape == zones.LINE then
                touched = geometry.crossing2d(from, to, zone.a, zone.b) ~= nil or zones.contains(zone, from) or zones.contains(zone, to)
            else
                touched = geometry.segmentDistance2d(zone.center, from, to) <= zone.radius
            end
            if touched then found[#found + 1] = zone end
        end
    end
    sort(found, function(a, b) return a.id < b.id end)
    return found
end

--- Zones qu'un cercle au sol recouvre (au moins en partie), de la plus ancienne à la plus récente.
---@param center table
---@param radius number
---@return vAvA.MagicZone[]
function zones.touching(center, radius)
    local found = {}
    for _, zone in pairs(active) do
        if abs(center.z - zone.center.z) <= HEIGHT then
            local touched
            if zone.shape == zones.LINE then
                touched = geometry.segmentDistance2d(center, zone.a, zone.b) <= radius + zone.width / 2
            else
                touched = geometry.distance2d(center, zone.center) <= radius + zone.radius
            end
            if touched then found[#found + 1] = zone end
        end
    end
    sort(found, function(a, b) return a.id < b.id end)
    return found
end

--- Point visé par un sort au sol (mur, brume, secousse, rempart), revérifié au début de l'incantation : lanceur et
--- point hors zone protégée, point à portée du niveau depuis la position du lanceur lue côté serveur (marge des
--- positions réseau), écart de hauteur borné. Renvoie le point, ou nil et un code de refus.
---@param ctx table  contexte de l'incantation (origin)
---@param reach number
---@param heightMargin number
---@return table|nil point
---@return string|nil code
function zones.aimed(ctx, x, y, z, reach, heightMargin)
    if combat.protected(ctx.origin) then return nil, 'protected_zone' end
    local point = { x = x, y = y, z = z }
    if geometry.distance2d(ctx.origin, point) > reach + moveMargin then return nil, 'too_far' end
    if abs(point.z - ctx.origin.z) > heightMargin then return nil, 'no_point' end
    if combat.protected(point) then return nil, 'protected_zone' end
    return point
end

--- Points d'une zone pour juger si elle touche une autre forme : le long de la ligne (au plus `spacing` mètres
--- entre deux), ou le centre et le bord du cercle.
---@param zone vAvA.MagicZone
---@param spacing number
---@return table[]
function zones.samples(zone, spacing)
    local points = {}
    if zone.shape == zones.LINE then
        local steps = max(1, floor(geometry.distance2d(zone.a, zone.b) / spacing + 0.5))
        for i = 0, steps do
            local t = i / steps
            points[#points + 1] = { x = zone.a.x + (zone.b.x - zone.a.x) * t, y = zone.a.y + (zone.b.y - zone.a.y) * t, z = zone.center.z }
        end
        return points
    end
    points[1] = zone.center
    for i = 1, CIRCLE_SAMPLES do
        local angle = i / CIRCLE_SAMPLES * 2 * pi
        points[#points + 1] = { x = zone.center.x + cos(angle) * zone.radius, y = zone.center.y + sin(angle) * zone.radius, z = zone.center.z }
    end
    return points
end

---@param zone vAvA.MagicZone
---@param src integer
local function show(zone, src)
    zone.viewers[src] = true
    TriggerClientEvent(EVENTS.ZONE, src, public(zone))
end

--- Une vérification : joueurs proches de chaque zone, zones montrées à ceux qui approchent, effets.
local function tick()
    local positions = {}
    for _, src in ipairs(bridge.ActivePlayers()) do
        local position = world.position(src)
        if position then positions[src] = position end
    end
    for _, zone in pairs(active) do
        local handler = kinds[zone.kind]
        for src, position in pairs(positions) do
            local distance = geometry.distance2d(position, zone.center)
            if distance <= cfg.syncRadius and not zone.viewers[src] then show(zone, src) end
            if distance <= zone.radius + HEIGHT * 2 then
                local from = zone.last[src]
                zone.last[src] = position
                if handler and handler.onTick and (zones.contains(zone, position) or (from and zones.crossed(zone, from, position))) then
                    handler.onTick(zone, src, position)
                end
            else
                zone.last[src] = nil
            end
        end
    end
end

local function startTicking()
    if ticking then return end
    ticking = true
    local function loop()
        if count == 0 then
            ticking = false
            return
        end
        local ok, err = pcall(tick)
        if not ok then
            local now = GetGameTimer()
            if not errorLoggedAt or now - errorLoggedAt >= ERROR_LOG_MS then
                errorLoggedAt = now
                VavaMagic.log.error('vérification des zones en erreur (reprise au tour suivant) : %s', tostring(err))
            end
        end
        SetTimeout(cfg.tickMs, loop)
    end
    SetTimeout(cfg.tickMs, loop)
end

--- Éteint une zone ; ceux qui la connaissaient en sont prévenus.
---@param id integer
---@param reason? string  expired, replaced, cleanup, removed…
function zones.remove(id, reason)
    local zone = active[id]
    if not zone then return end
    active[id] = nil
    count = count - 1
    for src in pairs(zone.viewers) do TriggerClientEvent(EVENTS.ZONE_END, src, id) end
    local handler = kinds[zone.kind]
    if handler and handler.onEnd then handler.onEnd(zone, reason or 'removed') end
end

--- Crée une zone. `def` : kind, spell, element, level, owner, shape ('line' : a, b, width ; 'circle' : center,
--- radius), durationMs, data. Renvoie la zone, ou nil et 'zone_limit'.
---@param def table
---@return vAvA.MagicZone|nil zone
---@return string|nil code
function zones.create(def)
    if count >= cfg.maxActive then return nil, 'zone_limit' end
    lastId = lastId + 1
    local zone = {
        id = lastId, kind = def.kind, spell = def.spell, element = def.element, level = def.level,
        owner = def.owner, ownerCharacter = bridge.GetCharacterId(def.owner) or 0, shape = def.shape,
        createdAt = GetGameTimer(), expiresAt = GetGameTimer() + def.durationMs, viewers = {}, last = {},
        data = def.data or {},
    }
    if def.shape == zones.LINE then
        zone.a, zone.b, zone.width = def.a, def.b, def.width
        zone.center = { x = (def.a.x + def.b.x) / 2, y = (def.a.y + def.b.y) / 2, z = (def.a.z + def.b.z) / 2 }
        zone.radius = geometry.distance2d(def.a, def.b) / 2 + def.width / 2
    else
        zone.center, zone.radius = def.center, def.radius
    end
    active[zone.id] = zone
    count = count + 1
    -- les joueurs proches la voient tout de suite ; les autres en approchant
    for _, entry in ipairs(world.near(zone.center, cfg.syncRadius)) do show(zone, entry.source) end
    SetTimeout(def.durationMs, function()
        if active[zone.id] == zone then zones.remove(zone.id, 'expired') end
    end)
    startTicking()
    return zone
end

---@param id integer
---@return vAvA.MagicZone|nil
function zones.get(id)
    return active[id]
end

--- Zones d'un genre (toutes sans genre), de la plus ancienne à la plus récente.
---@param kind? string
---@return vAvA.MagicZone[]
function zones.list(kind)
    local list = {}
    for _, zone in pairs(active) do
        if not kind or zone.kind == kind then list[#list + 1] = zone end
    end
    sort(list, function(a, b) return a.id < b.id end)
    return list
end

--- Zones d'un genre créées par un personnage (le plus ancien d'abord).
---@param characterId integer
---@param kind string
---@return vAvA.MagicZone[]
function zones.ofCharacter(characterId, kind)
    local list = {}
    for _, zone in ipairs(zones.list(kind)) do
        if zone.ownerCharacter == characterId then list[#list + 1] = zone end
    end
    return list
end

---@return integer
function zones.count()
    return count
end

--- Le joueur est parti : oublié de toutes les zones.
---@param src integer
function zones.leave(src)
    for _, zone in pairs(active) do
        zone.viewers[src] = nil
        zone.last[src] = nil
    end
end

--- Éteint toutes les zones. Renvoie leur nombre.
---@param reason string
---@return integer
function zones.clearAll(reason)
    local removed = 0
    for id in pairs(active) do
        zones.remove(id, reason)
        removed = removed + 1
    end
    return removed
end

spells.onLeave(zones.leave)
spells.onStop(function() zones.clearAll('stopped') end)
spells.onCleanup(function() return zones.clearAll('cleanup') end)

