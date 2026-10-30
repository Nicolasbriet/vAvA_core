--[[
    vava_farming/server/slots.lua
    Rôle : état des emplacements, tenu par le serveur : chargé au démarrage, avancé à la demande par les règles pures de
           shared/growth.lua (aucune boucle de croissance), publié aux clients par un state bag par parcelle (culture,
           stade, état de chaque emplacement) écrit au seul changement et relu toutes les 10 s pour que les plantes
           poussent sous les yeux, écrit par lots — et aussitôt, emplacement par emplacement, après un geste qui donne
           ou consomme des objets. Accès aux parcelles privées par genre de propriétaire (personnage ; d'autres se
           branchent par registerAccess). Couverture contre le gel ; plantes exposées et plantes perdues quand le gel
           d'une nuit d'hiver tombe (vava_time).
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua, server/catalog.lua
]]

local pairs, ipairs, tostring = pairs, ipairs, tostring
local floor, min, max = math.floor, math.min, math.max
local time = os.time
local GlobalState, CreateThread = GlobalState, CreateThread

local bridge = VavaFarming.bridge
local catalog = VavaFarming.catalog
local growth = VavaFarming.growth
local cfg = VavaFarming.config
local STATE_PARCEL = VavaFarming.STATE_PARCEL

local SELECT_SQL = 'SELECT `parcel`, `slot`, `crop`, `seed_tier`, `planted_at`, `growth`, `moisture`, `fertility`, `dry_since`, `dry_hours`, `waterings`, `wilted`, `dead`, `covered`, `last_family`, `updated_at` FROM `vava_farming_slots`'
local UPSERT_SQL = 'INSERT INTO `vava_farming_slots` (`parcel`, `slot`, `crop`, `seed_tier`, `planted_at`, `growth`, `moisture`, `fertility`, `dry_since`, `dry_hours`, `waterings`, `wilted`, `dead`, `covered`, `last_family`, `updated_at`) '
    .. 'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE `crop` = VALUES(`crop`), `seed_tier` = VALUES(`seed_tier`), '
    .. '`planted_at` = VALUES(`planted_at`), `growth` = VALUES(`growth`), `moisture` = VALUES(`moisture`), `fertility` = VALUES(`fertility`), '
    .. '`dry_since` = VALUES(`dry_since`), `dry_hours` = VALUES(`dry_hours`), `waterings` = VALUES(`waterings`), `wilted` = VALUES(`wilted`), '
    .. '`dead` = VALUES(`dead`), `covered` = VALUES(`covered`), `last_family` = VALUES(`last_family`), `updated_at` = VALUES(`updated_at`)'

local slots = {}
VavaFarming.slots = slots

-- parcelle → index → état (voir vAvA.SlotState dans shared/growth.lua) + dirty (true : à écrire ; WRITING : écriture
-- en cours, qu'une modification pendant l'attente remplace par true), inflight (une écriture en route), urgent (écrire
-- aussitôt quand elle se termine)
local states = {}
local WRITING = 'writing'
-- `waterings` est un SMALLINT UNSIGNED : une plante mûre arrosée sans fin ne doit pas faire échouer toute l'écriture
local MAX_WATERINGS = 65535
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
        drySince = nil, dryHours = 0, waterings = 0, wilted = false, dead = false, covered = false, lastFamily = nil,
        updatedAt = now, dirty = true,
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
                    wilted = bridge.Integer(row.wilted, 0) == 1, dead = bridge.Integer(row.dead, 0) == 1,
                    covered = bridge.Integer(row.covered, 0) == 1, lastFamily = row.last_family,
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
    growth.advance(slot, slot.crop and catalog.crop(slot.crop) or nil, time(), bridge.SeasonEffects())
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
        covered = slot.covered == true, frostHardy = crop ~= nil and crop.frostHardy == true,
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

-- effets de saison appliqués au passage précédent (UNKNOWN : aucun passage encore, ou saison en attente)
local UNKNOWN = {}
local appliedSeason = UNKNOWN

--- Relit et republie toutes les parcelles (passage de la boucle lente) : les plantes poussent sans qu'on y touche.
--- Saison en attente (vava_time démarre) : rien n'avance. Quand les effets de saison changent, chaque emplacement planté
--- est marqué à écrire : sa date de calcul en base suit, et un redémarrage ne recompte pas d'un bloc, au rythme de la
--- nouvelle saison, tout le temps passé depuis son dernier geste.
function slots.tick()
    local now = time()
    local season = bridge.SeasonEffects()
    if season == false then return end
    local changed = appliedSeason ~= UNKNOWN and appliedSeason ~= season
    appliedSeason = season
    for _, parcel in ipairs(catalog.parcels()) do
        for index = 1, parcel.count do
            local slot = states[parcel.id][index]
            growth.advance(slot, slot.crop and catalog.crop(slot.crop) or nil, now, season)
            if changed and slot.crop then slot.dirty = true end
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
    slot.wilted, slot.dead, slot.covered, slot.updatedAt, slot.dirty = false, false, false, now, true
end

--- Couvert contre le gel jusqu'à la récolte ou l'arrachage.
---@param slot table
function slots.cover(slot)
    slot.covered, slot.dirty = true, true
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

--- Récolte : l'emplacement redevient libre, la fertilité paie, la famille est retenue pour la rotation, la couverture
--- part avec la plante (shared/growth.lua).
---@param slot table
---@param crop table
---@param now integer
function slots.harvest(slot, crop, now)
    growth.harvest(slot, crop, now)
    slot.dirty = true
end

--- Arrachage : l'emplacement redevient libre sans rien payer ni retenir.
---@param slot table
---@param now integer
function slots.clear(slot, now)
    growth.clear(slot, now)
    slot.dirty = true
end

--- La besace a refusé ce que la plante donnait : elle est rendue telle qu'avant (copie de growth.snapshot), si personne
--- n'a semé entre-temps.
---@param slot table
---@param snapshot table
---@return boolean  vrai si la plante est rendue
function slots.giveBack(slot, snapshot)
    if not growth.giveBack(slot, snapshot) then return false end
    slot.dirty = true
    return true
end

-- Gel (vava_time) -------------------------------------------------------------------------------------------------------

--- Plantes que le gel tuerait cette nuit (état avancé à maintenant), par parcelle : liste { parcel, count } (parcelles
--- sans plante exposée omises).
---@return { parcel: vAvA.ParcelDefinition, count: integer }[]
function slots.exposed()
    local now = time()
    local season = bridge.SeasonEffects()
    local out = {}
    for _, parcel in ipairs(catalog.parcels()) do
        local count = 0
        for index = 1, parcel.count do
            local slot = states[parcel.id][index]
            local crop = slot.crop and catalog.crop(slot.crop) or nil
            growth.advance(slot, crop, now, season)
            if growth.frostKills(slot, crop) then count = count + 1 end
        end
        if count > 0 then out[#out + 1] = { parcel = parcel, count = count } end
    end
    return out
end

--- Le gel tombe : chaque plante ni couverte ni résistante meurt (état « morte » existant), à écrire avec le prochain lot ;
--- parcelles republiées. Rend { parcel, count } des parcelles touchées.
---@return { parcel: vAvA.ParcelDefinition, count: integer }[]
function slots.frost()
    local now = time()
    local season = bridge.SeasonEffects()
    local out = {}
    for _, parcel in ipairs(catalog.parcels()) do
        local count = 0
        for index = 1, parcel.count do
            local slot = states[parcel.id][index]
            local crop = slot.crop and catalog.crop(slot.crop) or nil
            growth.advance(slot, crop, now, season)
            if growth.frostKills(slot, crop) then
                slot.dead, slot.dirty = true, true
                count = count + 1
            end
        end
        if count > 0 then
            out[#out + 1] = { parcel = parcel, count = count }
            slots.publish(parcel)
        end
    end
    return out
end

--- Fertilité fixée (Conseil).
---@param slot table
---@param value number
function slots.setFertility(slot, value)
    slot.fertility = min(100, max(0, value))
    slot.dirty = true
end

--- Mûrit (Conseil) : croissance portée au total, terre arrosée (une sécheresse laissée en place la ferait reflétrir
--- ou mourir au calcul suivant).
---@param slot table
---@param crop table
function slots.ripen(slot, crop)
    slot.growth, slot.wilted, slot.dead = crop.growMinutes * 60, false, false
    slot.moisture, slot.drySince, slot.dirty = 100, nil, true
end

-- Écriture --------------------------------------------------------------------------------------------------------------
-- Deux chemins : l'écriture groupée (toutes les flushMs : humidité, croissance, arrosage…) et l'écriture immédiate d'un
-- emplacement qui vient de donner ou de consommer des objets (semis, récolte, compost, arrachage), pour qu'un crash
-- avant l'écriture groupée ne le rende pas tel qu'avant (récolte rejouée). Une seule écriture à la fois par emplacement
-- (`inflight`) : la base garde toujours la dernière ; une écriture immédiate demandée pendant une autre (`urgent`) part
-- dès que celle-ci se termine.

---@param parcelId string
---@param index integer
---@param slot table
---@return table values
local function valuesOf(parcelId, index, slot)
    -- croissance entière en base (en mémoire, une saison lui laisse ses fractions de seconde)
    return {
        parcelId, index, slot.crop, slot.seedTier, slot.plantedAt, floor(slot.growth), floor(slot.moisture * 100 + 0.5) / 100,
        floor(slot.fertility * 100 + 0.5) / 100, slot.drySince, floor(slot.dryHours * 1000 + 0.5) / 1000, min(slot.waterings, MAX_WATERINGS),
        slot.wilted and 1 or 0, slot.dead and 1 or 0, slot.covered and 1 or 0, slot.lastFamily, slot.updatedAt,
    }
end

local writeNow

--- Fin d'une écriture d'un emplacement : réussie, il est propre s'il est resté tel qu'écrit ; en échec, il reste à
--- écrire (l'écriture groupée le reprend). Une écriture immédiate demandée pendant l'attente part maintenant.
---@param parcelId string
---@param index integer
---@param slot table
---@param ok boolean
local function written(parcelId, index, slot, ok)
    slot.inflight = nil
    if ok and slot.dirty == WRITING then slot.dirty = false end
    local urgent = slot.urgent
    slot.urgent = nil
    if urgent and slot.dirty then writeNow(parcelId, index, slot) end
end

--- Écrit un emplacement tout de suite, dans son propre thread (l'appelant ne cède jamais la main). Valeurs relevées
--- avant le départ : une modification pendant l'attente le remarque à écrire.
---@param parcelId string
---@param index integer
---@param slot table
writeNow = function(parcelId, index, slot)
    slot.dirty, slot.inflight, slot.urgent = WRITING, true, nil
    local values = valuesOf(parcelId, index, slot)
    CreateThread(function()
        local _, err = bridge.db.update(UPSERT_SQL, values)
        if err then
            VavaFarming.log.warn("emplacement %s n° %d non écrit aussitôt (repris par l'écriture groupée) : %s", parcelId, index, tostring(err))
        end
        written(parcelId, index, slot, err == nil)
    end)
end

--- L'emplacement vient de donner ou de consommer des objets : il est écrit aussitôt (ou dès que l'écriture déjà en
--- route se termine).
---@param parcel vAvA.ParcelDefinition
---@param index integer
function slots.writeNow(parcel, index)
    local list = states[parcel.id]
    local slot = list and list[index]
    if not slot then return end
    if slot.inflight then
        slot.urgent = true
        return
    end
    writeNow(parcel.id, index, slot)
end

--- Requêtes des emplacements à écrire, marqués « en cours d'écriture » : l'écriture cède la main, et un geste joué
--- pendant l'attente les marque de nouveau à écrire au lieu d'être effacé. Un emplacement dont une écriture est déjà
--- en route attend le passage suivant. Renvoie le lot, à rendre à `markClean` (réussite) ou `markFailed` (échec).
---@param queries table[]
---@return table[] batch
function slots.collect(queries)
    local batch = {}
    for parcelId, list in pairs(states) do
        for index, slot in ipairs(list) do
            if slot.dirty and not slot.inflight then
                slot.dirty, slot.inflight = WRITING, true
                batch[#batch + 1] = { parcelId, index, slot }
                queries[#queries + 1] = { query = UPSERT_SQL, values = valuesOf(parcelId, index, slot) }
            end
        end
    end
    return batch
end

--- Écriture groupée réussie : seuls les emplacements restés tels qu'écrits sont propres.
---@param batch table[]|nil
function slots.markClean(batch)
    for _, entry in ipairs(batch or {}) do written(entry[1], entry[2], entry[3], true) end
end

--- Écriture groupée en échec : les emplacements restent à écrire.
---@param batch table[]|nil
function slots.markFailed(batch)
    for _, entry in ipairs(batch or {}) do written(entry[1], entry[2], entry[3], false) end
end
