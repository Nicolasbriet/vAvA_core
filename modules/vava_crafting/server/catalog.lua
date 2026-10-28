--[[
    vava_crafting/server/catalog.lua
    Rôle : la donnée de l'artisanat indexée depuis la config et exposée aux autres modules : types de stations
           (registre `vava_crafting:stations`), recettes (registre `vava_crafting:recipes`, données complètes ; chaque
           recette est aussi déclarée à `vava_skills:recipes`), stations placées, outils d'artisan, objets déclarés à
           l'inventaire (rappelé quand l'inventaire redémarre). Vérifie la cohérence au démarrage : une erreur de
           donnée refuse le module.
    Dépendances : shared/constants.lua, config.lua, server/core.lua, bridge/server.lua
]]

local type, pairs, ipairs, tostring = type, pairs, ipairs, tostring
local format = string.format
local sort = table.sort

local core = VavaCrafting.core
local bridge = VavaCrafting.bridge
local cfg = VavaCrafting.config
local REGISTRY = VavaCrafting.REGISTRY
local ID_PATTERN = VavaCrafting.ID_PATTERN
local MAX_TIER = VavaCrafting.MAX_TIER

local STATION_SCHEMA = {
    type = 'table',
    fields = {
        label = { type = 'string', min = 1, max = 48 },
        skills = { type = 'array', min = 1, max = 8, items = { type = 'string', min = 1, max = 32, pattern = ID_PATTERN } },
        fuel = { type = 'table', optional = true, fields = {
            item = { type = 'string', min = 1, max = 64 },
            perCraft = { type = 'integer', min = 1, max = 100 },
            capacity = { type = 'integer', min = 1, max = 10000 },
        } },
        anim = { type = 'string', min = 1, max = 32 },
        prop = { type = 'string', min = 1, max = 64 },
    },
}
local RECIPE_SCHEMA = {
    type = 'table',
    fields = {
        label = { type = 'string', min = 1, max = 64 },
        skill = { type = 'string', min = 1, max = 32, pattern = ID_PATTERN },
        level = { type = 'integer', min = 0, max = 100 },
        station = { type = 'string', min = 1, max = 32, pattern = ID_PATTERN },
        tool = { type = 'string', min = 1, max = 32, optional = true },
        durationMs = { type = 'integer', min = 0, max = 600000 },
        difficulty = { type = 'integer', min = 0, max = 100 },
        xp = { type = 'integer', min = 0, max = 500 },
        signed = { type = 'boolean', optional = true },
        signedIfQuality = { type = 'integer', min = 0, max = 100, optional = true },
        durability = { type = 'integer', min = 1, max = 10000, optional = true },
        transmission = { type = 'boolean', optional = true },
        fragments = { type = 'array', min = 1, max = 16, items = { type = 'string', min = 1, max = 32, pattern = ID_PATTERN }, optional = true },
        ingredients = { type = 'array', min = 1, max = 12, items = { type = 'table', fields = {
            item = { type = 'string', min = 1, max = 64 },
            quantity = { type = 'integer', min = 1, max = 1000 },
            minTier = { type = 'integer', min = 1, max = MAX_TIER, optional = true },
        } } },
        output = { type = 'table', fields = {
            item = { type = 'string', min = 1, max = 64 },
            quantity = { type = 'integer', min = 1, max = 1000 },
        } },
    },
}

local catalog = {}
VavaCrafting.catalog = catalog

---@class vAvA.StationType
---@field id string
---@field label string
---@field skills string[]
---@field skillSet table<string, boolean>
---@field fuel { item: string, perCraft: integer, capacity: integer }|nil
---@field anim string
---@field prop string

---@class vAvA.StationDefinition
---@field id string
---@field type vAvA.StationType
---@field label string
---@field x number
---@field y number
---@field z number
---@field quality integer
---@field owner { kind: string, id: integer }|nil

---@class vAvA.RecipeDefinition
---@field id string
---@field label string
---@field skill string
---@field level integer
---@field station string
---@field tool string|nil
---@field durationMs integer
---@field difficulty integer
---@field xp integer
---@field signed boolean
---@field signedIfQuality integer|nil
---@field durability integer
---@field transmission boolean
---@field fragments string[]|nil
---@field ingredients { item: string, quantity: integer, minTier: integer }[]
---@field output { item: string, quantity: integer }

local stationsById, stationsOrdered = {}, {}
-- caches reconstruits après un changement de registre
local typesById, recipesById, recipesByStation = nil, nil, nil

local function invalidate(payload)
    if payload.registry == REGISTRY.STATIONS then typesById = nil end
    if payload.registry == REGISTRY.RECIPES then recipesById, recipesByStation = nil, nil end
end

local function rebuildTypes()
    typesById = {}
    for id, data in pairs(core.registry.all(REGISTRY.STATIONS) or {}) do
        local set = {}
        for _, skill in ipairs(data.skills) do set[skill] = true end
        typesById[id] = { id = id, label = data.label, skills = data.skills, skillSet = set, fuel = data.fuel, anim = data.anim, prop = data.prop }
    end
end

local function rebuildRecipes()
    recipesById, recipesByStation = {}, {}
    for id, data in pairs(core.registry.all(REGISTRY.RECIPES) or {}) do
        local ingredients = {}
        for index, ingredient in ipairs(data.ingredients) do
            ingredients[index] = { item = ingredient.item, quantity = ingredient.quantity, minTier = ingredient.minTier or 1 }
        end
        local def = {
            id = id, label = data.label, skill = data.skill, level = data.level, station = data.station, tool = data.tool,
            durationMs = data.durationMs, difficulty = data.difficulty, xp = data.xp, signed = data.signed == true,
            signedIfQuality = data.signedIfQuality, durability = data.durability or 100, transmission = data.transmission == true,
            fragments = data.fragments, ingredients = ingredients, output = { item = data.output.item, quantity = data.output.quantity },
        }
        recipesById[id] = def
        local list = recipesByStation[def.station]
        if not list then
            list = {}
            recipesByStation[def.station] = list
        end
        list[#list + 1] = def
    end
    for _, list in pairs(recipesByStation) do
        sort(list, function(a, b)
            if a.level ~= b.level then return a.level < b.level end
            return a.id < b.id
        end)
    end
end

--- Déclare les objets de la config à l'inventaire (ceux qu'il ne connaît pas encore).
function catalog.declareItems()
    for name, def in pairs(cfg.items) do
        local definition = {}
        for key, value in pairs(def) do definition[key] = value end
        definition.image = definition.image or ('nui://' .. VavaCrafting.resource .. '/web/items/' .. name .. '.svg')
        bridge.DeclareItem(name, definition)
    end
end

--- Déclare les recettes de la config au registre des compétences (compétence, niveau, transmission, fragments).
---@return boolean ok
---@return string|nil err
local function declareSkillRecipes()
    for id, recipe in pairs(cfg.recipes) do
        local ok, err = bridge.DeclareSkillRecipe(id, {
            label = recipe.label, skill = recipe.skill, level = recipe.level, transmission = recipe.transmission == true, fragments = recipe.fragments,
        })
        if not ok then return false, format("recette '%s' auprès de vava_skills : %s", id, tostring(err)) end
    end
    return true
end

--- Indexe les stations placées et vérifie la config. Renvoie une erreur explicite à la première incohérence.
---@return boolean ok
---@return string|nil err
local function indexStations()
    for index, station in ipairs(cfg.stations) do
        if type(station.id) ~= 'string' or not station.id:find(ID_PATTERN) then return false, format('station #%d : identifiant invalide', index) end
        if stationsById[station.id] then return false, format("station '%s' en double", station.id) end
        local kind = catalog.stationType(station.type)
        if not kind then return false, format("station '%s' : type '%s' inconnu", station.id, tostring(station.type)) end
        local owner = nil
        if type(station.owner) == 'table' then
            if type(station.owner.kind) ~= 'string' or math.tointeger(station.owner.id) == nil then
                return false, format("station '%s' : owner = { kind, id } attendu", station.id)
            end
            owner = { kind = station.owner.kind, id = math.tointeger(station.owner.id) }
        end
        local def = {
            id = station.id, type = kind, label = station.label or kind.label, x = station.x, y = station.y, z = station.z,
            heading = station.heading or 0.0, quality = math.tointeger(station.quality) or 50, owner = owner,
            prop = type(station.prop) == 'string' and station.prop or nil,
        }
        stationsById[station.id] = def
        stationsOrdered[#stationsOrdered + 1] = def
    end
    return true
end

--- Stations telles que les clients les dessinent : { id, type, label, x, y, z, heading, prop }.
---@return table[]
function catalog.stationList()
    local list = {}
    for i, def in ipairs(stationsOrdered) do
        list[i] = { id = def.id, type = def.type.id, label = def.label, x = def.x, y = def.y, z = def.z, heading = def.heading or 0.0, prop = def.prop or def.type.prop }
    end
    return list
end

--- Définit les registres, y verse la config, déclare objets et recettes, indexe les stations. Appelé pendant le
--- setup du module.
---@return boolean ok
---@return string|nil err
function catalog.define()
    local ok, err = core.registry.define(REGISTRY.STATIONS, { schema = STATION_SCHEMA })
    if not ok then return false, err end
    ok, err = core.registry.define(REGISTRY.RECIPES, {
        schema = RECIPE_SCHEMA,
        validator = function(_, data)
            if not catalog.stationType(data.station) then return false, "type de station inconnu '" .. tostring(data.station) .. "'" end
            if data.tool and not catalog.toolKinds()[data.tool] then return false, "genre d'outil inconnu '" .. tostring(data.tool) .. "'" end
            return true
        end,
    })
    if not ok then return false, err end
    for id, kind in pairs(cfg.stationTypes) do
        if not cfg.anims[kind.anim] then return false, format("type de station '%s' : animation '%s' inconnue", id, tostring(kind.anim)) end
        ok, err = core.registry.add(REGISTRY.STATIONS, id, { label = kind.label, skills = kind.skills, fuel = kind.fuel, anim = kind.anim, prop = kind.prop })
        if not ok then return false, format("type de station '%s' : %s", id, tostring(err)) end
    end
    for id, recipe in pairs(cfg.recipes) do
        ok, err = core.registry.add(REGISTRY.RECIPES, id, recipe)
        if not ok then return false, format("recette '%s' : %s", id, tostring(err)) end
    end
    for _, hook in ipairs({ 'core:registry:added', 'core:registry:removed', 'core:registry:dropped' }) do
        local id, hookErr = core.hooks.after(hook, invalidate)
        if not id then return false, hookErr end
    end
    ok, err = indexStations()
    if not ok then return false, err end
    catalog.declareItems()
    ok, err = declareSkillRecipes()
    if not ok then return false, err end
    local id
    id, err = core.hooks.after('core:module:ready', function(payload)
        if payload.name == bridge.INVENTORY then catalog.declareItems() end
        if payload.name == bridge.SKILLS then declareSkillRecipes() end
    end)
    if not id then return false, err end
    for recipeId, recipe in pairs(catalog.recipes()) do
        for _, ingredient in ipairs(recipe.ingredients) do
            if not bridge.ItemDefinition(ingredient.item) then VavaCrafting.log.warn("recette '%s' : ingrédient '%s' inconnu de l'inventaire", recipeId, ingredient.item) end
        end
        local output = bridge.ItemDefinition(recipe.output.item)
        if not output then
            VavaCrafting.log.warn("recette '%s' : produit '%s' inconnu de l'inventaire", recipeId, recipe.output.item)
        elseif recipe.signed and output.stack ~= 1 then
            return false, format("recette '%s' : un objet signé doit être non empilable (stack = 1), '%s' a stack = %d", recipeId, recipe.output.item, output.stack)
        end
    end
    return true
end

--- Place une station depuis un autre module (type déjà déclaré au registre). Depuis 1.1.0.
---@param spec table  { id, type, label?, x, y, z, quality?, owner? }
---@return vAvA.StationDefinition|nil
---@return string|nil err
function catalog.addStation(spec)
    if type(spec) ~= 'table' or type(spec.id) ~= 'string' or not spec.id:find(ID_PATTERN) then return nil, 'invalid_id' end
    if stationsById[spec.id] then return nil, 'duplicate' end
    local kind = catalog.stationType(spec.type)
    if not kind then return nil, 'unknown_station_type' end
    if type(spec.x) ~= 'number' or type(spec.y) ~= 'number' or type(spec.z) ~= 'number' then return nil, 'invalid_position' end
    local owner = nil
    if type(spec.owner) == 'table' then
        if type(spec.owner.kind) ~= 'string' or math.tointeger(spec.owner.id) == nil then return nil, 'invalid_owner' end
        owner = { kind = spec.owner.kind, id = math.tointeger(spec.owner.id) }
    end
    local def = {
        id = spec.id, type = kind, label = spec.label or kind.label, x = spec.x, y = spec.y, z = spec.z,
        heading = type(spec.heading) == 'number' and spec.heading or 0.0,
        quality = math.tointeger(spec.quality) or 50, owner = owner, prop = type(spec.prop) == 'string' and spec.prop or nil,
    }
    stationsById[spec.id] = def
    stationsOrdered[#stationsOrdered + 1] = def
    return def
end

---@param id any
---@return vAvA.StationType|nil
function catalog.stationType(id)
    if type(id) ~= 'string' then return nil end
    if not typesById then rebuildTypes() end
    return typesById[id]
end

---@param id any
---@return vAvA.StationDefinition|nil
function catalog.station(id)
    return type(id) == 'string' and stationsById[id] or nil
end

--- Stations placées, dans l'ordre de la config.
---@return vAvA.StationDefinition[]
function catalog.stations()
    return stationsOrdered
end

---@param id any
---@return vAvA.RecipeDefinition|nil
function catalog.recipe(id)
    if type(id) ~= 'string' then return nil end
    if not recipesById then rebuildRecipes() end
    return recipesById[id]
end

---@return table<string, vAvA.RecipeDefinition>
function catalog.recipes()
    if not recipesById then rebuildRecipes() end
    return recipesById
end

--- Recettes d'un type de station, par niveau croissant.
---@param stationType string
---@return vAvA.RecipeDefinition[]
function catalog.recipesOf(stationType)
    if not recipesByStation then rebuildRecipes() end
    return recipesByStation[stationType] or {}
end

--- Première recette produisant un objet (pour la réparation), ou nil.
---@param item string
---@return vAvA.RecipeDefinition|nil
function catalog.recipeFor(item)
    local best
    for _, recipe in pairs(catalog.recipes()) do
        if recipe.output.item == item and (not best or recipe.id < best.id) then best = recipe end
    end
    return best
end

--- Genres d'outils d'artisan connus : { [kind] = true }.
---@return table<string, boolean>
function catalog.toolKinds()
    local kinds = {}
    for _, tool in pairs(cfg.tools) do kinds[tool.kind] = true end
    return kinds
end

--- Genre d'un outil d'artisan tenu, ou nil.
---@param item any
---@return string|nil
function catalog.toolKind(item)
    local tool = type(item) == 'string' and cfg.tools[item]
    return tool and tool.kind or nil
end

--- Libellé d'un objet : celui de l'inventaire, sinon de la config, sinon son nom.
---@param item string
---@return string
function catalog.itemLabel(item)
    local def = bridge.ItemDefinition(item)
    if def and def.label then return def.label end
    local own = cfg.items[item]
    return own and own.label or item
end
