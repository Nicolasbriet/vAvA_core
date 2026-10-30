local helper = require('tests.helper')

-- Porte gardée de la connexion (server/players/accounts.lua, core 0.9.1, T-026) : tant qu'un module « garde de
-- connexion » (players.connectionGuards, les bans de vava_admin) est démarré sans être prêt, ou en échec, la porte
-- est fermée ; absent du serveur ou arrêté, il n'est pas attendu (et la console le signale).

describe('vAvA.accounts porte gardée', function()
    local accounts, resources, records, warnings

    before_each(function()
        helper.reset()
        resources, records, warnings = {}, {}, {}
        _G.GetResourceState = function(name) return resources[name] or 'missing' end
        _G.vAvA = {
            CORE_OWNER = 'vAvA_core',
            hooks = {}, database = {},
            modules = { get = function(name) return records[name] and { name = name, state = records[name] } or nil end },
            config = { server = { players = { connectionGuards = { 'vava_admin' }, messages = {} } } },
            logger = { create = function()
                local noop = function() end
                return { info = noop, error = noop, warn = function(...) warnings[#warnings + 1] = { ... } end }
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

        it('n\'attend pas une ressource absente du serveur ou arrêtée', function()
            assert.equal('absent', accounts.guardVerdict('missing', nil))
            assert.equal('absent', accounts.guardVerdict('uninitialized', nil))
            assert.equal('absent', accounts.guardVerdict('stopped', nil))
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

        it('sans liste de gardes, la porte ne dépend de rien', function()
            _G.vAvA.config.server.players.connectionGuards = nil
            resources.vava_admin = 'starting'
            assert.is_nil(accounts.closedGuard())
        end)
    end)
end)
