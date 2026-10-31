--[[
    vava_characters_ui/client/camera.lua
    Rôle : caméras de la scène (vue d'ensemble, silhouette, visage) avec transition douce entre elles.
    Les positions sont calculées depuis l'orientation de la scène, pas celle du ped : le faire tourner ne déplace
    pas la caméra.
    Dépendances : config_client.lua
]]

local rad, sin, cos = math.rad, math.sin, math.cos
local CreateCamWithParams, PointCamAtCoord, SetCamActive, SetCamActiveWithInterp = CreateCamWithParams, PointCamAtCoord, SetCamActive, SetCamActiveWithInterp
local RenderScriptCams, DestroyCam, DoesCamExist, SetTimeout = RenderScriptCams, DestroyCam, DoesCamExist, SetTimeout

local cfg = VavaCharactersUi.config
local CAMERA_TYPE = 'DEFAULT_SCRIPTED_CAMERA'
local EASE = 1

local camera = {}
VavaCharactersUi.camera = camera

local active = nil
local activeName = nil

---@param preset table
---@return number px, number py, number pz, number tx, number ty, number tz
local function placement(preset)
    local scene = cfg.scene
    local heading = rad(scene.heading)
    -- avant et droite du ped (repère GTA : cap 0 = nord, sens antihoraire)
    local fx, fy = -sin(heading), cos(heading)
    local rx, ry = cos(heading), sin(heading)
    local baseX, baseY = scene.x + rx * preset.aim, scene.y + ry * preset.aim
    return baseX + fx * preset.distance, baseY + fy * preset.distance, scene.z + preset.height,
        baseX, baseY, scene.z + preset.target
end

--- Affiche une vue ; si une caméra est déjà active, transition interpolée.
---@param name string
---@return boolean ok
function camera.show(name)
    local preset = cfg.cameras[name]
    if not preset then return false end
    if name == activeName then return true end
    local px, py, pz, tx, ty, tz = placement(preset)
    local cam = CreateCamWithParams(CAMERA_TYPE, px, py, pz, 0.0, 0.0, 0.0, preset.fov, false, 0)
    PointCamAtCoord(cam, tx, ty, tz)
    if active then
        local previous = active
        SetCamActiveWithInterp(cam, previous, cfg.cameraTransitionMs, EASE, EASE)
        SetTimeout(cfg.cameraTransitionMs, function()
            if DoesCamExist(previous) then DestroyCam(previous, false) end
        end)
    else
        SetCamActive(cam, true)
        RenderScriptCams(true, false, 0, true, true)
    end
    active, activeName = cam, name
    return true
end

--- Rend la main à la caméra du jeu (l'écran est noir pendant l'apparition qui suit).
function camera.close()
    if not active then return end
    RenderScriptCams(false, false, 0, true, true)
    if DoesCamExist(active) then DestroyCam(active, false) end
    active, activeName = nil, nil
end
