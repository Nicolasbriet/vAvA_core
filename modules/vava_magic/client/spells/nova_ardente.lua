--[[
    vava_magic/client/spells/nova_ardente.lua
    Rôle : sort Nova ardente côté client : clic gauche en mode magie = incantation (aperçu au sol de son rayon autour
           du lanceur pendant la visée). Le serveur décide qui est touché ; les joueurs proches voient la nova :
           gerbes de flammes en cercle au rayon du niveau, éclat de lumière, anneau de feu qui s'élargit, sol qui
           tremble sous les plus proches. Plus le niveau est haut, plus la gerbe est grande. Rien au-delà de la
           distance des effets ; la boucle par image ne vit que le temps de l'éclat (une demi-seconde).
    Dépendances : shared/, config.lua, client/ (noyau)
]]

local type, sin, cos, pi, min, max, floor = type, math.sin, math.cos, math.pi, math.min, math.max, math.floor
local CreateThread, Wait, GetGameTimer, RegisterNetEvent = CreateThread, Wait, GetGameTimer, RegisterNetEvent
local PlayerPedId, GetEntityCoords, StartParticleFxNonLoopedAtCoord, DrawMarker, ShakeGameplayCam =
    PlayerPedId, GetEntityCoords, StartParticleFxNonLoopedAtCoord, DrawMarker, ShakeGameplayCam

local nui = VavaMagic.nui
local fx = VavaMagic.fx
local casting = VavaMagic.casting
local controls = VavaMagic.controls
local geometry = VavaMagic.geometry
local spellCfg = VavaMagic.config.spells.nova_ardente
local fxCfg = spellCfg.fx
local lightCfg = spellCfg.light
local EVENTS = VavaMagic.EVENTS
local NAME = 'nova_ardente'
-- part du rayon où naissent les gerbes, hauteur de l'anneau au-dessus du sol
local BURST_SHARE = 0.85
local RING_HEIGHT = 0.05
local RING_ALPHA = 220
-- joueurs proches dont la caméra tremble (en rayons de la nova), et la force du tremblement
local SHAKE_RADII, SHAKE_AMPLITUDE = 2.0, 0.25
local HEARING_DISTANCE = 60.0

--- Clic gauche en mode magie (ou /lancer) : la nova se libère autour du lanceur.
local function cast()
    casting.start(NAME, {})
end

--- La nova vue par un joueur proche : gerbes en cercle, éclat, anneau qui s'élargit.
---@param payload table
local function show(payload)
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
    local me = GetEntityCoords(PlayerPedId())
    local distance = geometry.distance(me, center)
    if distance <= radius * SHAKE_RADII then ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', SHAKE_AMPLITUDE) end
    if distance <= HEARING_DISTANCE then nui.send('sound', { name = 'impact', volume = max(0, 1 - distance / HEARING_DISTANCE) }) end
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

RegisterNetEvent(EVENTS.NOVA, function(payload)
    if type(payload) ~= 'table' or type(payload.x) ~= 'number' or type(payload.y) ~= 'number' or type(payload.z) ~= 'number'
        or type(payload.radius) ~= 'number' then return end
    show(payload)
end)

controls.register(NAME, { cast = cast })
