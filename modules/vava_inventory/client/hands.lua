--[[
    vava_inventory/client/hands.lua
    Rôle : accessoire tenu en main, vu de tous. Chaque client lit le champ public `vava_inventory:hands` des joueurs
           (statebag du joueur : { id, item, model, bone, offset, rotation } ou rien) et attache un objet LOCAL, jamais
           réseau, au ped du porteur. Une boucle lente ne tourne que tant qu'au moins un joueur tient quelque chose :
           elle attache ce qui attend son ped (joueur lointain, modèle en cours de chargement), rattache ce que le jeu
           a détaché (réapparition, changement de modèle) et retire les accessoires des joueurs partis.
    Dépendances : shared/constants.lua, config.lua, client/core.lua
]]

local type, tonumber, pairs, next = type, tonumber, pairs, next
local match, concat = string.match, table.concat
local CreateThread, Wait, GetGameTimer, AddEventHandler = CreateThread, Wait, GetGameTimer, AddEventHandler
local AddStateBagChangeHandler, GetPlayerFromServerId, GetActivePlayers, GetPlayerServerId, NetworkIsPlayerActive =
    AddStateBagChangeHandler, GetPlayerFromServerId, GetActivePlayers, GetPlayerServerId, NetworkIsPlayerActive
local GetPlayerPed, DoesEntityExist, GetEntityCoords, GetHashKey, Player = GetPlayerPed, DoesEntityExist, GetEntityCoords, GetHashKey, Player
local RequestModel, HasModelLoaded, IsModelValid, SetModelAsNoLongerNeeded = RequestModel, HasModelLoaded, IsModelValid, SetModelAsNoLongerNeeded
local CreateObject, DeleteObject, AttachEntityToEntity, IsEntityAttachedToEntity, GetPedBoneIndex, SetEntityCollision =
    CreateObject, DeleteObject, AttachEntityToEntity, IsEntityAttachedToEntity, GetPedBoneIndex, SetEntityCollision
local GetCurrentResourceName = GetCurrentResourceName

local cfg = VavaInventory.config.hands
local HANDS_FIELD = VavaInventory.HANDS_FIELD
local RESOURCE = GetCurrentResourceName()
local NO_PLAYER = -1

local hands = {}
VavaInventory.hands = hands

-- numéro serveur du joueur → valeur du champ (ce qu'il tient) ; une entrée tant qu'il tient quelque chose
local wanted = {}
-- numéro serveur → { entity, key, loading } : accessoire affiché, ou en cours de création
local shown = {}
local running = false

---@param value table
---@return string
local function keyOf(value)
    local o, r = value.offset or {}, value.rotation or {}
    return concat({ value.id, value.model, value.bone, o[1], o[2], o[3], r[1], r[2], r[3] }, '|')
end

---@param value any
---@return boolean
local function validValue(value)
    return type(value) == 'table' and type(value.model) == 'string' and type(value.bone) == 'number'
        and type(value.offset) == 'table' and type(value.rotation) == 'table'
end

---@param serverId integer
local function remove(serverId)
    local entry = shown[serverId]
    if not entry then return end
    shown[serverId] = nil
    if entry.entity and DoesEntityExist(entry.entity) then DeleteObject(entry.entity) end
end

--- Crée et attache l'accessoire au ped (modèle chargé avec une attente bornée). Dans son propre thread.
---@param serverId integer
---@param ped integer
---@param value table
local function attach(serverId, ped, value)
    local entry = { entity = nil, key = keyOf(value), loading = true }
    shown[serverId] = entry
    CreateThread(function()
        local model = GetHashKey(value.model)
        if not IsModelValid(model) then
            VavaInventory.core.log.warn("accessoire en main : modèle inconnu '%s'", value.model)
            -- l'entrée reste, sans entité : rien n'est retenté tant que la valeur ne change pas
            entry.loading = false
            return
        end
        RequestModel(model)
        local deadline = GetGameTimer() + cfg.modelTimeoutMs
        while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(50) end
        -- la valeur a pu changer pendant le chargement : cette création n'a plus lieu d'être
        if shown[serverId] ~= entry or not HasModelLoaded(model) or not DoesEntityExist(ped) then
            if shown[serverId] == entry then shown[serverId] = nil end
            SetModelAsNoLongerNeeded(model)
            return
        end
        local coords = GetEntityCoords(ped)
        local entity = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
        SetModelAsNoLongerNeeded(model)
        if entity == 0 then
            shown[serverId] = nil
            return
        end
        SetEntityCollision(entity, false, false)
        local o, r = value.offset, value.rotation
        AttachEntityToEntity(entity, ped, GetPedBoneIndex(ped, value.bone), o[1], o[2], o[3], r[1], r[2], r[3], true, true, false, true, 1, true)
        entry.entity, entry.loading = entity, false
    end)
end

--- Met l'affichage d'un joueur en accord avec ce qu'il tient. Appelé par le statebag et par la boucle lente.
---@param serverId integer
local function reconcile(serverId)
    local value = wanted[serverId]
    local player = GetPlayerFromServerId(serverId)
    local ped = player ~= NO_PLAYER and GetPlayerPed(player) or 0
    if not value or ped == 0 or not DoesEntityExist(ped) then
        remove(serverId)
        if value and player == NO_PLAYER then wanted[serverId] = nil end
        return
    end
    local entry = shown[serverId]
    if entry then
        if entry.loading then return end
        -- toujours là et toujours accroché à ce ped : rien à faire
        if entry.key == keyOf(value) and entry.entity and DoesEntityExist(entry.entity) and IsEntityAttachedToEntity(entry.entity, ped) then return end
        -- modèle inconnu : on n'insiste pas tant que la valeur est la même
        if entry.key == keyOf(value) and not entry.entity then return end
        remove(serverId)
    end
    attach(serverId, ped, value)
end

--- Boucle lente justifiée : une poignée de natives par joueur qui tient quelque chose, toutes les pollMs ; s'arrête
--- d'elle-même quand plus personne ne tient rien.
local function loop()
    while next(wanted) ~= nil do
        Wait(cfg.pollMs)
        for serverId in pairs(wanted) do reconcile(serverId) end
    end
    running = false
end

---@param serverId integer
---@param value any
local function setWanted(serverId, value)
    if validValue(value) then
        wanted[serverId] = value
    else
        wanted[serverId] = nil
    end
    reconcile(serverId)
    if wanted[serverId] and not running then
        running = true
        CreateThread(loop)
    end
end

--- Suit les statebags des joueurs et reprend ce que tiennent les joueurs déjà présents. Appelé par client/main.lua.
function hands.start()
    AddStateBagChangeHandler(HANDS_FIELD, nil, function(bagName, _, value)
        local serverId = tonumber(match(bagName, '^player:(%d+)$'))
        if serverId then setWanted(serverId, value) end
    end)
    for _, player in pairs(GetActivePlayers()) do
        if NetworkIsPlayerActive(player) then
            local serverId = GetPlayerServerId(player)
            local value = Player(serverId).state[HANDS_FIELD]
            if value ~= nil then setWanted(serverId, value) end
        end
    end
end

-- arrêt du module : aucun accessoire ne doit rester accroché aux peds
AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end
    for serverId in pairs(shown) do remove(serverId) end
end)
