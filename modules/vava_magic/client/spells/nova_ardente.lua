--[[
    vava_magic/client/spells/nova_ardente.lua
    Rôle : sort Nova ardente côté client : clic gauche en mode magie = incantation (aperçu au sol de son rayon autour
           du lanceur pendant la visée). Le serveur décide qui est touché ; les joueurs proches voient la nova :
           gerbes de flammes en cercle au rayon du niveau, éclat de lumière, anneau de feu qui s'élargit, sol qui
           tremble sous les plus proches ; la terre reste noircie un moment. Plus le niveau est haut, plus la gerbe est
           grande. Rien au-delà de la distance des effets ; la boucle par image ne vit que le temps de l'éclat (une
           demi-seconde).
    Dépendances : shared/, config.lua, client/ (noyau, zones, bursts)
]]

local sin, cos, pi, min, max, floor = math.sin, math.cos, math.pi, math.min, math.max, math.floor
local CreateThread, Wait, GetGameTimer = CreateThread, Wait, GetGameTimer
local StartParticleFxNonLoopedAtCoord, DrawMarker = StartParticleFxNonLoopedAtCoord, DrawMarker

local fx = VavaMagic.fx
local casting = VavaMagic.casting
local controls = VavaMagic.controls
local zoneRender = VavaMagic.zoneRender
local bursts = VavaMagic.bursts
local spellCfg = VavaMagic.config.spells.nova_ardente
local fxCfg = spellCfg.fx
local lightCfg = spellCfg.light
local NAME = 'nova_ardente'
-- le serveur annonce la position du lanceur ; la trace se pose à ses pieds
local FEET = VavaMagic.config.controls.preview.feetOffset
-- part du rayon où naissent les gerbes, hauteur de l'anneau au-dessus du sol
local BURST_SHARE = 0.85
local RING_HEIGHT = 0.05
local RING_ALPHA = 220
-- joueurs proches dont la caméra tremble (en rayons de la nova), et le tremblement
local SHAKE_RADII = 2.0
local SHAKE = { name = 'SMALL_EXPLOSION_SHAKE', amplitude = 0.25 }

--- Clic gauche en mode magie (ou /lancer) : la nova se libère autour du lanceur.
local function cast()
    casting.start(NAME, {})
end

--- La nova vue par un joueur proche : gerbes en cercle, éclat, anneau qui s'élargit.
---@param payload table
local function show(payload)
    if not bursts.isNumber(payload.radius) then return end
    local center = { x = payload.x, y = payload.y, z = payload.z }
    local detail = fx.detail(center)
    if not detail then return end
    local level = spellCfg.levels[payload.level] and payload.level or 1
    local scale = fxCfg.scale * (spellCfg.levelScale[level] or 1.0)
    local radius = payload.radius
    local points = detail == fx.FULL and fxCfg.points or max(4, fxCfg.points // 2)
    for i = 1, points do
        local angle = (i / points) * 2 * pi
        local x, y = center.x + cos(angle) * radius * BURST_SHARE, center.y + sin(angle) * radius * BURST_SHARE
        fx.oneShot(fxCfg.asset, function()
            StartParticleFxNonLoopedAtCoord(fxCfg.burst, x, y, center.z, 0.0, 0.0, 0.0, scale, false, false, false)
        end)
    end
    fx.oneShot(fxCfg.asset, function()
        StartParticleFxNonLoopedAtCoord(fxCfg.burst, center.x, center.y, center.z, 0.0, 0.0, 0.0, scale * 1.5, false, false, false)
    end)
    bursts.shake(center, radius * SHAKE_RADII, SHAKE)
    bursts.sound('impact', center)
    zoneRender.trace({ { x = center.x, y = center.y, z = center.z - FEET } }, radius * 2)
    CreateThread(function()
        local started = GetGameTimer()
        local duration = max(fxCfg.ringMs, lightCfg.flashMs)
        -- boucle par image justifiée : seulement le temps de l'éclat
        while GetGameTimer() - started < duration do
            local share = min(1, (GetGameTimer() - started) / fxCfg.ringMs)
            local fade = 1 - (GetGameTimer() - started) / duration
            fx.light(center.x, center.y, center.z + 1.0, lightCfg.r, lightCfg.g, lightCfg.b, lightCfg.range * (spellCfg.levelScale[level] or 1.0),
                lightCfg.intensity * fade)
            local size = radius * 2 * share
            DrawMarker(fxCfg.ring, center.x, center.y, center.z + RING_HEIGHT, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size, size, 1.0,
                lightCfg.r, lightCfg.g, lightCfg.b, floor(RING_ALPHA * fade), false, false, 2, false, nil, nil, false)
            Wait(0)
        end
    end)
end

bursts.define(NAME, show)

controls.register(NAME, { cast = cast })
