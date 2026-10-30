--[[
    vava_crafting/server/guard.lua
    Rôle : garde de la signature et de la solidité d'un objet d'artisan contre les écritures des autres modules (hook
           `before` de `vava_inventory:metadata`, abonné par le bridge). Règle pure `guard.decide` (testée hors jeu) :
           le créateur, la date, le poinçon et la qualité ne changent jamais ; sur un objet signé, le palier et le nom
           non plus, et la solidité ne remonte pas (réparation réservée à la station). Un refus est journalisé.
    Dépendances : shared/constants.lua ; à l'exécution : server/core.lua, server/journal.lua
]]

local type, pairs, ipairs, tostring = type, pairs, ipairs, tostring
local mathType = math.type

local guard = {}
VavaCrafting.guard = guard

-- Clés figées sur tout objet : elles n'apparaissent, ne changent ni ne disparaissent que par l'artisanat (une pile
-- ordinaire qui les recevrait d'un autre module serait une signature contrefaite ; `quality` désigne aussi l'objet
-- réparable à une station).
guard.FROZEN = { 'crafter_id', 'crafter_name', 'crafted_at', 'mark', 'quality' }
-- Clés figées sur un objet signé seulement : le palier d'une matière ordinaire reste libre ; le nom d'un objet signé ne
-- se donne que par le baptême d'un chef-d'œuvre.
guard.SIGNED_FROZEN = { 'tier', 'name' }
-- Solidité d'un objet signé : elle peut baisser (usure, coup) ou naître (outil sans solidité connue), jamais remonter
-- ni disparaître hors de l'artisanat.
guard.DURABILITY = { 'max_durability', 'durability' }

guard.SIGNATURE_LOCKED = 'signature_locked'
guard.DURABILITY_LOCKED = 'durability_locked'

-- profondeur d'une valeur comparée (l'inventaire borne déjà la profondeur des métadonnées)
local MAX_DEPTH = 8
-- bornes des colonnes du journal (INT et TINYINT UNSIGNED)
local MAX_CHARACTER_ID, MAX_QUALITY = 0xFFFFFFFF, 255

--- Égalité de deux valeurs de métadonnées (copies : les tables se comparent par contenu).
---@param a any
---@param b any
---@param depth integer
---@return boolean
local function same(a, b, depth)
    if a == b then return true end
    if type(a) ~= 'table' or type(b) ~= 'table' or depth > MAX_DEPTH then return false end
    for key, value in pairs(a) do
        if not same(value, b[key], depth + 1) then return false end
    end
    for key in pairs(b) do
        if a[key] == nil then return false end
    end
    return true
end

---@param value any
---@return boolean
local function isNumber(value)
    return mathType(value) ~= nil
end

--- Décide si une écriture de métadonnées est admise. Aucune erreur levée, quelles que soient les valeurs reçues.
---@param before any     métadonnées avant l'écriture (copie)
---@param after any      métadonnées après l'écriture (copie)
---@param internal any   vrai : l'écriture vient de l'artisanat lui-même (création, réparation, baptême)
---@return boolean ok
---@return string|nil reason  `signature_locked` ou `durability_locked`
---@return string|nil key     première clé en cause
function guard.decide(before, after, internal)
    if internal == true then return true end
    if type(before) ~= 'table' then before = {} end
    if type(after) ~= 'table' then after = {} end

    for _, key in ipairs(guard.FROZEN) do
        if not same(before[key], after[key], 1) then return false, guard.SIGNATURE_LOCKED, key end
    end
    -- objet ordinaire (jamais signé) : le reste ne regarde pas l'artisanat
    if before.crafter_id == nil then return true end

    for _, key in ipairs(guard.SIGNED_FROZEN) do
        if not same(before[key], after[key], 1) then return false, guard.SIGNATURE_LOCKED, key end
    end
    for _, key in ipairs(guard.DURABILITY) do
        local was, now = before[key], after[key]
        if isNumber(was) and not (isNumber(now) and now <= was) then return false, guard.DURABILITY_LOCKED, key end
    end
    if before.broken == true and after.broken ~= true then return false, guard.DURABILITY_LOCKED, 'broken' end
    return true
end

--- Abonné au hook `before` de `vava_inventory:metadata` (appelé par le bridge, sans jamais céder la main) : refuse
--- et journalise une écriture qui toucherait la signature ou rendrait de la solidité.
---@param payload table      { container, instanceId, item, owner, reason = set | patch, before, after }
---@param internal boolean   vrai : écriture de l'artisanat lui-même
---@return boolean|nil ok    false pour refuser
---@return string|nil reason
function guard.onMetadata(payload, internal)
    if type(payload) ~= 'table' then return end
    local ok, reason, key = guard.decide(payload.before, payload.after, internal)
    if ok then return end
    local before = type(payload.before) == 'table' and payload.before or {}
    local quality = before.quality
    VavaCrafting.log.warn("écriture de '%s' refusée sur l'objet %s (%s, conteneur %s) : clé '%s' protégée",
        tostring(payload.owner), tostring(payload.instanceId), tostring(payload.item), tostring(payload.container), key)
    VavaCrafting.journal.write(reason, {
        characterId = mathType(before.crafter_id) == 'integer' and before.crafter_id >= 0
            and before.crafter_id <= MAX_CHARACTER_ID and before.crafter_id or nil,
        item = type(payload.item) == 'string' and payload.item:sub(1, 64) or nil,
        quality = mathType(quality) == 'integer' and quality >= 0 and quality <= MAX_QUALITY and quality or nil,
        details = {
            module = tostring(payload.owner), key = key, write = tostring(payload.reason),
            instance = payload.instanceId, container = payload.container,
        },
    })
    return false, reason
end
