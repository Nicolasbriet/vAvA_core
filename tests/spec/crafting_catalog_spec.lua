local helper = require('tests.helper')

-- Registre des types de stations (modules/vava_crafting/server/catalog.lua), avec un faux registre du core et des
-- doublures du bridge. Règle documentée : README du module (« Stations ») et docs/api.md, section vava_crafting :
--   l'animation d'un type, de la config ou déclaré par un autre module (le composteur de vava_farming), est une clé de
--   `anims` (config_client.lua) ; sinon le type est refusé (relecture sécurité S-2 de T-144) : un geste ne se joue
--   jamais sans animation en silence.

describe('vava_crafting registre des types de stations', function()
    local registries, catalog, cfg

    before_each(function()
        helper.reset()
        VavaCrafting = nil
        helper.loadAll({
            'modules/vava_crafting/shared/constants.lua',
            'modules/vava_crafting/config.lua',
            'modules/vava_crafting/shared/stationzone.lua',
        })
        cfg = VavaCrafting.config
        registries = {}
        local hooks = {}
        local noop = function() end
        VavaCrafting.resource = 'vava_crafting'
        VavaCrafting.log = { warn = noop, error = noop, info = noop }
        -- faux registre : le schéma est l'affaire du core ; le validateur du module est appelé comme le core le fait
        VavaCrafting.core = {
            registry = {
                define = function(name, options)
                    registries[name] = { options = options, entries = {} }
                    return true
                end,
                add = function(name, key, data)
                    local registry = registries[name]
                    local validator = registry.options.validator
                    if validator then
                        local accepted, reason = validator(key, data)
                        if accepted ~= true then return false, reason end
                    end
                    registry.entries[key] = data
                    -- comme le core : les abonnés de core:registry:added (caches du catalogue) sont prévenus
                    for _, fn in ipairs(hooks['core:registry:added'] or {}) do fn({ registry = name, key = key }) end
                    return true
                end,
                all = function(name) return registries[name] and registries[name].entries or {} end,
            },
            hooks = {
                after = function(name, fn)
                    hooks[name] = hooks[name] or {}
                    table.insert(hooks[name], fn)
                    return #hooks[name]
                end,
            },
        }
        VavaCrafting.bridge = {
            INVENTORY = 'vava_inventory', SKILLS = 'vava_skills',
            DeclareItem = noop,
            DeclareSkillRecipe = function() return true end,
            ItemDefinition = function(item) return { label = item, stack = 1 } end,
        }
        helper.load('modules/vava_crafting/server/catalog.lua')
        catalog = VavaCrafting.catalog
    end)

    after_each(function()
        VavaCrafting = nil
    end)

    it('la config livrée passe : chaque type a une animation connue', function()
        assert.is_true(catalog.define())
        for id in pairs(cfg.stationTypes) do assert.is_table(catalog.stationType(id), id) end
    end)

    it('un type déclaré par un autre module avec une animation connue est admis (le composteur)', function()
        assert.is_true(catalog.define())
        local ok = VavaCrafting.core.registry.add(VavaCrafting.REGISTRY.STATIONS, 'composteur',
            { label = 'Composteur', skills = { 'agriculture' }, anim = 'tan', prop = 'prop_rub_binbag_01' })
        assert.is_true(ok)
        assert.equal('Composteur', catalog.stationType('composteur').label)
    end)

    it('un type dont l\'animation n\'est pas dans `anims` est refusé, avec la raison', function()
        assert.is_true(catalog.define())
        local ok, err = VavaCrafting.core.registry.add(VavaCrafting.REGISTRY.STATIONS, 'pressoir',
            { label = 'Pressoir', skills = { 'cuisine' }, anim = 'presser', prop = 'prop_barrel_01a' })
        assert.is_false(ok)
        assert.truthy(err:find('presser', 1, true))
        assert.is_nil(catalog.stationType('pressoir'))
    end)

    it('un type de la config avec une animation inconnue refuse le module', function()
        cfg.stationTypes.forge.anim = 'inconnue'
        local ok, err = catalog.define()
        assert.is_false(ok)
        assert.truthy(err:find("type de station 'forge'", 1, true))
        assert.truthy(err:find('inconnue', 1, true))
    end)
end)
