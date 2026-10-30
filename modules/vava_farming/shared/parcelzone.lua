--[[
    vava_farming/shared/parcelzone.lua
    Rôle : règles pures de la parcelle vue comme une zone du core (abonnements de zone, vAvA_core 0.11.0). Côté serveur :
           lieu de la zone (centre de la parcelle, rayon qui couvre ses emplacements et son grenier, marge), définition
           envoyée aux joueurs proches (`def` : ce qu'il faut pour dessiner la parcelle), valeur publiée de chaque
           emplacement (`s<n°>` → culture, stade, état), différences à envoyer (seuls les emplacements changés, par lots
           bornés). Côté client : lecture contrôlée de la définition et des emplacements reçus. Rien de secret : l'état
           d'une zone est public pour quiconque s'en approche.
    Dépendances : shared/constants.lua, shared/geometry.lua
]]

local type, pairs, ipairs, tostring, tonumber = type, pairs, ipairs, tostring, tonumber
local floor, sqrt, huge = math.floor, math.sqrt, math.huge
local tointeger = math.tointeger
local match, format = string.match, string.format
local concat = table.concat

local geometry = VavaFarming.geometry
local MAX_SLOTS = VavaFarming.MAX_SLOTS

local parcelzone = {}
VavaFarming.parcelzone = parcelzone

-- clé de la définition de la parcelle dans l'état de sa zone
parcelzone.DEF = 'def'
-- longueur au plus d'un texte reçu (nom de la parcelle, du grenier, modèle)
local MAX_TEXT = 128

---@param value any
---@return boolean
local function finite(value)
    return type(value) == 'number' and value == value and value ~= huge and value ~= -huge
end

--- Clé de l'emplacement n° `index` dans l'état de la zone.
---@param index integer
---@return string
function parcelzone.slotKey(index)
    return 's' .. index
end

--- N° d'emplacement d'une clé `s<n°>` (1 à MAX_SLOTS), ou nil.
---@param key any
---@return integer|nil
function parcelzone.slotIndex(key)
    if type(key) ~= 'string' then return nil end
    local digits = match(key, '^s([1-9]%d?%d?)$')
    local index = digits and tointeger(tonumber(digits))
    if not index or index < 1 or index > MAX_SLOTS then return nil end
    return index
end

--- Valeur publiée d'un emplacement : chaînes vides pour un emplacement libre (jamais de nil dans une table publiée).
---@param crop string|nil
---@param stage integer|nil
---@param state string|nil
---@return { crop: string, stage: integer, state: string }
function parcelzone.slotValue(crop, stage, state)
    return { crop = crop or '', stage = stage or 0, state = state or '' }
end

--- Signature d'une valeur publiée : deux valeurs de même signature sont identiques pour le joueur.
---@param value { crop: string, stage: integer, state: string }
---@return string
function parcelzone.signature(value)
    return value.crop .. ':' .. tostring(value.stage) .. ':' .. value.state
end

--- Définition de la parcelle envoyée aux joueurs proches : ce qu'il faut pour placer ses emplacements et son grenier,
--- rien de plus (ni propriétaire ni contenu du grenier).
---@param parcel vAvA.ParcelDefinition
---@return table
function parcelzone.definition(parcel)
    local def = {
        label = parcel.label, x = parcel.x, y = parcel.y, z = parcel.z, heading = parcel.heading or 0.0,
        rows = parcel.rows, cols = parcel.cols, spacing = parcel.spacing,
    }
    local g = parcel.granary
    if g then
        def.granary = { label = g.label, x = g.x, y = g.y, z = g.z, heading = g.heading or def.heading, prop = g.prop }
    end
    return def
end

--- Lieu de la zone : centre de la parcelle au sol ; rayon = plus grande distance horizontale du centre à un
--- emplacement ou au grenier (au moins `minRadius`) ; `margin` au-delà (portée des props + battement).
---@param parcel vAvA.ParcelDefinition
---@param margin number
---@param minRadius number
---@return { x: number, y: number, z: number, radius: number, margin: number }
function parcelzone.area(parcel, margin, minRadius)
    local radius = minRadius
    local function reach(x, y)
        local dx, dy = x - parcel.x, y - parcel.y
        local d = sqrt(dx * dx + dy * dy)
        if d > radius then radius = d end
    end
    for index = 1, geometry.slotCount(parcel) do
        local x, y = geometry.slotPosition(parcel, index)
        reach(x, y)
    end
    if parcel.granary then reach(parcel.granary.x, parcel.granary.y) end
    return { x = parcel.x, y = parcel.y, z = parcel.z, radius = radius, margin = margin }
end

--- État complet de la zone (déclaration, définition changée) et signatures des emplacements publiés.
---@param parcel vAvA.ParcelDefinition
---@param values { crop: string, stage: integer, state: string }[]  une valeur par emplacement (parcelzone.slotValue)
---@return table state
---@return string[] signatures
function parcelzone.state(parcel, values)
    local state, signatures = { [parcelzone.DEF] = parcelzone.definition(parcel) }, {}
    for index, value in ipairs(values) do
        state[parcelzone.slotKey(index)] = value
        signatures[index] = parcelzone.signature(value)
    end
    return state, signatures
end

--- Différences à envoyer : les seuls emplacements dont la signature a changé depuis la dernière publication, par lots
--- d'au plus `batchSize` clés (limite du core par appel). `published` nil : tout part (rien n'est connu des joueurs).
---@param published string[]|nil  signatures de la dernière publication réussie
---@param values { crop: string, stage: integer, state: string }[]
---@param batchSize integer
---@return table[] batches  lots { s<n°> = valeur } (liste vide : rien n'a changé)
---@return string[] signatures  signatures de toutes les valeurs, à garder si l'envoi réussit
function parcelzone.diff(published, values, batchSize)
    local batches, signatures = {}, {}
    local batch, count = nil, 0
    for index, value in ipairs(values) do
        local signature = parcelzone.signature(value)
        signatures[index] = signature
        if not published or published[index] ~= signature then
            if not batch or count >= batchSize then
                batch, count = {}, 0
                batches[#batches + 1] = batch
            end
            batch[parcelzone.slotKey(index)] = value
            count = count + 1
        end
    end
    return batches, signatures
end

-- Côté client : lecture contrôlée ---------------------------------------------------------------------------------------

---@param value any
---@return string|nil
local function text(value)
    if type(value) ~= 'string' or value == '' or #value > MAX_TEXT then return nil end
    return value
end

---@param value any
---@return integer|nil
local function count(value)
    local n = finite(value) and tointeger(value) or nil
    if not n or n < 1 or n > MAX_SLOTS then return nil end
    return n
end

--- Définition reçue, contrôlée (nombres finis, grille de 1 à MAX_SLOTS emplacements, textes bornés), ou nil.
---@param raw any
---@return table|nil
function parcelzone.readDefinition(raw)
    if type(raw) ~= 'table' then return nil end
    local rows, cols = count(raw.rows), count(raw.cols)
    if not rows or not cols or rows * cols > MAX_SLOTS then return nil end
    if not finite(raw.x) or not finite(raw.y) or not finite(raw.z) or not finite(raw.heading) then return nil end
    if not finite(raw.spacing) or raw.spacing <= 0 then return nil end
    local def = {
        label = text(raw.label) or '', x = raw.x, y = raw.y, z = raw.z, heading = raw.heading,
        rows = rows, cols = cols, spacing = raw.spacing,
    }
    local g = raw.granary
    if type(g) == 'table' and finite(g.x) and finite(g.y) and finite(g.z) then
        def.granary = {
            label = text(g.label), x = g.x, y = g.y, z = g.z,
            heading = finite(g.heading) and g.heading or def.heading, prop = text(g.prop),
        }
    end
    return def
end

--- Empreinte d'une définition lue : deux définitions de même empreinte placent les mêmes props aux mêmes endroits.
---@param def table  définition lue par parcelzone.readDefinition
---@return string
function parcelzone.definitionKey(def)
    local parts = {
        def.label, format('%.3f', def.x), format('%.3f', def.y), format('%.3f', def.z), format('%.3f', def.heading),
        tostring(def.rows), tostring(def.cols), format('%.3f', def.spacing),
    }
    local g = def.granary
    if g then
        parts[#parts + 1] = concat({ g.label or '', format('%.3f', g.x), format('%.3f', g.y), format('%.3f', g.z),
            format('%.3f', g.heading), g.prop or '' }, ',')
    end
    return concat(parts, '|')
end

--- Emplacement reçu, contrôlé : { crop = id | nil, stage ≥ 0, state = id | nil (nil si libre) }, ou nil.
---@param raw any
---@return { crop: string|nil, stage: integer, state: string|nil }|nil
function parcelzone.readSlot(raw)
    if type(raw) ~= 'table' then return nil end
    local crop = text(raw.crop)
    local state = crop and text(raw.state) or nil
    local stage = finite(raw.stage) and raw.stage >= 0 and floor(raw.stage) or 0
    return { crop = crop, stage = stage, state = state }
end

--- Emplacements d'un état reçu (clés `s<n°>` jusqu'à `slotCount`), contrôlés ; les autres clés sont ignorées.
---@param state table
---@param slotCount integer
---@return table<integer, table>
function parcelzone.readSlots(state, slotCount)
    local out = {}
    for key, raw in pairs(state) do
        local index = parcelzone.slotIndex(key)
        if index and index <= slotCount then out[index] = parcelzone.readSlot(raw) end
    end
    return out
end
