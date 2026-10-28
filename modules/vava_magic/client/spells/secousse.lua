--[[
    vava_magic/client/spells/secousse.lua
    Rôle : sort Secousse côté client.
      - Clic gauche en visant le sol (mode magie) : le point visé part au début (aperçu au sol : le disque du niveau).
        Sans visée, ou trop loin, rien ne part.
      - Présage (zone « quake », client/zones.lua), vu des joueurs proches : le cercle menacé se marque au sol (anneau
        aux couleurs de la terre) et se remplit à mesure que le choc approche ; le sol craque et fume de poussière. De
        quoi fuir : le serveur ne frappe qu'au terme du présage.
      - Choc (effet instantané du serveur) : éclats de roche sur tout le cercle, caméra qui tremble pour les plus
        proches, grondement. Moins d'éclats de loin, rien au-delà de la distance des effets.
    Dépendances : shared/, config.lua, client/ (noyau, controls, zones, bursts)
]]

local ipairs, max, min, floor, sin, random = ipairs, math.max, math.min, math.floor, math.sin, math.random
local GetGameTimer, DrawMarker, StartParticleFxNonLoopedAtCoord = GetGameTimer, DrawMarker, StartParticleFxNonLoopedAtCoord

local fx = VavaMagic.fx
local controls = VavaMagic.controls
local zoneRender = VavaMagic.zoneRender
local bursts = VavaMagic.bursts
local cfg = VavaMagic.config
local spellCfg = cfg.spells.secousse
local fxCfg = spellCfg.fx
local color = spellCfg.color
local NAME = 'secousse'
local KIND = 'quake'
local MARKER_CYLINDER = 1
local RING_HEIGHT, FILL_HEIGHT = 0.6, 0.04
local GROUND_OFFSET = 0.03
local DUST_EVERY_MS = 350      -- poussière qui monte pendant le présage (de près)…
local DUST_CHANCE = 0.3        -- …de plus en plus souvent : cette chance au début, certaine à la fin
local PULSE_SPEED = 8.0        -- l'anneau palpite de plus en plus vite à l'approche du choc

--- Poussière qui monte du cercle (seulement de près).
---@param zone table
---@param detail string
---@param count integer
local function dust(zone, detail, count)
    if detail ~= fx.FULL then return end
    local scale = fxCfg.scale * (spellCfg.levelScale[zone.level] or 1.0)
    for _, point in ipairs(zoneRender.spread(zone.center, zone.radius, count, zone.groundZ)) do
        fx.oneShot(fxCfg.asset, function()
            StartParticleFxNonLoopedAtCoord(fxCfg.dust, point.x, point.y, point.z, 0.0, 0.0, 0.0, scale, false, false, false)
        end)
    end
end

zoneRender.define(KIND, {
    start = function(zone, detail)
        zone.groundZ = zone.groundZ or zoneRender.groundZ(zone)
        local levelCfg = spellCfg.levels[zone.level] or spellCfg.levels[1]
        zone.delayMs = levelCfg.delayMs
        if not zone.cracked then
            zone.cracked = true
            dust(zone, detail, fxCfg.dustPoints)
            bursts.sound('crack', zone.center)
        end
        zone.nextDust = GetGameTimer() + DUST_EVERY_MS
    end,
    frame = function(zone, t, now)
        local share = 1 - max(0, min(1, (zone.untilMs - now) / zone.delayMs))
        local pulse = 0.75 + 0.25 * sin(t * PULSE_SPEED * (1 + share))
        local size = zone.radius * 2
        local z = zone.groundZ + GROUND_OFFSET
        DrawMarker(fxCfg.ring, zone.center.x, zone.center.y, z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size, size, RING_HEIGHT,
            color.r, color.g, color.b, floor(fxCfg.ringAlpha * pulse), false, false, 2, false, nil, nil, false)
        local fill = size * share
        if fill > 0 then
            DrawMarker(MARKER_CYLINDER, zone.center.x, zone.center.y, z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, fill, fill, FILL_HEIGHT,
                color.r, color.g, color.b, fxCfg.fillAlpha, false, false, 2, false, nil, nil, false)
        end
        if now >= zone.nextDust then
            zone.nextDust = now + DUST_EVERY_MS
            if random() < share + DUST_CHANCE then dust(zone, zone.detail, 1) end
        end
    end,
    stop = function() end,
})

--- Le sol se soulève : éclats sur le cercle, caméra qui tremble, grondement.
---@param payload table
local function strike(payload)
    if not bursts.isNumber(payload.radius) then return end
    local center = { x = payload.x, y = payload.y, z = payload.z }
    local detail = fx.detail(center)
    if not detail then return end
    local level = spellCfg.levels[payload.level] and payload.level or 1
    local scale = fxCfg.scale * (spellCfg.levelScale[level] or 1.0)
    local count = detail == fx.FULL and fxCfg.burstPoints or max(2, fxCfg.burstPoints // 2)
    for _, point in ipairs(zoneRender.spread(center, payload.radius, count, center.z + GROUND_OFFSET)) do
        fx.oneShot(fxCfg.asset, function()
            StartParticleFxNonLoopedAtCoord(fxCfg.burst, point.x, point.y, point.z, 0.0, 0.0, 0.0, scale, false, false, false)
        end)
    end
    bursts.shake(center, payload.radius * fxCfg.shake.radii, fxCfg.shake)
    bursts.sound('rumble', center)
end

bursts.define(NAME, strike)
controls.registerPoint(NAME)
