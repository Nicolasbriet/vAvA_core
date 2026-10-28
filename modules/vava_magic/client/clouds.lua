--[[
    vava_magic/client/clouds.lua
    Rôle : rendu commun des zones de nuées (brume, vapeur d'une combinaison) envoyées par le serveur :
      - vues du dehors : nappes en boucle réparties sur le disque, moins nombreuses de loin, rien au-delà de la
        distance des effets ;
      - qui s'y tient n'y voit plus guère : voile de la page (épaisseur propre à chaque genre) et filtre de GTA,
        posés en entrant, retirés en sortant (et à l'arrêt du module). La présence est relue toutes les 200 ms,
        seulement tant qu'une nuée est proche : aucun dessin par image.
    Chaque genre se déclare avec `clouds.define(genre, { fx, density(zone), timecycle })`.
    Dépendances : shared/, config.lua, client/nui.lua, client/fx.lua, client/zones.lua
]]

local pairs, ipairs, next, max, abs, ceil, min, pi = pairs, ipairs, next, math.max, math.abs, math.ceil, math.min, math.pi
local CreateThread, Wait, PlayerPedId, GetEntityCoords, StartParticleFxLoopedAtCoord =
    CreateThread, Wait, PlayerPedId, GetEntityCoords, StartParticleFxLoopedAtCoord
local SetTimecycleModifier, SetTimecycleModifierStrength, ClearTimecycleModifier =
    SetTimecycleModifier, SetTimecycleModifierStrength, ClearTimecycleModifier

local nui = VavaMagic.nui
local fx = VavaMagic.fx
local zoneRender = VavaMagic.zoneRender
local geometry = VavaMagic.geometry
local CHECK_MS = 200
-- écart de hauteur où l'on est encore dans la nuée (m)
local HEIGHT = 3.0
-- nappes posées un peu au-dessus du sol (m), et dans cette part du rayon (elles débordent d'elles-mêmes)
local CLOUD_HEIGHT = 0.3
local CLOUD_SHARE = 0.8

local clouds = {}
VavaMagic.clouds = clouds

---@type table<string, { fx: table, density: fun(zone: table): number, timecycle: string }>
local kinds = {}
---@type table<integer, table>  nuées visibles (assez proches pour qu'on puisse s'y tenir)
local nearby = {}
local watching = false
local density, timecycle = 0, ''

--- Voile à l'écran du joueur local (0 : aucun) et filtre de GTA.
---@param value number
---@param filter string
local function setDensity(value, filter)
    if value == density and filter == timecycle then return end
    density, timecycle = value, filter
    nui.send('screen:mist', { density = value })
    if value > 0 and filter ~= '' then
        SetTimecycleModifier(filter)
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

--- Relit toutes les 200 ms si le joueur se tient dans une nuée, tant qu'il en est une proche.
local function watch()
    if watching then return end
    watching = true
    CreateThread(function()
        while next(nearby) do
            local me = GetEntityCoords(PlayerPedId())
            local wanted, filter = 0, ''
            for _, zone in pairs(nearby) do
                local kind = kinds[zone.kind]
                if kind and inside(zone, me) then
                    local value = kind.density(zone)
                    if value > wanted then wanted, filter = value, kind.timecycle end
                end
            end
            setDensity(wanted, filter)
            Wait(CHECK_MS)
        end
        watching = false
        setDensity(0, '')
    end)
end

--- Déclare un genre de nuée. `def` : fx { asset, cloud, spacing, maxPoints, reducedPoints, scale }, density(zone)
--- (0 à 1, voile de qui s'y tient), timecycle (filtre de GTA, '' : aucun), scale(zone) facultatif (taille des nappes).
---@param kind string
---@param def table
function clouds.define(kind, def)
    kinds[kind] = { fx = def.fx, density = def.density, timecycle = def.timecycle or '' }
    zoneRender.define(kind, {
        start = function(zone, detail)
            local fxCfg = def.fx
            local limit = detail == fx.FULL and fxCfg.maxPoints or fxCfg.reducedPoints
            local count = min(limit, max(1, ceil(pi * zone.radius * zone.radius / (fxCfg.spacing * fxCfg.spacing))))
            local scale = fxCfg.scale * (def.scale and def.scale(zone) or 1.0)
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
            -- plus aucune nuée proche : le voile part tout de suite (arrêt du module compris)
            if not next(nearby) then setDensity(0, '') end
        end,
    })
end
