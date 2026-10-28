--[[
    vava_farming/server/slots.lua
    Rôle : état des emplacements, tenu par le serveur : chargé au démarrage, avancé à la demande par les règles pures de
           shared/growth.lua (aucune boucle de croissance), publié aux clients par un state bag par parcelle (culture,
           stade, état de chaque emplacement) écrit au seul changement et relu toutes les 10 s pour que les plantes
           poussent sous les yeux, écrit par lots. Accès aux parcelles privées par genre de propriétaire (personnage ;
           d'autres se branchent par registerAccess).
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua, server/catalog.lua
]]

local pairs, ipairs = pairs, ipairs
local floor, min, max = math.floor, math.min, math.max
local time = os.time
local GlobalState = GlobalState

local bridge = VavaFarming.bridge
local catalog = VavaFarming.catalog
local growth = VavaFarming.growth
local cfg = VavaFarming.config
local STATE_PARCEL = VavaFarming.STATE_PARCEL

local SELECT_SQL = 'SELECT `parcel`, `slot`, `crop`, `seed_tier`, `planted_at`, `growth`, `moisture`, `fertility`, `dry_since`, `dry_hours`, `waterings`, `wilted`, `dead`, `last_family`, `updated_at` FROM `vava_farming_slots`'
local UPSERT_SQL = 'INSERT INTO `vava_farming_slots` (`parcel`, `slot`, `crop`, `seed_tier`, `planted_at`, `growth`, `moisture`, `fertility`, `dry_since`, `dry_hours`, `waterings`, `wilted`, `dead`, `last_family`, `updated_at`) '
    .. 'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE `crop` = VALUES(`crop`), `seed_tier` = VALUES(`seed_tier`), '
    .. '`planted_at` = VALUES(`planted_at`), `growth` = VALUES(`growth`), `moisture` = VALUES(`moisture`), `fertility` = VALUES(`fertility`), '
    .. '`dry_since` = VALUES(`dry_since`), `dry_hours` = VALUES(`dry_hours`), `waterings` = VALUES(`waterings`), `wilted` = VALUES(`wilted`), '
    .. '`dead` = VALUES(`dead`), `last_family` = VALUES(`last_family`), `updated_at` = VALUES(`updated_at`)'

local slots = {}
VavaFarming.slots = slots

-- parcelle → index → état (voir vAvA.SlotState dans shared/growth.lua) + dirty
local states = {}
-- parcelle → dernière publication (clé de comparaison)
local published = {}
local accessors = {
    character = function(ownerId, characterId) return ownerId == characterId end,
}

---@param now integer
---@return table
local function fresh(now)
    return {
        crop = nil, seedTier = 1, plantedAt = 0, growth = 0, moisture = 0, fertility = cfg.fertility.initial,
        drySince = nil, dryHours = 0, waterings = 0, wilted = false, dead = false, lastFamily = nil, updatedAt = now, dirty = true,
    }
end

--- Charge l'état de tous les emplacements des parcelles de la config. Bloque le thread courant.
---@return boolean ok
---@return string|nil err
function slots.load()
    local rows, err = bridge.db.query(SELECT_SQL, {})
    if err then return false, err end
    local byKey = {}
    for _, row in ipairs(rows) do byKey[row.parcel .. ':' .. tostring(bridge.Integer(row.slot, 0))] = row end
    local now = time()
    for _, parcel in ipairs(catalog.parcels()) do
        local list = {}
        for index = 1, parcel.count do
            local row = byKey[parcel.id .. ':' .. index]
            if row then
                local drySince = row.dry_since ~= nil and bridge.Integer(row.dry_since, 0) or nil
                if drySince == 0 then drySince = nil end
                list[index] = {
                    crop = row.crop, seedTier = bridge.Integer(row.seed_tier, 1), plantedAt = bridge.Integer(row.planted_at, 0),
                    growth = bridge.Integer(row.growth, 0), moisture = bridge.Number(row.moisture, 0), fertility = bridge.Number(row.fertility, cfg.fertility.initial),
                    drySince = drySince, dryHours = bridge.Number(row.dry_hours, 0), waterings = bridge.Integer(row.waterings, 0),
                    wilted = bridge.Integer(row.wilted, 0) == 1, dead = bridge.Integer(row.dead, 0) == 1, lastFamily = row.last_family,
                    updatedAt = bridge.Integer(row.updated_at, now), dirty = false,
                }
                -- culture retirée de la config : l'emplacement redevient libre
                if list[index].crop and not catalog.crop(list[index].crop) then
                    list[index].crop, list[index].dirty = nil, true
                end
            else
                list[index] = fresh(now)
            end
        end
        states[parcel.id] = list
    end
    return true
end

---@param kind string
---@param fn fun(ownerId: integer, characterId: integer): boolean
function slots.registerAccess(kind, fn)
    accessors[kind] = fn
end

---@param parcel vAvA.ParcelDefinition
---@param characterId integer
---@return boolean
function slots.canAccess(parcel, characterId)
    if not parcel.owner then return true end
    local accessor = accessors[parcel.owner.kind]
    return accessor ~= nil and accessor(parcel.owner.id, characterId) == true
end

--- État d'un emplacement, avancé à maintenant.
---@param parcel vAvA.ParcelDefinition
---@param index integer
---@return table|nil
function slots.get(parcel, index)
    local list = states[parcel.id]
    local slot = list and list[index]
    if not slot then return nil end
    growth.advance(slot, slot.crop and catalog.crop(slot.crop) or nil, time())
    return slot
end

---@param slot table
function slots.touch(slot)
    slot.dirty = true
end

--- Vue d'un emplacement pour le client.
---@param parcel vAvA.ParcelDefinition
---@param index integer
---@return table
function slots.view(parcel, index)
    local slot = slots.get(parcel, index)
    local crop = slot.crop and catalog.crop(slot.crop) or nil
    return {
        parcel = parcel.id, index = index, crop = slot.crop, cropLabel = crop and crop.label or nil,
        state = crop and growth.state(slot, crop) or nil, stage = crop and growth.stage(slot, crop) or 0, stages = crop and #crop.stages or 0,
        progress = crop and growth.progress(slot, crop) or 0, moisture = floor(slot.moisture + 0.5), fertility = floor(slot.fertility + 0.5),
        waterings = slot.waterings, dryHours = floor(slot.dryHours * 10 + 0.5) / 10, plantedAt = slot.plantedAt,
    }
end

--- Publie la parcelle si un stade ou un état a changé.
---@param parcel vAvA.ParcelDefinition
function slots.publish(parcel)
    local list = states[parcel.id]
    local payload, key = {}, {}
    for index = 1, parcel.count do
        local slot = list[index]
        local crop = slot.crop and catalog.crop(slot.crop) or nil
        local stage = crop and growth.stage(slot, crop) or 0
        local state = crop and growth.state(slot, crop) or ''
        payload[index] = { crop = slot.crop or '', stage = stage, state = state }
        key[index] = (slot.crop or '') .. stage .. state
    end
    local signature = table.concat(key, '|')
    if published[parcel.id] == signature then return end
    published[parcel.id] = signature
    GlobalState[STATE_PARCEL .. parcel.id] = { slots = payload }
end

--- Relit et republie toutes les parcelles (passage de la boucle lente) : les plantes poussent sans qu'on y touche.
function slots.tick()
    local now = time()
    for _, parcel in ipairs(catalog.parcels()) do
        for index = 1, parcel.count do
            local slot = states[parcel.id][index]
            growth.advance(slot, slot.crop and catalog.crop(slot.crop) or nil, now)
        end
        slots.publish(parcel)
    end
end

-- Mutations -----------------------------------------------------------------------------------------------------------

---@param slot table
---@param crop table
---@param tier integer
---@param now integer
function slots.plant(slot, crop, tier, now)
    slot.crop, slot.seedTier, slot.plantedAt, slot.growth = crop.id, tier, now, 0
    slot.moisture, slot.drySince, slot.dryHours, slot.waterings = 60, nil, 0, 0
    slot.wilted, slot.dead, slot.updatedAt, slot.dirty = false, false, now, true
end

---@param slot table
function slots.water(slot)
    growth.water(slot)
    slot.dirty = true
end

---@param slot table
function slots.fertilize(slot)
    slot.fertility = min(100, slot.fertility + cfg.fertility.compostBonus)
    slot.dirty = true
end

--- Récolte : l'emplacement redevient libre, la fertilité paie, la famille est retenue pour la rotation.
---@param slot table
---@param crop table
---@param now integer
function slots.harvest(slot, crop, now)
    slot.fertility = growth.fertilityAfterHarvest(slot.fertility, crop, slot.lastFamily)
    slot.lastFamily = crop.family
    slot.crop, slot.seedTier, slot.plantedAt, slot.growth = nil, 1, 0, 0
    slot.moisture, slot.drySince, slot.dryHours, slot.waterings = 0, nil, 0, 0
    slot.wilted, slot.dead, slot.updatedAt, slot.dirty = false, false, now, true
end

--- Arrachage : l'emplacement redevient libre sans rien payer ni retenir.
---@param slot table
---@param now integer
function slots.clear(slot, now)
    slot.crop, slot.seedTier, slot.plantedAt, slot.growth = nil, 1, 0, 0
    slot.moisture, slot.drySince, slot.dryHours, slot.waterings = 0, nil, 0, 0
    slot.wilted, slot.dead, slot.updatedAt, slot.dirty = false, false, now, true
end

--- Fertilité fixée (Conseil).
---@param slot table
---@param value number
function slots.setFertility(slot, value)
    slot.fertility = min(100, max(0, value))
    slot.dirty = true
end

--- Mûrit (Conseil) : croissance portée au total.
---@param slot table
---@param crop table
function slots.ripen(slot, crop)
    slot.growth, slot.wilted, slot.dead, slot.dirty = crop.growMinutes * 60, false, false, true
end

---@param queries table[]
function slots.collect(queries)
    for parcelId, list in pairs(states) do
        for index, slot in ipairs(list) do
            if slot.dirty then
                queries[#queries + 1] = { query = UPSERT_SQL, values = {
                    parcelId, index, slot.crop, slot.seedTier, slot.plantedAt, slot.growth, floor(slot.moisture * 100 + 0.5) / 100,
                    floor(slot.fertility * 100 + 0.5) / 100, slot.drySince, floor(slot.dryHours * 1000 + 0.5) / 1000, slot.waterings,
                    slot.wilted and 1 or 0, slot.dead and 1 or 0, slot.lastFamily, slot.updatedAt,
                } }
            end
        end
    end
end

function slots.markClean()
    for _, list in pairs(states) do
        for _, slot in ipairs(list) do slot.dirty = false end
    end
end
