--[[
    vava_magic/client/spells/brume.lua
    Rôle : sort Brume côté client.
      - Clic gauche en visant le sol (mode magie) : le point visé part au début (aperçu au sol : le disque du niveau).
        Sans visée, ou trop loin, rien ne part.
      - Rendu de la zone « mist » (client/zones.lua) : nappes de brume en boucle réparties sur le disque, vues du
        dehors ; moins nombreuses de loin, rien au-delà de la distance des effets.
      - Qui s'y tient n'y voit plus guère : voile de la page, plus épais selon le niveau, et filtre de GTA
        (`screen.timecycle`), posés en entrant, retirés en sortant (et à l'arrêt du module). La présence est relue
        toutes les 200 ms, seulement tant qu'une brume est proche : aucun dessin par image.
    Dépendances : shared/, config.lua, client/ (noyau, controls, zones)
]]

local pairs, ipairs, next, max, abs, ceil, min, pi = pairs, ipairs, next, math.max, math.abs, math.ceil, math.min, math.pi
local CreateThread, Wait, PlayerPedId, GetEntityCoords, StartParticleFxLoopedAtCoord =
    CreateThread, Wait, PlayerPedId, GetEntityCoords, StartParticleFxLoopedAtCoord
local SetTimecycleModifier, SetTimecycleModifierStrength, ClearTimecycleModifier =
    SetTimecycleModifier, SetTimecycleModifierStrength, ClearTimecycleModifier

local nui = VavaMagic.nui
local fx = VavaMagic.fx
local controls = VavaMagic.controls
local zoneRender = VavaMagic.zoneRender
local geometry = VavaMagic.geometry
local spellCfg = VavaMagic.config.spells.brume
local fxCfg = spellCfg.fx
local screenCfg = spellCfg.screen
local NAME = 'brume'
local KIND = 'mist'
local CHECK_MS = 200
-- écart de hauteur où l'on est encore dans la brume (m)
local HEIGHT = 3.0
-- nappes posées un peu au-dessus du sol (m), et dans cette part du rayon (elles débordent d'elles-mêmes)
local CLOUD_HEIGHT = 0.3
local CLOUD_SHARE = 0.8

---@type table<integer, table>  brumes visibles (assez proches pour qu'on puisse s'y tenir)
local nearby = {}
local watching = false
local density = 0

--- Voile à l'écran du joueur local (0 : aucun).
---@param value number
local function setDensity(value)
    if value == density then return end
    density = value
    nui.send('screen:mist', { density = value })
    if screenCfg.timecycle == '' then return end
    if value > 0 then
        SetTimecycleModifier(screenCfg.timecycle)
        SetTimecycleModifierStrength(value)
    else
        ClearTimecycleModifier()
    end
end

---@param zone table
---@param me table
---@return boolean
local function inside(zone, me)
    return abs(me.z - zone.center.z) <= HEIGHT and geometry.distance2d(me, zone.center) <= zone.radius
end

--- Relit toutes les 200 ms si le joueur se tient dans une brume, tant qu'il en est une proche.
local function watch()
    if watching then return end
    watching = true
    CreateThread(function()
        while next(nearby) do
            local me = GetEntityCoords(PlayerPedId())
            local wanted = 0
            for _, zone in pairs(nearby) do
                if inside(zone, me) then
                    local levelCfg = spellCfg.levels[zone.level] or spellCfg.levels[1]
                    wanted = max(wanted, levelCfg.density)
                end
            end
            setDensity(wanted)
            Wait(CHECK_MS)
        end
        watching = false
        setDensity(0)
    end)
end

zoneRender.define(KIND, {
    start = function(zone, detail)
        local limit = detail == fx.FULL and fxCfg.maxPoints or fxCfg.reducedPoints
        local count = min(limit, max(1, ceil(pi * zone.radius * zone.radius / (fxCfg.spacing * fxCfg.spacing))))
        local scale = fxCfg.scale * (spellCfg.levelScale[zone.level] or 1.0)
        zone.handles = {}
        for _, point in ipairs(zoneRender.spread(zone.center, zone.radius * CLOUD_SHARE, count, zone.center.z + CLOUD_HEIGHT)) do
            local handle = fx.startLooped(fxCfg.asset, function()
                return StartParticleFxLoopedAtCoord(fxCfg.cloud, point.x, point.y, point.z, 0.0, 0.0, 0.0, scale, false, false, false, false)
            end)
            if handle then zone.handles[#zone.handles + 1] = handle end
        end
        nearby[zone.id] = zone
        watch()
    end,
    stop = function(zone)
        for _, handle in ipairs(zone.handles or {}) do fx.stopLooped(handle) end
        zone.handles = {}
        nearby[zone.id] = nil
        -- plus aucune brume proche : le voile part tout de suite (arrêt du module compris)
        if not next(nearby) then setDensity(0) end
    end,
})

controls.registerPoint(NAME)
