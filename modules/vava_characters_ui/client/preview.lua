--[[
    vava_characters_ui/client/preview.lua
    Rôle : ped d'aperçu de l'éditeur. Créé en local (non réseau) : invisible pour les autres joueurs, aucun coût
           de synchronisation, aucune interférence entre joueurs qui créent au même endroit.
    Dépendances : config.lua
]]

local GetGameTimer, Wait = GetGameTimer, Wait
local GetHashKey, IsModelInCdimage, RequestModel, HasModelLoaded, SetModelAsNoLongerNeeded = GetHashKey, IsModelInCdimage, RequestModel, HasModelLoaded, SetModelAsNoLongerNeeded
local CreatePed, DeleteEntity, DoesEntityExist, FreezeEntityPosition = CreatePed, DeleteEntity, DoesEntityExist, FreezeEntityPosition
local SetEntityInvincible, SetBlockingOfNonTemporaryEvents, SetPedCanRagdoll = SetEntityInvincible, SetBlockingOfNonTemporaryEvents, SetPedCanRagdoll
local GetEntityHeading, SetEntityHeading, GetGroundZFor_3dCoord = GetEntityHeading, SetEntityHeading, GetGroundZFor_3dCoord

local cfg = VavaCharactersUi.config
local PED_TYPE_CIVILIAN = 4
-- la position de la scène est celle du centre du ped : le sol est cherché juste en dessous
local GROUND_PROBE_OFFSET = 1.0

local preview = {}
VavaCharactersUi.preview = preview

local ped = nil

---@param predicate fun(): boolean
---@param timeoutMs number
---@return boolean
local function waitUntil(predicate, timeoutMs)
    local deadline = GetGameTimer() + timeoutMs
    while not predicate() do
        if GetGameTimer() > deadline then return false end
        Wait(cfg.pollMs)
    end
    return true
end

---@param model string
---@return integer|nil
local function loadModel(model)
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    if not waitUntil(function() return HasModelLoaded(hash) end, cfg.modelTimeoutMs) then return nil end
    return hash
end

---@return number
local function groundZ()
    local scene = cfg.scene
    local z = scene.z - GROUND_PROBE_OFFSET
    waitUntil(function()
        local found, ground = GetGroundZFor_3dCoord(scene.x, scene.y, scene.z + GROUND_PROBE_OFFSET, false)
        if found then z = ground end
        return found
    end, cfg.collisionTimeoutMs)
    return z
end

--- Crée (ou remplace) le ped d'aperçu pour un sexe. Bloque le thread pendant le chargement du modèle.
---@param sex string
---@return integer|nil ped
function preview.spawn(sex)
    local model = cfg.models[sex]
    local hash = model and loadModel(model)
    if not hash then return nil end
    preview.destroy()
    local scene = cfg.scene
    ped = CreatePed(PED_TYPE_CIVILIAN, hash, scene.x, scene.y, groundZ(), scene.heading, false, false)
    SetModelAsNoLongerNeeded(hash)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    return ped
end

---@return integer|nil
function preview.get()
    if ped and DoesEntityExist(ped) then return ped end
    return nil
end

---@param delta number  degrés
function preview.rotate(delta)
    local current = preview.get()
    if current then SetEntityHeading(current, (GetEntityHeading(current) + delta) % 360.0) end
end

function preview.destroy()
    if ped and DoesEntityExist(ped) then DeleteEntity(ped) end
    ped = nil
end
