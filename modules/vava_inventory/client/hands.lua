--[[
    vava_inventory/client/hands.lua
    Rôle : accessoire tenu en main, vu des joueurs proches. Le serveur écrit ce que tient chaque joueur sur le statebag
           de son ped (`vava_inventory:inHand`, { id, item } ou rien, 1.7.0) ; OneSync ne l'envoie qu'aux joueurs qui
           ont ce ped à portée, et le renvoie quand le ped apparaît chez eux (arrivée de loin, nouveau ped). Ce client
           attache alors un objet LOCAL, jamais réseau, au ped. Une boucle lente ne tourne que tant qu'une main reçue
           est suivie : elle attache ce qui attend son ped (main reçue avant lui, modèle en cours de chargement),
           rattache ce que le jeu a détaché, et oublie les mains dont le ped a disparu (hors de portée, remplacé) : à
           son retour, le statebag revient avec lui.
           Le statebag d'un ped peut avoir été écrit par le client qui le possède : seuls `id` et `item` y sont lus,
           l'accessoire (modèle, os, décalage, rotation) vient de la liste des objets tenables que le serveur publie
           dans GlobalState (que seul le serveur écrit), et rien n'est montré ailleurs que sur un ped de joueur.
    Dépendances : shared/constants.lua, config.lua, shared/held.lua, client/core.lua
]]

local type, pairs, next = type, pairs, next
local concat = table.concat
local CreateThread, Wait, GetGameTimer, AddEventHandler = CreateThread, Wait, GetGameTimer, AddEventHandler
local AddStateBagChangeHandler, GetActivePlayers, GetPlayerPed, Entity =
    AddStateBagChangeHandler, GetActivePlayers, GetPlayerPed, Entity
local NetworkDoesEntityExistWithNetworkId, NetworkGetEntityFromNetworkId, NetworkGetNetworkIdFromEntity,
    NetworkGetEntityIsNetworked = NetworkDoesEntityExistWithNetworkId, NetworkGetEntityFromNetworkId,
    NetworkGetNetworkIdFromEntity, NetworkGetEntityIsNetworked
local DoesEntityExist, IsEntityAPed, IsPedAPlayer, GetEntityCoords, GetHashKey =
    DoesEntityExist, IsEntityAPed, IsPedAPlayer, GetEntityCoords, GetHashKey
local RequestModel, HasModelLoaded, IsModelValid, SetModelAsNoLongerNeeded = RequestModel, HasModelLoaded, IsModelValid, SetModelAsNoLongerNeeded
local CreateObject, DeleteObject, AttachEntityToEntity, IsEntityAttachedToEntity, GetPedBoneIndex, SetEntityCollision =
    CreateObject, DeleteObject, AttachEntityToEntity, IsEntityAttachedToEntity, GetPedBoneIndex, SetEntityCollision
local GetCurrentResourceName = GetCurrentResourceName

local cfg = VavaInventory.config.hands
local held = VavaInventory.held
local HELD_STATE = VavaInventory.HELD_STATE
local HELD_MODELS = VavaInventory.HELD_MODELS
local RESOURCE = GetCurrentResourceName()
-- raisons pour lesquelles une main reçue n'a pas (encore) de ped où se montrer (voir pedOf)
local ABSENT, NOT_PED, NOT_PLAYER = 1, 2, 3

local hands = {}
VavaInventory.hands = hands

---@class vAvA.HeldWanted
---@field value table     valeur reçue { id, item }
---@field since integer   instant de réception (attente bornée du ped)
---@field ped? integer    handle de l'entité vue ici sous ce numéro réseau depuis la réception (nil : pas encore vue)
---@field prop? table     accessoire à montrer (held.prop), calculé à la réception et quand la liste change ; nil : rien
---@field key? string     identité de cet accessoire (keyOf)

---@type table<integer, vAvA.HeldWanted>  numéro réseau du ped → main reçue ; une entrée tant qu'elle est suivie
local wanted = {}
-- numéro réseau du ped → { entity, key, loading } : accessoire affiché, ou en cours de création
local shown = {}
local running = false
-- objet → accessoire déclaré { model, bone, offset, rotation }, publié par le serveur : seule source de placement
local declared = {}

---@param prop table  accessoire (voir held.prop)
---@return string
local function keyOf(prop)
    local o, r = prop.offset, prop.rotation
    return concat({ prop.id, prop.model, prop.bone, o[1], o[2], o[3], r[1], r[2], r[3] }, '|')
end

--- Accessoire d'une main reçue, d'après la liste courante des objets tenables.
---@param want vAvA.HeldWanted
local function resolve(want)
    want.prop = held.prop(want.value, declared)
    want.key = want.prop and keyOf(want.prop) or nil
end

---@param netId integer
local function remove(netId)
    local entry = shown[netId]
    if not entry then return end
    shown[netId] = nil
    if entry.entity and DoesEntityExist(entry.entity) then DeleteObject(entry.entity) end
end

--- Entité qui porte ce numéro réseau ici (0 si aucune), et ce qui empêche d'y montrer la main : ABSENT (aucune entité
--- ici : pas encore créée, hors de portée, supprimée), NOT_PED (une main écrite ailleurs que sur un ped n'est jamais
--- montrée), NOT_PLAYER (ped tout juste créé et pas encore lié à son joueur, ou ped d'un PNJ : rien de montré tant que
--- c'est le cas), nil : ped de joueur.
---@param netId integer
---@return integer entity
---@return integer|nil reason
local function pedOf(netId)
    if not NetworkDoesEntityExistWithNetworkId(netId) then return 0, ABSENT end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return 0, ABSENT end
    if not IsEntityAPed(entity) then return entity, NOT_PED end
    if not IsPedAPlayer(entity) then return entity, NOT_PLAYER end
    return entity, nil
end

--- Crée et attache l'accessoire au ped (modèle chargé avec une attente bornée). Dans son propre thread.
---@param netId integer
---@param ped integer
---@param prop table  accessoire (voir held.prop)
---@param key string  identité de cet accessoire (keyOf)
local function attach(netId, ped, prop, key)
    local entry = { entity = nil, key = key, loading = true }
    shown[netId] = entry
    CreateThread(function()
        local model = GetHashKey(prop.model)
        if not IsModelValid(model) then
            VavaInventory.core.log.warn("accessoire en main : modèle inconnu '%s'", prop.model)
            -- l'entrée reste, sans entité : rien n'est retenté tant que la valeur ne change pas
            entry.loading = false
            return
        end
        RequestModel(model)
        local deadline = GetGameTimer() + cfg.modelTimeoutMs
        while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(50) end
        -- la valeur a pu changer pendant le chargement : cette création n'a plus lieu d'être
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
        local o, r = prop.offset, prop.rotation
        AttachEntityToEntity(entity, ped, GetPedBoneIndex(ped, prop.bone), o[1], o[2], o[3], r[1], r[2], r[3], true, true, false, true, 1, true)
        entry.entity, entry.loading = entity, false
    end)
end

--- Met l'affichage d'un ped en accord avec la main reçue. Appelé par le statebag et par la boucle lente.
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
        -- ped parti (hors de portée, remplacé) : son statebag reviendra avec lui ; ped jamais venu : attente bornée
        if want.ped or GetGameTimer() - want.since > cfg.awaitPedMs then wanted[netId] = nil end
        return
    end
    -- une main écrite ailleurs que sur un ped n'est jamais montrée ; une autre entité sous ce numéro réseau que celle
    -- vue d'abord (numéro redonné) n'a pas cette main : oubliée, son propre statebag arrivera s'il en a un
    if reason == NOT_PED or (want.ped and want.ped ~= ped) then
        remove(netId)
        wanted[netId] = nil
        return
    end
    want.ped = ped
    -- ped pas encore lié à son joueur, ou objet qui n'est pas (ou plus) déclaré tenable : rien d'affiché, relu au tour
    -- suivant ou quand la liste change
    local prop, key = want.prop, want.key
    if reason == NOT_PLAYER or not prop then
        remove(netId)
        return
    end
    local entry = shown[netId]
    if entry then
        if entry.loading then return end
        -- toujours là et toujours accroché à ce ped : rien à faire
        if entry.key == key and entry.entity and DoesEntityExist(entry.entity) and IsEntityAttachedToEntity(entry.entity, ped) then return end
        -- modèle inconnu : on n'insiste pas tant que la valeur est la même
        if entry.key == key and not entry.entity then return end
        remove(netId)
    end
    attach(netId, ped, prop, key)
end

--- Boucle lente justifiée : une poignée de natives par main suivie, toutes les pollMs ; s'arrête d'elle-même quand
--- plus aucune main n'est suivie (personne à portée ne tient rien).
local function loop()
    while next(wanted) ~= nil do
        Wait(cfg.pollMs)
        for netId in pairs(wanted) do reconcile(netId) end
    end
    running = false
end

--- Main reçue pour un ped (nil : mains vides). L'accessoire est calculé ici une fois, non à chaque tour de boucle.
---@param netId integer
---@param value any
local function setWanted(netId, value)
    if type(value) == 'table' then
        local want = { value = value, since = GetGameTimer() }
        resolve(want)
        wanted[netId] = want
    else
        wanted[netId] = nil
    end
    reconcile(netId)
    if wanted[netId] and not running then
        running = true
        CreateThread(loop)
    end
end

--- Nouvelle liste des objets tenables : chaque accessoire est recalculé puis revérifié (déclaration retirée, ou
--- arrivée après la main).
---@param list any
local function setDeclared(list)
    declared = type(list) == 'table' and list or {}
    for netId, want in pairs(wanted) do
        resolve(want)
        reconcile(netId)
    end
end

--- Suit les statebags des peds et reprend ce que tiennent les joueurs déjà à portée. Appelé par client/main.lua.
--- Seuls les peds présents ici ont un statebag ici : un joueur hors de portée n'a rien à montrer, sa main arrivera
--- avec son ped.
function hands.start()
    declared = type(GlobalState[HELD_MODELS]) == 'table' and GlobalState[HELD_MODELS] or {}
    AddStateBagChangeHandler(HELD_MODELS, 'global', function(_, _, list) setDeclared(list) end)
    AddStateBagChangeHandler(HELD_STATE, nil, function(bagName, _, value)
        local netId = held.netIdOf(bagName)
        if netId then setWanted(netId, value) end
    end)
    for _, player in pairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        if ped ~= 0 and DoesEntityExist(ped) and NetworkGetEntityIsNetworked(ped) then
            local value = Entity(ped).state[HELD_STATE]
            if value ~= nil then setWanted(NetworkGetNetworkIdFromEntity(ped), value) end
        end
    end
end

-- arrêt du module : aucun accessoire ne doit rester accroché aux peds
AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end
    for netId in pairs(shown) do remove(netId) end
end)
