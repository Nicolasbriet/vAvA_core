--[[
    vava_admin/client/tools.lua
    Rôle : outils du membre du Conseil sur son propre personnage, activés après l'accord du serveur (droit vérifié,
           action au journal) :
      - vol libre : seule boucle par image du module (exception assumée : les touches doivent être lues à chaque
        image), et seulement tant que l'outil est actif ; le membre devient invisible des autres pendant le vol
        (il se voit toujours lui-même) et retrouve ensuite sa visibilité d'avant ;
      - invisibilité, invulnérabilité : bascules, sans boucle ;
      - repère de la carte : sol cherché à quelques hauteurs, borné ;
      - observation : le membre, invisible et sans collision, est placé sous le joueur (OneSync ne transmet que les
        entités proches) et recalé une fois par seconde ; il revient à sa place à la fin. S'il quitte le jeu avant,
        le serveur le replace à sa prochaine apparition (server/spectate.lua), jamais sous terre.
    Dépendances : config.lua, client/core.lua
]]

local ipairs = ipairs
local sin, cos, rad = math.sin, math.cos, math.rad
local CreateThread, Wait, GetGameTimer = CreateThread, Wait, GetGameTimer
local PlayerId, PlayerPedId, GetVehiclePedIsIn, GetEntityCoords, GetEntityHeading =
    PlayerId, PlayerPedId, GetVehiclePedIsIn, GetEntityCoords, GetEntityHeading
local SetEntityCoordsNoOffset, SetEntityHeading, SetEntityCollision, FreezeEntityPosition =
    SetEntityCoordsNoOffset, SetEntityHeading, SetEntityCollision, FreezeEntityPosition
local SetEntityVisible, SetEntityInvincible, SetPlayerInvincible = SetEntityVisible, SetEntityInvincible, SetPlayerInvincible
local SetEntityLocallyVisible = SetEntityLocallyVisible
local IsControlPressed, GetGameplayCamRot = IsControlPressed, GetGameplayCamRot
local GetFirstBlipInfoId, DoesBlipExist, GetBlipInfoIdCoord = GetFirstBlipInfoId, DoesBlipExist, GetBlipInfoIdCoord
local GetGroundZFor_3dCoord, RequestCollisionAtCoord = GetGroundZFor_3dCoord, RequestCollisionAtCoord
local GetPlayerFromServerId, GetPlayerPed, DoesEntityExist, NetworkSetInSpectatorMode =
    GetPlayerFromServerId, GetPlayerPed, DoesEntityExist, NetworkSetInSpectatorMode

local cfg = VavaAdmin.config

-- touches du vol libre (contrôles GTA)
local CONTROL = { forward = 32, back = 33, left = 34, right = 35, up = 22, down = 36, fast = 21, slow = 19 }
local WAYPOINT_SPRITE = 8
local NO_PLAYER = -1
local CAMERA_ORDER = 2
local GROUND_CLEARANCE = 1.0

local tools = {}
VavaAdmin.tools = tools

local state = { noclip = false, invisible = false, godmode = false }
local spectating = nil

--- État des outils (affiché par le panneau).
---@return table
function tools.state()
    return { noclip = state.noclip, invisible = state.invisible, godmode = state.godmode, spectating = spectating and spectating.label or nil }
end

local function applyGodmode()
    local ped = PlayerPedId()
    SetEntityInvincible(ped, state.godmode)
    SetPlayerInvincible(PlayerId(), state.godmode)
end

--- Invisible tant que l'outil d'invisibilité ou le vol libre est actif.
local function applyVisibility()
    SetEntityVisible(PlayerPedId(), not (state.invisible or state.noclip), false)
end

-- Vol libre ----------------------------------------------------------------------------------------------------

local function moved(entity, speed)
    local rot = GetGameplayCamRot(CAMERA_ORDER)
    local heading, pitch = rad(rot.z), rad(rot.x)
    local fx, fy, fz = -sin(heading) * cos(pitch), cos(heading) * cos(pitch), sin(pitch)
    local rx, ry = cos(heading), sin(heading)
    local c = GetEntityCoords(entity)
    local x, y, z = c.x, c.y, c.z
    if IsControlPressed(0, CONTROL.forward) then x, y, z = x + fx * speed, y + fy * speed, z + fz * speed end
    if IsControlPressed(0, CONTROL.back) then x, y, z = x - fx * speed, y - fy * speed, z - fz * speed end
    if IsControlPressed(0, CONTROL.right) then x, y = x + rx * speed, y + ry * speed end
    if IsControlPressed(0, CONTROL.left) then x, y = x - rx * speed, y - ry * speed end
    if IsControlPressed(0, CONTROL.up) then z = z + speed end
    if IsControlPressed(0, CONTROL.down) then z = z - speed end
    SetEntityCoordsNoOffset(entity, x, y, z, true, true, true)
    SetEntityHeading(entity, rot.z)
end

local function startNoclip()
    CreateThread(function()
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        local entity = vehicle ~= 0 and vehicle or ped
        SetEntityCollision(entity, false, false)
        FreezeEntityPosition(entity, true)
        SetEntityInvincible(entity, true)
        -- invisible des autres pendant le vol (le véhicule aussi, s'il y en a un)
        applyVisibility()
        if vehicle ~= 0 then SetEntityVisible(vehicle, false, false) end
        local speeds = cfg.noclip
        while state.noclip do
            -- exception à la règle « aucune boucle par image » : lecture des touches, seulement pendant le vol
            Wait(0)
            -- le membre se voit lui-même : l'invisibilité ne vaut que pour les autres
            SetEntityLocallyVisible(ped)
            if vehicle ~= 0 then SetEntityLocallyVisible(vehicle) end
            local speed = speeds.speed
            if IsControlPressed(0, CONTROL.fast) then speed = speeds.fastSpeed end
            if IsControlPressed(0, CONTROL.slow) then speed = speeds.slowSpeed end
            moved(entity, speed)
        end
        SetEntityCollision(entity, true, true)
        FreezeEntityPosition(entity, false)
        SetEntityInvincible(entity, state.godmode)
        if vehicle ~= 0 then SetEntityVisible(vehicle, true, false) end
        applyVisibility()
    end)
end

--- Active ou coupe un outil (après l'accord du serveur).
---@param name string  noclip, invisible ou godmode
---@param enabled boolean
function tools.set(name, enabled)
    if state[name] == nil or state[name] == enabled then return end
    state[name] = enabled
    if name == 'noclip' then
        if enabled then startNoclip() end
    elseif name == 'invisible' then
        applyVisibility()
    elseif name == 'godmode' then
        applyGodmode()
    end
end

--- Après une apparition : le jeu a pu remettre le ped à zéro.
function tools.reapply()
    if state.godmode then applyGodmode() end
    if state.invisible then applyVisibility() end
end

--- Coupe tout (personnage déchargé, module arrêté).
function tools.reset()
    tools.stopSpectate()
    for _, name in ipairs({ 'noclip', 'invisible', 'godmode' }) do tools.set(name, false) end
end

-- Repère de la carte -------------------------------------------------------------------------------------------

--- Rejoint le repère posé sur la carte du menu pause. Renvoie faux s'il n'y en a pas.
---@return boolean
function tools.waypoint()
    local blip = GetFirstBlipInfoId(WAYPOINT_SPRITE)
    if not DoesBlipExist(blip) then return false end
    local target = GetBlipInfoIdCoord(blip)
    CreateThread(function()
        local ped = PlayerPedId()
        FreezeEntityPosition(ped, true)
        local landed = false
        for _, height in ipairs(cfg.waypoint.probeHeights) do
            SetEntityCoordsNoOffset(ped, target.x, target.y, height, false, false, false)
            RequestCollisionAtCoord(target.x, target.y, height)
            Wait(cfg.waypoint.probeWaitMs)
            local found, ground = GetGroundZFor_3dCoord(target.x, target.y, height, false)
            if found then
                SetEntityCoordsNoOffset(ped, target.x, target.y, ground + GROUND_CLEARANCE, false, false, false)
                landed = true
                break
            end
        end
        if not landed then SetEntityCoordsNoOffset(ped, target.x, target.y, target.z + GROUND_CLEARANCE, false, false, false) end
        FreezeEntityPosition(ped, state.noclip)
    end)
    return true
end

-- Observation ---------------------------------------------------------------------------------------------------

---@param serverId integer
---@return integer ped  0 si le joueur n'est pas (encore) transmis
local function pedOf(serverId)
    local player = GetPlayerFromServerId(serverId)
    if player == NO_PLAYER then return 0 end
    local ped = GetPlayerPed(player)
    return DoesEntityExist(ped) and ped or 0
end

---@param x number
---@param y number
---@param z number
local function anchor(x, y, z)
    SetEntityCoordsNoOffset(PlayerPedId(), x, y, z - cfg.spectate.anchorDepth, false, false, false)
end

--- Observe un joueur : { source, label, x, y, z } (accordé par le serveur). Renvoie faux s'il n'a pas pu être reçu.
---@param target table
---@param onEnd fun()  appelé à la fin de l'observation (retour, joueur parti)
function tools.spectate(target, onEnd)
    tools.stopSpectate()
    local ped = PlayerPedId()
    local session = {
        target = target.source, label = target.label, back = GetEntityCoords(ped), heading = GetEntityHeading(ped), onEnd = onEnd,
    }
    spectating = session
    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    anchor(target.x, target.y, target.z)
    CreateThread(function()
        local deadline = GetGameTimer() + cfg.spectate.streamWaitMs
        local targetPed = pedOf(target.source)
        while targetPed == 0 and GetGameTimer() < deadline and spectating == session do
            Wait(cfg.spectate.pollMs)
            targetPed = pedOf(target.source)
        end
        if spectating ~= session then return end
        if targetPed == 0 then
            tools.stopSpectate()
            return
        end
        NetworkSetInSpectatorMode(true, targetPed)
        while spectating == session do
            Wait(cfg.spectate.anchorMs)
            targetPed = pedOf(target.source)
            if targetPed == 0 then
                tools.stopSpectate()
                return
            end
            local c = GetEntityCoords(targetPed)
            anchor(c.x, c.y, c.z)
        end
    end)
end

---@return boolean
function tools.isSpectating()
    return spectating ~= nil
end

function tools.stopSpectate()
    local session = spectating
    if not session then return end
    spectating = nil
    NetworkSetInSpectatorMode(false, PlayerPedId())
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, session.back.x, session.back.y, session.back.z, false, false, false)
    SetEntityHeading(ped, session.heading)
    SetEntityCollision(ped, not state.noclip, true)
    FreezeEntityPosition(ped, state.noclip)
    SetEntityInvincible(ped, state.godmode)
    applyVisibility()
    if session.onEnd then session.onEnd() end
end
