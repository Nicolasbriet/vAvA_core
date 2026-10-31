--[[
    vava_gathering/client/blips.lua
    Rôle : les zones de récolte sur la carte, vues du joueur : un blip par zone (icône et couleur selon le type de lieu,
           nommé comme elle, à courte portée) et le cercle translucide de son rayon. Depuis 1.8.0 (T-102), la liste ne
           vient plus de la config : elle est gardée en stockage local (KVP `vava_gathering:map`, avec sa version) et
           redemandée au serveur une fois par séance, à la première apparition (RPC `vava_gathering:map`, ≈ 30 octets
           si rien n'a changé) ; une liste reçue remplace les blips et la KVP. Une zone suivie qui porte son nom, son
           type et son lieu corrige son blip (rien n'est envoyé). Retirés à la sélection, au déchargement et à l'arrêt
           du module ; repère de la carte posé sur une zone à la demande du panneau. Aucune boucle.
    Dépendances : shared/constants.lua, config_client.lua, shared/zonestate.lua, client/core.lua, client/props.lua
]]

local type, ipairs, pairs, pcall, tostring = type, ipairs, pairs, pcall, tostring
local CreateThread, AddEventHandler = CreateThread, AddEventHandler
local GetResourceKvpString, SetResourceKvp, DeleteResourceKvp = GetResourceKvpString, SetResourceKvp, DeleteResourceKvp
local AddBlipForCoord, AddBlipForRadius, RemoveBlip, DoesBlipExist = AddBlipForCoord, AddBlipForRadius, RemoveBlip, DoesBlipExist
local SetBlipSprite, SetBlipColour, SetBlipScale, SetBlipAlpha, SetBlipAsShortRange =
    SetBlipSprite, SetBlipColour, SetBlipScale, SetBlipAlpha, SetBlipAsShortRange
local BeginTextCommandSetBlipName, AddTextComponentSubstringPlayerName, EndTextCommandSetBlipName =
    BeginTextCommandSetBlipName, AddTextComponentSubstringPlayerName, EndTextCommandSetBlipName
local SetNewWaypoint = SetNewWaypoint
local jsonEncode, jsonDecode = json.encode, json.decode

local core = VavaGathering.core
if not core then return end

local mapCfg = VavaGathering.config.map
local zonestate = VavaGathering.zonestate
local props = VavaGathering.props
local RPC = VavaGathering.RPC
local RESOURCE = VavaGathering.resource
local KVP = VavaGathering.MAP_KVP
local MAX_BYTES = VavaGathering.MAX_MAP_BYTES
local NAME_TEXT = 'STRING'

local blips = {}
VavaGathering.blips = blips

-- liste de la carte : { version, zones = { { i, l, k, x, y, r } } } ; zones par identifiant
local list = { version = '', zones = {} }
local byId = {}
-- blips posés : id de zone → { blip, ring? }
local handles = {}
local shown = false
-- liste déjà redemandée au serveur pendant cette séance
local asked = false

---@param kind string
---@return { sprite: integer, colour: integer }
local function lookOf(kind)
    return mapCfg.kinds[kind] or mapCfg.default
end

---@param blip integer
---@param label string
local function name(blip, label)
    BeginTextCommandSetBlipName(NAME_TEXT)
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)
end

local function drop(id)
    local entry = handles[id]
    if not entry then return end
    handles[id] = nil
    if DoesBlipExist(entry.blip) then RemoveBlip(entry.blip) end
    if entry.ring and DoesBlipExist(entry.ring) then RemoveBlip(entry.ring) end
end

--- Pose (ou repose) le blip d'une zone : { i, l, k, x, y, r }.
local function place(zone)
    drop(zone.i)
    local look = lookOf(zone.k)
    local blip = AddBlipForCoord(zone.x, zone.y, 0.0)
    SetBlipSprite(blip, look.sprite)
    SetBlipColour(blip, look.colour)
    SetBlipScale(blip, mapCfg.scale)
    SetBlipAsShortRange(blip, true)
    name(blip, zone.l)
    local entry = { blip = blip }
    if mapCfg.ring.show then
        local ring = AddBlipForRadius(zone.x, zone.y, 0.0, zone.r)
        SetBlipColour(ring, look.colour)
        SetBlipAlpha(ring, mapCfg.ring.alpha)
        entry.ring = ring
    end
    handles[zone.i] = entry
end

--- Retire tous les blips du module.
function blips.hide()
    shown = false
    for id in pairs(handles) do drop(id) end
end

--- Pose les blips de la liste gardée (une seule fois : les apparitions suivantes ne les doublent pas).
local function showAll()
    if not mapCfg.blips then return end
    for id in pairs(handles) do drop(id) end
    for _, zone in ipairs(list.zones) do place(zone) end
    shown = true
end

--- Adopte une liste contrôlée (zonestate.mapList) et la garde en stockage local.
local function adopt(checked, save)
    list = checked
    byId = {}
    for _, zone in ipairs(list.zones) do byId[zone.i] = zone end
    if save then
        local called, text = pcall(jsonEncode, list)
        if called and type(text) == 'string' and #text <= MAX_BYTES then SetResourceKvp(KVP, text) end
    end
    if shown or mapCfg.blips then showAll() end
end

--- Liste gardée en stockage local, contrôlée ; abîmée : oubliée.
local function loadKept()
    local raw = GetResourceKvpString(KVP)
    if type(raw) ~= 'string' or raw == '' then return end
    local checked = nil
    if #raw <= MAX_BYTES then
        local called, decoded = pcall(jsonDecode, raw)
        checked = called and zonestate.mapList(decoded) or nil
    end
    if checked then adopt(checked, false) else DeleteResourceKvp(KVP) end
end

--- Liste redemandée au serveur (sa version gardée part avec) ; une liste reçue remplace les blips et la KVP.
local function refresh()
    local ok, success, answer = core.rpc.call(RPC.MAP, list.version)
    if not ok or not success or type(answer) ~= 'table' then
        core.log.debug('liste de la carte non reçue : %s', tostring(ok and answer or success))
        return
    end
    if answer.zones == nil then return end
    local checked = zonestate.mapList(answer)
    if checked then adopt(checked, true) end
end

--- Première apparition de la séance : blips de la liste gardée, puis la liste redemandée une fois.
local function spawned()
    if not shown then
        loadKept()
        if mapCfg.blips then showAll() end
    end
    if asked then return end
    asked = true
    CreateThread(refresh)
end

--- Une zone suivie porte son nom, son type et son lieu : son blip est corrigé (rien n'est envoyé).
---@param zoneId string
---@param def table|nil  { label, kind, x, y, z, radius }
function blips.correct(zoneId, def)
    if not def then return end
    local zone = byId[zoneId]
    if zone and zone.l == def.label and zone.k == def.kind and zone.x == def.x and zone.y == def.y
        and zone.r == def.radius then
        return
    end
    zone = { i = zoneId, l = def.label, k = def.kind, x = def.x, y = def.y, r = def.radius }
    if not byId[zoneId] then list.zones[#list.zones + 1] = zone end
    byId[zoneId] = zone
    for i, known in ipairs(list.zones) do
        if known.i == zoneId then list.zones[i] = zone end
    end
    if shown then place(zone) end
end

--- Repère de la carte posé au centre d'une zone (panneau des zones).
---@param zoneId string
---@return boolean  faux si la zone est inconnue
function blips.waypoint(zoneId)
    local zone = byId[zoneId]
    if zone then
        SetNewWaypoint(zone.x, zone.y)
        return true
    end
    local def = props.zone(zoneId)
    if not def then return false end
    SetNewWaypoint(def.x, def.y)
    return true
end

--- Suit l'entrée et la sortie du jeu. Appelé par client/main.lua.
function blips.start()
    core.hooks.after('core:character:spawning', spawned)
    core.hooks.after('core:character:selection', function()
        blips.hide()
        asked = false
    end)
    core.hooks.after('core:character:unloaded', function()
        blips.hide()
        asked = false
    end)
    props.onDef(blips.correct)
    if core.characters.current() and not core.characters.awaitingSelection() then spawned() end
end

-- arrêt du module : aucun blip ne doit rester sur la carte
AddEventHandler('onResourceStop', function(resource)
    if resource == RESOURCE then blips.hide() end
end)
