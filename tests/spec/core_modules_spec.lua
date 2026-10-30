local helper = require('tests.helper')

-- Cycle de vie des modules (server/core/modules.lua), au regard de la section « core.modules » de docs/api.md :
-- déclaration validée tout de suite, démarrage asynchrone (core prêt, dépendances, migrations, setup), échec explicite
-- avec purge, arrêt différé d'un tour (0.8.1).
-- Hors jeu, un petit planificateur remplace promise / Citizen.Await / CreateThread : un thread qui attend une
-- promesse se suspend (coroutine) et reprend quand elle est résolue, comme dans FiveM.
describe('vAvA.modules', function()
    local modules, hooks, resources, purged, events, migrationsOk, realPrint

    local function installScheduler()
        local Promise = {}
        Promise.__index = Promise
        function Promise:resolve(value)
            if self.resolved then return end
            self.resolved, self.value = true, value
            local waiters = self.waiters
            self.waiters = {}
            for _, co in ipairs(waiters) do
                local ok, err = coroutine.resume(co)
                if not ok then error(err, 0) end
            end
        end
        _G.promise = { new = function() return setmetatable({ resolved = false, waiters = {} }, Promise) end }
        _G.Citizen = { Await = function(p)
            if not p.resolved then
                local co, isMain = coroutine.running()
                if isMain then error('attente d\'une promesse non résolue hors de tout thread') end
                p.waiters[#p.waiters + 1] = co
                coroutine.yield()
            end
            return p.value
        end }
        _G.CreateThread = function(fn)
            local co = coroutine.create(fn)
            local ok, err = coroutine.resume(co)
            if not ok then error(err, 0) end
        end
    end

    before_each(function()
        helper.reset()
        installScheduler()
        realPrint = _G.print
        _G.print = function() end
        _G.GetResourceMetadata = function() return '0.8.1' end
        resources = {}
        _G.GetResourceState = function(name) return resources[name] or 'missing' end
        helper.loadAll({
            'shared/init.lua',
            'config/shared.lua',
            'shared/lib/table.lua',
            'shared/lib/string.lua',
            'shared/lib/semver.lua',
            'shared/lib/schema.lua',
            'shared/core/logger.lua',
            'shared/core/hooks.lua',
            'config/server.lua',
        })
        migrationsOk = true
        vAvA.migrations = { apply = function() if migrationsOk then return true end return false, 'table absente' end }
        helper.load('server/core/modules.lua')
        modules, hooks = vAvA.modules, vAvA.hooks
        purged = {}
        modules.setPurgeHandler(function(owner) purged[#purged + 1] = owner end)
        events = {}
        for _, name in ipairs({ 'core:module:ready', 'core:module:failed', 'core:module:stopped' }) do
            hooks.subscribe('test', 'after', name, function(payload) events[#events + 1] = { hook = name, payload = payload } end)
        end
    end)

    after_each(function()
        _G.print = realPrint
    end)

    local function declare(name, def)
        def = def or {}
        def.version = def.version or '1.0.0'
        def.coreVersion = def.coreVersion or '0.1.0'
        resources[name] = 'started'
        return modules.declare(name, def)
    end

    local function state(name)
        local info = modules.get(name)
        return info and info.state
    end

    describe('declare', function()
        it('refuse une définition mal formée, tout de suite', function()
            local cases = {
                { 'texte', 'définition de module' },
                { { version = '1', coreVersion = '0.1.0' }, 'version invalide' },
                { { version = '1.0.0', coreVersion = 'x' }, 'coreVersion invalide' },
                { { version = '1.0.0', coreVersion = '0.1.0', dependencies = 'vava_inv' }, 'dependencies' },
                { { version = '1.0.0', coreVersion = '0.1.0', dependencies = { [''] = '1.0.0' } }, 'nom de dépendance' },
                { { version = '1.0.0', coreVersion = '0.1.0', dependencies = { vava_test = '1.0.0' } }, 'dépendre de lui' },
                { { version = '1.0.0', coreVersion = '0.1.0', dependencies = { vava_inv = 'récente' } }, 'version minimale' },
                { { version = '1.0.0', coreVersion = '0.1.0', setup = 'go' }, 'setup' },
            }
            for _, case in ipairs(cases) do
                local ok, err = modules.declare('vava_test', case[1])
                assert.is_false(ok)
                assert.matches(case[2], err)
                assert.is_nil(modules.get('vava_test'))
            end
        end)

        it('refuse les noms réservés au core et une seconde déclaration', function()
            modules.setCoreReady()
            local ok, err = modules.declare('core', { version = '1.0.0', coreVersion = '0.1.0' })
            assert.is_false(ok)
            assert.matches('réservé', err)
            ok = modules.declare(vAvA.resourceName, { version = '1.0.0', coreVersion = '0.1.0' })
            assert.is_false(ok)
            assert.is_true(declare('vava_test'))
            ok, err = declare('vava_test')
            assert.is_false(ok)
            assert.matches('déjà déclaré', err)
            assert.matches('ready', err)
        end)
    end)

    describe('démarrage', function()
        it('attend que le core soit prêt, puis passe par migrating, starting et ready', function()
            local seen = {}
            assert.is_true(declare('vava_test', { setup = function()
                seen[#seen + 1] = state('vava_test')
                seen[#seen + 1] = modules.isActive('vava_test')
                return true
            end }))
            assert.equal('waiting', state('vava_test'))
            assert.is_false(modules.isActive('vava_test'))
            assert.equal(0, #events)
            modules.setCoreReady()
            assert.equal('ready', state('vava_test'))
            assert.same({ 'starting', true }, seen)
            assert.is_true(modules.isActive('vava_test'))
            assert.equal(1, #events)
            assert.equal('core:module:ready', events[1].hook)
            assert.same({ name = 'vava_test', version = '1.0.0' }, events[1].payload)
        end)

        it('démarre sans setup', function()
            modules.setCoreReady()
            assert.is_true(declare('vava_test'))
            assert.equal('ready', state('vava_test'))
        end)

        it('refuse un module qui demande un core plus récent', function()
            modules.setCoreReady()
            assert.is_true(declare('vava_test', { coreVersion = '9.0.0' }))
            assert.equal('failed', state('vava_test'))
            assert.matches('requiert vAvA_core', modules.get('vava_test').error)
            assert.same({ 'vava_test' }, purged)
            assert.equal('core:module:failed', events[1].hook)
        end)

        it('échoue quand les migrations échouent', function()
            modules.setCoreReady()
            migrationsOk = false
            assert.is_true(declare('vava_test'))
            assert.equal('failed', state('vava_test'))
            assert.matches('migrations', modules.get('vava_test').error)
        end)

        it('échoue quand setup refuse, lève une erreur, ou quand le core a échoué', function()
            modules.setCoreReady()
            assert.is_true(declare('vava_a', { setup = function() return false, 'table manquante' end }))
            assert.equal('failed', state('vava_a'))
            assert.matches('table manquante', modules.get('vava_a').error)
            assert.is_false(modules.isActive('vava_a'))
            assert.is_true(declare('vava_b', { setup = function() error('cassé') end }))
            assert.equal('failed', state('vava_b'))
            assert.matches('erreur dans setup', modules.get('vava_b').error)
            assert.same({ 'vava_a', 'vava_b' }, purged)
            assert.equal(2, #events)
            assert.equal('table manquante', events[1].payload.reason:match('table manquante'))
        end)

        it('refuse tout module quand le core a échoué', function()
            modules.setCoreFailed('base injoignable')
            assert.is_true(declare('vava_test'))
            assert.equal('failed', state('vava_test'))
            assert.matches('base injoignable', modules.get('vava_test').error)
        end)
    end)

    describe('dépendances', function()
        before_each(function() modules.setCoreReady() end)

        it('échoue tout de suite si la ressource dépendante est absente ou arrêtée', function()
            resources.vava_inv = 'stopped'
            assert.is_true(declare('vava_test', { dependencies = { vava_inv = '1.0.0' } }))
            assert.equal('failed', state('vava_test'))
            assert.matches('absente ou arrêtée', modules.get('vava_test').error)
        end)

        it('démarre après une dépendance prête en version suffisante, et refuse une version trop basse', function()
            assert.is_true(declare('vava_inv', { version = '1.2.0' }))
            assert.is_true(declare('vava_test', { dependencies = { vava_inv = '1.1.0' } }))
            assert.equal('ready', state('vava_test'))
            assert.is_true(declare('vava_exigeant', { dependencies = { vava_inv = '2.0.0' } }))
            assert.equal('failed', state('vava_exigeant'))
            assert.matches('minimum requis', modules.get('vava_exigeant').error)
        end)

        it('attend une dépendance démarrée mais pas encore déclarée, puis continue quand elle est prête', function()
            resources.vava_inv = 'starting'
            assert.is_true(declare('vava_test', { dependencies = { vava_inv = '1.0.0' } }))
            assert.equal('waiting', state('vava_test'))
            assert.is_true(declare('vava_inv', { version = '1.0.0' }))
            assert.equal('ready', state('vava_inv'))
            assert.equal('ready', state('vava_test'))
        end)

        it('échoue quand la dépendance attendue ne se déclare pas dans le délai, ou échoue', function()
            resources.vava_inv = 'started'
            assert.is_true(declare('vava_test', { dependencies = { vava_inv = '1.0.0' } }))
            assert.equal(1, #helper.timers)
            assert.equal(vAvA.config.server.modules.dependencyTimeoutMs, helper.timers[1].ms)
            helper.timers[1].fn()
            assert.equal('failed', state('vava_test'))
            assert.matches('pas prêt après', modules.get('vava_test').error)

            assert.is_true(declare('vava_autre', { dependencies = { vava_inv = '1.0.0' } }))
            assert.is_true(declare('vava_inv', { setup = function() return false, 'non' end }))
            assert.equal('failed', state('vava_autre'))
            assert.matches('en échec', modules.get('vava_autre').error)
        end)

        it('refuse une dépendance circulaire', function()
            resources.vava_b = 'started'
            assert.is_true(declare('vava_a', { dependencies = { vava_b = '1.0.0' } }))
            assert.is_true(declare('vava_b', { dependencies = { vava_a = '1.0.0' } }))
            assert.equal('failed', state('vava_b'))
            assert.matches('circulaire', modules.get('vava_b').error)
            assert.equal('failed', state('vava_a'))
        end)

        it('list rend les modules connus, triés par nom', function()
            assert.is_true(declare('vava_b'))
            assert.is_true(declare('vava_a'))
            local list = modules.list()
            assert.equal('vava_a', list[1].name)
            assert.equal('vava_b', list[2].name)
            assert.same({}, list[1].dependencies)
        end)
    end)

    describe('arrêt (handleStop)', function()
        before_each(function() modules.setCoreReady() end)

        it('ne fait rien pour une ressource qui n’est pas un module', function()
            modules.handleStop('vava_inconnu')
            assert.equal(0, #events)
            assert.equal(0, #helper.timers)
        end)

        it('garde le module actif jusqu’au tour suivant, puis le retire en signalant ceux qui en dépendent', function()
            assert.is_true(declare('vava_inv'))
            assert.is_true(declare('vava_shop', { dependencies = { vava_inv = '1.0.0' } }))
            events = {}
            modules.handleStop('vava_inv')
            assert.equal('stopping', state('vava_inv'))
            assert.is_true(modules.isActive('vava_inv'))
            assert.equal(0, #events)
            assert.equal(1, #helper.timers)
            assert.equal(0, helper.timers[1].ms)
            helper.timers[1].fn()
            assert.is_nil(modules.get('vava_inv'))
            assert.is_false(modules.isActive('vava_inv'))
            assert.equal(1, #events)
            assert.equal('core:module:stopped', events[1].hook)
            assert.same({ name = 'vava_inv', version = '1.0.0', dependents = { 'vava_shop' } }, events[1].payload)
            assert.equal('ready', state('vava_shop'))
        end)

        it('un second arrêt pendant le tour ne change rien', function()
            assert.is_true(declare('vava_inv'))
            events = {}
            modules.handleStop('vava_inv')
            modules.handleStop('vava_inv')
            assert.equal(1, #helper.timers)
            helper.timers[1].fn()
            helper.timers[1].fn()
            assert.equal(1, #events)
        end)

        it('laisse une ressource redémarrée dans le même tour se redéclarer, sans attendre', function()
            assert.is_true(declare('vava_inv', { version = '1.0.0' }))
            modules.handleStop('vava_inv')
            events = {}
            assert.is_true(declare('vava_inv', { version = '1.0.1' }))
            assert.equal('ready', state('vava_inv'))
            assert.equal('1.0.1', modules.get('vava_inv').version)
            assert.equal('core:module:stopped', events[1].hook)
            assert.equal('core:module:ready', events[2].hook)
            -- la minuterie de l'arrêt précédent n'a plus rien à retirer
            helper.timers[1].fn()
            assert.equal('ready', state('vava_inv'))
            assert.equal(2, #events)
        end)

        it('libère ceux qui l’attendaient et refuse d’en être la dépendance', function()
            resources.vava_ext = 'started'
            assert.is_true(declare('vava_inv', { dependencies = { vava_ext = '1.0.0' } }))   -- attend vava_ext
            assert.is_true(declare('vava_shop', { dependencies = { vava_inv = '1.0.0' } }))  -- attend vava_inv
            assert.equal('waiting', state('vava_shop'))
            modules.handleStop('vava_inv')
            assert.equal('failed', state('vava_shop'))
            assert.matches('arrêtée', modules.get('vava_shop').error)
            assert.is_true(declare('vava_autre', { dependencies = { vava_inv = '1.0.0' } }))
            assert.equal('failed', state('vava_autre'))
            assert.matches('arrêtée', modules.get('vava_autre').error)
            -- le délai de vava_ext tombe après l'arrêt : le démarrage interrompu ne touche plus à rien
            for _, timer in ipairs(helper.timers) do timer.fn() end
            assert.is_nil(modules.get('vava_inv'))
        end)
    end)

    describe('awaitCore', function()
        it('attend le core avec un délai, puis répond selon son état', function()
            local results = {}
            CreateThread(function() results[#results + 1] = { modules.awaitCore(5000) } end)
            assert.equal(0, #results)
            assert.equal(5000, helper.timers[1].ms)
            helper.timers[1].fn()
            assert.same({ false, 'timeout' }, results[1])
            modules.setCoreReady()
            assert.is_true(modules.isCoreReady())
            CreateThread(function() results[#results + 1] = { modules.awaitCore(5000) } end)
            assert.same({ true }, results[2])
        end)

        it('répond failed quand le core a échoué', function()
            modules.setCoreFailed('base injoignable')
            local result
            CreateThread(function() result = { modules.awaitCore(5000) } end)
            assert.same({ false, 'failed' }, result)
        end)
    end)
end)
