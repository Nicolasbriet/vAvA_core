--[[
    vava_crafting/server/catalog.lua
    Rôle : la donnée de l'artisanat indexée depuis la config et exposée aux autres modules : types de stations
           (registre `vava_crafting:stations`), recettes (registre `vava_crafting:recipes`, données complètes ; chaque
           recette est aussi déclarée à `vava_skills:recipes`), stations placées, outils d'artisan, objets déclarés à
           l'inventaire (rappelé quand l'inventaire redémarre). Vérifie la cohérence au démarrage : une erreur de
           donnée refuse le module. Recettes absentes de `vava_skills:recipes` (T-147) : auteur de chaque recette
           suivi, cache des recettes des compétences, une ligne en console par recette absente (après le démarrage,
           l'ajout d'une recette par un autre module, le retour de vava_skills), lu par le menu pour la verrouiller.
    Dépendances : shared/constants.lua, config.lua, shared/stationzone.lua (bornes), server/core.lua, bridge/server.lua
]]

local type, pairs, ipairs, tostring = type, pairs, ipairs, tostring
local format = string.format
local sort, remove = table.sort, table.remove
local floor, max, min = math.floor, math.max, math.min
local SetTimeout, GetGameTimer = SetTimeout, GetGameTimer

local core = VavaCrafting.core
local bridge = VavaCrafting.bridge
local cfg = VavaCrafting.config
local REGISTRY = VavaCrafting.REGISTRY
local ID_PATTERN = VavaCrafting.ID_PATTERN
local STATION_ID_MAX = VavaCrafting.STATION_ID_MAX
-- nom et modèle d'une station placée par un module : bornes de ce que lit le client
local LABEL_MAX, PROP_MAX = VavaCrafting.stationzone.LABEL_MAX, VavaCrafting.stationzone.PROP_MAX
local MAX_TIER = VavaCrafting.MAX_TIER
-- réserve de combustible d'un type : borne relue par le client dans le dessin d'une station (T-144)
local FUEL_CAPACITY_MAX = VavaCrafting.FUEL_CAPACITY_MAX

local STATION_SCHEMA = {
    type = 'table',
    fields = {
        label = { type = 'string', min = 1, max = 48 },
        skills = { type = 'array', min = 1, max = 8, items = { type = 'string', min = 1, max = 32, pattern = ID_PATTERN } },
        fuel = { type = 'table', optional = true, fields = {
            item = { type = 'string', min = 1, max = 64 },
            perCraft = { type = 'integer', min = 1, max = 100 },
            capacity = { type = 'integer', min = 1, max = FUEL_CAPACITY_MAX },
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

--- Identifiant de station : motif du module, au plus STATION_ID_MAX octets (borne du schéma des RPC, et nom de sa zone
--- du core).
---@param id any
---@return boolean
local function validId(id)
    return type(id) == 'string' and #id <= STATION_ID_MAX and id:find(ID_PATTERN) ~= nil
end

---@param value any
---@return boolean
local function finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local stationsById, stationsOrdered = {}, {}
-- caches reconstruits après un changement de registre
local typesById, recipesById, recipesByStation = nil, nil, nil

-- Recettes auprès des compétences (T-147) : ressource qui a ajouté chaque recette (hook core:registry:added ; ce module
-- pour celles de la config) ; identifiants de `vava_skills:recipes` ({ [id] = true } ; false : registre absent ; nil :
-- à relire) ; recettes déjà signalées en console (une ligne chacune, oubliées au retour de vava_skills) ; lecture du
-- registre en échec déjà signalée ; tour du contrôle différé (seul le dernier demandé passe) et instant de la première
-- demande encore en attente (plafond du report).
local recipeOwners = {}
local skillIds = nil
local reported, registryReported, readFailReported = {}, false, false
local checkRound, pendingSince = 0, nil

local function invalidate(payload)
    if payload.registry == REGISTRY.STATIONS then typesById = nil end
    if payload.registry == REGISTRY.RECIPES then recipesById, recipesByStation = nil, nil end
    if payload.registry == bridge.SKILL_RECIPES then skillIds = nil end
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
        if not validId(station.id) then return false, format('station #%d : identifiant invalide', index) end
        if not finite(station.x) or not finite(station.y) or not finite(station.z) then
            return false, format("station '%s' : position x, y, z attendue", station.id)
        end
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

--- Définit les registres, y verse la config, déclare objets et recettes, indexe les stations. Appelé pendant le
--- setup du module.
---@return boolean ok
---@return string|nil err
function catalog.define()
    -- l'animation d'un type, d'ici ou d'un autre module (le composteur), est une clé de `anims` (config_client.lua) :
    -- sinon le geste se jouerait sans animation, en silence (relecture sécurité S-2 de T-144)
    local ok, err = core.registry.define(REGISTRY.STATIONS, {
        schema = STATION_SCHEMA,
        validator = function(_, data)
            if not cfg.anims[data.anim] then return false, "animation '" .. tostring(data.anim) .. "' inconnue" end
            return true
        end,
    })
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
        ok, err = core.registry.add(REGISTRY.STATIONS, id, { label = kind.label, skills = kind.skills, fuel = kind.fuel, anim = kind.anim, prop = kind.prop })
        if not ok then return false, format("type de station '%s' : %s", id, tostring(err)) end
    end
    for id, recipe in pairs(cfg.recipes) do
        ok, err = core.registry.add(REGISTRY.RECIPES, id, recipe)
        if not ok then return false, format("recette '%s' : %s", id, tostring(err)) end
        recipeOwners[id] = VavaCrafting.resource
    end
    for _, hook in ipairs({ 'core:registry:added', 'core:registry:removed', 'core:registry:dropped' }) do
        local id, hookErr = core.hooks.after(hook, invalidate)
        if not id then return false, hookErr end
    end
    -- T-147 : auteur des recettes ajoutées par d'autres modules, et contrôle différé quand une recette arrive ici ou
    -- quitte les compétences (le module a pu déclarer les deux registres l'un après l'autre)
    for _, def in ipairs({
        { 'core:registry:added', function(payload)
            if payload.registry == REGISTRY.RECIPES and type(payload.key) == 'string' then
                recipeOwners[payload.key] = payload.owner
                if payload.owner ~= VavaCrafting.resource then catalog.scheduleSkillCheck() end
            elseif payload.registry == bridge.SKILL_RECIPES and type(payload.key) == 'string' and reported[payload.key] then
                -- recette signalée, déclarée aux compétences après le contrôle : la console le dira (S-1, R-2 de T-147)
                catalog.scheduleSkillCheck()
            end
        end },
        { 'core:registry:removed', function(payload)
            if payload.registry == REGISTRY.RECIPES and type(payload.key) == 'string' then
                recipeOwners[payload.key], reported[payload.key] = nil, nil
            elseif payload.registry == bridge.SKILL_RECIPES then
                catalog.scheduleSkillCheck()
            end
        end },
    }) do
        local id, hookErr = core.hooks.after(def[1], def[2])
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
        if payload.name == bridge.SKILLS then
            declareSkillRecipes()
            -- retour de vava_skills : chaque recette encore absente est signalée de nouveau, une fois que les autres
            -- modules ont redéclaré les leurs
            reported, registryReported = {}, false
            catalog.scheduleSkillCheck()
        end
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
    -- les autres modules ajoutent leurs recettes à l'annonce de ce module : contrôle différé
    catalog.scheduleSkillCheck()
    return true
end

-- Recettes auprès des compétences (T-147) -------------------------------------------------------------------------

--- Identifiants de `vava_skills:recipes` (cache) ; false : registre absent ; nil : lecture en échec, rien n'est gardé
--- (relu à l'appel suivant), toutes les recettes sont tenues pour absentes cette fois (côté sûr).
---@return table<string, boolean>|false|nil
local function skillRecipeIds()
    if skillIds == nil then skillIds = bridge.SkillRecipeIds() end
    return skillIds
end

--- Vrai si la recette est déclarée au registre des compétences (`vava_skills:recipes`). Sinon vava_skills ne la connaît
--- pas (`knowsRecipe` faux, la station la refuse : `not_known`) et le menu la montre verrouillée. Lecture du cache, tenu
--- à jour par les hooks du registre.
---@param id string
---@return boolean
function catalog.declaredToSkills(id)
    local ids = skillRecipeIds()
    return type(ids) == 'table' and ids[id] == true
end

--- Recettes de l'artisanat absentes du registre des compétences, par identifiant : { { id, owner } } (`owner` : la
--- ressource qui l'a déclarée à l'artisanat, '?' si elle n'est pas connue).
---@return { id: string, owner: string }[]
function catalog.missingFromSkills()
    local list = {}
    for id in pairs(catalog.recipes()) do
        if not catalog.declaredToSkills(id) then list[#list + 1] = { id = id, owner = recipeOwners[id] or '?' } end
    end
    sort(list, function(a, b) return a.id < b.id end)
    return list
end

--- Signale en console les recettes de l'artisanat absentes du registre des compétences, une ligne par recette et une
--- seule fois (de nouveau après le retour de vava_skills, ou si elle redevient absente) ; une recette signalée puis
--- déclarée : une ligne qui le dit ; registre absent : une ligne ; lecture du registre en échec : une ligne, rien de
--- signalé. Rend la liste des recettes absentes ({ { id, owner } }).
---@return { id: string, owner: string }[]
function catalog.checkSkillRecipes()
    local ids = skillRecipeIds()
    if ids == nil then
        if not readFailReported then
            readFailReported = true
            VavaCrafting.log.warn('lecture du registre vava_skills:recipes en échec : contrôle des recettes remis au prochain changement')
        end
        return {}
    end
    readFailReported = false
    local missing = catalog.missingFromSkills()
    if ids == false then
        if not registryReported and #missing > 0 then
            registryReported = true
            VavaCrafting.log.warn("registre vava_skills:recipes absent : %d recette(s) de l'artisanat verrouillée(s) au menu, refusée(s) à la station", #missing)
        end
        return missing
    end
    registryReported = false
    local absent = {}
    for _, entry in ipairs(missing) do
        absent[entry.id] = true
        if not reported[entry.id] then
            reported[entry.id] = true
            VavaCrafting.log.warn("recette '%s' (déclarée par %s) absente de vava_skills:recipes : inconnue des compétences, "
                .. "verrouillée au menu et refusée à la station ; à déclarer aussi à vava_skills:recipes", entry.id, entry.owner)
        end
    end
    for id in pairs(reported) do
        if not absent[id] then
            reported[id] = nil
            -- signalée, puis déclarée aux compétences (plus de délai que le contrôle) : la console le dit (S-1 de T-147)
            VavaCrafting.log.info("recette '%s' désormais déclarée à vava_skills:recipes : déverrouillée", id)
        end
    end
    return missing
end

--- Délai du contrôle : `skillsCheck.delayMs`, borné de 1 s à 10 min (5 s si la valeur n'est pas un nombre).
---@return integer
local function checkDelay()
    local delay = tonumber(type(cfg.skillsCheck) == 'table' and cfg.skillsCheck.delayMs or nil) or 5000
    if delay ~= delay then delay = 5000 end
    return floor(min(max(delay, 1000), 600000))
end

--- Demande le contrôle des recettes auprès des compétences dans `skillsCheck.delayMs` : le temps que chaque module ait
--- déclaré ses recettes aux deux registres. Seule la dernière demande passe ; des demandes rapprochées ne le repoussent
--- pas au-delà de 4 × le délai depuis la première encore en attente.
function catalog.scheduleSkillCheck()
    local delay, now = checkDelay(), GetGameTimer()
    if pendingSince == nil then pendingSince = now end
    local wait = max(0, min(delay, pendingSince + 4 * delay - now))
    checkRound = checkRound + 1
    local round = checkRound
    SetTimeout(wait, function()
        if round ~= checkRound then return end
        pendingSince = nil
        catalog.checkSkillRecipes()
    end)
end

--- Place une station depuis un autre module (type déjà déclaré au registre). Depuis 1.1.0 ; depuis 1.5.0, identifiant
--- de 32 octets au plus, position finie, nom et modèle bornés (ce que les clients proches reçoivent pour la dessiner).
---@param spec table  { id, type, label?, x, y, z, heading?, quality?, owner?, prop? }
---@return vAvA.StationDefinition|nil
---@return string|nil err
function catalog.addStation(spec)
    if type(spec) ~= 'table' or not validId(spec.id) then return nil, 'invalid_id' end
    if stationsById[spec.id] then return nil, 'duplicate' end
    local kind = catalog.stationType(spec.type)
    if not kind then return nil, 'unknown_station_type' end
    if not finite(spec.x) or not finite(spec.y) or not finite(spec.z) then return nil, 'invalid_position' end
    if spec.label ~= nil and (type(spec.label) ~= 'string' or #spec.label < 1 or #spec.label > LABEL_MAX) then return nil, 'invalid_label' end
    if spec.prop ~= nil and (type(spec.prop) ~= 'string' or #spec.prop < 1 or #spec.prop > PROP_MAX) then return nil, 'invalid_prop' end
    local owner = nil
    if type(spec.owner) == 'table' then
        if type(spec.owner.kind) ~= 'string' or math.tointeger(spec.owner.id) == nil then return nil, 'invalid_owner' end
        owner = { kind = spec.owner.kind, id = math.tointeger(spec.owner.id) }
    end
    local def = {
        id = spec.id, type = kind, label = spec.label or kind.label, x = spec.x, y = spec.y, z = spec.z,
        heading = finite(spec.heading) and spec.heading or 0.0,
        quality = math.tointeger(spec.quality) or 50, owner = owner, prop = spec.prop,
    }
    stationsById[spec.id] = def
    stationsOrdered[#stationsOrdered + 1] = def
    return def
end

--- Retire une station placée par `addStation` dont la zone a été refusée par le core (aucun joueur ne la verrait).
---@param id string
function catalog.removeStation(id)
    if not stationsById[id] then return end
    stationsById[id] = nil
    for i = #stationsOrdered, 1, -1 do
        if stationsOrdered[i].id == id then remove(stationsOrdered, i) end
    end
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
