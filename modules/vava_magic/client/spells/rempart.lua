--[[
    vava_magic/client/spells/rempart.lua
    Rôle : sort Rempart côté client.
      - Clic gauche en visant le sol (mode magie) : le point visé part au début (aperçu au sol : la ligne du mur, ou
        ses deux bras en chevron au niveau 5, face au regard). Sans visée, ou trop loin, rien ne part.
      - Les blocs de pierre sont des objets réseau créés par le serveur, qui les monte du sol et les retire : chaque
        client les voit d'eux-mêmes. Ce fichier n'ajoute que l'effet vu des joueurs proches quand le mur se dresse ou
        s'effondre : poussière et éclats le long de sa ligne, caméra qui tremble pour les plus proches, grondement.
    Dépendances : shared/, config_client.lua, client/ (noyau, controls, zones, bursts)
]]

local type, ipairs, min = type, ipairs, math.min
local StartParticleFxNonLoopedAtCoord = StartParticleFxNonLoopedAtCoord

local fx = VavaMagic.fx
local controls = VavaMagic.controls
local zoneRender = VavaMagic.zoneRender
local bursts = VavaMagic.bursts
local spellCfg = VavaMagic.config.spells.rempart
local fxCfg = spellCfg.fx
local NAME = 'rempart'
-- poussière tous les tant de mètres le long du mur (de près ; deux fois moins de loin)
local DUST_SPACING = 1.2
-- segments lus au plus (le serveur en envoie un ou deux)
local MAX_SEGMENTS = 4

--- Segments reçus du serveur, vérifiés : { { a, b } }.
---@param list any
---@return table[]
local function segmentsOf(list)
    local segments = {}
    if type(list) ~= 'table' then return segments end
    for index = 1, min(#list, MAX_SEGMENTS) do
        local s = list[index]
        if type(s) == 'table' and bursts.isNumber(s.x) and bursts.isNumber(s.y) and bursts.isNumber(s.z)
            and bursts.isNumber(s.x2) and bursts.isNumber(s.y2) and bursts.isNumber(s.z2) then
            segments[#segments + 1] = { a = { x = s.x, y = s.y, z = s.z }, b = { x = s.x2, y = s.y2, z = s.z2 } }
        end
    end
    return segments
end

--- Le mur se dresse (ou s'effondre) : poussière le long de sa ligne, caméra qui tremble, grondement.
---@param payload table
local function show(payload)
    local center = { x = payload.x, y = payload.y, z = payload.z }
    local detail = fx.detail(center)
    if not detail then return end
    local spacing = detail == fx.FULL and DUST_SPACING or DUST_SPACING * 2
    for _, segment in ipairs(segmentsOf(payload.segments)) do
        for _, point in ipairs(zoneRender.along(segment.a, segment.b, spacing)) do
            fx.oneShot(fxCfg.asset, function()
                StartParticleFxNonLoopedAtCoord(fxCfg.dust, point.x, point.y, point.z, 0.0, 0.0, 0.0, fxCfg.scale, false, false, false)
            end)
        end
    end
    bursts.shake(center, fxCfg.shake.radius, fxCfg.shake)
    bursts.sound('rumble', center)
end

bursts.define(NAME, show)
controls.registerPoint(NAME)
