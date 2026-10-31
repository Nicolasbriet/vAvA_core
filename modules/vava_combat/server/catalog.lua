--[[
    vava_combat/server/catalog.lua
    Rôle : le catalogue des armes, contrôlé au démarrage (shared/weapons.lua : la première erreur refuse le module) et
           exposé au reste du module : fiche d'une arme (catalog.weapon), liste ordonnée, arme réellement tenable
           (objet connu de l'inventaire avec un `held`). Déclare les objets à l'inventaire (ceux qu'il ne connaît pas
           encore, `onUse` posé sur chaque bouclier), les recettes à l'artisanat (signées, solidité tirée de la fiche)
           et aux compétences, et les redéclare au démarrage de vava_inventory, vava_crafting et vava_skills. Une
           recette refusée est une ligne d'avertissement, jamais un échec. L'Épée courte de vava_crafting est adoptée
           sans être redéclarée.
    Dépendances : shared/constants.lua, config.lua, shared/weapons.lua, server/core.lua, bridge/server.lua
]]

local type, pairs, ipairs, tostring = type, pairs, ipairs, tostring
local sort = table.sort

local bridge = VavaCombat.bridge
local weapons = VavaCombat.weapons
local cfg = VavaCombat.config
local SHIELD = VavaCombat.SHIELD_CATEGORY
local CATEGORIES = VavaCombat.CATEGORIES

local catalog = {}
VavaCombat.catalog = catalog

---@class vAvA.CombatWeapon
---@field item string
---@field label string
---@field category string
---@field family string
---@field kind string
---@field damage number
---@field reachBonus number
---@field durability integer
---@field block number
---@field provisional boolean

---@type table<string, vAvA.CombatWeapon>
local byItem = {}
---@type vAvA.CombatWeapon[]|nil  liste ordonnée, refaite quand un libellé change
local ordered = nil
-- arme → true si l'inventaire la connaît avec un `held` (bouclier : jamais)
local holdable = {}
-- objets, recettes de l'artisanat et des compétences que ce module a déclarés aux registres actuels
local oursItems, oursRecipes, oursSkillRecipes = {}, {}, {}
-- avertissements déjà écrits (une ligne par démarrage du module et par sujet)
local warned = {}

---@param key string
---@param fmt string
local function warnOnce(key, fmt, ...)
    if warned[key] then return end
    warned[key] = true
    VavaCombat.log.warn(fmt, ...)
end

--- Image d'un objet du module.
---@param name string
---@return string
local function imageOf(name)
    return 'nui://' .. VavaCombat.resource .. '/web/items/' .. name .. '.svg'
end

--- Fiches indexées depuis la config ; libellé de l'objet déclaré ici, sinon le nom (corrigé à la déclaration).
local function build()
    byItem, ordered = {}, nil
    for name, def in pairs(cfg.weapons) do
        local item = cfg.items[name]
        byItem[name] = {
            item = name, label = type(item) == 'table' and item.label or name, category = def.category,
            family = def.family, kind = def.kind, damage = def.damage, reachBonus = def.reachBonus,
            durability = def.durability, block = def.block, provisional = def.provisional,
        }
    end
end

-- Lecture -------------------------------------------------------------------------------------------------------------

--- Fiche d'une arme du catalogue (table du module : à ne pas modifier), ou nil.
---@param item any
---@return vAvA.CombatWeapon|nil
function catalog.weapon(item)
    if type(item) ~= 'string' then return nil end
    return byItem[item]
end

--- Copie d'une fiche, pour un export.
---@param item any
---@return table|nil
function catalog.view(item)
    local def = catalog.weapon(item)
    if not def then return nil end
    local out = {}
    for key, value in pairs(def) do out[key] = value end
    return out
end

--- Fiches ordonnées : catégorie (ordre de la config), puis libellé (accents et casse ignorés), puis nom.
---@return vAvA.CombatWeapon[]
function catalog.list()
    if not ordered then
        ordered = {}
        for _, def in pairs(byItem) do ordered[#ordered + 1] = def end
        sort(ordered, function(a, b)
            local oa, ob = cfg.categories[a.category].order, cfg.categories[b.category].order
            if oa ~= ob then return oa < ob end
            local ka, kb = weapons.sortKey(a.label), weapons.sortKey(b.label)
            if ka ~= kb then return ka < kb end
            return a.item < b.item
        end)
    end
    return ordered
end

--- Vrai si l'arme peut frapper : du catalogue, pas un bouclier, et connue de l'inventaire avec un `held`.
---@param item any
---@return boolean
function catalog.holdable(item)
    local def = catalog.weapon(item)
    return def ~= nil and def.category ~= SHIELD and holdable[item] == true
end

-- Déclarations --------------------------------------------------------------------------------------------------------

--- Relit chaque arme dans l'inventaire : tenable ou non, libellé de l'objet adopté.
local function refreshHoldable()
    holdable = {}
    for name, def in pairs(byItem) do
        if def.category ~= SHIELD then
            local item = bridge.ItemDefinition(name)
            if type(item) == 'table' and type(item.held) == 'table' then
                holdable[name] = true
                if not cfg.items[name] and type(item.label) == 'string' and item.label ~= def.label then
                    def.label, ordered = item.label, nil
                end
            elseif not cfg.items[name] then
                warnOnce('adopted:' .. name, "arme adoptée '%s' inconnue de l'inventaire ou sans held : ignorée par strike tant qu'il manque", name)
            end
        end
    end
end

--- Déclare les objets de la config que l'inventaire ne connaît pas encore. Sans inventaire prêt : rien (rappelé à son
--- annonce). Rend le nombre d'objets déclarés par ce module.
---@return integer
function catalog.declareItems()
    if not bridge.ItemsReady() then return 0 end
    local count = 0
    for name, def in pairs(cfg.items) do
        if bridge.HasItem(name) then
            if oursItems[name] then
                count = count + 1
            else
                warnOnce('item:' .. name, "objet '%s' déjà déclaré par une autre ressource : sa définition est gardée", name)
            end
        else
            local definition = {}
            for key, value in pairs(def) do definition[key] = value end
            definition.image = imageOf(name)
            if cfg.weapons[name].category == SHIELD then
                -- l'inventaire a déjà vérifié la possession, la besace et la limite `use` ; jamais consommé
                definition.onUse = function(source, instance) return VavaCombat.shields.onUse(source, instance) end
            end
            local ok, err = bridge.AddItem(name, definition)
            if ok then
                oursItems[name] = true
                count = count + 1
            else
                VavaCombat.log.warn("objet '%s' non déclaré : %s", name, tostring(err))
            end
        end
    end
    refreshHoldable()
    return count
end

--- Retour de vava_inventory : son registre est neuf, les objets sont redéclarés (les piles gardées à part reviennent).
---@return integer
function catalog.onInventoryReady()
    oursItems = {}
    return catalog.declareItems()
end

--- Vrai si le module facultatif est prêt dans une version suffisante ; sinon une ligne de console (une fois).
---@param name string
---@return boolean
local function optionalReady(name)
    local version = bridge.ModuleVersion(name)
    if version and weapons.versionAtLeast(version, cfg.optional[name]) then return true end
    warnOnce('optional:' .. name, '%s absent, en démarrage ou plus ancien que %s : armes sans recette tant qu\'il manque',
        name, cfg.optional[name])
    return false
end

--- Ajoute les recettes à l'artisanat (signées, solidité de la fiche). Rend le nombre de recettes de ce module au
--- registre actuel.
---@return integer
function catalog.declareRecipes()
    if not bridge.RecipesReady() or not optionalReady(bridge.CRAFTING) then return 0 end
    local count = 0
    for id, recipe in pairs(cfg.recipes) do
        if oursRecipes[id] then
            count = count + 1
        else
            local data = {}
            for key, value in pairs(recipe) do data[key] = value end
            data.signed = true
            data.durability = cfg.weapons[id].durability
            local ok, err = bridge.AddRecipe(id, data)
            if ok then
                oursRecipes[id] = true
                count = count + 1
            else
                VavaCombat.log.warn("recette '%s' non déclarée à l'artisanat : %s", id, tostring(err))
            end
        end
    end
    -- armes adoptées : leur recette (celle d'un autre module) doit donner la solidité de la fiche
    for name, def in pairs(cfg.weapons) do
        if not cfg.recipes[name] then
            local recipe = bridge.Recipe(name)
            if type(recipe) == 'table' and recipe.durability ~= nil and recipe.durability ~= def.durability then
                VavaCombat.log.warn("arme '%s' : solidité %s dans sa recette, %d dans sa fiche", name,
                    tostring(recipe.durability), def.durability)
            end
        end
    end
    return count
end

--- Déclare les recettes au registre des compétences (sans quoi l'artisanat les refuse : « recette inconnue »).
---@return integer
function catalog.declareSkillRecipes()
    if not bridge.SkillRecipesReady() or not optionalReady(bridge.SKILLS) then return 0 end
    local count = 0
    for id, recipe in pairs(cfg.recipes) do
        if oursSkillRecipes[id] then
            count = count + 1
        else
            local ok, err = bridge.AddSkillRecipe(id, {
                label = recipe.label, skill = recipe.skill, level = recipe.level, transmission = recipe.transmission == true,
            })
            if ok then
                oursSkillRecipes[id] = true
                count = count + 1
            else
                VavaCombat.log.warn("recette '%s' non déclarée aux compétences : %s", id, tostring(err))
            end
        end
    end
    return count
end

--- Retour de vava_crafting : registre neuf, recettes redéclarées ; adoption relue (l'Épée courte vient de lui).
---@return integer
function catalog.onCraftingReady()
    oursRecipes = {}
    warned['optional:' .. bridge.CRAFTING] = nil
    refreshHoldable()
    return catalog.declareRecipes()
end

--- Retour de vava_skills : registre neuf, recettes de compétence redéclarées.
---@return integer
function catalog.onSkillsReady()
    oursSkillRecipes = {}
    warned['optional:' .. bridge.SKILLS] = nil
    return catalog.declareSkillRecipes()
end

--- Contrôle le catalogue puis déclare objets, recettes et champ. Appelé pendant le setup.
---@return boolean ok
---@return string|integer err_or_items
---@return integer|nil recipes
function catalog.setup()
    local ok, err = weapons.check(cfg, CATEGORIES)
    if not ok then return false, 'config : ' .. tostring(err) end
    build()
    local kinds = bridge.HealthKinds()
    if not kinds then
        VavaCombat.log.warn('vava_health ne donne pas son vocabulaire : types de dégâts des armes non recoupés')
    else
        local known = {}
        for _, kind in ipairs(kinds) do known[kind] = true end
        for _, kind in ipairs(cfg.kinds) do
            if not known[kind] then VavaCombat.log.warn("type de dégâts '%s' inconnu de vava_health", kind) end
        end
    end
    ok, err = bridge.DefineShieldField()
    if not ok then return false, VavaCombat.SHIELD_FIELD .. ' : ' .. tostring(err) end
    local items = catalog.declareItems()
    local recipes = catalog.declareRecipes()
    catalog.declareSkillRecipes()
    return true, items, recipes
end
