--[[
    vava_magic/client/combos.lua
    Rôle : combinaisons entre éléments côté client (le serveur les décide, `config.combos`) :
      - mot bref à l'écran du lanceur (« Vapeur ! ») à chaque combinaison réussie, près de la barre de mana ;
      - effet et son vus des joueurs proches, d'après la config de la combinaison, à l'endroit annoncé ;
      - zones nées des combinaisons : vapeur (nuée, client/clouds.lua : nappes blanches, voile) et boue (disque brun
        au sol, éclaboussure à la naissance).
    Dépendances : shared/, config.lua, client/ (noyau, fx, zones, clouds, bursts)
]]

local type, ipairs = type, ipairs
local RegisterNetEvent, StartParticleFxNonLoopedAtCoord, DrawMarker = RegisterNetEvent, StartParticleFxNonLoopedAtCoord, DrawMarker

local nui = VavaMagic.nui
local fx = VavaMagic.fx
local zoneRender = VavaMagic.zoneRender
local clouds = VavaMagic.clouds
local bursts = VavaMagic.bursts
local cfg = VavaMagic.config
local EVENTS = VavaMagic.EVENTS
local MARKER_CYLINDER = 1
-- éclaboussures de la boue à sa naissance : sur cette part de son rayon
local SPLASH_SHARE = 0.6

local combos = {}
VavaMagic.combos = combos

-- mot bref au lanceur
RegisterNetEvent(EVENTS.COMBO, function(id)
    local combo = type(id) == 'string' and cfg.combos[id]
    if combo then nui.send('combo', { label = combo.notify or combo.label }) end
end)

--- Effet d'une combinaison vu d'un joueur proche : particules réparties autour du point, son.
---@param payload table
local function show(payload)
    local combo = type(payload.combo) == 'string' and cfg.combos[payload.combo]
    if not combo or not combo.fx then return end
    local point = { x = payload.x, y = payload.y, z = payload.z }
    local detail = fx.detail(point)
    if not detail then return end
    local fxCfg = combo.fx
    local count = detail == fx.FULL and (fxCfg.points or 1) or 1
    for _, spot in ipairs(zoneRender.spread(point, fxCfg.points and 1.0 or 0.0, count, point.z)) do
        fx.oneShot(fxCfg.asset, function()
            StartParticleFxNonLoopedAtCoord(fxCfg.name, spot.x, spot.y, spot.z, 0.0, 0.0, 0.0, fxCfg.scale or 1.0, false, false, false)
        end)
    end
    if combo.sound then bursts.sound(combo.sound, point) end
end

bursts.define('combo', show)

-- vapeur : une nuée blanche, voile de la combinaison
local steam = cfg.combos.vapeur
if steam and steam.cloud then
    clouds.define('steam', {
        fx = steam.cloud,
        timecycle = steam.screen and steam.screen.timecycle or '',
        density = function() return steam.result.density or 0 end,
    })
end

-- boue : disque brun au sol, éclaboussure à la naissance
local mud = cfg.combos.boue
if mud and mud.render then
    zoneRender.define('mud', {
        start = function(zone, detail)
            zone.groundZ = zone.groundZ or zoneRender.groundZ(zone)
            if zone.splashed or detail ~= fx.FULL or not mud.fx then return end
            zone.splashed = true
            for _, point in ipairs(zoneRender.spread(zone.center, zone.radius * SPLASH_SHARE, mud.fx.points or 4, zone.groundZ)) do
                fx.oneShot(mud.fx.asset, function()
                    StartParticleFxNonLoopedAtCoord(mud.fx.name, point.x, point.y, point.z, 0.0, 0.0, 0.0, mud.fx.scale or 1.0, false, false, false)
                end)
            end
        end,
        frame = function(zone)
            local render = mud.render
            local size = zone.radius * 2
            DrawMarker(MARKER_CYLINDER, zone.center.x, zone.center.y, zone.groundZ + render.groundOffset, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                size, size, render.height, render.r, render.g, render.b, render.alpha, false, false, 2, false, nil, nil, false)
        end,
        stop = function() end,
    })
end
