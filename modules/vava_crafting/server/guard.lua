--[[
    vava_crafting/server/guard.lua
    Rôle : garde de la signature et de la solidité d'un objet d'artisan contre les écritures des autres modules (hook
           `before` de `vava_inventory:metadata`, abonné par le bridge). Règle pure `guard.decide` (testée hors jeu) :
           le créateur, la date, le poinçon et la qualité ne changent jamais ; sur un objet signé, le palier et le nom
           non plus, et la solidité ne remonte pas (réparation réservée à la station) ni ne naît au-delà d'un plafond.
           Un refus est journalisé et signalé une fois par fenêtre (même module, même objet, même clé).
    Dépendances : shared/constants.lua, config.lua ; à l'exécution : server/core.lua, server/journal.lua,
                  server/catalog.lua
]]

local type, pairs, ipairs, tostring = type, pairs, ipairs, tostring
local mathType = math.type
local format = string.format
local GetGameTimer = GetGameTimer

local guardCfg = VavaCrafting.config.guard

local guard = {}
VavaCrafting.guard = guard

-- Clés figées sur tout objet : elles n'apparaissent, ne changent ni ne disparaissent que par l'artisanat (une pile
-- ordinaire qui les recevrait d'un autre module serait une signature contrefaite ; `quality` désigne aussi l'objet
-- réparable à une station).
guard.FROZEN = { 'crafter_id', 'crafter_name', 'crafted_at', 'mark', 'quality' }
-- Clés figées sur un objet signé seulement : le palier d'une matière ordinaire reste libre ; le nom d'un objet signé ne
-- se donne que par le baptême d'un chef-d'œuvre.
guard.SIGNED_FROZEN = { 'tier', 'name' }
-- Solidité d'un objet signé (`max_durability`, `durability`) : elle peut baisser (usure, coup) ou naître, bornée
-- (outil sans solidité connue), jamais remonter ni disparaître hors de l'artisanat.

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

--- Solidité admise après l'écriture. Connue avant : elle peut seulement baisser. Inconnue avant (elle « naît ») : absente,
--- ou un nombre de 0 au plafond.
---@param was any
---@param now any
---@param ceiling any  plafond d'une solidité qui naît ; pas un nombre : elle ne peut pas naître
---@return boolean
local function durabilityAllowed(was, now, ceiling)
    if isNumber(was) then return isNumber(now) and now <= was end
    if now == nil then return true end
    return isNumber(now) and isNumber(ceiling) and now >= 0 and now <= ceiling
end

--- Décide si une écriture de métadonnées est admise. Aucune erreur levée, quelles que soient les valeurs reçues.
---@param before any     métadonnées avant l'écriture (copie)
---@param after any      métadonnées après l'écriture (copie)
---@param internal any   vrai : l'écriture vient de l'artisanat lui-même (création, réparation, baptême)
---@param ceiling? any   plafond d'une solidité qui naît sur un objet signé qui n'en avait pas (`guard.bornCeiling`)
---@return boolean ok
---@return string|nil reason  `signature_locked` ou `durability_locked`
---@return string|nil key     première clé en cause
function guard.decide(before, after, internal, ceiling)
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
    -- la maximale d'abord : une solidité courante qui naît ne dépasse pas la maximale admise
    if not durabilityAllowed(before.max_durability, after.max_durability, ceiling) then
        return false, guard.DURABILITY_LOCKED, 'max_durability'
    end
    local maximum = isNumber(after.max_durability) and after.max_durability or ceiling
    if not durabilityAllowed(before.durability, after.durability, maximum) then
        return false, guard.DURABILITY_LOCKED, 'durability'
    end
    if before.broken == true and after.broken ~= true then return false, guard.DURABILITY_LOCKED, 'broken' end
    return true
end

--- Plafond d'une solidité qui naît sur un objet signé : celle que pose l'usure de la récolte (config), ou celle de sa
--- recette si elle est plus haute.
---@param recipeDurability any  solidité de la recette qui produit l'objet, ou nil
---@param bornDurability any    `config.guard.bornDurability`
---@return number
function guard.bornCeiling(recipeDurability, bornDurability)
    local ceiling = isNumber(bornDurability) and bornDurability or 0
    if isNumber(recipeDurability) and recipeDurability > ceiling then ceiling = recipeDurability end
    return ceiling
end

--- Nouvel état de suivi des refus signalés (tenu par l'appelant de `guard.shouldRecord`).
---@return table
function guard.newRecords()
    return { entries = {}, count = 0, purgeAt = 0, untold = 0 }
end

--- Faut-il journaliser et signaler ce refus ? Un même refus (`id`) ne l'est qu'une fois par fenêtre ; au plus
--- `maxTracked` refus distincts suivis, les expirés purgés au passage une fois par fenêtre. Les refus tus sont comptés
--- et rendus avec le prochain signalé.
---@param state table      `guard.newRecords()`
---@param id string
---@param now integer      ms
---@param windowMs integer
---@param maxTracked integer
---@return boolean record
---@return integer untold  refus tus depuis le dernier signalé
function guard.shouldRecord(state, id, now, windowMs, maxTracked)
    if now >= state.purgeAt then
        for key, entry in pairs(state.entries) do
            if now >= entry.untilMs then
                state.untold = state.untold + entry.suppressed
                state.entries[key] = nil
                state.count = state.count - 1
            end
        end
        state.purgeAt = now + windowMs
    end
    local entry = state.entries[id]
    if entry and now < entry.untilMs then
        entry.suppressed = entry.suppressed + 1
        return false, 0
    end
    if not entry then
        if state.count >= maxTracked then
            state.untold = state.untold + 1
            return false, 0
        end
        state.count = state.count + 1
    end
    local untold = state.untold + (entry and entry.suppressed or 0)
    state.untold = 0
    state.entries[id] = { untilMs = now + windowMs, suppressed = 0 }
    return true, untold
end

local records = guard.newRecords()

--- Abonné au hook `before` de `vava_inventory:metadata` (appelé par le bridge, sans jamais céder la main) : refuse
--- une écriture qui toucherait la signature ou rendrait de la solidité ; la journalise et la signale une fois par
--- fenêtre pour un même module, un même objet et une même clé.
---@param payload table      { container, instanceId, item, owner, reason = set | patch, before, after }
---@param internal boolean   vrai : écriture de l'artisanat lui-même
---@return boolean|nil ok    false pour refuser
---@return string|nil reason
function guard.onMetadata(payload, internal)
    if type(payload) ~= 'table' then return end
    local before = type(payload.before) == 'table' and payload.before or {}
    -- plafond calculé seulement quand une solidité peut naître : objet signé à qui il en manque une
    local ceiling
    if before.crafter_id ~= nil and not (isNumber(before.max_durability) and isNumber(before.durability)) then
        local recipe = type(payload.item) == 'string' and VavaCrafting.catalog.recipeFor(payload.item) or nil
        ceiling = guard.bornCeiling(recipe and recipe.durability, guardCfg.bornDurability)
    end
    local ok, reason, key = guard.decide(payload.before, payload.after, internal, ceiling)
    if ok then return end
    local id = format('%s|%s|%s|%s', tostring(payload.owner), tostring(payload.instanceId), reason, key)
    local record, untold = guard.shouldRecord(records, id, GetGameTimer(), guardCfg.windowMs, guardCfg.maxTracked)
    if not record then return false, reason end
    local quality = before.quality
    VavaCrafting.log.warn("écriture de '%s' refusée sur l'objet %s (%s, conteneur %s) : clé '%s' protégée%s",
        tostring(payload.owner), tostring(payload.instanceId), tostring(payload.item), tostring(payload.container), key,
        untold > 0 and format(' [%d refus semblable(s) tu(s)]', untold) or '')
    VavaCrafting.journal.write(reason, {
        characterId = mathType(before.crafter_id) == 'integer' and before.crafter_id >= 0
            and before.crafter_id <= MAX_CHARACTER_ID and before.crafter_id or nil,
        item = type(payload.item) == 'string' and payload.item:sub(1, 64) or nil,
        quality = mathType(quality) == 'integer' and quality >= 0 and quality <= MAX_QUALITY and quality or nil,
        details = {
            module = tostring(payload.owner), key = key, write = tostring(payload.reason),
            instance = payload.instanceId, container = payload.container, untold = untold,
        },
    })
    return false, reason
end
