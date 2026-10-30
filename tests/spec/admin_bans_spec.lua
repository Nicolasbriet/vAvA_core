local helper = require('tests.helper')

-- Bans du Registre du Conseil (modules/vava_admin/server/bans.lua, T-026) :
--   - verdict pur `bans.decide` : une base qui ne répond pas ne laisse jamais passer un compte connu ; une première
--     venue (aucun compte) n'a rien à vérifier ;
--   - démarrage : lecture d'essai de la table des bans, le module échoue si elle est illisible ;
--   - hook before `core:player:connecting` : banni refusé avec le motif, bans illisibles refusés avec un message
--     clair ;
--   - hook after `core:player:joined` et relecture des joueurs déjà en jeu au démarrage (`bans.sweep`) : banni
--     expulsé (au journal) ; base muette : seconde lecture, puis `banRecheck.onError` (kick ou keep) ; rien pour un
--     joueur parti ou un numéro repris ; un joueur pas encore repris par le core est relu au tour suivant.

describe('vava_admin bans', function()
    local bans, messages, store, hooks, dropped, recorded, errors, playersBySource, connected, waits

    local BAN = { id = 42, reason = 'triche', ['until'] = '01/11/2026 12:00' }

    before_each(function()
        helper.reset()
        dropped, recorded, errors, playersBySource, connected, waits = {}, {}, {}, {}, {}, {}
        hooks = { before = {}, after = {} }
        -- `queue` : réponses successives { ban, err } ; vide, la réponse fixe `ban`, `err`
        store = { calls = 0, queue = {} }
        function store.activeBan(accountId)
            store.calls = store.calls + 1
            store.lastAccount = accountId
            local answer = table.remove(store.queue, 1)
            if answer then return answer[1], answer[2] end
            return store.ban, store.err
        end
        _G.DropPlayer = function(src, reason) dropped[#dropped + 1] = { src = src, reason = reason } end
        _G.GetPlayers = function()
            local ids = {}
            for _, src in ipairs(connected) do ids[#ids + 1] = tostring(src) end
            return ids
        end
        _G.DoesPlayerExist = function(src)
            for _, id in ipairs(connected) do if id == tonumber(src) then return true end end
            return false
        end
        _G.Wait = function(ms) waits[#waits + 1] = ms end

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
        store.calls = 0
    end)

    after_each(function()
        _G.DropPlayer, _G.GetPlayers, _G.DoesPlayerExist, _G.VavaAdmin = nil, nil, nil, nil
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

    describe('démarrage', function()
        it('échoue sans brancher de vérification quand la table des bans est illisible', function()
            hooks.before, hooks.after = {}, {}
            store.err = "Table 'vava_admin_bans' doesn't exist"
            local ok, err = bans.start()
            assert.is_false(ok)
            assert.truthy(err:find('table des bans illisible', 1, true))
            assert.is_nil(hooks.before['core:player:connecting'])
            assert.is_nil(hooks.after['core:player:joined'])
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
            assert.equal(messages.whenJoined, recorded[1].details.moment)
            assert.equal('console', recorded[1].actor.rank.name)
        end)

        it('ne touche pas un compte sans ban, sans attendre', function()
            playersBySource[3] = { source = 3, accountId = 7 }
            joined(3, 7)
            assert.equal(1, store.calls)
            assert.same({}, dropped)
            assert.same({}, recorded)
            assert.same({}, waits)
        end)

        it('relit une seconde fois après retryMs avant de conclure : un hoquet passager n\'expulse personne', function()
            playersBySource[3] = { source = 3, accountId = 7 }
            store.queue = { { nil, 'hoquet' } }
            joined(3, 7)
            assert.equal(2, store.calls)
            assert.same({ VavaAdmin.config.banRecheck.retryMs }, waits)
            assert.same({}, dropped)
            assert.same({}, errors)
        end)

        it('trouve le ban à la seconde lecture et expulse', function()
            playersBySource[3] = { source = 3, accountId = 7 }
            store.queue = { { nil, 'hoquet' }, { BAN, nil } }
            joined(3, 7)
            assert.same({ { src = '3', reason = bans.message(BAN) } }, dropped)
        end)

        it('expulse avec un message clair (onError = kick) quand les deux lectures échouent, sans journal', function()
            playersBySource[3] = { source = 3, accountId = 7 }
            store.err = 'base injoignable'
            joined(3, 7)
            assert.equal(2, store.calls)
            assert.same({ { src = '3', reason = messages.banCheckUnavailable } }, dropped)
            assert.same({}, recorded)
            assert.equal(1, #errors)
        end)

        it('laisse le joueur en jeu et l\'écrit à la console quand onError = keep', function()
            VavaAdmin.config.banRecheck.onError = 'keep'
            playersBySource[3] = { source = 3, accountId = 7 }
            store.err = 'base injoignable'
            joined(3, 7)
            assert.same({}, dropped)
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

        it('ne relit pas un joueur parti pendant l\'attente de la seconde lecture', function()
            playersBySource[3] = { source = 3, accountId = 7 }
            _G.Wait = function() playersBySource[3] = nil end
            helper.load('modules/vava_admin/server/bans.lua')
            assert.is_true(VavaAdmin.bans.start())
            store.err = 'base injoignable'
            store.calls = 0
            hooks.after['core:player:joined']({ source = 3, accountId = 7 })
            assert.equal(1, store.calls)
            assert.same({}, dropped)
        end)

        it('ne consulte rien sans compte', function()
            joined(3, nil)
            assert.equal(0, store.calls)
        end)
    end)

    describe('au démarrage du Registre', function()
        it('relit chaque joueur déjà en jeu et expulse les bannis, au journal', function()
            connected = { 3, 4 }
            playersBySource[3] = { source = 3, accountId = 7 }
            playersBySource[4] = { source = 4, accountId = 8 }
            store.queue = { { BAN, nil }, { nil, nil } }
            bans.sweep()
            assert.equal(2, store.calls)
            assert.same({ { src = '3', reason = bans.message(BAN) } }, dropped)
            assert.equal(messages.whenSwept, recorded[1].details.moment)
        end)

        it('attend qu\'un joueur soit repris par le core (core redémarré) avant de le relire', function()
            connected = { 3 }
            store.ban = BAN
            _G.Wait = function(ms)
                waits[#waits + 1] = ms
                playersBySource[3] = { source = 3, accountId = 7 }
            end
            helper.load('modules/vava_admin/server/bans.lua')
            VavaAdmin.bans.start()
            VavaAdmin.bans.sweep()
            assert.same({ VavaAdmin.config.banRecheck.sweepRetryMs }, waits)
            assert.equal(1, #dropped)
        end)

        it('abandonne après sweepAttempts tours un joueur jamais repris, et oublie celui qui est parti', function()
            connected = { 3, 5 }
            _G.Wait = function(ms)
                waits[#waits + 1] = ms
                connected = { 3 }
            end
            helper.load('modules/vava_admin/server/bans.lua')
            VavaAdmin.bans.start()
            store.calls = 0
            VavaAdmin.bans.sweep()
            assert.equal(VavaAdmin.config.banRecheck.sweepAttempts - 1, #waits)
            assert.equal(0, store.calls)
            assert.same({}, dropped)
        end)
    end)

    it('garde des libellés de journal dans les bornes du Registre', function()
        assert.truthy(#messages.logBanEnforced <= VavaAdmin.LOG_LIMITS.label)
        assert.truthy(#messages.whenSwept <= VavaAdmin.LOG_LIMITS.value)
    end)
end)
