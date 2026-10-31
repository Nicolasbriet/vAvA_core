local helper = require('tests.helper')

-- Recette du compost déclarée aux compétences (T-136) : vava_farming l'ajoute à l'artisanat (`vava_crafting:recipes`)
-- et au registre des compétences (`vava_skills:recipes`), sans quoi vava_skills ne la connaît pas et le composteur
-- refuse de la faire (`knowsRecipe` faux : code `not_known` de vava_crafting). Montage réel : registres et hooks du
-- core (server/core/registry.lua, shared/core/hooks.lua), registres et savoirs de vava_skills (server/registries.lua,
-- server/sheets.lua, server/lessons.lua), bridge et catalogue de vava_farming ; l'artisanat et l'inventaire ne sont que
-- leurs registres (schéma libre) et un `addStation` simulé. Règles : README de vava_farming (Composteur) et de
-- vava_skills (Recettes).

local SKILLS, FARMING, CRAFTING, INVENTORY = 'vava_skills', 'vava_farming', 'vava_crafting', 'vava_inventory'
local SKILL_RECIPES = 'vava_skills:recipes'
local ANY = { schema = { type = 'any' } }

local function newLogs()
    local logs = { error = {}, warn = {}, info = {}, debug = {} }
    local log = {}
    for level in pairs(logs) do
        log[level] = function(fmt, ...) logs[level][#logs[level] + 1] = fmt:format(...) end
    end
    return logs, log
end

describe('vava_farming : recette du compost aux compétences', function()
    local registry, hooks, logs, stations, started, realPrint

    --- API du core telle que la voit une ressource (server/core/api.lua) : registres et hooks au nom du propriétaire.
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
            },
        }
    end

    --- Démarre vava_skills (registres, fiches, savoirs) comme son setup : compétences de la config versées.
    local function startSkills()
        VavaSkills = nil
        helper.loadAll({ 'modules/vava_skills/shared/constants.lua', 'modules/vava_skills/config.lua', 'modules/vava_skills/shared/progression.lua' })
        local _, log = newLogs()
        VavaSkills.core, VavaSkills.log, VavaSkills.resource = coreFor(SKILLS, log), log, SKILLS
        VavaSkills.bridge, VavaSkills.journal = {}, {}
        helper.loadAll({ 'modules/vava_skills/server/registries.lua', 'modules/vava_skills/server/sheets.lua', 'modules/vava_skills/server/lessons.lua' })
        assert.is_true(VavaSkills.registries.define())
    end

    --- Arrêt d'une ressource vu par le core : ses registres, ses entrées chez les autres et ses hooks retirés.
    local function stop(owner)
        registry.purgeOwner(owner)
        hooks.purgeOwner(owner)
    end

    --- Annonce du core qu'un module est prêt.
    local function ready(name)
        hooks.runAfter('core:module:ready', { name = name })
    end

    --- Fiche d'un personnage sans aucune pratique (Agriculture 0) ou au niveau donné.
    local function sheet(level)
        return { skills = { agriculture = level and { level = level } or nil }, recipes = {} }
    end

    local function knows(level)
        return VavaSkills.lessons.knows(sheet(level), 'compost')
    end

    --- Démarre vava_farming jusqu'au catalogue (son setup l'appelle en premier).
    local function startFarming()
        VavaFarming = nil
        helper.loadAll({ 'modules/vava_farming/shared/constants.lua', 'modules/vava_farming/config.lua', 'modules/vava_farming/shared/geometry.lua' })
        local log
        logs, log = newLogs()
        VavaFarming.core, VavaFarming.log, VavaFarming.resource, VavaFarming.ready = coreFor(FARMING, log), log, FARMING, false
        helper.loadAll({ 'modules/vava_farming/bridge/server.lua', 'modules/vava_farming/server/catalog.lua' })
        return VavaFarming.catalog.define()
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
        stations, started = {}, { [SKILLS] = true, [CRAFTING] = true, [INVENTORY] = true }
        _G.GetResourceState = function(name) return started[name] and 'started' or 'missing' end
        _G.exports = setmetatable({}, {
            __index = function(_, name)
                if name ~= CRAFTING then return nil end
                return {
                    addStation = function(_, def)
                        if stations[def.id] then return false, 'duplicate' end
                        stations[def.id] = def
                        return true
                    end,
                }
            end,
        })
        assert.is_true(registry.define(CRAFTING, 'vava_crafting:stations', ANY))
        assert.is_true(registry.define(CRAFTING, 'vava_crafting:recipes', ANY))
        assert.is_true(registry.define(INVENTORY, 'vava_inventory:items', ANY))
        startSkills()
    end)

    after_each(function()
        _G.print = realPrint
        VavaFarming, VavaSkills = nil, nil
    end)

    it('une recette connue de la seule artisanat est inconnue des compétences : le composteur la refuserait', function()
        -- ce que faisait vava_farming jusqu'à 1.8.0 : la recette au seul registre de vava_crafting
        local recipe = {}
        helper.loadAll({ 'modules/vava_farming/shared/constants.lua', 'modules/vava_farming/config.lua' })
        for key, value in pairs(VavaFarming.config.composter.recipe) do
            if key ~= 'id' then recipe[key] = value end
        end
        assert.is_true(registry.add(FARMING, 'vava_crafting:recipes', 'compost', recipe))
        assert.is_nil(VavaSkills.registries.recipe('compost'))
        assert.is_false(knows(0))
        assert.is_false(knows(100))
    end)

    it('déclare la recette aux compétences au démarrage : libre, Agriculture, niveau 0, connue sans pratique', function()
        assert.is_true(startFarming())
        assert.same({ label = 'Compost', skill = 'agriculture', level = 0, transmission = false }, registry.get(SKILL_RECIPES, 'compost'))
        assert.same({ id = 'compost', label = 'Compost', skill = 'agriculture', level = 0, transmission = false, fragments = nil },
            VavaSkills.registries.recipe('compost'))
        assert.is_true(knows(nil))
        -- l'artisanat la connaît toujours, la station est posée
        assert.is_true(registry.has('vava_crafting:recipes', 'compost'))
        assert.is_table(stations.composteur_communal)
        assert.same({}, logs.warn)
    end)

    it('la même compétence, le même niveau et le même nom à l\'artisanat et aux compétences', function()
        assert.is_true(startFarming())
        local crafting, skills = registry.get('vava_crafting:recipes', 'compost'), registry.get(SKILL_RECIPES, 'compost')
        assert.equal(crafting.skill, skills.skill)
        assert.equal(crafting.level, skills.level)
        assert.equal(crafting.label, skills.label)
        assert.equal(crafting.transmission == true, skills.transmission)
    end)

    it('redéclare la recette au retour de vava_skills, qui a perdu son registre', function()
        assert.is_true(startFarming())
        stop(SKILLS)
        assert.is_false(registry.exists(SKILL_RECIPES))
        startSkills()
        assert.is_false(knows(nil))
        ready(SKILLS)
        assert.is_true(registry.has(SKILL_RECIPES, 'compost'))
        assert.is_true(knows(nil))
        assert.same({}, logs.warn)
        -- deux retours de suite : une seule entrée, aucun avertissement
        ready(SKILLS)
        assert.same({}, logs.warn)
    end)

    it('redéclare aussi la recette quand vava_skills démarre après vava_farming', function()
        stop(SKILLS)
        started[SKILLS] = nil
        assert.is_true(startFarming())
        assert.equal(1, #logs.warn)
        assert.matches('recette du compost non déclarée aux compétences', logs.warn[1])
        started[SKILLS] = true
        startSkills()
        ready(SKILLS)
        assert.is_true(knows(nil))
        assert.equal(1, #logs.warn)
    end)

    it('le retour de vava_crafting ne touche pas la recette des compétences', function()
        assert.is_true(startFarming())
        stop(CRAFTING)
        assert.is_true(registry.has(SKILL_RECIPES, 'compost'))
        assert.is_true(registry.define(CRAFTING, 'vava_crafting:stations', ANY))
        assert.is_true(registry.define(CRAFTING, 'vava_crafting:recipes', ANY))
        stations = {}
        ready(CRAFTING)
        assert.is_true(registry.has('vava_crafting:recipes', 'compost'))
        assert.is_true(registry.has(SKILL_RECIPES, 'compost'))
        assert.is_true(knows(nil))
    end)

    it("une recette refusée par les compétences (compétence inconnue) : false et la raison, rien d'ajouté", function()
        assert.is_true(startFarming())
        assert.is_true(registry.remove(FARMING, SKILL_RECIPES, 'compost'))
        local recipe = {}
        for key, value in pairs(VavaFarming.config.composter.recipe) do recipe[key] = value end
        recipe.skill = 'jardinage'
        local ok, err = VavaFarming.bridge.DeclareSkillRecipe(recipe)
        assert.is_false(ok)
        assert.matches("compétence inconnue 'jardinage'", err)
        assert.is_false(registry.has(SKILL_RECIPES, 'compost'))
    end)
end)
