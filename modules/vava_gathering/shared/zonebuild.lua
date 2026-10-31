--[[
    vava_gathering/shared/zonebuild.lua
    Rôle : logique pure de l'état d'une zone de récolte, côté serveur seul (jamais téléchargée par les joueurs) : valeurs
           publiées et leur format compact, cercle de la zone du core, état entier, différence entre deux états et
           paquets de 64 clés. Complète VavaGathering.zonestate (shared/zonestate.lua : lecture côté client).
           Format compact (relecture réseau R-3 de T-102) : `def` → { nom, type, x, y, z, rayon } et `p:<nœud>` →
           { ressource, x, y, z, cap }, longueurs en centimètres entiers, cap en dixièmes de degré entiers dans
           [0, 3600) ; un nœud d'essai ajoute ses charges en 6e place. Toujours des listes pures.
           Testée : tests/spec/gathering_zonestate_spec.lua, gathering_bounds_spec.lua, gathering_share_spec.lua.
    Dépendances : shared/constants.lua, shared/zonestate.lua
]]

local type, pairs, ipairs, sqrt, floor = type, pairs, ipairs, math.sqrt, math.floor
local tointeger = math.tointeger
local sort = table.sort

local zonestate = VavaGathering.zonestate
local finite = zonestate.finite
local ZONE_KEY, NODE_PREFIX, DEF_KEY, PLACE_PREFIX = zonestate.ZONE_KEY, zonestate.NODE_PREFIX, zonestate.DEF_KEY,
    zonestate.PLACE_PREFIX
local COORD, HEADING = VavaGathering.COORD_SCALE, VavaGathering.HEADING_SCALE
local FULL_TURN = 360 * HEADING

-- clés changées ou retirées au plus par appel à core.zones.set
zonestate.CHUNK = 64

--- Longueur en mètres → centimètres entiers.
local function cm(value)
    return tointeger(floor(value * COORD + 0.5)) or 0
end

--- Cap en degrés → dixièmes de degré entiers dans [0, 3600).
local function tenth(value)
    if not finite(value) then return 0 end
    return (tointeger(floor(value * HEADING + 0.5)) or 0) % FULL_TURN
end

--- Valeur publiée d'une zone : bande et cicatrice, rien d'autre (jamais la vitalité).
function zonestate.zoneValue(band, scarred)
    return { band = band, scarred = scarred == true }
end

--- Deux valeurs publiées identiques ?
function zonestate.sameZone(a, b)
    return type(a) == 'table' and type(b) == 'table' and a.band == b.band and a.scarred == b.scarred
end

--- `def` d'une zone : { nom, type, x, y, z, rayon } (centimètres).
function zonestate.defValue(zone)
    return { zone.label, zone.kind, cm(zone.x), cm(zone.y), cm(zone.z), cm(zone.radius) }
end

--- `p:<nœud>` d'un nœud : { ressource, x, y, z, cap } (centimètres, dixièmes de degré).
function zonestate.placeValue(node)
    local resource = type(node.resource) == 'table' and node.resource.id or node.resource
    return { resource, cm(node.x), cm(node.y), cm(node.z), tenth(node.heading or 0.0) }
end

--- Nœud d'essai : `p:` et ses charges d'essai en 6e place.
function zonestate.trialValue(node, charges)
    local value = zonestate.placeValue(node)
    value[6] = charges
    return value
end

--- Cercle de la zone du core : centre de la zone, rayon = la plus grande distance au sol entre ce centre et ses nœuds
--- (au moins le rayon de la zone), marge donnée.
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

--- État entier d'une zone : valeur publiée, charges de chaque nœud (clé omise si `chargesOf` rend nil) ; avec `zone`,
--- aussi `def` et le lieu de chaque nœud.
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

--- Différence entre l'état déclaré et l'état neuf : clés changées (clé → valeur) et clés retirées (triées).
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

--- Paquets d'une différence, `size` clés au plus chacun (changées puis retirées, dans l'ordre des clés).
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
