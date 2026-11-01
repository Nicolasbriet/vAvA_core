--[[
    vava_gathering/shared/zonestate.lua
    Rôle : lecture pure de l'état d'une zone de récolte reçu du core (clés, valeurs mal formées ignorées, 120 points au
           plus), de l'essai de l'Atelier et de la liste de la carte ; construction de l'état : shared/zonebuild.lua.
    Dépendances : shared/constants.lua
]]

local type, pairs, ipairs, mathType, tostring = type, pairs, ipairs, math.type, tostring
local find, sub = string.find, string.sub

local BANDS = VavaGathering.BANDS
local ID_PATTERN = VavaGathering.ID_PATTERN
local MAX_NODES = VavaGathering.ZONE_MAX_NODES
local MAX_NODE_ID, MAX_ZONE_ID = VavaGathering.MAX_NODE_ID, VavaGathering.MAX_ZONE_ID
local MAX_LABEL, MAX_KIND, MAX_RESOURCE = VavaGathering.MAX_LABEL, VavaGathering.MAX_KIND, VavaGathering.MAX_RESOURCE
local COORD, HEADING = VavaGathering.COORD_SCALE, VavaGathering.HEADING_SCALE

local zonestate = {}
VavaGathering.zonestate = zonestate

local ZONE_KEY = 'zone'
local NODE_PREFIX = 'n:'
local DEF_KEY = VavaGathering.DEF_KEY
local PLACE_PREFIX = VavaGathering.PLACE_PREFIX
zonestate.ZONE_KEY = ZONE_KEY
zonestate.NODE_PREFIX = NODE_PREFIX
zonestate.DEF_KEY = DEF_KEY
zonestate.PLACE_PREFIX = PLACE_PREFIX

local KNOWN_BANDS = {}
for _, band in pairs(BANDS) do KNOWN_BANDS[band] = true end

local function finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end
zonestate.finite = finite

local function isId(value, max)
    return type(value) == 'string' and #value <= max and find(value, ID_PATTERN) ~= nil
end

--- Clé des charges d'un nœud (`n:<nœud>`).
function zonestate.nodeKey(nodeId)
    return NODE_PREFIX .. nodeId
end

--- Clé du lieu d'un nœud (`p:<nœud>`).
function zonestate.placeKey(nodeId)
    return PLACE_PREFIX .. nodeId
end

local function suffix(key, prefix)
    if type(key) ~= 'string' or #key <= #prefix or sub(key, 1, #prefix) ~= prefix then return nil end
    return sub(key, #prefix + 1)
end

--- Nœud d'une clé `n:<nœud>`, ou nil.
function zonestate.nodeOf(key)
    return suffix(key, NODE_PREFIX)
end

--- Nœud d'une clé `p:<nœud>`, ou nil.
function zonestate.placeOf(key)
    return suffix(key, PLACE_PREFIX)
end

local function readZone(value)
    if type(value) ~= 'table' then return nil end
    return { band = KNOWN_BANDS[value.band] and value.band or BANDS.NORMAL, scarred = value.scarred == true }
end

local function readCharges(value)
    if mathType(value) == 'integer' and value >= 0 then return value end
    if mathType(value) == 'float' and value >= 0 and value == value and value < math.huge and value % 1 == 0 then
        return math.tointeger(value)
    end
    return nil
end
zonestate.readCharges = readCharges

--- `def` reçue (liste { nom, type, x, y, z, rayon }, longueurs en centimètres) → { label, kind, x, y, z, radius }, ou nil.
function zonestate.readDef(value)
    if type(value) ~= 'table' then return nil end
    local label, kind, x, y, z, r = value[1], value[2], value[3], value[4], value[5], value[6]
    if type(label) ~= 'string' or #label == 0 or #label > MAX_LABEL or not isId(kind, MAX_KIND) then return nil end
    if not finite(x) or not finite(y) or not finite(z) or not finite(r) then return nil end
    r = r / COORD
    if r <= 0 or r > VavaGathering.ZONE_MAX_RADIUS then return nil end
    return { label = label, kind = kind, x = x / COORD, y = y / COORD, z = z / COORD, radius = r }
end

--- `p:<nœud>` reçu (liste { ressource, x, y, z, cap }, centimètres et dixièmes de degré) → { resource, x, y, z,
--- heading }, ou nil.
function zonestate.readPlace(value)
    if type(value) ~= 'table' or not isId(value[1], MAX_RESOURCE) then return nil end
    local x, y, z, h = value[2], value[3], value[4], value[5]
    if not finite(x) or not finite(y) or not finite(z) then return nil end
    return { resource = value[1], x = x / COORD, y = y / COORD, z = z / COORD,
        heading = finite(h) and h / HEADING or 0.0 }
end

---@class vAvA.GatheringZoneRecord
---@field zone { band: string, scarred: boolean }|nil
---@field charges table<string, integer>
---@field def table|nil
---@field nodes table<string, table>
---@field count integer

--- Pose ou retire le lieu d'un nœud (120 au plus). Vrai si les lieux montrés changent.
local function setPlace(record, nodeId, value)
    if not isId(nodeId, MAX_NODE_ID) then return false end
    local known = record.nodes[nodeId] ~= nil
    local place = value ~= nil and zonestate.readPlace(value) or nil
    if place then
        if not known then
            if record.count >= MAX_NODES then return false end
            record.count = record.count + 1
        end
        record.nodes[nodeId] = place
        return true
    elseif known then
        record.nodes[nodeId] = nil
        record.count = record.count - 1
        return true
    end
    return false
end

--- Applique une différence (`set` puis `removed`) à une zone suivie. Rend l'enregistrement, puis vrai si les lieux
--- montrés ont changé (`def` ou `p:`), puis vrai si `def` a changé : sinon, seuls bande et charges ont bougé.
function zonestate.patch(record, set, removed)
    record.nodes = record.nodes or {}
    record.count = record.count or 0
    local places, def = false, false
    if type(set) == 'table' then
        for key, value in pairs(set) do
            if key == ZONE_KEY then
                record.zone = readZone(value)
            elseif key == DEF_KEY then
                record.def = zonestate.readDef(value)
                places, def = true, true
            else
                local nodeId = zonestate.nodeOf(key)
                if nodeId then
                    record.charges[nodeId] = readCharges(value)
                else
                    nodeId = zonestate.placeOf(key)
                    if nodeId and setPlace(record, nodeId, value) then places = true end
                end
            end
        end
    end
    if type(removed) == 'table' then
        for _, key in ipairs(removed) do
            if key == ZONE_KEY then
                record.zone = nil
            elseif key == DEF_KEY then
                if record.def then places, def = true, true end
                record.def = nil
            else
                local nodeId = zonestate.nodeOf(key)
                if nodeId then
                    record.charges[nodeId] = nil
                else
                    nodeId = zonestate.placeOf(key)
                    if nodeId and setPlace(record, nodeId, nil) then places = true end
                end
            end
        end
    end
    return record, places, def
end

--- Zone suivie lue dans un état entier reçu.
function zonestate.decode(state)
    return (zonestate.patch({ zone = nil, charges = {}, def = nil, nodes = {}, count = 0 }, state, nil))
end

-- Essai de l'Atelier (au seul auteur) ---------------------------------------------------------------------------------

--- Nœud d'essai reçu : liste { ressource, x, y, z, cap, charges } (entier), ou nombre (charges seules d'un nœud connu).
--- Vrai si le lieu montré change.
local function trialNode(record, nodeId, value)
    if not isId(nodeId, MAX_NODE_ID) then return false end
    local known = record.nodes[nodeId]
    if type(value) ~= 'table' then
        local charges = readCharges(value)
        if known and charges then known.charges = charges end
        return false
    end
    local place = zonestate.readPlace(value)
    if not place then return false end
    if not known then
        if record.count >= MAX_NODES then return false end
        record.count = record.count + 1
    end
    place.charges = readCharges(value[6]) or (known and known.charges) or 0
    record.nodes[nodeId] = place
    return true
end

--- Applique un message `vava_gathering:trial` : `full` remplace tout, `patch` change `def`, des nœuds (entiers ou
--- charges seules) et en cache (`hidden`). Rend l'enregistrement (nil si mal formé, ou `patch` sans essai) et vrai si
--- les lieux montrés ont changé.
function zonestate.trial(record, payload)
    if type(payload) ~= 'table' then return nil, false end
    local places = false
    if payload.mode == 'full' then
        record, places = { def = nil, nodes = {}, count = 0 }, true
    elseif payload.mode ~= 'patch' or not record then
        return nil, false
    end
    if payload.def ~= nil then
        record.def = zonestate.readDef(payload.def)
        places = true
    end
    if type(payload.nodes) == 'table' then
        for nodeId, value in pairs(payload.nodes) do
            if trialNode(record, nodeId, value) then places = true end
        end
    end
    if type(payload.hidden) == 'table' then
        for _, nodeId in ipairs(payload.hidden) do
            if type(nodeId) == 'string' and record.nodes[nodeId] then
                record.nodes[nodeId] = nil
                record.count = record.count - 1
                places = true
            end
        end
    end
    return record, places
end

--- Zone d'un message d'essai ou d'une fin d'essai, ou nil.
function zonestate.trialZone(payload)
    local zone = type(payload) == 'table' and payload.zone or payload
    if not isId(zone, MAX_ZONE_ID) then return nil end
    return zone
end

-- Carte -----------------------------------------------------------------------------------------------------------------

--- Liste de la carte reçue ou relue ({ version, zones = { { i, l, k, x, y, r } } }) contrôlée, ou nil si abîmée.
function zonestate.mapList(raw)
    if type(raw) ~= 'table' then return nil end
    local version = raw.version
    if type(version) ~= 'string' or #version > 16 or not find(version, '^%x*$') then return nil end
    local zones = raw.zones
    if type(zones) ~= 'table' or #zones > VavaGathering.MAX_MAP_ZONES then return nil end
    local out = {}
    for i, zone in ipairs(zones) do
        if type(zone) ~= 'table' or not isId(zone.i, MAX_ZONE_ID) or type(zone.l) ~= 'string' or #zone.l == 0
            or #zone.l > MAX_LABEL or not isId(zone.k, MAX_KIND) or not finite(zone.x) or not finite(zone.y)
            or not finite(zone.r) or zone.r <= 0 or zone.r > VavaGathering.ZONE_MAX_RADIUS then
            return nil
        end
        out[i] = { i = zone.i, l = zone.l, k = zone.k, x = zone.x, y = zone.y, r = zone.r }
    end
    return { version = tostring(version), zones = out }
end
