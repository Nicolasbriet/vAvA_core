local helper = require('tests.helper')

-- Bans du Registre du Conseil (modules/vava_admin/server/bans.lua, T-026) :
--   - verdict pur `bans.decide` : une base qui ne répond pas ne laisse jamais passer un compte connu ; une première
--     venue (aucun compte) n'a rien à vérifier ;
--   - hook before `core:player:connecting` : banni refusé avec le motif, bans illisibles refusés avec un message
--     clair ;
--   - hook after `core:player:joined` : second contrôle, qui expulse un compte banni pendant son chargement (au
--     journal) ou dont les bans ne peuvent être lus, sans toucher un joueur parti ou un numéro repris.

describe('vava_admin bans', function()
    local bans, messages, store, hooks, dropped, recorded, errors, playersBySource

    local BAN = { id = 42, reason = 'triche', ['until'] = '01/11/2026 12:00' }

    before_each(function()
        helper.reset()
        dropped, recorded, errors, playersBySource = {}, {}, {}, {}
        hooks = { before = {}, after = {} }
        store = { calls = 0 }
        function store.activeBan(accountId)
            store.calls = store.calls + 1
            store.lastAccount = accountId
            return store.ban, store.err
        end
        _G.DropPlayer = function(src, reason) dropped[#dropped + 1] = { src = src, reason = reason } end

        helper.loadAll({ 'modules/vava_admin/shared/constants.lua', 'modules/vava_admin/config.lua' })
        local noop = function() end
        VavaAdmin.store = store
        VavaAdmin.log = { error = function(...) errors[#errors + 1] = { ... } end, warn = noop, info = noop }
        VavaAdmin.ranks = { CONSOLE = { name = 'console', label = 'Console' } }
        VavaAdmin.audit = {
            record = function(actor, action, target, details)
                recorded[#recorded + 1] = { actor = actor, action = action, target = target, details = details }
            end,
        }
        VavaAdmin.core = {
            hooks = {
                before = function(name, fn) hooks.before[name] = fn return 1 end,
                after = function(name, fn) hooks.after[name] = fn return 2 end,
            },
            players = { get = function(src) return playersBySource[src] end },
        }
        helper.load('modules/vava_admin/server/bans.lua')
        bans, messages = VavaAdmin.bans, VavaAdmin.config.messages
        assert.is_true(bans.start())
    end)

    after_each(function()
        _G.DropPlayer, _G.VavaAdmin = nil, nil
    end)

    describe('verdict', function()
        it('laisse passer une première venue, sans compte à vérifier', function()
            assert.equal('allow', bans.decide(nil, nil, nil))
            assert.equal('allow', bans.decide(nil, nil, 'base injoignable'))
        end)

        it('refuse un compte connu quand la base ne répond pas, ban trouvé ou non', function()
            assert.equal('unavailable', bans.decide(7, nil, 'base injoignable'))
            assert.equal('unavailable', bans.decide(7, BAN, 'base injoignable'))
        end)

        it('dit banni pour un ban actif, et laisse passer sans ban', function()
            assert.equal('banned', bans.decide(7, BAN, nil))
            assert.equal('allow', bans.decide(7, nil, nil))
        end)
    end)

    describe('à la connexion', function()
        local function connecting(accountId)
            local payload = { source = 65537, license = 'license:abc', name = 'B', accountId = accountId }
            return hooks.before['core:player:connecting'](payload)
        end

        it('ne consulte pas la base pour une première venue', function()
            store.err = 'base injoignable'
            assert.is_nil(connecting(nil))
            assert.equal(0, store.calls)
        end)

        it('laisse entrer un compte sans ban', function()
            assert.is_nil(connecting(7))
            assert.equal(7, store.lastAccount)
        end)

        it('refuse un compte banni avec le motif, la fin et le numéro du ban', function()
            store.ban = BAN
            local allowed, reason = connecting(7)
            assert.is_false(allowed)
            assert.equal(bans.message(BAN), reason)
            assert.truthy(reason:find('triche', 1, true))
            assert.truthy(reason:find('42', 1, true))
        end)

        it('refuse avec un message clair quand les bans ne peuvent être lus, et le dit à la console', function()
            store.err = 'base injoignable'
            local allowed, reason = connecting(7)
            assert.is_false(allowed)
            assert.equal(messages.banCheckUnavailable, reason)
            assert.equal(1, #errors)
        end)
    end)

    describe('à l\'arrivée en jeu', function()
        local function joined(src, accountId)
            hooks.after['core:player:joined']({ source = src, accountId = accountId })
        end

        it('expulse un compte banni pendant son chargement, avec le motif, et l\'inscrit au journal', function()
            playersBySource[3] = { source = 3, accountId = 7 }
            store.ban = BAN
            joined(3, 7)
            assert.same({ { src = '3', reason = bans.message(BAN) } }, dropped)
            assert.equal(1, #recorded)
            assert.equal(messages.logBanEnforced, recorded[1].action)
            assert.equal(7, recorded[1].target.accountId)
            assert.equal(42, recorded[1].details.ban)
            assert.equal('console', recorded[1].actor.rank.name)
        end)

        it('ne touche pas un compte sans ban', function()
            playersBySource[3] = { source = 3, accountId = 7 }
            joined(3, 7)
            assert.equal(1, store.calls)
            assert.same({}, dropped)
            assert.same({}, recorded)
        end)

        it('expulse avec un message clair quand les bans ne peuvent être lus, sans écrire au journal', function()
            playersBySource[3] = { source = 3, accountId = 7 }
            store.err = 'base injoignable'
            joined(3, 7)
            assert.same({ { src = '3', reason = messages.banCheckUnavailable } }, dropped)
            assert.same({}, recorded)
            assert.equal(1, #errors)
        end)

        it('ne fait rien pour un joueur parti ou un numéro repris par un autre compte', function()
            store.ban = BAN
            joined(3, 7)
            playersBySource[4] = { source = 4, accountId = 8 }
            joined(4, 7)
            assert.same({}, dropped)
            assert.same({}, recorded)
        end)

        it('ne consulte rien sans compte', function()
            joined(3, nil)
            assert.equal(0, store.calls)
        end)
    end)

    it('garde des libellés de journal dans les bornes du Registre', function()
        assert.truthy(#messages.logBanEnforced <= VavaAdmin.LOG_LIMITS.label)
    end)
end)
