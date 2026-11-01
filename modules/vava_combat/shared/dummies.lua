--[[
    vava_combat/shared/dummies.lua
    Rôle : règles pures des mannequins d'entraînement (T-156), servies au serveur et au client : contrôle de la part
           client de `dummies` (modèles, distances, balancement, éclats, liste), index des mannequins (numéro `n` = place
           dans la liste, centre visé). Aucune native, aucun état, aucune erreur.
    Dépendances : shared/constants.lua
]]

local type, pairs, ipairs, tostring = type, pairs, ipairs, tostring
local mathType, huge = math.type, math.huge
local find, format = string.find, string.format

local ID_PATTERN, MODEL_MAX, MAX_DUMMIES = VavaCombat.ID_PATTERN, VavaCombat.MODEL_MAX, VavaCombat.MAX_DUMMIES
local ID_MAX, LABEL_MAX = 32, 48
local XY_MAX, Z_MIN, Z_MAX = 50000, -200, 2000
local BUCKET_MAX = 65535
local ENTRY_KEYS = { id = true, x = true, y = true, z = true, heading = true, model = true, bucket = true, label = true }
local WOBBLE_KEYS = { ms = true, angle = true, cycles = true }
local FX_KEYS = { asset = true, name = true, scale = true }

local dummyRules = {}
VavaCombat.dummyRules = dummyRules

local function between(value, low, high)
    return type(value) == 'number' and value == value and value ~= huge and value ~= -huge and value >= low
        and value <= high
end

local function integerIn(value, low, high)
    return mathType(value) == 'integer' and value >= low and value <= high
end

local function text(value, max)
    return type(value) == 'string' and #value >= 1 and #value <= max
end

--- Première clé de `map` hors de `allowed`, ou nil.
local function extraKey(map, allowed)
    for key in pairs(map) do
        if not allowed[key] then return key end
    end
    return nil
end

--- Un mannequin de la liste : nil, ou la raison.
local function entryError(i, d)
    local where = format('dummies.list[%d]', i)
    if type(d) ~= 'table' then return where .. ' : table attendue' end
    local extra = extraKey(d, ENTRY_KEYS)
    if extra ~= nil then return format("%s : champ inconnu '%s'", where, tostring(extra)) end
    if not text(d.id, ID_MAX) or not find(d.id, ID_PATTERN) then
        return format('%s : id attendu (^[a-z0-9_]+$, 1 à %d octets)', where, ID_MAX)
    end
    where = format("dummies.list[%d] '%s'", i, d.id)
    if not between(d.x, -XY_MAX, XY_MAX) or not between(d.y, -XY_MAX, XY_MAX) then
        return where .. ' : x et y attendus (nombres finis, 50 000 au plus en valeur absolue)'
    end
    if not between(d.z, Z_MIN, Z_MAX) then return where .. ' : z attendu de -200 à 2 000' end
    if not between(d.heading, 0, 360) then return where .. ' : heading attendu de 0 à 360' end
    if d.model ~= nil and not text(d.model, MODEL_MAX) then
        return format('%s : model attendu (1 à %d octets)', where, MODEL_MAX)
    end
    if d.bucket ~= nil and not integerIn(d.bucket, 0, BUCKET_MAX) then
        return where .. ' : bucket attendu (entier de 0 à 65 535)'
    end
    if d.label ~= nil and not text(d.label, LABEL_MAX) then
        return format('%s : label attendu (1 à %d octets)', where, LABEL_MAX)
    end
    return nil
end

--- Liste pure de mannequins (64 au plus, identifiants uniques) : nil, ou la raison.
local function listError(list)
    if type(list) ~= 'table' then return 'dummies.list : liste attendue' end
    local count = 0
    for _ in pairs(list) do count = count + 1 end
    if count ~= #list then return 'dummies.list : liste pure attendue (aucune clé nommée)' end
    if count > MAX_DUMMIES then return format('dummies.list : %d mannequins au plus', MAX_DUMMIES) end
    local seen = {}
    for i, d in ipairs(list) do
        local err = entryError(i, d)
        if err then return err end
        if seen[d.id] then return format("dummies.list : id '%s' en double", d.id) end
        seen[d.id] = true
    end
    return nil
end

--- Contrôle de la part client des mannequins (`config.dummies`, ou une table aux mêmes clés). Les autres clés (part du
--- serveur) sont ignorées ici. Rend `true`, ou `false, raison`.
function dummyRules.check(part)
    if type(part) ~= 'table' then return false, 'dummies : table attendue' end
    if not text(part.label, LABEL_MAX) then return false, 'dummies.label attendu (1 à 48 octets)' end
    if not text(part.model, MODEL_MAX) or not text(part.fallbackModel, MODEL_MAX) then
        return false, 'dummies.model et fallbackModel attendus (1 à 64 octets)'
    end
    if not integerIn(part.modelTimeoutMs, 500, 30000) then
        return false, 'dummies.modelTimeoutMs entier de 500 à 30 000 attendu'
    end
    local stream, keep = part.streamRadius, part.keepRadius
    if not between(stream, 10, 200) or not between(keep, 10, 200) or keep <= stream then
        return false, 'dummies : 10 ≤ streamRadius < keepRadius ≤ 200 attendu'
    end
    if not integerIn(part.nearPollMs, 100, 5000) or not integerIn(part.farPollMs, 500, 10000) then
        return false, 'dummies : nearPollMs (100 à 5 000) et farPollMs (500 à 10 000) entiers attendus'
    end
    if not between(part.centerHeight, 0.2, 2) or not between(part.anchorHeight, 0.5, 3) then
        return false, 'dummies : centerHeight (0,2 à 2) et anchorHeight (0,5 à 3) attendus'
    end
    local w = part.wobble
    if type(w) ~= 'table' or extraKey(w, WOBBLE_KEYS) ~= nil or not integerIn(w.ms, 0, 3000)
        or not between(w.angle, 0, 45) or not integerIn(w.cycles, 1, 4) then
        return false, 'dummies.wobble : { ms (0 à 3 000), angle (0 à 45), cycles (entier de 1 à 4) } attendu'
    end
    local fx = part.fx
    if fx ~= false and (type(fx) ~= 'table' or extraKey(fx, FX_KEYS) ~= nil or not text(fx.asset, MODEL_MAX)
        or not text(fx.name, MODEL_MAX) or not between(fx.scale, 0, 5)) then
        return false, 'dummies.fx : false ou { asset, name (1 à 64 octets), scale (0 à 5) } attendu'
    end
    local err = listError(part.list)
    if err then return false, err end
    return true
end


--- Index d'une liste déjà contrôlée : mannequins par numéro (liste) et par identifiant.
function dummyRules.index(list, part)
    local byN, byId = {}, {}
    for n, d in ipairs(list) do
        local entry = {
            n = n, id = d.id, x = d.x, y = d.y, z = d.z, heading = d.heading, model = d.model or part.model,
            bucket = d.bucket or 0, label = d.label or part.label,
            center = { x = d.x, y = d.y, z = d.z + part.centerHeight },
        }
        byN[n] = entry
        byId[d.id] = entry
    end
    return byN, byId
end
