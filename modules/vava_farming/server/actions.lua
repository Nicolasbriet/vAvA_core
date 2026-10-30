--[[
    vava_farming/server/actions.lua
    Rôle : les gestes du cultivateur décidés par le serveur : menu d'un emplacement ; début d'un geste (parcelle et
           emplacement à portée, accès, geste possible dans l'état présent, graines au palier choisi, seau en main avec
           des charges, compost, plante mûre, place ; hook annulable ; jeton, durée) ; fin du geste (durée revérifiée,
           distance — trop loin, le geste est abandonné —, puis application : semis, arrosage, compost, récolte avec
           qualité, provenance, graines récupérées et XP, arrachage avec déchets, couverture contre le gel (en automne
           et en hiver seulement, config.frost.coverSeasons ; un objet de config.frost.cover consommé, déchets
           végétaux d'abord, compost en secours ; saison et objet revérifiés à la fin) ; l'emplacement d'un geste qui donne ou consomme des objets
           est écrit aussitôt ; une récolte ou un arrachage vide l'emplacement avant d'ajouter quoi que ce soit à la
           besace, et une récolte refusée par la besace rend la plante) ; remplissage du seau au puits. Une seule action à la fois par joueur ; aucune à terre
           (vava_health) : ni menu, ni début, ni fin, ni puits.
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua, server/journal.lua, server/catalog.lua,
                  server/slots.lua, server/frost.lua
]]

local type, pairs, ipairs = type, pairs, ipairs
local mathType, floor, max, min, random = math.type, math.floor, math.max, math.min, math.random
local format = string.format
local sort = table.sort
local TriggerClientEvent, GetGameTimer, SetTimeout = TriggerClientEvent, GetGameTimer, SetTimeout
local time = os.time

local core = VavaFarming.core
local bridge = VavaFarming.bridge
local journal = VavaFarming.journal
local catalog = VavaFarming.catalog
local slots = VavaFarming.slots
local frost = VavaFarming.frost
local growth = VavaFarming.growth
local geometry = VavaFarming.geometry
local cfg = VavaFarming.config
local interact, messages, ACTIONS, STATES = cfg.interact, cfg.messages, VavaFarming.ACTIONS, VavaFarming.STATES
local EVENTS = VavaFarming.EVENTS
local MAX_TOKEN, MAX_TIER = VavaFarming.MAX_TOKEN, VavaFarming.MAX_TIER

local HOOK_ACTING = 'vava_farming:acting'
local HOOK_HARVESTED = 'vava_farming:harvested'

local actions = {}
VavaFarming.actions = actions

---@class vAvA.FarmSession
---@field token integer
---@field source integer
---@field characterId integer
---@field parcel vAvA.ParcelDefinition
---@field index integer
---@field action string
---@field crop table|nil
---@field tier integer
---@field heldId integer|nil
---@field startedAt integer
---@field durationMs integer

---@type table<integer, vAvA.FarmSession>
local sessions = {}
local lastToken = 0

---@param tier integer
---@return string
local function tierLabel(tier)
    return cfg.quality.tierLabels[tier] or tostring(tier)
end

--- Le joueur est-il à portée d'un emplacement ?
---@param src integer
---@param parcel vAvA.ParcelDefinition
---@param index integer
---@return boolean
local function nearSlot(src, parcel, index)
    local position = parcel.positions[index]
    local x, y, z = bridge.Position(src)
    if not x or not position then return false end
    return geometry.within(x, y, z, position.x, position.y, position.z, interact.distance + interact.serverTolerance)
end

--- Seau tenu en main et ses charges, ou nil.
---@param src integer
---@return table|nil held
---@return integer charges
local function bucketOf(src)
    local held = bridge.Held(src)
    if not held or catalog.toolKind(held.item) ~= 'seau' then return nil, 0 end
    local meta = type(held.metadata) == 'table' and held.metadata or {}
    local charges = mathType(meta.water) == 'integer' and meta.water or 0
    return held, max(0, charges)
end

---@param src integer
---@return boolean
local function hasSickle(src)
    local held = bridge.Held(src)
    return held ~= nil and catalog.toolKind(held.item) == 'faucille'
end

--- Piles de graines du joueur par culture et palier : culture → palier → { count, piles }.
---@param src integer
---@return table
local function seedIndex(src)
    local byCrop = {}
    for _, instance in ipairs(bridge.Items(src)) do
        local crop = catalog.cropOfSeed(instance.item)
        if crop then
            local meta = type(instance.metadata) == 'table' and instance.metadata or {}
            local tier = mathType(meta.tier) == 'integer' and meta.tier or 1
            local tiers = byCrop[crop.id]
            if not tiers then
                tiers = {}
                byCrop[crop.id] = tiers
            end
            local entry = tiers[tier]
            if not entry then
                entry = { count = 0, piles = {} }
                tiers[tier] = entry
            end
            entry.count = entry.count + instance.quantity
            entry.piles[#entry.piles + 1] = instance
        end
    end
    return byCrop
end

---@param index table
---@param cropId string
---@return table[]
local function seedAvailability(index, cropId)
    local list = {}
    for tier = 1, MAX_TIER do
        local entry = index[cropId] and index[cropId][tier]
        if entry and entry.count > 0 then list[#list + 1] = { tier = tier, count = entry.count } end
    end
    return list
end

--- Retrait d'une graine du palier donné (la pile la plus ancienne), ou nil.
---@param index table
---@param cropId string
---@param tier integer
---@return table|nil removal
local function seedRemoval(index, cropId, tier)
    local entry = index[cropId] and index[cropId][tier]
    if not entry or entry.count < 1 then return nil end
    local piles = {}
    for i, pile in ipairs(entry.piles) do piles[i] = pile end
    sort(piles, function(a, b) return a.id < b.id end)
    return { instanceId = piles[1].id, quantity = 1 }
end

-- Menu ------------------------------------------------------------------------------------------------------------------

---@param src integer
---@param parcelId any
---@param index any
---@return boolean ok
---@return table|string result
function actions.menu(src, parcelId, index)
    local characterId = bridge.GetCharacterId(src)
    if not characterId then return false, 'no_character' end
    if bridge.IsDowned(src) then return false, 'downed' end
    local parcel = catalog.parcel(parcelId)
    if not parcel then return false, 'unknown_parcel' end
    if mathType(index) ~= 'integer' or index < 1 or index > parcel.count then return false, 'unknown_slot' end
    if not nearSlot(src, parcel, index) then return false, 'too_far' end
    if not slots.canAccess(parcel, characterId) then
        bridge.Notify(src, messages.noAccess, 'warning')
        return false, 'no_access'
    end
    local slot = slots.get(parcel, index)
    local crop = slot.crop and catalog.crop(slot.crop) or nil
    local state = crop and growth.state(slot, crop) or nil
    local seeds = {}
    local sIndex = seedIndex(src)
    for cropId, def in pairs(catalog.crops()) do
        local available = seedAvailability(sIndex, cropId)
        if #available > 0 then seeds[#seeds + 1] = { crop = cropId, label = def.label, item = def.seed, available = available } end
    end
    sort(seeds, function(a, b) return a.label < b.label end)
    local bucket, charges = bucketOf(src)
    local compost = bridge.Count(src, cfg.compost.item)
    -- objets qui couvrent : comptés une fois chacun (le compost l'est déjà)
    local counts = { [cfg.compost.item] = compost }
    local function countOf(item)
        if counts[item] == nil then counts[item] = bridge.Count(src, item) end
        return counts[item]
    end
    -- hors des saisons où l'on couvre, le geste n'est pas proposé (et rien n'est compté pour lui)
    local coverSeason = frost.coverSeason()
    local coverWith = coverSeason and growth.coverOption(frost.covers(), countOf) or nil
    local coverOptions = {}
    if coverSeason then
        for i, option in ipairs(frost.covers()) do
            coverOptions[i] = { item = option.item, label = catalog.itemLabel(option.item), quantity = option.quantity, count = countOf(option.item) }
        end
    end
    return true, {
        parcel = { id = parcel.id, label = parcel.label, communal = parcel.owner == nil },
        slot = slots.view(parcel, index),
        seeds = seeds,
        bucket = { held = bucket ~= nil, charges = charges },
        compost = compost,
        cover = { season = coverSeason, options = coverOptions, use = coverWith and coverWith.item or nil },
        -- nuit de gel annoncée par vava_time (tirée, pas encore tombée) : mentionnée sur la fiche de la plante
        frost = { tonight = crop ~= nil and bridge.FrostTonight() },
        sickle = hasSickle(src),
        actions = {
            plant = crop == nil and #seeds > 0,
            water = crop ~= nil and state ~= STATES.DEAD,
            fertilize = compost > 0,
            harvest = state == STATES.RIPE,
            clear = crop ~= nil,
            cover = coverSeason and crop ~= nil and state ~= STATES.DEAD and not slot.covered and not crop.frostHardy and coverWith ~= nil,
        },
        rules = { moistureThreshold = cfg.growth.moistureThreshold, tierLabels = cfg.quality.tierLabels, frostTonight = messages.frostTonight },
        now = time(),
    }
end

-- Sessions ---------------------------------------------------------------------------------------------------------------

---@param src integer
---@return vAvA.FarmSession|nil
function actions.session(src)
    return sessions[src]
end

---@param src integer
---@param token any
---@return boolean
function actions.cancel(src, token)
    local session = sessions[src]
    if session and session.token == token then sessions[src] = nil end
    return true
end

---@param src integer
function actions.forget(src)
    sessions[src] = nil
end

--- Commence un geste. Bloque le thread courant (inventaire, hook).
---@param src integer
---@param parcelId any
---@param index any
---@param action any
---@param cropId any
---@param tier any
---@return boolean ok
---@return table|string result  { token, durationMs, anim, label } ou code
function actions.begin(src, parcelId, index, action, cropId, tier)
    local characterId = bridge.GetCharacterId(src)
    if not characterId then return false, 'no_character' end
    if bridge.IsDowned(src) then return false, 'downed' end
    local parcel = catalog.parcel(parcelId)
    if not parcel then return false, 'unknown_parcel' end
    if mathType(index) ~= 'integer' or index < 1 or index > parcel.count then return false, 'unknown_slot' end
    local spec = cfg.actions[action]
    if not spec then return false, 'invalid_action' end
    if sessions[src] then return false, 'busy' end
    if not nearSlot(src, parcel, index) then return false, 'too_far' end
    if not slots.canAccess(parcel, characterId) then
        bridge.Notify(src, messages.noAccess, 'warning')
        return false, 'no_access'
    end
    local slot = slots.get(parcel, index)
    local planted = slot.crop and catalog.crop(slot.crop) or nil
    local state = planted and growth.state(slot, planted) or nil
    local crop, chosenTier, heldId = nil, 0, nil

    if action == ACTIONS.PLANT then
        if planted then
            bridge.Notify(src, messages.occupied, 'info')
            return false, 'occupied'
        end
        crop = catalog.crop(cropId)
        if not crop then return false, 'unknown_crop' end
        local index_ = seedIndex(src)
        local available = seedAvailability(index_, crop.id)
        if #available == 0 then
            bridge.Notify(src, messages.noSeed, 'warning')
            return false, 'no_seed'
        end
        if tier == nil or tier == 0 then
            chosenTier = available[1].tier
        elseif mathType(tier) ~= 'integer' or tier < 1 or tier > MAX_TIER then
            return false, 'bad_tier'
        else
            chosenTier = tier
            if not seedRemoval(index_, crop.id, chosenTier) then
                bridge.Notify(src, messages.noSeed, 'warning')
                return false, 'no_seed'
            end
        end
    elseif action == ACTIONS.WATER then
        if not planted then
            bridge.Notify(src, messages.empty, 'info')
            return false, 'empty'
        end
        if state == STATES.DEAD then
            bridge.Notify(src, messages.dead, 'info')
            return false, 'dead'
        end
        local bucket, charges = bucketOf(src)
        if not bucket then
            bridge.Notify(src, messages.noBucket, 'warning')
            return false, 'no_bucket'
        end
        if charges < 1 then
            bridge.Notify(src, messages.bucketEmpty, 'warning')
            return false, 'bucket_empty'
        end
        heldId = bucket.id
    elseif action == ACTIONS.FERTILIZE then
        if bridge.Count(src, cfg.compost.item) < 1 then
            bridge.Notify(src, messages.noCompost, 'warning')
            return false, 'no_compost'
        end
    elseif action == ACTIONS.HARVEST then
        if not planted then
            bridge.Notify(src, messages.empty, 'info')
            return false, 'empty'
        end
        if state == STATES.DEAD then
            bridge.Notify(src, messages.dead, 'info')
            return false, 'dead'
        end
        if state ~= STATES.RIPE then
            bridge.Notify(src, format(messages.notRipe, planted.label, floor(growth.progress(slot, planted) * 100 + 0.5)), 'info')
            return false, 'not_ripe'
        end
        if not bridge.CanCarry(src, planted.product, 1) then
            bridge.Notify(src, messages.noSpace, 'warning')
            return false, 'no_space'
        end
        crop = planted
    elseif action == ACTIONS.CLEAR then
        if not planted then
            bridge.Notify(src, messages.empty, 'info')
            return false, 'empty'
        end
        crop = planted
    elseif action == ACTIONS.COVER then
        if not frost.coverSeason() then
            bridge.Notify(src, messages.offSeason, 'info')
            return false, 'off_season'
        end
        if not planted then
            bridge.Notify(src, messages.empty, 'info')
            return false, 'empty'
        end
        if state == STATES.DEAD then
            bridge.Notify(src, messages.dead, 'info')
            return false, 'dead'
        end
        if slot.covered then
            bridge.Notify(src, messages.alreadyCovered, 'info')
            return false, 'covered'
        end
        if planted.frostHardy then
            bridge.Notify(src, messages.frostHardy, 'info')
            return false, 'frost_hardy'
        end
        if not growth.coverOption(frost.covers(), function(item) return bridge.Count(src, item) end) then
            bridge.Notify(src, format(messages.noCover, frost.coverLabels()), 'warning')
            return false, 'no_cover'
        end
        crop = planted
    end

    local payload = { source = src, characterId = characterId, parcel = parcel.id, slot = index, action = action, crop = crop and crop.id or nil }
    local allowed, reason = core.hooks.runBefore(HOOK_ACTING, payload)
    if not allowed then return false, (type(reason) == 'string' and reason ~= 'hook_error') and reason or 'refused' end
    if sessions[src] then return false, 'busy' end

    local durationMs = spec.durationMs
    if action == ACTIONS.HARVEST and hasSickle(src) then durationMs = floor(durationMs * (spec.sickleFactor or 1)) end
    lastToken = (lastToken % MAX_TOKEN) + 1
    local session = {
        token = lastToken, source = src, characterId = characterId, parcel = parcel, index = index, action = action,
        crop = crop, tier = chosenTier, heldId = heldId, plantedAt = slot.plantedAt, startedAt = GetGameTimer(), durationMs = durationMs,
    }
    sessions[src] = session
    SetTimeout(interact.expireMs, function()
        if sessions[src] == session then sessions[src] = nil end
    end)
    local label = crop and crop.label or (planted and planted.label) or parcel.label
    return true, { token = session.token, durationMs = durationMs, anim = spec.anim, label = label }
end

--- Vue de l'emplacement envoyée au joueur (menu ouvert) et publication de la parcelle.
---@param src integer
---@param parcel vAvA.ParcelDefinition
---@param index integer
---@return table view
local function settle(src, parcel, index)
    slots.publish(parcel)
    local view = slots.view(parcel, index)
    TriggerClientEvent(EVENTS.SLOT, src, view)
    return view
end

--- Fin d'un geste : le serveur applique. Bloque le thread courant.
---@param src integer
---@param token any
---@return boolean ok
---@return table|string result
function actions.finish(src, token)
    local session = sessions[src]
    if not session or session.token ~= token then return false, 'not_found' end
    if GetGameTimer() - session.startedAt < session.durationMs - interact.finishToleranceMs then return false, 'too_soon' end
    local parcel, index, action = session.parcel, session.index, session.action
    -- la session tombe dans tous les cas : à terre ou trop loin, le geste est abandonné (rien n'est encore consommé)
    sessions[src] = nil
    if bridge.IsDowned(src) then return false, 'downed' end
    if not nearSlot(src, parcel, index) then return false, 'too_far' end
    local now = time()
    local slot = slots.get(parcel, index)
    local planted = slot.crop and catalog.crop(slot.crop) or nil

    if action == ACTIONS.PLANT then
        if planted then return false, 'missing_items' end
        local crop = session.crop
        local removal = seedRemoval(seedIndex(src), crop.id, session.tier)
        if not removal then
            bridge.Notify(src, messages.noSeed, 'warning')
            return false, 'missing_items'
        end
        if not bridge.Exchange(src, { removal }, {}) then return false, 'missing_items' end
        slots.plant(slot, crop, session.tier, now)
        slots.writeNow(parcel, index)
        bridge.AddXp(src, { skill = 'agriculture', source = crop.id .. ':plant', difficulty = crop.difficulty, amount = max(1, floor(crop.xp * cfg.quality.plantXpShare)) })
        journal.write('planted', { parcel = parcel.id, slot = index, characterId = session.characterId, item = crop.seed, details = { tier = session.tier } })
        bridge.Notify(src, format(messages.planted, crop.label), 'info')
        return true, { action = action, slot = settle(src, parcel, index) }
    elseif action == ACTIONS.WATER then
        if not planted or slot.dead then return false, 'not_found' end
        local bucket, charges = bucketOf(src)
        if not bucket or bucket.id ~= session.heldId then return false, 'no_bucket' end
        if charges < 1 then return false, 'bucket_empty' end
        if not bridge.PatchMetadata(src, bucket.id, { water = charges - 1 }) then return false, 'no_bucket' end
        slots.water(slot)
        bridge.Notify(src, format(messages.watered, charges - 1), 'info')
        return true, { action = action, slot = settle(src, parcel, index) }
    elseif action == ACTIONS.FERTILIZE then
        if not bridge.Exchange(src, { { item = cfg.compost.item, quantity = 1 } }, {}) then
            bridge.Notify(src, messages.noCompost, 'warning')
            return false, 'missing_items'
        end
        slots.fertilize(slot)
        slots.writeNow(parcel, index)
        bridge.Notify(src, format(messages.fertilized, floor(slot.fertility + 0.5)), 'info')
        return true, { action = action, slot = settle(src, parcel, index) }
    elseif action == ACTIONS.HARVEST then
        local level = bridge.GetLevel(src, 'agriculture')
        -- relue après le niveau (un export peut céder la main) : du contrôle à la prise de la plante, rien ne cède la main
        slot = slots.get(parcel, index)
        planted = slot.crop and catalog.crop(slot.crop) or nil
        if not planted or growth.state(slot, planted) ~= STATES.RIPE then return false, 'not_found' end
        local regularity = growth.regularity(slot, planted)
        local value = growth.quality(slot.seedTier, level, regularity, slot.fertility, (random() * 2 - 1) * cfg.quality.jitter)
        local tier = growth.tierOf(value)
        local quantity = max(1, random(planted.yield[1], planted.yield[2]))
        local metadata = { tier = tier }
        if cfg.quality.origin then metadata.origin = parcel.label end
        -- la plante est prise AVANT l'ajout à la besace (ses hooks peuvent céder la main) : un second cultivateur qui
        -- finit le même geste trouve l'emplacement libre ; si la besace refuse, la plante est rendue telle quelle
        -- (couverture comprise), à moins qu'on n'ait semé entre-temps
        local taken = growth.snapshot(slot)
        slots.harvest(slot, planted, now)
        local ok = bridge.Add(src, planted.product, quantity, metadata)
        if not ok then
            if not slots.giveBack(slot, taken) then
                VavaFarming.log.warn('récolte de %s n° %d refusée par la besace du personnage %d : emplacement semé '
                    .. 'entre-temps, plante perdue', parcel.id, index, session.characterId)
            end
            bridge.Notify(src, messages.noSpace, 'warning')
            return false, 'no_space'
        end
        slots.writeNow(parcel, index)
        local seedsBack = 0
        local chance = min(cfg.seeds.maxChance, cfg.seeds.baseChance + level * cfg.seeds.perLevel)
        if random() < chance then
            seedsBack = random(cfg.seeds.count[1], cfg.seeds.count[2])
            if not bridge.Add(src, planted.seed, seedsBack, { tier = tier }) then seedsBack = 0 end
        end
        bridge.AddXp(src, { skill = 'agriculture', source = planted.id, difficulty = planted.difficulty, amount = planted.xp })
        local productLabel = catalog.itemLabel(planted.product)
        bridge.Notify(src, format(messages.harvested, planted.label, quantity, productLabel, tierLabel(tier)), 'info')
        if seedsBack > 0 then bridge.Notify(src, format(messages.seedsBack, seedsBack), 'info') end
        if tier >= cfg.logTier then
            journal.write('harvested', { parcel = parcel.id, slot = index, characterId = session.characterId, item = planted.product, quality = value, details = { tier = tier, quantity = quantity, regularity = floor(regularity) } })
        end
        core.hooks.runAfter(HOOK_HARVESTED, {
            source = src, characterId = session.characterId, parcel = parcel.id, slot = index, crop = planted.id, item = planted.product,
            quantity = quantity, quality = value, tier = tier, seeds = seedsBack,
        })
        return true, { action = action, slot = settle(src, parcel, index), item = planted.product, label = productLabel, quantity = quantity, tier = tier, seeds = seedsBack }
    elseif action == ACTIONS.CLEAR then
        if not planted then return false, 'not_found' end
        local waste = 0
        if slot.wilted or slot.dead then waste = random(cfg.compost.waste.count[1], cfg.compost.waste.count[2]) end
        -- la plante est arrachée AVANT l'ajout des déchets (ses hooks peuvent céder la main) : un second cultivateur
        -- trouve l'emplacement libre ; l'arrachage ne dépend pas des déchets, perdus si la besace est pleine
        slots.clear(slot, now)
        slots.writeNow(parcel, index)
        if waste > 0 and not bridge.Add(src, cfg.compost.waste.item, waste) then waste = 0 end
        journal.write('cleared', { parcel = parcel.id, slot = index, characterId = session.characterId, item = planted.id, details = { waste = waste } })
        bridge.Notify(src, waste > 0 and format(messages.clearedWaste, waste) or messages.cleared, 'info')
        return true, { action = action, slot = settle(src, parcel, index), item = waste > 0 and cfg.compost.waste.item or nil, quantity = waste > 0 and waste or nil }
    elseif action == ACTIONS.COVER then
        -- la saison a pu tourner pendant le geste
        if not frost.coverSeason() then
            bridge.Notify(src, messages.offSeason, 'info')
            return false, 'off_season'
        end
        local cover = growth.coverOption(frost.covers(), function(item) return bridge.Count(src, item) end)
        if not cover then
            bridge.Notify(src, format(messages.noCover, frost.coverLabels()), 'warning')
            return false, 'missing_items'
        end
        -- l'état a pu changer pendant le geste (gel tombé, autre joueur, arrachage puis nouveau semis, même de la même
        -- culture : la date de semis gardée en session le dit) ; vérification et couverture sans céder la main
        local plantedAt = slot.plantedAt
        if not planted or planted.id ~= session.crop.id or plantedAt ~= session.plantedAt or slot.dead or slot.covered
            or planted.frostHardy then
            return false, 'not_found'
        end
        -- couverte AVANT l'échange (qui peut céder la main) : un second cultivateur voit la plante couverte et ne paie
        -- pas pour elle ; l'échange refusé retire la couverture
        slots.cover(slot)
        if not bridge.Exchange(src, { { item = cover.item, quantity = cover.quantity } }, {}) then
            if slot.plantedAt == plantedAt and slot.crop == planted.id then slot.covered = false end
            bridge.Notify(src, format(messages.noCover, frost.coverLabels()), 'warning')
            return false, 'missing_items'
        end
        if slot.plantedAt ~= plantedAt or slot.crop ~= planted.id then
            -- la plante a été récoltée ou arrachée pendant l'échange : l'objet est rendu
            if not bridge.Add(src, cover.item, cover.quantity) then
                VavaFarming.log.warn('couverture de %s n° %d : %d × %s non rendu(s) au personnage %d (besace pleine ?)',
                    parcel.id, index, cover.quantity, cover.item, session.characterId)
            end
            return false, 'not_found'
        end
        slots.writeNow(parcel, index)
        journal.write('covered', { parcel = parcel.id, slot = index, characterId = session.characterId, item = cover.item, details = { crop = planted.id, quantity = cover.quantity } })
        bridge.Notify(src, messages.covered, 'info')
        return true, { action = action, slot = settle(src, parcel, index) }
    end
    return false, 'not_found'
end

--- Remplit le seau tenu en main à un puits.
---@param src integer
---@param wellId any
---@return boolean ok
---@return table|string result  { charges } ou code
function actions.fill(src, wellId)
    if not bridge.GetCharacterId(src) then return false, 'no_character' end
    if bridge.IsDowned(src) then return false, 'downed' end
    local well = catalog.well(wellId)
    if not well then return false, 'unknown_well' end
    local x, y, z = bridge.Position(src)
    if not x or not geometry.within(x, y, z, well.x, well.y, well.z, interact.distance + interact.serverTolerance) then return false, 'too_far' end
    local bucket, charges = bucketOf(src)
    if not bucket then
        bridge.Notify(src, messages.noBucket, 'warning')
        return false, 'no_bucket'
    end
    if charges >= cfg.bucket.charges then return false, 'full' end
    if not bridge.PatchMetadata(src, bucket.id, { water = cfg.bucket.charges }) then return false, 'no_bucket' end
    bridge.Notify(src, format(messages.filled, cfg.bucket.charges), 'info')
    return true, { charges = cfg.bucket.charges }
end

actions.tierLabel = tierLabel
