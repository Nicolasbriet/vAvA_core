--[[
    vava_crafting/server/repair.lua
    Rôle : la réparation d'un objet signé, à une station qui sert la compétence de sa recette, par un artisan du niveau
           requis : une part des ingrédients de la recette est consommée, la solidité est rendue mais la solidité
           maximale baisse à chaque fois, l'histoire de l'objet garde la réparation et son auteur, l'objet n'est plus
           brisé ; le créateur n'est jamais touché. Petite XP, journal, hook `vava_crafting:repaired`.
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua, server/journal.lua, server/catalog.lua,
                  server/stations.lua, server/signature.lua, server/crafting.lua
]]

local type, pairs, ipairs = type, pairs, ipairs
local mathType, max, ceil, floor = math.type, math.max, math.ceil, math.floor
local format = string.format
local TriggerClientEvent = TriggerClientEvent
local time = os.time

local core = VavaCrafting.core
local bridge = VavaCrafting.bridge
local journal = VavaCrafting.journal
local catalog = VavaCrafting.catalog
local stations = VavaCrafting.stations
local signature = VavaCrafting.signature
local crafting = VavaCrafting.crafting
local cfg = VavaCrafting.config
local repairCfg, messages = cfg.repair, cfg.messages
local EVENTS = VavaCrafting.EVENTS

local HOOK_REPAIRED = 'vava_crafting:repaired'

local repair = {}
VavaCrafting.repair = repair

--- Coût d'une réparation : part des ingrédients de la recette, arrondie au-dessus.
---@param recipe vAvA.RecipeDefinition
---@return { item: string, quantity: integer }[]
function repair.cost(recipe)
    local list = {}
    for i, ingredient in ipairs(recipe.ingredients) do
        list[i] = { item = ingredient.item, quantity = max(1, ceil(ingredient.quantity * repairCfg.ingredientShare)) }
    end
    return list
end

---@param recipe vAvA.RecipeDefinition
---@return integer
local function requiredLevel(recipe)
    return floor(recipe.level * repairCfg.minLevelShare + 0.5)
end

--- Solidité d'un objet signé : courante et maximale (défauts de la recette).
---@param metadata table
---@param recipe vAvA.RecipeDefinition
---@return integer current, integer maximum
local function durabilityOf(metadata, recipe)
    local maximum = mathType(metadata.max_durability) == 'integer' and metadata.max_durability or recipe.durability
    local current = mathType(metadata.durability) == 'integer' and metadata.durability or maximum
    return current, maximum
end

--- Objets signés de la besace réparables à cette station : usés ou brisés, d'une recette servie ici.
---@param src integer
---@param def vAvA.StationDefinition
---@param index vAvA.PileIndex
---@return table[]
function repair.list(src, def, index)
    local list = {}
    for _, instance in ipairs(bridge.Items(src)) do
        local meta = type(instance.metadata) == 'table' and instance.metadata or nil
        local recipe = meta and meta.quality ~= nil and catalog.recipeFor(instance.item) or nil
        if recipe and def.type.skillSet[recipe.skill] then
            local current, maximum = durabilityOf(meta, recipe)
            if meta.broken == true or current < maximum then
                local cost, affordable = {}, true
                for i, part in ipairs(repair.cost(recipe)) do
                    local available = 0
                    for _, entry in pairs(index.byItem[part.item] or {}) do available = available + entry.count end
                    if available < part.quantity then affordable = false end
                    cost[i] = { item = part.item, label = catalog.itemLabel(part.item), quantity = part.quantity, available = available }
                end
                list[#list + 1] = {
                    instanceId = instance.id, item = instance.item, label = catalog.itemLabel(instance.item), name = meta.name,
                    durability = current, maxDurability = maximum, broken = meta.broken == true,
                    recipe = recipe.id, recipeLabel = recipe.label, levelOk = bridge.GetLevel(src, recipe.skill) >= requiredLevel(recipe),
                    affordable = affordable, cost = cost,
                }
            end
        end
    end
    return list
end

--- Commence une réparation. Bloque le thread courant.
---@param src integer
---@param stationId any
---@param instanceId any
---@return boolean ok
---@return table|string result  { token, durationMs, anim, label } ou code
function repair.begin(src, stationId, instanceId)
    local characterId = bridge.GetCharacterId(src)
    if not characterId then return false, 'no_character' end
    local def = catalog.station(stationId)
    if not def then return false, 'unknown_station' end
    if crafting.session(src) then return false, 'busy' end
    if not stations.near(src, def) then return false, 'too_far' end
    if not stations.canAccess(def, characterId) then
        bridge.Notify(src, messages.noAccess, 'warning')
        return false, 'no_access'
    end
    if stations.busyBy(def) then
        bridge.Notify(src, messages.busy, 'info')
        return false, 'busy'
    end
    if mathType(instanceId) ~= 'integer' then return false, 'not_found' end
    local instance
    for _, candidate in ipairs(bridge.Items(src)) do
        if candidate.id == instanceId then instance = candidate end
    end
    local meta = instance and type(instance.metadata) == 'table' and instance.metadata or nil
    if not meta or meta.quality == nil then return false, 'not_found' end
    local recipe = catalog.recipeFor(instance.item)
    if not recipe then return false, 'not_repairable' end
    if not def.type.skillSet[recipe.skill] then return false, 'wrong_station' end
    if bridge.GetLevel(src, recipe.skill) < requiredLevel(recipe) then return false, 'level' end
    local current, maximum = durabilityOf(meta, recipe)
    if meta.broken ~= true and current >= maximum then return false, 'intact' end
    local cost = repair.cost(recipe)
    for _, part in ipairs(cost) do
        if bridge.Count(src, part.item) < part.quantity then
            bridge.Notify(src, messages.missing, 'warning')
            return false, 'missing_items'
        end
    end
    local session = crafting.open(src, {
        kind = 'repair', characterId = characterId, station = def, recipe = recipe, choices = {}, heldId = nil,
        level = bridge.GetLevel(src, recipe.skill), durationMs = repairCfg.durationMs, instanceId = instanceId, cost = cost,
    })
    return true, { token = session.token, durationMs = session.durationMs, anim = def.type.anim, label = catalog.itemLabel(instance.item) }
end

--- Fin d'une réparation (appelée par crafting.finish). Bloque le thread courant.
---@param session vAvA.CraftSession
---@return boolean ok
---@return table|string result
function repair.finish(session)
    local src, def, recipe = session.source, session.station, session.recipe
    -- trop loin à la fin : la réparation est abandonnée (rien n'est encore consommé), la station libérée aussitôt
    if not stations.near(src, def) then
        crafting.release(src)
        return false, 'too_far'
    end
    local instance
    for _, candidate in ipairs(bridge.Items(src)) do
        if candidate.id == session.instanceId then instance = candidate end
    end
    local meta = instance and type(instance.metadata) == 'table' and instance.metadata or nil
    if not meta then
        crafting.release(src)
        return false, 'not_found'
    end
    local removals = {}
    for i, part in ipairs(session.cost) do removals[i] = { item = part.item, quantity = part.quantity } end
    local ok = bridge.Exchange(src, removals, {})
    if not ok then
        crafting.release(src)
        bridge.Notify(src, messages.missing, 'warning')
        return false, 'missing_items'
    end
    local _, maximum = durabilityOf(meta, recipe)
    local newMax = max(1, maximum - repairCfg.maxDurabilityLoss)
    local who = bridge.GetCharacterName(src) or '?'
    local patched = bridge.PatchMetadata(src, session.instanceId, {
        durability = newMax, max_durability = newMax,
        history = signature.appendHistory(meta, { at = time(), kind = 'repair', by = who }),
    }, { 'broken' })
    crafting.release(src)
    if not patched then return false, 'not_found' end
    bridge.AddXp(src, { skill = recipe.skill, source = recipe.id .. ':repair', difficulty = recipe.difficulty, amount = max(1, floor(recipe.xp * repairCfg.xpShare)) })
    local label = catalog.itemLabel(instance.item)
    bridge.Notify(src, format(messages.repaired, label, newMax, newMax), 'info')
    journal.write('repaired', { station = def.id, recipe = recipe.id, characterId = session.characterId, item = instance.item, quality = meta.quality, details = { instance = session.instanceId, maxDurability = newMax } })
    local result = { kind = 'repair', item = instance.item, label = label, quantity = 1, quality = meta.quality, tier = meta.tier, signed = true, nameable = false, instanceId = session.instanceId, nameWindowMs = 0 }
    TriggerClientEvent(EVENTS.CRAFTED, src, result)
    core.hooks.runAfter(HOOK_REPAIRED, { source = src, characterId = session.characterId, station = def.id, recipe = recipe.id, item = instance.item, instanceId = session.instanceId, maxDurability = newMax })
    return true, result
end
