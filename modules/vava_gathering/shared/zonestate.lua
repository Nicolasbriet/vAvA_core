--[[
    vava_gathering/shared/zonestate.lua
    Rôle : règles pures de l'état d'une zone de récolte tenu par les abonnements de zone du core (vAvA_core ≥ 0.11.0).
           Clés : `zone` → { band, scarred } (jamais la vitalité : seule la bande et la cicatrice changent ce que voit
           le joueur) et `n:<nœud>` → charges. Côté serveur : cercle de la zone du core (centre de la zone, rayon qui
           englobe ses nœuds au sol, marge), état entier à la déclaration. Côté client : lecture d'un état reçu et
           application d'une différence, valeurs mal formées ramenées aux valeurs par défaut.
           L'état d'une zone est public (positions déclarées par les clients sous OneSync) : rien de secret dedans.
    Dépendances : shared/constants.lua
]]

local type, pairs, ipairs, sqrt, mathType = type, pairs, ipairs, math.sqrt, math.type
local sub = string.sub

local BANDS = VavaGathering.BANDS

local zonestate = {}
VavaGathering.zonestate = zonestate

local ZONE_KEY = 'zone'
local NODE_PREFIX = 'n:'
zonestate.ZONE_KEY = ZONE_KEY
zonestate.NODE_PREFIX = NODE_PREFIX

local KNOWN_BANDS = {}
for _, band in pairs(BANDS) do KNOWN_BANDS[band] = true end

---@param value any
---@return boolean
local function finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

--- Clé de l'état qui porte les charges d'un nœud.
---@param nodeId string
---@return string
function zonestate.nodeKey(nodeId)
    return NODE_PREFIX .. nodeId
end

--- Nœud d'une clé de l'état (`n:<nœud>`), ou nil pour toute autre clé.
---@param key any
---@return string|nil
function zonestate.nodeOf(key)
    if type(key) ~= 'string' or #key <= #NODE_PREFIX or sub(key, 1, #NODE_PREFIX) ~= NODE_PREFIX then return nil end
    return sub(key, #NODE_PREFIX + 1)
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
--- encore inconnu : sa clé est omise).
---@param zoneValue { band: string, scarred: boolean }
---@param nodes { id: string }[]
---@param chargesOf fun(node: table): integer|nil
---@return table<string, any>
function zonestate.build(zoneValue, nodes, chargesOf)
    local state = { [ZONE_KEY] = { band = zoneValue.band, scarred = zoneValue.scarred == true } }
    for _, node in ipairs(nodes) do
        local charges = chargesOf(node)
        if charges ~= nil then state[NODE_PREFIX .. node.id] = charges end
    end
    return state
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

---@class vAvA.GatheringZoneRecord
---@field zone { band: string, scarred: boolean }|nil  nil : valeur par défaut (pleine, sans cicatrice)
---@field charges table<string, integer>              nœud → charges ; absent : charges de la config

--- Applique une différence reçue à une zone suivie : `set` (clé → valeur) puis `removed` (liste de clés). Une valeur
--- mal formée retire la clé (valeur par défaut) ; les clés inconnues sont ignorées.
---@param record vAvA.GatheringZoneRecord
---@param set any
---@param removed any
---@return vAvA.GatheringZoneRecord
function zonestate.patch(record, set, removed)
    if type(set) == 'table' then
        for key, value in pairs(set) do
            if key == ZONE_KEY then
                record.zone = readZone(value)
            else
                local nodeId = zonestate.nodeOf(key)
                if nodeId then record.charges[nodeId] = readCharges(value) end
            end
        end
    end
    if type(removed) == 'table' then
        for _, key in ipairs(removed) do
            if key == ZONE_KEY then
                record.zone = nil
            else
                local nodeId = zonestate.nodeOf(key)
                if nodeId then record.charges[nodeId] = nil end
            end
        end
    end
    return record
end

--- Zone suivie lue dans un état entier reçu (entrée, ou état renvoyé entier après un trou).
---@param state any
---@return vAvA.GatheringZoneRecord
function zonestate.decode(state)
    return zonestate.patch({ zone = nil, charges = {} }, state, nil)
end
