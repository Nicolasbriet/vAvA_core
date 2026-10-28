--[[
    vava_magic/client/spells/vague.lua
    Rôle : sort Vague côté client.
      - Clic gauche en mode magie (ou /lancer) : incantation ; à la fin, la direction du regard (la caméra en visant,
        sinon droit devant le personnage) part au serveur, qui décide de tout, et le lanceur se tourne vers elle.
        Aperçu au sol pendant la visée : le cône du niveau (client/controls.lua).
      - Vue des joueurs proches : gerbes d'eau qui balaient le cône, des plus proches aux plus lointaines, le temps de
        `fx.sweepMs` ; son de vague. Moins de gerbes de loin, rien au-delà de la distance des effets. Aucune boucle
        par image : les rangées partent à intervalles.
    Dépendances : shared/, config.lua, client/ (noyau, controls, bursts)
]]

local ipairs, sin, cos, rad, atan, max = ipairs, math.sin, math.cos, math.rad, math.atan, math.max
local CreateThread, Wait, PlayerPedId, GetEntityForwardVector, SetEntityHeading, GetHeadingFromVector_2d, StartParticleFxNonLoopedAtCoord =
    CreateThread, Wait, PlayerPedId, GetEntityForwardVector, SetEntityHeading, GetHeadingFromVector_2d, StartParticleFxNonLoopedAtCoord

local fx = VavaMagic.fx
local casting = VavaMagic.casting
local controls = VavaMagic.controls
local bursts = VavaMagic.bursts
local geometry = VavaMagic.geometry
local cfg = VavaMagic.config
local spellCfg = cfg.spells.vague
local fxCfg = spellCfg.fx
local NAME = 'vague'
-- le serveur annonce la position du lanceur ; les gerbes naissent à ses pieds
local FEET = cfg.controls.preview.feetOffset
local NORTH = { x = 0.0, y = 1.0 }

--- Direction de la vague au sol : le regard en visant, sinon droit devant le personnage.
---@return table
local function direction()
    local info = controls.aimInfo()
    local wanted = info.aiming and info.direction or GetEntityForwardVector(PlayerPedId())
    return geometry.direction2d({ x = 0, y = 0 }, wanted) or NORTH
end

--- Clic gauche en mode magie (ou /lancer) : la vague part dans la direction du regard.
local function cast()
    local forward = nil
    casting.start(NAME, {
        finishArgs = function()
            forward = direction()
            return { forward.x, forward.y }
        end,
        beforeRelease = function()
            if forward then SetEntityHeading(PlayerPedId(), GetHeadingFromVector_2d(forward.x, forward.y)) end
        end,
    })
end

--- La vague vue par un joueur proche : rangées de gerbes qui balaient le cône.
---@param payload table
local function show(payload)
    for _, field in ipairs({ 'dx', 'dy', 'range', 'angle' }) do
        if not bursts.isNumber(payload[field]) then return end
    end
    local apex = { x = payload.x, y = payload.y, z = payload.z - FEET }
    local detail = fx.detail(apex)
    if not detail then return end
    local level = spellCfg.levels[payload.level] and payload.level or 1
    local scale = fxCfg.scale * (spellCfg.levelScale[level] or 1.0)
    local perRow = detail == fx.FULL and fxCfg.perRow or max(2, fxCfg.perRow // 2)
    local base, half = atan(payload.dy, payload.dx), rad(payload.angle)
    bursts.sound('splash', apex)
    CreateThread(function()
        for row = 1, fxCfg.rows do
            local distance = payload.range * row / fxCfg.rows
            for k = 1, perRow do
                local angle = base - half + (2 * half) * (k - 1) / (perRow - 1)
                local x, y = apex.x + cos(angle) * distance, apex.y + sin(angle) * distance
                fx.oneShot(fxCfg.asset, function()
                    StartParticleFxNonLoopedAtCoord(fxCfg.splash, x, y, apex.z, 0.0, 0.0, 0.0, scale, false, false, false)
                end)
            end
            Wait(fxCfg.sweepMs // fxCfg.rows)
        end
    end)
end

bursts.define(NAME, show)
controls.register(NAME, { cast = cast })
