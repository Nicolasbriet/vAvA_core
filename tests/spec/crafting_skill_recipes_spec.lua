local helper = require('tests.helper')

-- Recette de l'artisanat inconnue des compétences (T-147) : un module qui ajoute une recette à `vava_crafting:recipes`
-- sans la déclarer à `vava_skills:recipes` la voyait montrée au menu puis refusée au clic (`not_known`), sans rien en
-- console. Désormais : une ligne en console par recette absente (nom et module), après le démarrage, l'ajout d'une
-- recette par un autre module ou le retour de vava_skills (délai `skillsCheck.delayMs`), et la recette verrouillée au
-- menu (`unregistered`, `known = false`) ; le serveur la refuse toujours au début (`not_known`).
-- Montage réel : registres et hooks du core (server/core/registry.lua, shared/core/hooks.lua), registres, fiches et
-- savoirs de vava_skills (registries.lua, sheets.lua, lessons.lua, export `knowsRecipe` simulé par lessons.knows),
-- bridge, catalogue et fabrication de vava_crafting ; stations, poinçon et réparation réduits à des doublures, inventaire
-- arrêté (besace vide). Règles : README de vava_crafting (Recettes) et de vava_skills (Savoirs).

local SKILLS, CRAFTING, INVENTORY, FORGERONS = 'vava_skills', 'vava_crafting', 'vava_inventory', 'vava_forgerons'
local CRAFT_RECIPES, SKILL_RECIPES = 'vava_crafting:recipes', 'vava_skills:recipes'
local ANY = { schema = { type = 'any' } }
local PLAYER = 3

-- recette d'un module tiers : libre, Forge niveau 0, à la forge, sans outil
local CLOUS = {
    label = 'Clous de fer', skill = 'forge', level = 0, station = 'forge', durationMs = 4000, difficulty = 0, xp = 4,
    ingredients = { { item = 'lingot_fer', quantity = 1 } }, output = { item = 'clou_fer', quantity = 10 },
}
local CLOUS_SKILL = { label = 'Clous de fer', skill = 'forge', level = 0, transmission = false }

local function newLogs()
    local logs = { error = {}, warn = {}, info = {}, debug = {} }
    local log = {}
    for level in pairs(logs) do
        log[level] = function(fmt, ...) logs[level][#logs[level] + 1] = fmt:format(...) end
    end
    return logs, log
end

describe('vava_crafting : recette inconnue des compétences', function()
    local registry, hooks, logs, started, realPrint, sheet

    local function coreFor(owner, log)
        return {
            log = log,
            registry = {
                define = function(name, options) return registry.define(owner, name, options) end,
                add = function(name, key, data) return registry.add(owner, name, key, data) end,
                remove = function(name, key) return registry.remove(owner, name, key) end,
                get = function(name, key) return registry.get(name, key) end,
                has = function(name, key) return registry.has(name, key) end,
                exists = function(name) return registry.exists(name) end,
                all = function(name) return registry.all(name) end,
            },
            hooks = {
                after = function(name, fn) return hooks.subscribe(owner, 'after', name, fn) end,
                runBefore = function(name, payload) return hooks.runBefore(name, payload) end,
                runAfter = function(name, payload) return hooks.runAfter(name, payload) end,
            },
        }
    end

    local function startSkills()
        VavaSkills = nil
        helper.loadAll({ 'modules/vava_skills/shared/constants.lua', 'modules/vava_skills/config.lua', 'modules/vava_skills/shared/progression.lua' })
        local _, log = newLogs()
        VavaSkills.core, VavaSkills.log, VavaSkills.resource = coreFor(SKILLS, log), log, SKILLS
        VavaSkills.bridge, VavaSkills.journal = {}, {}
        helper.loadAll({ 'modules/vava_skills/server/registries.lua', 'modules/vava_skills/server/sheets.lua', 'modules/vava_skills/server/lessons.lua' })
        assert.is_true(VavaSkills.registries.define())
    end

    --- Démarre vava_crafting jusqu'au catalogue (premier pas de son setup) et charge la fabrication.
    local function startCrafting()
        VavaCrafting = nil
        helper.loadAll({
            'modules/vava_crafting/shared/constants.lua',
            'modules/vava_crafting/config.lua',
            'modules/vava_crafting/shared/stationzone.lua',
            'modules/vava_crafting/shared/quality.lua',
        })
        local log
        logs, log = newLogs()
        local core = coreFor(CRAFTING, log)
        core.players = { get = function(src) return src == PLAYER and { state = 'active', accountId = 1 } or nil end }
        core.characters = { getActive = function(src) return src == PLAYER and { id = 7, firstName = 'Ada', lastName = 'Forgeronne' } or nil end }
        VavaCrafting.core, VavaCrafting.log, VavaCrafting.resource = core, log, CRAFTING
        helper.loadAll({ 'modules/vava_crafting/bridge/server.lua', 'modules/vava_crafting/server/catalog.lua' })
        VavaCrafting.journal = { write = function() end }
        VavaCrafting.stations = {
            near = function() return true end,
            canAccess = function() return true end,
            busyBy = function() return nil end,
            hasFuel = function() return true end,
            view = function(def) return { id = def.id } end,
        }
        VavaCrafting.signature = { view = function() return {} end }
        VavaCrafting.repair = { list = function() return {} end }
        helper.load('modules/vava_crafting/server/crafting.lua')
        return VavaCrafting.catalog.define()
    end

    local function stop(owner)
        registry.purgeOwner(owner)
        hooks.purgeOwner(owner)
    end

    local function ready(name)
        hooks.runAfter('core:module:ready', { name = name })
    end

    --- Échéance des contrôles différés : chaque minuterie posée depuis le dernier passage (les anciennes ne font rien).
    local function elapse()
        local timers = helper.timers
        helper.timers = {}
        for _, timer in ipairs(timers) do
            assert.equal(VavaCrafting.config.skillsCheck.delayMs, timer.ms)
            timer.fn()
        end
    end

    --- Lignes de la console qui parlent des recettes des compétences.
    local function skillWarnings()
        local list = {}
        for _, line in ipairs(logs.warn) do
            if line:find('vava_skills:recipes', 1, true) then list[#list + 1] = line end
        end
        return list
    end

    --- Vue de la recette au menu de la forge du bourg, ou nil.
    local function menuEntry(id)
        local ok, menu = VavaCrafting.crafting.menu(PLAYER, 'forge_bourg')
        assert.is_true(ok, menu)
        for _, recipe in ipairs(menu.recipes) do
            if recipe.id == id then return recipe end
        end
        return nil
    end

    before_each(function()
        helper.reset()
        realPrint = _G.print
        _G.print = function() end
        helper.loadAll({
            'shared/init.lua',
            'config/shared.lua',
            'shared/lib/table.lua',
            'shared/lib/string.lua',
            'shared/lib/schema.lua',
            'shared/core/logger.lua',
            'shared/core/hooks.lua',
            'server/core/registry.lua',
        })
        registry, hooks = vAvA.registry, vAvA.hooks
        started = { [SKILLS] = true }
        sheet = { skills = { forge = { level = 22 } }, recipes = {} }
        _G.GetResourceState = function(name) return started[name] and 'started' or 'missing' end
        _G.TriggerClientEvent = function() end
        _G.exports = setmetatable({}, {
            __index = function(_, name)
                if name ~= SKILLS then return nil end
                return {
                    knowsRecipe = function(_, src, recipe) return src == PLAYER and VavaSkills.lessons.knows(sheet, recipe) end,
                    getLevel = function(_, src, skill) return src == PLAYER and VavaSkills.sheets.level(sheet, skill) or 0 end,
                }
            end,
        })
        assert.is_true(registry.define(INVENTORY, 'vava_inventory:items', ANY))
        startSkills()
        local ok, err = startCrafting()
        assert.is_true(ok, err)
    end)

    after_each(function()
        _G.print = realPrint
        VavaCrafting, VavaSkills = nil, nil
    end)

    it('les recettes de la config sont toutes connues des compétences : aucune ligne au démarrage', function()
        elapse()
        assert.same({}, skillWarnings())
        assert.same({}, VavaCrafting.catalog.missingFromSkills())
        assert.is_true(VavaCrafting.catalog.declaredToSkills('lingot_fer'))
        local entry = menuEntry('lingot_fer')
        assert.is_true(entry.known)
        assert.is_nil(entry.unregistered)
    end)

    it("une recette déclarée à l'artisanat seul : une ligne avec son nom et son module, verrouillée au menu, refusée", function()
        elapse()
        assert.is_true(registry.add(FORGERONS, CRAFT_RECIPES, 'clou_fer', CLOUS))
        -- rien avant le délai : le module a pu déclarer les deux registres l'un après l'autre
        assert.same({}, skillWarnings())
        elapse()
        local lines = skillWarnings()
        assert.equal(1, #lines)
        assert.truthy(lines[1]:find("recette 'clou_fer' (déclarée par vava_forgerons)", 1, true))
        assert.same({ { id = 'clou_fer', owner = FORGERONS } }, VavaCrafting.catalog.missingFromSkills())

        local entry = menuEntry('clou_fer')
        assert.is_table(entry)
        assert.is_true(entry.unregistered)
        assert.is_false(entry.known)
        -- le niveau suffit : seule la déclaration manque
        assert.is_true(entry.levelOk)
        assert.same({ false, 'not_known' }, { VavaCrafting.crafting.begin(PLAYER, 'forge_bourg', 'clou_fer', nil) })

        -- une seule fois : un autre contrôle ne répète pas la ligne
        VavaCrafting.catalog.checkSkillRecipes()
        assert.equal(1, #skillWarnings())
    end)

    it('la même recette déclarée ensuite aux compétences : déverrouillée, admise par le serveur', function()
        assert.is_true(registry.add(FORGERONS, CRAFT_RECIPES, 'clou_fer', CLOUS))
        elapse()
        assert.is_true(menuEntry('clou_fer').unregistered)

        assert.is_true(registry.add(FORGERONS, SKILL_RECIPES, 'clou_fer', CLOUS_SKILL))
        assert.is_true(VavaCrafting.catalog.declaredToSkills('clou_fer'))
        local entry = menuEntry('clou_fer')
        assert.is_nil(entry.unregistered)
        assert.is_true(entry.known)
        -- la connaissance passe : le refus suivant vient de la besace vide
        assert.same({ false, 'missing_items' }, { VavaCrafting.crafting.begin(PLAYER, 'forge_bourg', 'clou_fer', nil) })
        assert.same({}, VavaCrafting.catalog.checkSkillRecipes())
        assert.equal(1, #skillWarnings())
    end)

    it("un module qui déclare les deux registres l'un après l'autre : aucune ligne", function()
        elapse()
        assert.is_true(registry.add(FORGERONS, CRAFT_RECIPES, 'clou_fer', CLOUS))
        assert.is_true(registry.add(FORGERONS, SKILL_RECIPES, 'clou_fer', CLOUS_SKILL))
        elapse()
        assert.same({}, skillWarnings())
        assert.is_nil(menuEntry('clou_fer').unregistered)
    end)

    it('au retour de vava_skills : la recette que son module ne redéclare pas est signalée de nouveau', function()
        assert.is_true(registry.add(FORGERONS, CRAFT_RECIPES, 'clou_fer', CLOUS))
        assert.is_true(registry.add(FORGERONS, SKILL_RECIPES, 'clou_fer', CLOUS_SKILL))
        elapse()
        assert.same({}, skillWarnings())

        stop(SKILLS)
        startSkills()
        ready(SKILLS)
        -- l'artisanat a redéclaré les siennes ; le module tiers a oublié clou_fer
        assert.is_true(registry.has(SKILL_RECIPES, 'lingot_fer'))
        elapse()
        local lines = skillWarnings()
        assert.equal(1, #lines)
        assert.truthy(lines[1]:find("recette 'clou_fer' (déclarée par vava_forgerons)", 1, true))
        assert.is_true(menuEntry('clou_fer').unregistered)

        -- un second retour : la ligne revient une fois
        stop(SKILLS)
        startSkills()
        ready(SKILLS)
        elapse()
        assert.equal(2, #skillWarnings())
    end)

    it('au retour de vava_skills, un module qui redéclare sa recette : aucune ligne', function()
        assert.is_true(registry.add(FORGERONS, CRAFT_RECIPES, 'clou_fer', CLOUS))
        assert.is_true(registry.add(FORGERONS, SKILL_RECIPES, 'clou_fer', CLOUS_SKILL))
        hooks.subscribe(FORGERONS, 'after', 'core:module:ready', function(payload)
            if payload.name == SKILLS then registry.add(FORGERONS, SKILL_RECIPES, 'clou_fer', CLOUS_SKILL) end
        end)
        elapse()
        stop(SKILLS)
        startSkills()
        ready(SKILLS)
        elapse()
        assert.same({}, skillWarnings())
        assert.is_nil(menuEntry('clou_fer').unregistered)
    end)

    it("une recette de l'artisanat retirée des compétences : signalée au nom de vava_crafting", function()
        elapse()
        assert.is_true(registry.remove(CRAFTING, SKILL_RECIPES, 'lingot_fer'))
        elapse()
        local lines = skillWarnings()
        assert.equal(1, #lines)
        assert.truthy(lines[1]:find("recette 'lingot_fer' (déclarée par vava_crafting)", 1, true))
        assert.is_true(menuEntry('lingot_fer').unregistered)
    end)

    it('registre des compétences absent : une seule ligne, toutes les recettes verrouillées', function()
        elapse()
        stop(SKILLS)
        local missing = VavaCrafting.catalog.checkSkillRecipes()
        assert.is_true(#missing > 0)
        VavaCrafting.catalog.checkSkillRecipes()
        local lines = skillWarnings()
        assert.equal(1, #lines)
        assert.truthy(lines[1]:find('registre vava_skills:recipes absent', 1, true))
        assert.is_false(VavaCrafting.catalog.declaredToSkills('lingot_fer'))
    end)

    it("une recette retirée de l'artisanat n'est plus signalée", function()
        assert.is_true(registry.add(FORGERONS, CRAFT_RECIPES, 'clou_fer', CLOUS))
        assert.is_true(registry.remove(FORGERONS, CRAFT_RECIPES, 'clou_fer'))
        elapse()
        assert.same({}, skillWarnings())
        assert.is_nil(menuEntry('clou_fer'))
    end)
end)
