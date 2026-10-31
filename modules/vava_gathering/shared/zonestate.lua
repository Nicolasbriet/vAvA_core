--[[
    vava_gathering/shared/zonestate.lua
    Rôle : règles pures de l'état d'une zone de récolte tenu par les abonnements de zone du core (vAvA_core ≥ 0.11.0).
           Clés : `zone` → { band, scarred } (jamais la vitalité : seule la bande et la cicatrice changent ce que voit
           le joueur) et `n:<nœud>` → charges ; depuis 1.8.0 (T-102), `def` → { l, k, x, y, z, r } (nom, type de lieu,
           lieu de la zone) et `p:<nœud>` → { r, x, y, z, h } (ressource et lieu d'un point) : les zones et les points
           créés dans l'Atelier arrivent ainsi chez les seuls joueurs proches, sans redémarrage. Ni coût, ni repos, ni
           cicatrice réglée, ni charges maximales, ni repousse, ni nom d'un point dans l'état (part serveur).
           Côté serveur : cercle de la zone du core (centre de la zone, rayon qui englobe ses nœuds au sol, marge),
           état entier, différence entre deux états (clés changées, clés retirées) et paquets de 64 clés. Côté client :
           lecture d'un état reçu et application d'une différence (valeurs mal formées ignorées ou ramenées aux valeurs
           par défaut, 120 points au plus), lecture de l'essai de l'Atelier (envoyé au seul auteur), liste de la carte
           gardée en stockage local.
           L'état d'une zone est public (positions déclarées par les clients sous OneSync) : rien de secret dedans.
           Testée : tests/spec/gathering_zonestate_spec.lua.
    Dépendances : shared/constants.lua
]]

local type, pairs, ipairs, sqrt, mathType, tostring = type, pairs, ipairs, math.sqrt, math.type, tostring
local find, sub = string.find, string.sub
local sort = table.sort

local BANDS = VavaGathering.BANDS
local ID_PATTERN = VavaGathering.ID_PATTERN
local MAX_NODES = VavaGathering.ZONE_MAX_NODES
local MAX_NODE_ID, MAX_ZONE_ID = VavaGathering.MAX_NODE_ID, VavaGathering.MAX_ZONE_ID
local MAX_LABEL, MAX_KIND, MAX_RESOURCE = VavaGathering.MAX_LABEL, VavaGathering.MAX_KIND, VavaGathering.MAX_RESOURCE

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

-- clés changées ou retirées au plus par appel à core.zones.set
zonestate.CHUNK = 64

local KNOWN_BANDS = {}
for _, band in pairs(BANDS) do KNOWN_BANDS[band] = true end

---@param value any
---@return boolean
local function finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function isId(value, max)
    return type(value) == 'string' and #value <= max and find(value, ID_PATTERN) ~= nil
end

--- Clé de l'état qui porte les charges d'un nœud.
---@param nodeId string
---@return string
function zonestate.nodeKey(nodeId)
    return NODE_PREFIX .. nodeId
end

--- Clé de l'état qui porte la ressource et le lieu d'un nœud (T-102).
---@param nodeId string
---@return string
function zonestate.placeKey(nodeId)
    return PLACE_PREFIX .. nodeId
end

---@param key any
---@param prefix string
---@return string|nil
local function suffix(key, prefix)
    if type(key) ~= 'string' or #key <= #prefix or sub(key, 1, #prefix) ~= prefix then return nil end
    return sub(key, #prefix + 1)
end

--- Nœud d'une clé de l'état (`n:<nœud>`), ou nil pour toute autre clé.
---@param key any
---@return string|nil
function zonestate.nodeOf(key)
    return suffix(key, NODE_PREFIX)
end

--- Nœud d'une clé de lieu (`p:<nœud>`), ou nil.
---@param key any
---@return string|nil
function zonestate.placeOf(key)
    return suffix(key, PLACE_PREFIX)
end

--- Valeur publiée d'une zone : bande et cicatrice, rien d'autre.
---@param band string
---@param scarred any
---@return { band: string, scarred: boolean }
function zonestate.zoneValue(band, scarred)
    return { band = band, scarred = scarred == true }
end

--- Deux valeurs publiées identiques (rien à envoyer) ?
---@param a any
---@param b any
---@return boolean
function zonestate.sameZone(a, b)
    return type(a) == 'table' and type(b) == 'table' and a.band == b.band and a.scarred == b.scarred
end

--- Valeur `def` d'une zone : nom, type de lieu, centre et rayon (ce que voit le joueur, rien d'autre).
---@param zone { label: string, kind: string, x: number, y: number, z: number, radius: number }
---@return { l: string, k: string, x: number, y: number, z: number, r: number }
function zonestate.defValue(zone)
    return { l = zone.label, k = zone.kind, x = zone.x, y = zone.y, z = zone.z, r = zone.radius }
end

--- Valeur `p:<nœud>` d'un nœud : ressource, lieu et cap.
---@param node { resource: string|table, x: number, y: number, z: number, heading?: number }
---@return { r: string, x: number, y: number, z: number, h: number }
function zonestate.placeValue(node)
    local resource = type(node.resource) == 'table' and node.resource.id or node.resource
    return { r = resource, x = node.x, y = node.y, z = node.z, h = node.heading or 0.0 }
end

--- Cercle de la zone du core : centre de la zone de récolte ; rayon = la plus grande distance au sol entre ce centre et
--- ses nœuds, au moins le rayon de la zone ; marge donnée (portée des props + jeu). La hauteur est ignorée : le core
--- mesure au sol.
---@param zone { x: number, y: number, z: number, radius: number }
---@param nodes { x: number, y: number }[]
---@param margin number
---@return { x: number, y: number, z: number, radius: number, margin: number }
function zonestate.area(zone, nodes, margin)
    local radius = finite(zone.radius) and zone.radius > 0 and zone.radius or 0.0
    for _, node in ipairs(nodes) do
        if finite(node.x) and finite(node.y) then
            local dx, dy = node.x - zone.x, node.y - zone.y
            local distance = sqrt(dx * dx + dy * dy)
            if distance > radius then radius = distance end
        end
    end
    return { x = zone.x, y = zone.y, z = zone.z, radius = radius, margin = margin }
end

--- État entier d'une zone : sa valeur publiée et les charges de chacun de ses nœuds (`chargesOf` rend nil pour un nœud
--- encore inconnu : sa clé est omise) ; avec `zone` (T-102), aussi `def` et le lieu de chaque nœud (`p:<nœud>`).
---@param zoneValue { band: string, scarred: boolean }
---@param nodes table[]
---@param chargesOf fun(node: table): integer|nil
---@param zone? table  définition de la zone (label, kind, x, y, z, radius)
---@return table<string, any>
function zonestate.build(zoneValue, nodes, chargesOf, zone)
    local state = { [ZONE_KEY] = { band = zoneValue.band, scarred = zoneValue.scarred == true } }
    if zone then state[DEF_KEY] = zonestate.defValue(zone) end
    for _, node in ipairs(nodes) do
        local charges = chargesOf(node)
        if charges ~= nil then state[NODE_PREFIX .. node.id] = charges end
        if zone then state[PLACE_PREFIX .. node.id] = zonestate.placeValue(node) end
    end
    return state
end

--- Deux valeurs d'état égales (tables comparées clé par clé, un niveau) ?
local function same(a, b)
    if type(a) ~= 'table' or type(b) ~= 'table' then return a == b end
    for key, value in pairs(a) do
        if b[key] ~= value then return false end
    end
    for key in pairs(b) do
        if a[key] == nil then return false end
    end
    return true
end

--- Différence entre l'état déclaré et l'état neuf d'une zone (serveur) : clés changées (clé → valeur) et clés retirées
--- (liste triée). Rien n'a changé : deux tables vides.
---@param before table|nil
---@param after table
---@return table<string, any> changes
---@return string[] removed
function zonestate.diff(before, after)
    before = before or {}
    local changes, removed = {}, {}
    for key, value in pairs(after) do
        if not same(before[key], value) then changes[key] = value end
    end
    for key in pairs(before) do
        if after[key] == nil then removed[#removed + 1] = key end
    end
    sort(removed)
    return changes, removed
end

--- Paquets d'une différence, `size` clés au plus chacun (changées puis retirées, dans l'ordre des clés) : une liste de
--- { changes, removed } à envoyer dans le même tour (le core les regroupe pour chaque abonné). Vide si rien.
---@param changes table<string, any>
---@param removed string[]
---@param size? integer
---@return { changes: table, removed: string[] }[]
function zonestate.chunks(changes, removed, size)
    size = size or zonestate.CHUNK
    local keys = {}
    for key in pairs(changes) do keys[#keys + 1] = key end
    sort(keys)
    local out, current, count = {}, nil, 0
    local function slot()
        if not current or count >= size then
            current, count = { changes = {}, removed = {} }, 0
            out[#out + 1] = current
        end
        count = count + 1
        return current
    end
    for _, key in ipairs(keys) do slot().changes[key] = changes[key] end
    for _, key in ipairs(removed) do
        local chunk = slot()
        chunk.removed[#chunk.removed + 1] = key
    end
    return out
end

-- Client ---------------------------------------------------------------------------------------------------------------

---@param value any
---@return { band: string, scarred: boolean }|nil
local function readZone(value)
    if type(value) ~= 'table' then return nil end
    return { band = KNOWN_BANDS[value.band] and value.band or BANDS.NORMAL, scarred = value.scarred == true }
end

---@param value any
---@return integer|nil
local function readCharges(value)
    if mathType(value) == 'integer' and value >= 0 then return value end
    if mathType(value) == 'float' and value >= 0 and value == value and value < math.huge and value % 1 == 0 then
        return math.tointeger(value)
    end
    return nil
end
zonestate.readCharges = readCharges

--- `def` reçue : { label, kind, x, y, z, radius }, ou nil si elle est mal formée.
---@param value any
---@return table|nil
function zonestate.readDef(value)
    if type(value) ~= 'table' then return nil end
    if type(value.l) ~= 'string' or #value.l == 0 or #value.l > MAX_LABEL then return nil end
    if not isId(value.k, MAX_KIND) then return nil end
    if not finite(value.x) or not finite(value.y) or not finite(value.z) then return nil end
    if not finite(value.r) or value.r <= 0 or value.r > VavaGathering.ZONE_MAX_RADIUS then return nil end
    return { label = value.l, kind = value.k, x = value.x, y = value.y, z = value.z, radius = value.r }
end

--- `p:<nœud>` reçu : { resource, x, y, z, heading }, ou nil s'il est mal formé.
---@param value any
---@return table|nil
function zonestate.readPlace(value)
    if type(value) ~= 'table' or not isId(value.r, MAX_RESOURCE) then return nil end
    if not finite(value.x) or not finite(value.y) or not finite(value.z) then return nil end
    return { resource = value.r, x = value.x, y = value.y, z = value.z, heading = finite(value.h) and value.h or 0.0 }
end

---@class vAvA.GatheringZoneRecord
---@field zone { band: string, scarred: boolean }|nil  nil : valeur par défaut (pleine, sans cicatrice)
---@field charges table<string, integer>              nœud → charges
---@field def table|nil                               nom, type et lieu de la zone (T-102)
---@field nodes table<string, table>                  nœud → { resource, x, y, z, heading } (120 au plus)
---@field count integer                               nœuds connus

--- Pose ou retire le lieu d'un nœud (120 au plus : au-delà, ignoré).
local function setPlace(record, nodeId, value)
    if not isId(nodeId, MAX_NODE_ID) then return end
    local known = record.nodes[nodeId] ~= nil
    local place = value ~= nil and zonestate.readPlace(value) or nil
    if place then
        if not known then
            if record.count >= MAX_NODES then return end
            record.count = record.count + 1
        end
        record.nodes[nodeId] = place
    elseif known then
        record.nodes[nodeId] = nil
        record.count = record.count - 1
    end
end

--- Applique une différence reçue à une zone suivie : `set` (clé → valeur) puis `removed` (liste de clés). Une valeur
--- mal formée retire la clé (valeur par défaut) ; les clés inconnues sont ignorées.
---@param record vAvA.GatheringZoneRecord
---@param set any
---@param removed any
---@return vAvA.GatheringZoneRecord
function zonestate.patch(record, set, removed)
    record.nodes = record.nodes or {}
    record.count = record.count or 0
    if type(set) == 'table' then
        for key, value in pairs(set) do
            if key == ZONE_KEY then
                record.zone = readZone(value)
            elseif key == DEF_KEY then
                record.def = zonestate.readDef(value)
            else
                local nodeId = zonestate.nodeOf(key)
                if nodeId then
                    record.charges[nodeId] = readCharges(value)
                else
                    nodeId = zonestate.placeOf(key)
                    if nodeId then setPlace(record, nodeId, value) end
                end
            end
        end
    end
    if type(removed) == 'table' then
        for _, key in ipairs(removed) do
            if key == ZONE_KEY then
                record.zone = nil
            elseif key == DEF_KEY then
                record.def = nil
            else
                local nodeId = zonestate.nodeOf(key)
                if nodeId then
                    record.charges[nodeId] = nil
                else
                    nodeId = zonestate.placeOf(key)
                    if nodeId then setPlace(record, nodeId, nil) end
                end
            end
        end
    end
    return record
end

--- Zone suivie lue dans un état entier reçu (entrée, ou état renvoyé entier après un trou).
---@param state any
---@return vAvA.GatheringZoneRecord
function zonestate.decode(state)
    return zonestate.patch({ zone = nil, charges = {}, def = nil, nodes = {}, count = 0 }, state, nil)
end

-- Essai de l'Atelier (au seul auteur) ---------------------------------------------------------------------------------

---@class vAvA.GatheringTrialRecord
---@field def table|nil                  nom, type et lieu de la zone essayée
---@field nodes table<string, table>     nœud → { resource, x, y, z, heading, charges }
---@field count integer

--- Nœud d'essai reçu (entier : ressource et lieu ; ou partiel : charges seules d'un nœud connu).
local function trialNode(record, nodeId, value)
    if not isId(nodeId, MAX_NODE_ID) or type(value) ~= 'table' then return end
    local known = record.nodes[nodeId]
    local charges = readCharges(value.c)
    if value.r ~= nil then
        local place = zonestate.readPlace(value)
        if not place then return end
        if not known then
            if record.count >= MAX_NODES then return end
            record.count = record.count + 1
        end
        place.charges = charges or (known and known.charges) or 0
        record.nodes[nodeId] = place
    elseif known and charges then
        known.charges = charges
    end
end

--- Applique un message d'essai (`vava_gathering:trial`) : `full` remplace tout, `patch` change `def`, des nœuds
--- (entiers, ou leurs charges seules) et en cache (`hidden`). Rend l'enregistrement, ou nil si le message est mal
--- formé (ou un `patch` sans essai en cours).
---@param record vAvA.GatheringTrialRecord|nil
---@param payload any
---@return vAvA.GatheringTrialRecord|nil
function zonestate.trial(record, payload)
    if type(payload) ~= 'table' then return nil end
    if payload.mode == 'full' then
        record = { def = nil, nodes = {}, count = 0 }
    elseif payload.mode ~= 'patch' or not record then
        return nil
    end
    if payload.def ~= nil then record.def = zonestate.readDef(payload.def) end
    if type(payload.nodes) == 'table' then
        for nodeId, value in pairs(payload.nodes) do trialNode(record, nodeId, value) end
    end
    if type(payload.hidden) == 'table' then
        for _, nodeId in ipairs(payload.hidden) do
            if type(nodeId) == 'string' and record.nodes[nodeId] then
                record.nodes[nodeId] = nil
                record.count = record.count - 1
            end
        end
    end
    return record
end

--- Identifiant de zone d'un message d'essai, ou nil.
---@param payload any
---@return string|nil
function zonestate.trialZone(payload)
    local zone = type(payload) == 'table' and payload.zone or payload
    if not isId(zone, MAX_ZONE_ID) then return nil end
    return zone
end

-- Carte (liste des zones gardée en stockage local) ---------------------------------------------------------------------

--- Liste de la carte reçue ou relue : { version, zones = { { i, l, k, x, y, r } } } contrôlée (256 zones au plus,
--- champs bornés), ou nil si elle est abîmée (elle est alors oubliée).
---@param raw any
---@return { version: string, zones: table[] }|nil
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
