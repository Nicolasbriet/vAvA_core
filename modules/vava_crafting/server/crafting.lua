--[[
    vava_crafting/server/crafting.lua
    Rôle : la fabrication décidée par le serveur. Rien à terre (vava_health) : ni menu, ni début, ni fin (pièce
           abandonnée, station libérée), ni combustible. Menu d'une station (recettes connues de ce type, paliers
           possédés par ingrédient, réparables, poinçon, règles pour l'aperçu). Début : station à portée et
           accessible, libre, recette connue et au niveau, outil en main du bon genre, combustible, paliers choisis
           valides et possédés,
           place, hook annulable ; jeton, station occupée (jusqu'à la fin, l'annulation, ou l'oubli après 2 min ou la
           durée de la pièce + une marge). Fin : durée revérifiée, distance (trop loin : pièce abandonnée, station
           libérée), outil et combustible, piles relues et consommées par instance (le palier choisi, les plus
           anciennes d'abord), qualité (matériaux, niveau, station, aléa, plafonnée), palier, objet signé ou produit
           simple, échange atomique, combustible, XP, leçons aux élèves présents (recette transmise), baptême possible
           d'un chef-d'œuvre, journal, hooks.
           Les sessions (création et réparation) vivent ici ; repair.lua s'y branche.
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua, server/journal.lua, server/catalog.lua,
                  server/stations.lua, server/signature.lua ; server/repair.lua (lié à l'exécution)
]]

local type, ipairs = type, ipairs
local mathType, floor, max, random = math.type, math.floor, math.max, math.random
local format = string.format
local sort = table.sort
local TriggerClientEvent, GetGameTimer, SetTimeout = TriggerClientEvent, GetGameTimer, SetTimeout
local time = os.time

local core = VavaCrafting.core
local bridge = VavaCrafting.bridge
local journal = VavaCrafting.journal
local catalog = VavaCrafting.catalog
local stations = VavaCrafting.stations
local signature = VavaCrafting.signature
local quality = VavaCrafting.quality
local cfg = VavaCrafting.config
local interact, messages = cfg.interact, cfg.messages
local EVENTS = VavaCrafting.EVENTS
local MAX_TOKEN = VavaCrafting.MAX_TOKEN
local MAX_TIER = VavaCrafting.MAX_TIER

local HOOK_CRAFTING = 'vava_crafting:crafting'
local HOOK_CRAFTED = 'vava_crafting:crafted'

local crafting = {}
VavaCrafting.crafting = crafting

---@class vAvA.CraftSession
---@field token integer
---@field source integer
---@field characterId integer
---@field kind 'craft'|'repair'
---@field station vAvA.StationDefinition
---@field recipe vAvA.RecipeDefinition
---@field choices table<integer, integer>   index d'ingrédient → palier (création)
---@field heldId integer|nil
---@field level integer
---@field startedAt integer
---@field durationMs integer
---@field instanceId integer|nil             réparation : objet
---@field cost table[]|nil                   réparation : { item, quantity }

---@type table<integer, vAvA.CraftSession>
local sessions = {}
local lastToken = 0

---@param kind string
---@return string
local function toolLabel(kind)
    return messages.toolKinds[kind] or kind
end

-- Inventaire : piles par objet et palier ----------------------------------------------------------------------------

---@class vAvA.PileIndex
---@field byItem table<string, table<integer, { count: integer, piles: table[] }>>   objet → palier → compte et piles

--- Index des piles de la besace : objet → palier (1 pour une pile sans palier) → compte et piles (les plus anciennes
--- d'abord). Les objets signés (qualité) n'entrent pas dans les matières.
---@param src integer
---@return vAvA.PileIndex
local function indexPiles(src)
    local byItem = {}
    for _, instance in ipairs(bridge.Items(src)) do
        local meta = type(instance.metadata) == 'table' and instance.metadata or {}
        if meta.quality == nil then
            local tier = mathType(meta.tier) == 'integer' and meta.tier or 1
            local tiers = byItem[instance.item]
            if not tiers then
                tiers = {}
                byItem[instance.item] = tiers
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
    return { byItem = byItem }
end

--- Paliers possédés d'un objet à partir du palier minimal : { { tier, count } } croissants.
---@param index vAvA.PileIndex
---@param item string
---@param minTier integer
---@return table[]
local function availability(index, item, minTier)
    local list = {}
    local tiers = index.byItem[item]
    if tiers then
        for tier = minTier, MAX_TIER do
            local entry = tiers[tier]
            if entry and entry.count > 0 then list[#list + 1] = { tier = tier, count = entry.count } end
        end
    end
    return list
end

--- Palier par défaut d'un ingrédient : le plus bas possédé qui respecte le minimum, sinon le minimum.
---@param index vAvA.PileIndex
---@param ingredient table
---@return integer
local function defaultTier(index, ingredient)
    local available = availability(index, ingredient.item, ingredient.minTier)
    return available[1] and available[1].tier or ingredient.minTier
end

--- Retraits par instance pour un ingrédient au palier choisi (les plus anciennes piles d'abord) ; nil s'il en manque.
---@param index vAvA.PileIndex
---@param ingredient table
---@param tier integer
---@return table[]|nil removals
local function takeFrom(index, ingredient, tier)
    local tiers = index.byItem[ingredient.item]
    local entry = tiers and tiers[tier]
    if not entry or entry.count < ingredient.quantity then return nil end
    local piles = {}
    for i, pile in ipairs(entry.piles) do piles[i] = pile end
    sort(piles, function(a, b) return a.id < b.id end)
    local removals, needed = {}, ingredient.quantity
    for _, pile in ipairs(piles) do
        if needed <= 0 then break end
        local amount = pile.quantity < needed and pile.quantity or needed
        removals[#removals + 1] = { instanceId = pile.id, quantity = amount }
        needed = needed - amount
    end
    return removals
end

-- Menu ------------------------------------------------------------------------------------------------------------------

---@param src integer
---@param def vAvA.StationDefinition
---@param index vAvA.PileIndex
---@return table[]
local function recipeViews(src, def, index)
    local held = bridge.Held(src)
    local heldKind = held and catalog.toolKind(held.item) or nil
    local heldBroken = held and type(held.metadata) == 'table' and held.metadata.broken == true
    local list = {}
    for _, recipe in ipairs(catalog.recipesOf(def.type.id)) do
        if bridge.KnowsRecipe(src, recipe.id) or not recipe.transmission then
            local playerLevel = bridge.GetLevel(src, recipe.skill)
            local ingredients = {}
            for i, ingredient in ipairs(recipe.ingredients) do
                ingredients[i] = {
                    item = ingredient.item, label = catalog.itemLabel(ingredient.item), quantity = ingredient.quantity, minTier = ingredient.minTier,
                    available = availability(index, ingredient.item, ingredient.minTier),
                }
            end
            list[#list + 1] = {
                id = recipe.id, label = recipe.label, skill = recipe.skill, skillLabel = bridge.SkillLabel(recipe.skill),
                level = recipe.level, playerLevel = playerLevel, levelOk = playerLevel >= recipe.level,
                known = recipe.transmission and true or playerLevel >= recipe.level,
                toolKind = recipe.tool, toolLabel = recipe.tool and toolLabel(recipe.tool) or nil,
                toolOk = recipe.tool == nil or (heldKind == recipe.tool and not heldBroken),
                durationMs = crafting.duration(recipe, playerLevel), difficulty = recipe.difficulty, xp = recipe.xp,
                signed = recipe.signed or recipe.signedIfQuality ~= nil, transmission = recipe.transmission,
                ingredients = ingredients, output = { item = recipe.output.item, label = catalog.itemLabel(recipe.output.item), quantity = recipe.output.quantity },
            }
        end
    end
    return list
end

--- Menu complet d'une station pour un joueur à portée et autorisé. Bloque le thread courant (inventaire, compétences).
---@param src integer
---@param stationId any
---@return boolean ok
---@return table|string result
function crafting.menu(src, stationId)
    local characterId = bridge.GetCharacterId(src)
    if not characterId then return false, 'no_character' end
    if bridge.IsDowned(src) then return false, 'downed' end
    local def = catalog.station(stationId)
    if not def then return false, 'unknown_station' end
    if not stations.near(src, def) then return false, 'too_far' end
    if not stations.canAccess(def, characterId) then
        bridge.Notify(src, messages.noAccess, 'warning')
        return false, 'no_access'
    end
    local index = indexPiles(src)
    local skills = {}
    for i, skill in ipairs(def.type.skills) do skills[i] = { id = skill, label = bridge.SkillLabel(skill), level = bridge.GetLevel(src, skill) } end
    local view = stations.view(def)
    if view.owner then view.owner.name = view.owner.kind == 'character' and (bridge.GetCharacterName(src) or nil) or nil end
    local q, tiers = cfg.quality, cfg.tiers
    return true, {
        station = view,
        skills = skills,
        recipes = recipeViews(src, def, index),
        repairables = VavaCrafting.repair.list(src, def, index),
        mark = signature.view(src, characterId),
        rules = {
            weights = { materials = q.weights.materials, skill = q.weights.skill, station = q.weights.station },
            materialQuality = tiers.materialQuality, thresholds = tiers.thresholds, tierLabels = tiers.labels,
            jitter = q.jitter, capByLevel = q.capByLevel, masterpieceTier = cfg.masterpiece.tier,
            repair = { share = cfg.repair.ingredientShare, loss = cfg.repair.maxDurabilityLoss },
        },
    }
end

-- Sessions -------------------------------------------------------------------------------------------------------------

---@param recipe vAvA.RecipeDefinition
---@param level integer
---@return integer
function crafting.duration(recipe, level)
    local ms = recipe.durationMs * max(0.0, 1.0 - level * cfg.duration.skillFactor)
    return max(cfg.duration.minMs, floor(ms))
end

---@param src integer
---@return vAvA.CraftSession|nil
function crafting.session(src)
    return sessions[src]
end

--- Ouvre une session (création ou réparation) : jeton, station occupée, oubli programmé (délai de la config, ou durée
--- du geste + marge pour une longue recette, qui doit pouvoir finir).
---@param src integer
---@param fields table
---@return vAvA.CraftSession
function crafting.open(src, fields)
    lastToken = (lastToken % MAX_TOKEN) + 1
    fields.token, fields.source, fields.startedAt = lastToken, src, GetGameTimer()
    sessions[src] = fields
    stations.setBusy(fields.station, src)
    SetTimeout(max(interact.expireMs, fields.durationMs + interact.expireMarginMs), function()
        if sessions[src] == fields then crafting.release(src) end
    end)
    return fields
end

--- Ferme la session d'un joueur et libère sa station.
---@param src integer
function crafting.release(src)
    local session = sessions[src]
    if not session then return end
    sessions[src] = nil
    if stations.busyBy(session.station) == src then stations.setBusy(session.station, nil) end
end

--- Interrompt la pièce en cours si le jeton correspond. Toujours vrai.
---@param src integer
---@param token any
---@return boolean
function crafting.cancel(src, token)
    local session = sessions[src]
    if session and session.token == token then crafting.release(src) end
    return true
end

--- Vérifie l'outil demandé par la recette : en main, du bon genre, non brisé. Renvoie l'instance ou nil, code.
---@param src integer
---@param recipe vAvA.RecipeDefinition
---@return table|nil held
---@return string|nil code
local function toolCheck(src, recipe)
    if not recipe.tool then return nil, nil end
    local held = bridge.Held(src)
    if not held then
        bridge.Notify(src, format(messages.noTool, toolLabel(recipe.tool)), 'warning')
        return nil, 'no_tool'
    end
    if catalog.toolKind(held.item) ~= recipe.tool then
        bridge.Notify(src, format(messages.noTool, toolLabel(recipe.tool)), 'warning')
        return nil, 'wrong_tool'
    end
    if type(held.metadata) == 'table' and held.metadata.broken == true then
        bridge.Notify(src, messages.brokenTool, 'warning')
        return nil, 'broken_tool'
    end
    return held, nil
end

--- Normalise les paliers choisis : un par ingrédient, ≥ minimum, possédé en quantité.
---@param index vAvA.PileIndex
---@param recipe vAvA.RecipeDefinition
---@param choices any  { [objet] = palier } venu du client
---@return table<integer, integer>|nil resolved
---@return string|nil code
local function resolveChoices(index, recipe, choices)
    if choices ~= nil and type(choices) ~= 'table' then return nil, 'bad_tier' end
    local resolved = {}
    for i, ingredient in ipairs(recipe.ingredients) do
        local chosen = choices and choices[ingredient.item]
        if chosen == nil then
            chosen = defaultTier(index, ingredient)
        elseif mathType(chosen) ~= 'integer' or chosen < ingredient.minTier or chosen > MAX_TIER then
            return nil, 'bad_tier'
        end
        local tiers = index.byItem[ingredient.item]
        local entry = tiers and tiers[chosen]
        if not entry or entry.count < ingredient.quantity then return nil, 'missing_items' end
        resolved[i] = chosen
    end
    return resolved
end

--- Commence une pièce. Bloque le thread courant.
---@param src integer
---@param stationId any
---@param recipeId any
---@param choices any
---@return boolean ok
---@return table|string result  { token, durationMs, anim, label } ou code
function crafting.begin(src, stationId, recipeId, choices)
    local characterId = bridge.GetCharacterId(src)
    if not characterId then return false, 'no_character' end
    if bridge.IsDowned(src) then return false, 'downed' end
    local def = catalog.station(stationId)
    if not def then return false, 'unknown_station' end
    if sessions[src] then return false, 'busy' end
    if not stations.near(src, def) then return false, 'too_far' end
    if not stations.canAccess(def, characterId) then
        bridge.Notify(src, messages.noAccess, 'warning')
        return false, 'no_access'
    end
    if stations.busyBy(def) then
        bridge.Notify(src, messages.busy, 'info')
        return false, 'busy'
    end
    local recipe = catalog.recipe(recipeId)
    if not recipe then return false, 'unknown_recipe' end
    if recipe.station ~= def.type.id then return false, 'wrong_station' end
    if not bridge.KnowsRecipe(src, recipe.id) then return false, 'not_known' end
    local level = bridge.GetLevel(src, recipe.skill)
    if level < recipe.level then return false, 'level' end
    local held, toolErr = toolCheck(src, recipe)
    if toolErr then return false, toolErr end
    if not stations.hasFuel(def) then
        bridge.Notify(src, format(messages.noFuel, def.type.label), 'warning')
        return false, 'no_fuel'
    end
    local index = indexPiles(src)
    local resolved, code = resolveChoices(index, recipe, choices)
    if not resolved then
        if code == 'missing_items' then bridge.Notify(src, messages.missing, 'warning') end
        return false, code
    end
    local canCarry = bridge.CanCarry(src, recipe.output.item, recipe.output.quantity, { tier = 1 })
    if not canCarry then
        bridge.Notify(src, messages.noSpace, 'warning')
        return false, 'no_space'
    end
    local payload = { source = src, characterId = characterId, station = def.id, recipe = recipe.id, item = recipe.output.item }
    local allowed, reason = core.hooks.runBefore(HOOK_CRAFTING, payload)
    if not allowed then return false, (type(reason) == 'string' and reason ~= 'hook_error') and reason or 'refused' end
    -- le hook a pu céder la main
    if sessions[src] or stations.busyBy(def) then return false, 'busy' end

    local session = crafting.open(src, {
        kind = 'craft', characterId = characterId, station = def, recipe = recipe, choices = resolved,
        heldId = held and held.id or nil, level = level, durationMs = crafting.duration(recipe, level),
    })
    return true, { token = session.token, durationMs = session.durationMs, anim = def.type.anim, label = recipe.label }
end

--- Leçons : une recette transmise réalisée devant des élèves à portée.
---@param src integer
---@param session vAvA.CraftSession
local function teach(src, session)
    local recipe = session.recipe
    for _, student in ipairs(bridge.PlayersNear(src, cfg.lessons.radius)) do
        local ok = bridge.RecordLesson(src, student, recipe.id)
        if ok then
            journal.write('lesson', { station = session.station.id, recipe = recipe.id, characterId = session.characterId, details = { student = bridge.GetCharacterId(student) } })
        end
    end
end

--- Fin d'une pièce : contrôles, qualité, échange, combustible, XP, leçons, baptême, journal, hooks. Bloque le thread.
---@param session vAvA.CraftSession
---@return boolean ok
---@return table|string result
local function finishCraft(session)
    local src, def, recipe = session.source, session.station, session.recipe
    -- trop loin à la fin : la pièce est abandonnée (rien n'est encore consommé), la station libérée aussitôt
    if not stations.near(src, def) then
        crafting.release(src)
        return false, 'too_far'
    end
    local _, toolErr = toolCheck(src, recipe)
    if toolErr then
        crafting.release(src)
        return false, toolErr
    end
    if not stations.hasFuel(def) then
        crafting.release(src)
        bridge.Notify(src, format(messages.noFuel, def.type.label), 'warning')
        return false, 'no_fuel'
    end
    local index = indexPiles(src)
    local removals = {}
    for i, ingredient in ipairs(recipe.ingredients) do
        local part = takeFrom(index, ingredient, session.choices[i])
        if not part then
            crafting.release(src)
            bridge.Notify(src, messages.missing, 'warning')
            return false, 'missing_items'
        end
        for _, removal in ipairs(part) do removals[#removals + 1] = removal end
    end

    local now = time()
    local materials = quality.materials(recipe.ingredients, session.choices)
    local score = quality.score(materials, session.level, def.quality)
    local value = quality.finalize(score, (random() * 2 - 1) * cfg.quality.jitter, session.level)
    local tier = quality.tierOf(value)
    local signed = recipe.signed or (recipe.signedIfQuality ~= nil and value >= recipe.signedIfQuality)
    local name = bridge.GetCharacterName(src) or '?'
    local metadata = signed and signature.build(session.characterId, name, recipe, value, tier, now) or signature.simple(tier)
    local ok, code = bridge.Exchange(src, removals, { { item = recipe.output.item, quantity = recipe.output.quantity, metadata = metadata } })
    if not ok then
        crafting.release(src)
        bridge.Notify(src, code == 'no_space' and messages.noSpace or messages.missing, 'warning')
        return false, code == 'no_space' and 'no_space' or 'missing_items'
    end
    stations.consumeFuel(def)
    crafting.release(src)
    bridge.AddXp(src, { skill = recipe.skill, source = recipe.id, difficulty = recipe.difficulty, amount = recipe.xp })
    if recipe.transmission then teach(src, session) end

    local itemLabel = catalog.itemLabel(recipe.output.item)
    local tierLabel = quality.tierLabel(tier)
    local instanceId, nameable = nil, false
    if signed then
        for _, candidate in ipairs(bridge.Items(src, { item = recipe.output.item, metadata = { crafted_at = now, crafter_id = session.characterId } })) do
            instanceId = candidate.id
        end
        bridge.Notify(src, format(messages.crafted, recipe.label, itemLabel, tierLabel, value), 'info')
        if tier >= cfg.masterpiece.tier and instanceId then
            nameable = true
            signature.offerName(src, instanceId, itemLabel)
            bridge.Notify(src, messages.masterpiece, 'info')
        end
    else
        bridge.Notify(src, format(messages.craftedSimple, recipe.label, recipe.output.quantity, itemLabel, tierLabel), 'info')
    end
    if tier >= cfg.logTier then
        journal.write('crafted', { station = def.id, recipe = recipe.id, characterId = session.characterId, item = recipe.output.item, quality = value, details = { tier = tier, signed = signed, instance = instanceId } })
    end
    local result = {
        kind = 'craft', item = recipe.output.item, label = itemLabel, quantity = recipe.output.quantity, quality = value, tier = tier,
        signed = signed, nameable = nameable, instanceId = instanceId, nameWindowMs = cfg.masterpiece.nameWindowMs,
    }
    TriggerClientEvent(EVENTS.CRAFTED, src, result)
    core.hooks.runAfter(HOOK_CRAFTED, {
        source = src, characterId = session.characterId, station = def.id, recipe = recipe.id, item = recipe.output.item,
        quantity = recipe.output.quantity, quality = value, tier = tier, signed = signed, instanceId = instanceId,
    })
    return true, result
end

--- Fin du geste (création ou réparation) : la durée annoncée doit être écoulée.
---@param src integer
---@param token any
---@return boolean ok
---@return table|string result
function crafting.finish(src, token)
    local session = sessions[src]
    if not session or session.token ~= token then return false, 'not_found' end
    if GetGameTimer() - session.startedAt < session.durationMs - interact.finishToleranceMs then return false, 'too_soon' end
    -- tombé pendant le geste : abandonné (rien n'est encore consommé), la station libérée aussitôt
    if bridge.IsDowned(src) then
        crafting.release(src)
        return false, 'downed'
    end
    if session.kind == 'repair' then return VavaCrafting.repair.finish(session) end
    return finishCraft(session)
end

--- Alimente le combustible d'une station depuis la besace. Bloque le thread courant.
---@param src integer
---@param stationId any
---@param quantity any
---@return boolean ok
---@return table|string result  { stock, capacity } ou code
function crafting.fuel(src, stationId, quantity)
    local characterId = bridge.GetCharacterId(src)
    if not characterId then return false, 'no_character' end
    if bridge.IsDowned(src) then return false, 'downed' end
    local def = catalog.station(stationId)
    if not def then return false, 'unknown_station' end
    local fuel = def.type.fuel
    if not fuel then return false, 'no_fuel_station' end
    if mathType(quantity) ~= 'integer' or quantity < 1 then return false, 'missing_items' end
    if not stations.near(src, def) then return false, 'too_far' end
    if not stations.canAccess(def, characterId) then return false, 'no_access' end
    local room = fuel.capacity - stations.fuel(def)
    if room <= 0 then return false, 'full' end
    local amount = quantity < room and quantity or room
    if bridge.Count(src, fuel.item) < amount then
        bridge.Notify(src, messages.missing, 'warning')
        return false, 'missing_items'
    end
    local ok = bridge.Remove(src, fuel.item, amount)
    if not ok then return false, 'missing_items' end
    stations.addFuel(def, amount)
    bridge.Notify(src, format(messages.fueled, def.label, stations.fuel(def), fuel.capacity), 'info')
    TriggerClientEvent(EVENTS.STATION, src, { id = def.id, fuel = stations.fuel(def), busy = stations.busyBy(def) ~= nil })
    return true, { stock = stations.fuel(def), capacity = fuel.capacity }
end

--- Joueur parti : session et station libérées.
---@param src integer
function crafting.forget(src)
    crafting.release(src)
    stations.release(src)
end

crafting.indexPiles = indexPiles
crafting.toolLabel = toolLabel
