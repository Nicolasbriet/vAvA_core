--[[
    vava_combat/client/shields.lua
    Rôle : boucliers accrochés des peds à portée (patron de vava_inventory/client/hands.lua). Le serveur écrit
           { id, item } sur le statebag du ped du porteur (`vava_combat:shield`) ; OneSync ne l'envoie qu'aux joueurs
           qui ont ce ped à portée, et le renvoie quand le ped apparaît chez eux. Ce client attache alors un objet
           LOCAL (jamais réseau, sans collision) au ped : au bras si le porteur tient une arme qui s'y prête, dans le dos
           sinon (position lue sur le statebag de la main de l'inventaire, même ped, et calculée par shared/shield.lua).
           Placement (modèle, os, décalage, rotation) lu dans SA config, jamais dans la valeur ; rien n'est montré
           ailleurs que sur un ped de joueur. Quand la main change, l'accessoire est réattaché à l'autre os sans être
           recréé. Une boucle lente ne tourne que tant qu'un bouclier est suivi : elle attache ce qui attendait son ped
           ou son modèle, rattache ce que le jeu a détaché, oublie les peds disparus, et ne montre un bouclier qu'à
           `shield.showRadius` (120 m) du joueur local : au-delà, l'accessoire est retiré et revient quand on
           s'approche. Position et placement sont recalculés seulement quand la valeur ou la main change. Modèle invalide : une ligne de
           console, rien d'affiché, pas de nouvel essai tant que la valeur ne change pas.
    Dépendances : shared/constants.lua, config_client.lua, shared/shield.lua, client/core.lua, bridge/client.lua
]]

local type, pairs, next, tostring = type, pairs, next, tostring
local CreateThread, Wait, GetGameTimer, AddEventHandler = CreateThread, Wait, GetGameTimer, AddEventHandler
local AddStateBagChangeHandler, GetActivePlayers, GetPlayerPed, Entity =
    AddStateBagChangeHandler, GetActivePlayers, GetPlayerPed, Entity
local NetworkDoesEntityExistWithNetworkId, NetworkGetEntityFromNetworkId, NetworkGetNetworkIdFromEntity,
    NetworkGetEntityIsNetworked = NetworkDoesEntityExistWithNetworkId, NetworkGetEntityFromNetworkId,
    NetworkGetNetworkIdFromEntity, NetworkGetEntityIsNetworked
local DoesEntityExist, IsEntityAPed, IsPedAPlayer, GetEntityCoords, GetHashKey, PlayerPedId =
    DoesEntityExist, IsEntityAPed, IsPedAPlayer, GetEntityCoords, GetHashKey, PlayerPedId
local RequestModel, HasModelLoaded, IsModelValid, SetModelAsNoLongerNeeded = RequestModel, HasModelLoaded, IsModelValid, SetModelAsNoLongerNeeded
local CreateObject, DeleteObject, AttachEntityToEntity, IsEntityAttachedToEntity, GetPedBoneIndex, SetEntityCollision =
    CreateObject, DeleteObject, AttachEntityToEntity, IsEntityAttachedToEntity, GetPedBoneIndex, SetEntityCollision
local GetCurrentResourceName = GetCurrentResourceName

local cfg = VavaCombat.config
local shield = VavaCombat.shield
local bridge = VavaCombat.bridge
local SHIELD_STATE = VavaCombat.SHIELD_STATE
local HELD_STATE = bridge.HELD_STATE
local RESOURCE = GetCurrentResourceName()
local ABSENT, NOT_PED, NOT_PLAYER = 1, 2, 3
-- carré du rayon d'affichage : au-delà, l'accessoire est retiré (la valeur reste suivie, il revient en s'approchant)
local SHOW_RADIUS_SQ = cfg.shield.showRadius * cfg.shield.showRadius

local shields = {}
VavaCombat.shields = shields

---@class vAvA.ShieldWanted
---@field value table      valeur reçue { id, item }
---@field since integer    instant de réception (attente bornée du ped)
---@field ped? integer     entité vue sous ce numéro réseau depuis la réception
---@field handKnown boolean  main du porteur connue (statebag lu, ou reçue par son gestionnaire)
---@field handItem? string   objet tenu par le porteur (nil : mains vides)
---@field position? string   bras ou dos, calculé quand la valeur ou la main change (resolve)
---@field place? table       placement de la config pour cette position, ou nil (objet sans placement)
---@field key? string        identité de l'accessoire (numéro de pile, objet, modèle)

---@type table<integer, vAvA.ShieldWanted>  numéro réseau du ped → bouclier reçu
local wanted = {}
-- numéro réseau du ped → { entity, key, loading, position } : accessoire affiché, ou en cours de création
local shown = {}
local running = false

--- Objet tenu d'après une valeur du statebag de la main (seul `item` est lu ; toute autre forme : mains vides).
---@param value any
---@return string|nil
local function itemOf(value)
    if type(value) == 'table' and type(value.item) == 'string' then return value.item end
    return nil
end

--- Position, placement et identité de l'accessoire, recalculés seulement quand la valeur ou la main change (jamais à
--- chaque tour de boucle). La main n'est lue sur le statebag que si son gestionnaire ne l'a pas encore donnée.
---@param want vAvA.ShieldWanted
---@param ped integer
local function resolve(want, ped)
    if not want.handKnown then
        want.handItem, want.handKnown = itemOf(Entity(ped).state[HELD_STATE]), true
    end
    want.position = shield.position(want.handItem, cfg.weaponClasses, cfg.shield.armWith, cfg.shield.armWithEmptyHand)
    want.place = shield.placement(want.value.item, want.position, cfg.shields)
    want.key = want.place and (tostring(want.value.id) .. '|' .. want.value.item .. '|' .. want.place.model) or nil
end

--- Vrai si le ped est assez près du joueur local pour montrer son bouclier.
---@param ped integer
---@return boolean
local function near(ped)
    local me = PlayerPedId()
    if ped == me then return true end
    local a, b = GetEntityCoords(ped), GetEntityCoords(me)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return dx * dx + dy * dy + dz * dz <= SHOW_RADIUS_SQ
end

---@param netId integer
local function remove(netId)
    local entry = shown[netId]
    if not entry then return end
    shown[netId] = nil
    if entry.entity and DoesEntityExist(entry.entity) then DeleteObject(entry.entity) end
end

---@param netId integer
---@return integer entity
---@return integer|nil reason  ABSENT, NOT_PED, NOT_PLAYER, ou nil (ped de joueur)
local function pedOf(netId)
    if not NetworkDoesEntityExistWithNetworkId(netId) then return 0, ABSENT end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return 0, ABSENT end
    if not IsEntityAPed(entity) then return entity, NOT_PED end
    if not IsPedAPlayer(entity) then return entity, NOT_PLAYER end
    return entity, nil
end

---@param entity integer
---@param ped integer
---@param place table  { bone, offset, rotation }
local function attachTo(entity, ped, place)
    local o, r = place.offset, place.rotation
    AttachEntityToEntity(entity, ped, GetPedBoneIndex(ped, place.bone), o[1], o[2], o[3], r[1], r[2], r[3], true, true,
        false, true, 1, true)
end

--- Crée et attache l'accessoire (modèle chargé avec une attente bornée), dans son propre thread.
---@param netId integer
---@param ped integer
---@param place table  { model, bone, offset, rotation }
---@param key string
---@param position string
local function attach(netId, ped, place, key, position)
    local entry = { entity = nil, key = key, loading = true, position = position }
    shown[netId] = entry
    CreateThread(function()
        local model = GetHashKey(place.model)
        if not IsModelValid(model) then
            VavaCombat.log.warn("bouclier accroché : modèle inconnu '%s'", tostring(place.model))
            entry.loading = false
            return
        end
        RequestModel(model)
        local deadline = GetGameTimer() + cfg.shield.modelTimeoutMs
        while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(50) end
        if shown[netId] ~= entry or not HasModelLoaded(model) or not DoesEntityExist(ped) then
            if shown[netId] == entry then shown[netId] = nil end
            SetModelAsNoLongerNeeded(model)
            return
        end
        local coords = GetEntityCoords(ped)
        local entity = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
        SetModelAsNoLongerNeeded(model)
        if entity == 0 then
            shown[netId] = nil
            return
        end
        SetEntityCollision(entity, false, false)
        attachTo(entity, ped, place)
        entry.entity, entry.loading = entity, false
    end)
end

--- Met l'affichage d'un ped en accord avec le bouclier reçu et la main de son porteur.
---@param netId integer
local function reconcile(netId)
    local want = wanted[netId]
    if not want then
        remove(netId)
        return
    end
    local ped, reason = pedOf(netId)
    if reason == ABSENT then
        remove(netId)
        if want.ped or GetGameTimer() - want.since > cfg.shield.awaitPedMs then wanted[netId] = nil end
        return
    end
    if reason == NOT_PED or (want.ped and want.ped ~= ped) then
        remove(netId)
        wanted[netId] = nil
        return
    end
    want.ped = ped
    if reason == NOT_PLAYER then
        remove(netId)
        return
    end
    if not want.position then resolve(want, ped) end
    local position, place, key = want.position, want.place, want.key
    -- objet sans placement, ou porteur au-delà du rayon d'affichage : rien de montré, relu au tour suivant
    if not place or not near(ped) then
        remove(netId)
        return
    end
    local entry = shown[netId]
    if entry then
        if entry.loading then return end
        if entry.key == key and not entry.entity then return end
        if entry.key == key and DoesEntityExist(entry.entity) then
            -- même accessoire : réattaché seulement si la position a changé ou si le jeu l'a détaché
            if entry.position ~= position or not IsEntityAttachedToEntity(entry.entity, ped) then
                attachTo(entry.entity, ped, place)
                entry.position = position
            end
            return
        end
        remove(netId)
    end
    attach(netId, ped, place, key, position)
end

--- Boucle lente justifiée : une poignée de natives par bouclier suivi, toutes les pollMs ; s'arrête d'elle-même quand
--- plus aucun bouclier n'est suivi.
local function loop()
    while next(wanted) ~= nil do
        Wait(cfg.shield.pollMs)
        for netId in pairs(wanted) do reconcile(netId) end
    end
    running = false
end

--- Bouclier reçu pour un ped (nil : décroché).
---@param netId integer
---@param value any
local function setWanted(netId, value)
    if value ~= nil and shield.valid(value) then
        local previous = wanted[netId]
        -- la main déjà connue est gardée ; position et placement seront recalculés (resolve)
        wanted[netId] = { value = value, since = GetGameTimer(), handKnown = previous ~= nil and previous.handKnown,
            handItem = previous and previous.handItem }
    else
        wanted[netId] = nil
    end
    reconcile(netId)
    if wanted[netId] and not running then
        running = true
        CreateThread(loop)
    end
end

--- Suit les statebags des peds et reprend les boucliers des joueurs déjà à portée. Appelé par client/main.lua.
function shields.start()
    AddStateBagChangeHandler(SHIELD_STATE, nil, function(bagName, _, value)
        local netId = shield.netIdOf(bagName)
        if netId then setWanted(netId, value) end
    end)
    -- main d'un porteur suivi : la valeur reçue fait foi (le statebag n'est pas encore à jour pendant l'appel)
    AddStateBagChangeHandler(HELD_STATE, nil, function(bagName, _, value)
        local netId = shield.netIdOf(bagName)
        local want = netId and wanted[netId]
        if not want then return end
        want.handItem, want.handKnown, want.position = itemOf(value), true, nil
        reconcile(netId)
    end)
    for _, player in pairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        if ped ~= 0 and DoesEntityExist(ped) and NetworkGetEntityIsNetworked(ped) then
            local value = Entity(ped).state[SHIELD_STATE]
            if value ~= nil then setWanted(NetworkGetNetworkIdFromEntity(ped), value) end
        end
    end
end

-- arrêt du module : aucun bouclier ne doit rester accroché aux peds
AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end
    for netId in pairs(shown) do remove(netId) end
end)
