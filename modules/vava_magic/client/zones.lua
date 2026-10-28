--[[
    vava_magic/client/zones.lua
    Rôle : rendu des zones au sol envoyées par le serveur (qui seul en décide : forme, fin, effets sur les joueurs).
      - Mur de flammes (genre « flames ») : flammes en boucle le long de la ligne, serrées de près, espacées de loin,
        rien au-delà de la distance des effets ; embrasement à la naissance, fumée à l'extinction (ou noyé par une
        vague) ; lumières dynamiques le long du mur, qui éclairent le décor et les personnages (dans les plafonds de
        client/fx.lua).
      - Sol mouillé (genre « wet », Vague et Brume) : reflet d'eau posé au sol, gouttes à sa naissance.
      - Les autres genres se déclarent avec `zones.define` depuis le fichier de leur sort (brume, présage d'une
        secousse).
    Une recherche toutes les 250 ms choisit le niveau de détail ; le dessin par image (lumières, reflets, présages) ne
    tourne que tant qu'une zone visible a quelque chose à dessiner.
    Dépendances : shared/, config.lua, client/fx.lua
]]

local type, pairs, ipairs, next, floor, max, sqrt, sin, cos, pi = type, pairs, ipairs, next, math.floor, math.max, math.sqrt, math.sin, math.cos, math.pi
local CreateThread, Wait, GetGameTimer, RegisterNetEvent = CreateThread, Wait, GetGameTimer, RegisterNetEvent
local StartParticleFxLoopedAtCoord, StartParticleFxNonLoopedAtCoord, DrawMarker, GetGroundZFor_3dCoord =
    StartParticleFxLoopedAtCoord, StartParticleFxNonLoopedAtCoord, DrawMarker, GetGroundZFor_3dCoord

local fx = VavaMagic.fx
local geometry = VavaMagic.geometry
local cfg = VavaMagic.config
local EVENTS = VavaMagic.EVENTS
local SCAN_MS = 250
-- une zone dont la fin n'est jamais arrivée est oubliée passé ce délai
local GRACE_MS = 2000
-- scintillement des flammes (amplitude, vitesse)
local FLICKER, FLICKER_SPEED = 0.18, 6.0
-- recherche du sol sous une zone : départ au-dessus de son centre (m)
local GROUND_PROBE = 1.5
local MARKER_CYLINDER = 1
-- gouttes d'un sol mouillé : sur un cercle à cette part de son rayon
local SPLASH_SHARE = 0.6
-- angle d'or (radians) : points répartis sur un disque
local GOLDEN_ANGLE = pi * (3 - sqrt(5))

local zones = {}
VavaMagic.zoneRender = zones

---@type table<integer, table>
local active = {}
local running = false
---@type table<string, { start: fun(zone: table, detail: string), frame?: fun(zone: table, t: number, now: integer), stop: fun(zone: table, ended: boolean) }>
local kinds = {}

--- Rendu d'un genre de zone : `start(zone, détail)` quand elle devient visible (ou change de niveau de détail),
--- `frame(zone, t, now)` à chaque image tant qu'elle l'est (facultatif), `stop(zone, finie)`.
---@param kind string
---@param renderer table
function zones.define(kind, renderer)
    kinds[kind] = renderer
end

--- Hauteur du sol sous le centre d'une zone (sa hauteur à elle si le sol n'est pas chargé).
---@param zone table
---@return number
function zones.groundZ(zone)
    local c = zone.center
    local found, z = GetGroundZFor_3dCoord(c.x, c.y, c.z + GROUND_PROBE, false)
    if found == true or found == 1 then return z end
    return c.z
end

--- `count` points répartis régulièrement sur un disque (spirale à l'angle d'or : ni trous ni amas), au niveau `z`.
---@param center table
---@param radius number
---@param count integer
---@param z number
---@return table[]
function zones.spread(center, radius, count, z)
    local points = {}
    for i = 1, count do
        local distance = radius * sqrt((i - 0.5) / count)
        local angle = i * GOLDEN_ANGLE
        points[i] = { x = center.x + cos(angle) * distance, y = center.y + sin(angle) * distance, z = z }
    end
    return points
end

--- Points le long d'une ligne, espacés d'au plus `spacing` mètres (les deux bouts compris).
---@param a table
---@param b table
---@param spacing number
---@return table[]
function zones.along(a, b, spacing)
    local length = geometry.distance2d(a, b)
    local steps = max(1, floor(length / spacing + 0.5))
    local points = {}
    for i = 0, steps do
        local t = i / steps
        points[#points + 1] = { x = a.x + (b.x - a.x) * t, y = a.y + (b.y - a.y) * t, z = a.z + (b.z - a.z) * t }
    end
    return points
end

local function stop(zone, ended)
    local renderer = kinds[zone.kind]
    if renderer then renderer.stop(zone, ended) end
    zone.detail = nil
end

local function run()
    if running then return end
    running = true
    CreateThread(function()
        local nextScan = 0
        while next(active) do
            local now = GetGameTimer()
            local visible = false
            if now >= nextScan then
                nextScan = now + SCAN_MS
                for id, zone in pairs(active) do
                    if now > zone.untilMs + GRACE_MS then
                        stop(zone, false)
                        active[id] = nil
                    else
                        local detail = fx.detail(zone.center)
                        if detail ~= zone.detail then
                            stop(zone, false)
                            zone.detail = detail
                            local renderer = kinds[zone.kind]
                            if detail and renderer then renderer.start(zone, detail) end
                        end
                    end
                end
            end
            local t = now / 1000.0
            for _, zone in pairs(active) do
                local renderer = kinds[zone.kind]
                if zone.detail and renderer and renderer.frame then
                    visible = true
                    renderer.frame(zone, t, now)
                end
            end
            -- boucle par image justifiée : seulement tant qu'une zone visible a quelque chose à dessiner
            Wait(visible and 0 or SCAN_MS)
        end
        running = false
    end)
end

-- Mur de flammes -------------------------------------------------------------------------------------------------

---@param zone table
---@return table spell config
local function spellOf(zone)
    return cfg.spells[zone.spell] or cfg.spells.mur_de_flammes
end

zones.define('flames', {
    start = function(zone, detail)
        local spellCfg = spellOf(zone)
        local fxCfg = spellCfg.fx
        local scale = fxCfg.scale * ((spellCfg.levelScale and spellCfg.levelScale[zone.level]) or 1.0)
        local spacing = detail == fx.FULL and fxCfg.spacing or fxCfg.reducedSpacing
        zone.handles = {}
        for _, point in ipairs(zones.along(zone.a, zone.b, spacing)) do
            local handle = fx.startLooped(fxCfg.asset, function()
                return StartParticleFxLoopedAtCoord(fxCfg.flame, point.x, point.y, point.z, 0.0, 0.0, 0.0, scale, false, false, false, false)
            end)
            if handle then zone.handles[#zone.handles + 1] = handle end
        end
        -- embrasement : seulement à la naissance du mur, vu de près
        if not zone.ignited and detail == fx.FULL then
            zone.ignited = true
            for _, point in ipairs(zones.along(zone.a, zone.b, fxCfg.spacing * 2)) do
                fx.oneShot(fxCfg.asset, function()
                    StartParticleFxNonLoopedAtCoord(fxCfg.ignite, point.x, point.y, point.z, 0.0, 0.0, 0.0, fxCfg.igniteScale * scale, false, false, false)
                end)
            end
        end
        local light = spellCfg.light
        zone.lightPoints = zones.along(zone.a, zone.b, geometry.distance2d(zone.a, zone.b) / max(1, light.count - 1))
    end,
    frame = function(zone, t)
        local light = spellOf(zone).light
        for index, point in ipairs(zone.lightPoints or {}) do
            local flicker = 1 + FLICKER * sin(t * FLICKER_SPEED + index * 1.7)
            fx.light(point.x, point.y, point.z + 0.6, light.r, light.g, light.b, light.range, light.intensity * flicker)
        end
    end,
    stop = function(zone, ended)
        for _, handle in ipairs(zone.handles or {}) do fx.stopLooped(handle) end
        zone.handles = {}
        if ended and zone.detail == fx.FULL then
            local fxCfg = spellOf(zone).fx
            for _, point in ipairs(zones.along(zone.a, zone.b, fxCfg.spacing * 2)) do
                fx.oneShot(fxCfg.asset, function()
                    StartParticleFxNonLoopedAtCoord(fxCfg.smother, point.x, point.y, point.z, 0.0, 0.0, 0.0, 1.0, false, false, false)
                end)
            end
        end
    end,
})

-- Sol mouillé ------------------------------------------------------------------------------------------------------

local wetCfg = cfg.wetGround

zones.define('wet', {
    start = function(zone, detail)
        zone.groundZ = zone.groundZ or zones.groundZ(zone)
        -- gouttes : seulement à la naissance du sol mouillé, vu de près
        if zone.splashed or detail ~= fx.FULL then return end
        zone.splashed = true
        local splash = wetCfg.fx
        for i = 1, splash.points do
            local angle = i / splash.points * 2 * pi
            local x, y = zone.center.x + cos(angle) * zone.radius * SPLASH_SHARE, zone.center.y + sin(angle) * zone.radius * SPLASH_SHARE
            fx.oneShot(splash.asset, function()
                StartParticleFxNonLoopedAtCoord(splash.splash, x, y, zone.groundZ, 0.0, 0.0, 0.0, splash.scale, false, false, false)
            end)
        end
    end,
    frame = function(zone)
        local render = wetCfg.render
        local size = zone.radius * 2
        DrawMarker(MARKER_CYLINDER, zone.center.x, zone.center.y, zone.groundZ + render.groundOffset, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
            size, size, render.height, render.r, render.g, render.b, render.alpha, false, false, 2, false, nil, nil, false)
    end,
    stop = function() end,
})

-- Évènements du serveur -------------------------------------------------------------------------------------------

---@param value any
---@return boolean
local function isNumber(value)
    return type(value) == 'number' and value == value
end

RegisterNetEvent(EVENTS.ZONE, function(payload)
    if type(payload) ~= 'table' or type(payload.id) ~= 'number' or type(payload.kind) ~= 'string' or not isNumber(payload.ms) then return end
    if not isNumber(payload.x) or not isNumber(payload.y) or not isNumber(payload.z) then return end
    local zone = {
        id = payload.id, kind = payload.kind, spell = payload.spell, level = type(payload.level) == 'number' and payload.level or 1,
        shape = payload.shape, untilMs = GetGameTimer() + payload.ms,
    }
    if payload.shape == 'line' then
        if not isNumber(payload.x2) or not isNumber(payload.y2) or not isNumber(payload.z2) then return end
        zone.a = { x = payload.x, y = payload.y, z = payload.z }
        zone.b = { x = payload.x2, y = payload.y2, z = payload.z2 }
        zone.width = isNumber(payload.width) and payload.width or 1.0
        zone.center = { x = (zone.a.x + zone.b.x) / 2, y = (zone.a.y + zone.b.y) / 2, z = (zone.a.z + zone.b.z) / 2 }
    else
        zone.center = { x = payload.x, y = payload.y, z = payload.z }
        zone.radius = isNumber(payload.radius) and payload.radius or 1.0
    end
    local previous = active[zone.id]
    if previous then stop(previous, false) end
    active[zone.id] = zone
    run()
end)

RegisterNetEvent(EVENTS.ZONE_END, function(id)
    local zone = type(id) == 'number' and active[id]
    if not zone then return end
    active[id] = nil
    stop(zone, true)
end)

--- Arrêt du module, retour à la sélection : plus rien ne brûle.
function zones.clear()
    for id, zone in pairs(active) do
        stop(zone, false)
        active[id] = nil
    end
end
