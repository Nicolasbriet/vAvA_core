local helper = require('tests.helper')

-- Porte gardée de la connexion (server/players/accounts.lua, core 0.9.1, T-026) : tant qu'un module « garde de
-- connexion » (players.connectionGuards, les bans de vava_admin) n'est pas prêt — démarrage, échec, ou arrêté (un
-- restart du core arrête vava_admin sans le relancer) —, la porte est fermée ; seule une ressource absente du serveur
-- n'est pas attendue (et la console le signale). Une entrée invalide de la liste est ignorée et signalée.

describe('vAvA.accounts porte gardée', function()
    local accounts, resources, records, warnings, errors

    before_each(function()
        helper.reset()
        resources, records, warnings, errors = {}, {}, {}, {}
        _G.GetResourceState = function(name) return resources[name] or 'missing' end
        _G.vAvA = {
            CORE_OWNER = 'vAvA_core',
            hooks = {}, database = {},
            modules = { get = function(name) return records[name] and { name = name, state = records[name] } or nil end },
            config = { server = { players = { connectionGuards = { 'vava_admin' }, messages = {} } } },
            logger = { create = function()
                local noop = function() end
                return {
                    info = noop,
                    error = function(...) errors[#errors + 1] = { ... } end,
                    warn = function(...) warnings[#warnings + 1] = { ... } end,
                }
            end },
        }
        helper.load('server/players/accounts.lua')
        accounts = _G.vAvA.accounts
    end)

    after_each(function()
        _G.GetResourceState = nil
        _G.vAvA = nil
    end)

    describe('verdict', function()
        it('ouvre quand la ressource tourne et que le module est prêt', function()
            assert.equal('open', accounts.guardVerdict('started', 'ready'))
        end)

        it('ferme pendant le démarrage, le redémarrage, l\'arrêt en cours et après un échec', function()
            for _, state in ipairs({ 'declared', 'waiting', 'migrating', 'starting', 'failed', 'stopping' }) do
                assert.equal('closed', accounts.guardVerdict('started', state), state)
            end
            assert.equal('closed', accounts.guardVerdict('started', nil))
            assert.equal('closed', accounts.guardVerdict('starting', nil))
            assert.equal('closed', accounts.guardVerdict('stopping', 'ready'))
            assert.equal('closed', accounts.guardVerdict('unknown', 'ready'))
            assert.equal('closed', accounts.guardVerdict(nil, nil))
        end)

        it('ferme pour un garde arrêté ou jamais démarré (restart du core : FiveM ne relance pas ses dépendants)', function()
            assert.equal('closed', accounts.guardVerdict('stopped', nil))
            assert.equal('closed', accounts.guardVerdict('stopped', 'ready'))
            assert.equal('closed', accounts.guardVerdict('uninitialized', nil))
        end)

        it('n\'attend qu\'une ressource absente du serveur', function()
            assert.equal('absent', accounts.guardVerdict('missing', nil))
        end)
    end)

    describe('garde fermant la porte', function()
        it('rien quand le garde est prêt', function()
            resources.vava_admin, records.vava_admin = 'started', 'ready'
            assert.is_nil(accounts.closedGuard())
            assert.same({}, warnings)
        end)

        it('nomme le garde et ses états quand il démarre ou a échoué', function()
            resources.vava_admin, records.vava_admin = 'started', 'failed'
            local name, detail = accounts.closedGuard()
            assert.equal('vava_admin', name)
            assert.truthy(detail:find('failed', 1, true))
            resources.vava_admin, records.vava_admin = 'starting', nil
            name, detail = accounts.closedGuard()
            assert.equal('vava_admin', name)
            assert.truthy(detail:find('non déclaré', 1, true))
        end)

        it('laisse passer sans le garde absent, mais le signale à la console (sauf en silence)', function()
            assert.is_nil(accounts.closedGuard())
            assert.equal(1, #warnings)
            assert.is_nil(accounts.closedGuard(true))
            assert.equal(1, #warnings)
        end)

        it('garde arrêté : porte fermée, et la console dit quoi faire (ensure, ou retrait de la liste)', function()
            resources.vava_admin = 'stopped'
            local name, detail = accounts.closedGuard()
            assert.equal('vava_admin', name)
            assert.truthy(detail:find('ensure vava_admin', 1, true))
            assert.truthy(detail:find('players.connectionGuards', 1, true))
            assert.same({}, warnings)
        end)

        it('ignore et signale une entrée qui n\'est pas un nom de ressource, sans erreur, une seule fois', function()
            _G.vAvA.config.server.players.connectionGuards = { 42, '', 'vava_admin', { 'x' } }
            local asked = {}
            _G.GetResourceState = function(name)
                asked[#asked + 1] = name
                assert.equal('string', type(name))
                return 'stopped'
            end
            helper.load('server/players/accounts.lua')
            accounts = _G.vAvA.accounts
            assert.equal('vava_admin', (accounts.closedGuard()))
            assert.equal(3, #errors)
            accounts.closedGuard()
            assert.equal(3, #errors)
            assert.same({ 'vava_admin', 'vava_admin' }, asked)
        end)

        it('ignore une liste qui n\'en est pas une', function()
            _G.vAvA.config.server.players.connectionGuards = 'vava_admin'
            resources.vava_admin = 'stopped'
            assert.is_nil(accounts.closedGuard())
            assert.equal(1, #errors)
        end)

        it('sans liste de gardes, la porte ne dépend de rien', function()
            _G.vAvA.config.server.players.connectionGuards = nil
            resources.vava_admin = 'starting'
            assert.is_nil(accounts.closedGuard())
        end)
    end)
end)
