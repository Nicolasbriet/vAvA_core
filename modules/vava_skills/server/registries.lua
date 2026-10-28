--[[
    vava_skills/server/registries.lua
    Rôle : registres du core définis par ce module : `vava_skills:skills` (compétences, remplies par la config et
           extensibles par d'autres modules) et `vava_skills:recipes` (recettes, déclarées par vava_crafting et tout
           module qui enseigne un savoir : compétence, niveau, transmission, fragments). Caches locaux tenus à jour par
           les hooks du registre : une décision de jeu ne paie pas un appel inter-ressources par lecture.
    Dépendances : shared/constants.lua, config.lua, server/core.lua
]]

local type, pairs, ipairs = type, pairs, ipairs
local sort = table.sort

local core = VavaSkills.core
local cfg = VavaSkills.config
local REGISTRY = VavaSkills.REGISTRY

local SKILL_SCHEMA = {
    type = 'table',
    fields = {
        label = { type = 'string', min = 1, max = 48 },
        category = { type = 'string', min = 1, max = 32, pattern = VavaSkills.SKILL_PATTERN },
        order = { type = 'integer', min = 0, max = 1000, optional = true },
        mentoredOnly = { type = 'boolean', optional = true },
    },
}
local RECIPE_SCHEMA = {
    type = 'table',
    fields = {
        label = { type = 'string', min = 1, max = 64 },
        skill = { type = 'string', min = 1, max = 32, pattern = VavaSkills.SKILL_PATTERN },
        level = { type = 'integer', min = 0, max = VavaSkills.MAX_LEVEL },
        transmission = { type = 'boolean' },
        fragments = { type = 'array', min = 1, max = 16, items = { type = 'string', min = 1, max = 32, pattern = VavaSkills.RECIPE_PATTERN }, optional = true },
    },
}

local registries = {}
VavaSkills.registries = registries

---@class vAvA.SkillDefinition
---@field id string
---@field label string
---@field category string
---@field order integer
---@field mentoredOnly boolean

---@class vAvA.RecipeDefinition
---@field id string
---@field label string
---@field skill string
---@field level integer
---@field transmission boolean
---@field fragments string[]|nil

-- caches, reconstruits à la demande après un changement du registre
local skillsById, skillsOrdered = nil, nil
local recipesById = nil
local categoriesById = {}
for index, category in ipairs(cfg.categories) do categoriesById[category.id] = { id = category.id, label = category.label, order = index } end

local function invalidate(payload)
    if payload.registry == REGISTRY.SKILLS then
        skillsById, skillsOrdered = nil, nil
    elseif payload.registry == REGISTRY.RECIPES then
        recipesById = nil
    end
end

local function rebuildSkills()
    skillsById, skillsOrdered = {}, {}
    local all = core.registry.all(REGISTRY.SKILLS) or {}
    for id, data in pairs(all) do
        local def = { id = id, label = data.label, category = data.category, order = data.order or 1000, mentoredOnly = data.mentoredOnly == true }
        skillsById[id] = def
        skillsOrdered[#skillsOrdered + 1] = def
    end
    sort(skillsOrdered, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.id < b.id
    end)
end

local function rebuildRecipes()
    recipesById = {}
    local all = core.registry.all(REGISTRY.RECIPES) or {}
    for id, data in pairs(all) do
        recipesById[id] = {
            id = id, label = data.label, skill = data.skill, level = data.level,
            transmission = data.transmission == true, fragments = data.fragments,
        }
    end
end

--- Définit les deux registres, y verse les compétences de la config, branche l'invalidation des caches.
--- Appelé pendant le setup du module.
---@return boolean ok
---@return string|nil err
function registries.define()
    local ok, err = core.registry.define(REGISTRY.SKILLS, {
        schema = SKILL_SCHEMA,
        validator = function(_, data)
            if not categoriesById[data.category] then return false, "catégorie inconnue '" .. tostring(data.category) .. "'" end
            return true
        end,
    })
    if not ok then return false, err end
    ok, err = core.registry.define(REGISTRY.RECIPES, {
        schema = RECIPE_SCHEMA,
        validator = function(_, data)
            if not registries.skill(data.skill) then return false, "compétence inconnue '" .. tostring(data.skill) .. "'" end
            return true
        end,
    })
    if not ok then return false, err end
    for index, skill in ipairs(cfg.skills) do
        ok, err = core.registry.add(REGISTRY.SKILLS, skill.id, {
            label = skill.label, category = skill.category, order = index, mentoredOnly = skill.mentoredOnly == true,
        })
        if not ok then return false, "compétence '" .. tostring(skill.id) .. "' : " .. tostring(err) end
    end
    local id
    id, err = core.hooks.after('core:registry:added', invalidate)
    if not id then return false, err end
    id, err = core.hooks.after('core:registry:removed', invalidate)
    if not id then return false, err end
    id, err = core.hooks.after('core:registry:dropped', invalidate)
    if not id then return false, err end
    return true
end

---@param id any
---@return vAvA.SkillDefinition|nil
function registries.skill(id)
    if type(id) ~= 'string' then return nil end
    if not skillsById then rebuildSkills() end
    return skillsById[id]
end

--- Compétences dans l'ordre d'affichage.
---@return vAvA.SkillDefinition[]
function registries.skills()
    if not skillsOrdered then rebuildSkills() end
    return skillsOrdered
end

---@param id any
---@return vAvA.RecipeDefinition|nil
function registries.recipe(id)
    if type(id) ~= 'string' then return nil end
    if not recipesById then rebuildRecipes() end
    return recipesById[id]
end

---@return table<string, vAvA.RecipeDefinition>
function registries.recipes()
    if not recipesById then rebuildRecipes() end
    return recipesById
end

--- Catégories dans l'ordre d'affichage : { { id, label } }.
---@return table[]
function registries.categories()
    local list = {}
    for index, category in ipairs(cfg.categories) do list[index] = { id = category.id, label = category.label } end
    return list
end

--- Libellé d'une compétence (son identifiant si elle est inconnue).
---@param id string
---@return string
function registries.skillLabel(id)
    local def = registries.skill(id)
    return def and def.label or tostring(id)
end
