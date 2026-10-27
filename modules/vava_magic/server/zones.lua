--[[
    vava_magic/server/zones.lua
    Rôle : zones au sol des sorts (mur de flammes ; plus tard brume, sol mouillé, boue, vapeur), décidées par le
           serveur : genre, élément, forme (ligne avec une largeur, ou cercle), lanceur, fin.
      - Tant qu'il en existe, le serveur vérifie toutes les `zones.tickMs` les joueurs en jeu proches : dedans, ou qui
        ont traversé une ligne depuis la vérification précédente (un joueur qui court ne passe pas entre deux), et
        appelle le genre de la zone (`zones.define`), qui décide de l'effet (dégâts, état…).
      - Chaque zone n'est envoyée qu'aux joueurs à moins de `zones.syncRadius`, y compris à ceux qui s'en approchent
        après sa naissance ; sa fin n'est envoyée qu'à ceux qui la connaissent. Jamais à tout le serveur.
      - Plafond pour tout le royaume ; nettoyage d'urgence du Conseil ; départ d'un joueur oublié de toutes les zones.
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua, server/world.lua, server/spells.lua
]]

local pairs, ipairs, abs, max, sort = pairs, ipairs, math.abs, math.max, table.sort
local GetGameTimer, SetTimeout, TriggerClientEvent = GetGameTimer, SetTimeout, TriggerClientEvent

local bridge = VavaMagic.bridge
local world = VavaMagic.world
local spells = VavaMagic.spells
local geometry = VavaMagic.geometry
local cfg = VavaMagic.config.zones
local EVENTS = VavaMagic.EVENTS
-- hauteur au-dessus et au-dessous de la zone où un joueur compte comme dedans (m)
local HEIGHT = 2.5

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
---@field viewers table<integer, true>
---@field last table<integer, table>  dernière position vue de chaque joueur proche
---@field data table              propre au sort (dégâts, brûlure…)

---@type table<integer, vAvA.MagicZone>
local active = {}
local count, lastId = 0, 0
local ticking = false
---@type table<string, { onTick: fun(zone: vAvA.MagicZone, src: integer, position: table), onEnd?: fun(zone: vAvA.MagicZone, reason: string) }>
local kinds = {}

--- Genre de zone : `onTick(zone, joueur, position)` pour chaque joueur dedans à une vérification, `onEnd(zone, raison)`.
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
                if handler and (zones.contains(zone, position) or (from and zones.crossed(zone, from, position))) then
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
        tick()
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
        expiresAt = GetGameTimer() + def.durationMs, viewers = {}, last = {}, data = def.data or {},
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

