local helper = require('tests.helper')

-- Demandes au Conseil (vava_admin 1.10.0, T-145 § 7.3) : logique pure de shared/requests.lua.
describe('vava_admin : demandes au Conseil', function()
    local rules
    local MEMORY = 900000

    before_each(function()
        helper.reset()
        VavaAdmin = nil
        helper.loadAll({
            'modules/vava_admin/shared/constants.lua',
            'modules/vava_admin/config.lua',
            'modules/vava_admin/shared/requests.lua',
        })
        rules = VavaAdmin.requestRules
    end)

    describe('statusOf', function()
        it('aucune demande : nil', function()
            assert.is_nil(rules.statusOf({}, nil, 7, 100000, MEMORY))
        end)

        it('demande envoyée : sent, âge en secondes', function()
            local open = { [12] = { id = 12, accountId = 7, kind = 'question', at = 1000 } }
            assert.same({ id = 12, kind = 'question', state = 'sent', age = 180 }, rules.statusOf(open, nil, 7, 181500, MEMORY))
        end)

        it('demande prise en charge : claimed', function()
            local open = { [12] = { id = 12, accountId = 7, kind = 'bug', at = 1000, claimedBy = 'Gardien X' } }
            assert.equal('claimed', rules.statusOf(open, nil, 7, 2000, MEMORY).state)
        end)

        it('ignore les demandes d\'un autre compte', function()
            local open = { [12] = { id = 12, accountId = 8, kind = 'bug', at = 1000 } }
            assert.is_nil(rules.statusOf(open, nil, 7, 2000, MEMORY))
        end)

        it('deux ouvertes : la plus récente', function()
            local open = {
                [12] = { id = 12, accountId = 7, kind = 'bug', at = 1000, claimedBy = 'Gardien X' },
                [15] = { id = 15, accountId = 7, kind = 'player', at = 5000 },
            }
            local status = rules.statusOf(open, nil, 7, 6000, MEMORY)
            assert.equal(15, status.id)
            assert.equal('sent', status.state)
        end)

        it('une ouverte passe avant la dernière close', function()
            local open = { [15] = { id = 15, accountId = 7, kind = 'other', at = 5000 } }
            local closed = { id = 12, kind = 'bug', at = 5500 }
            assert.equal(15, rules.statusOf(open, closed, 7, 6000, MEMORY).id)
        end)

        it('close : gardée 14 min 59 s, oubliée à 15 min 1 s', function()
            local closed = { id = 12, kind = 'bug', at = 10000 }
            local status = rules.statusOf({}, closed, 7, 10000 + 899000, MEMORY)
            assert.same({ id = 12, kind = 'bug', state = 'closed', age = 899 }, status)
            assert.is_nil(rules.statusOf({}, closed, 7, 10000 + 901000, MEMORY))
        end)
    end)

    it('openCount compte les demandes ouvertes du seul compte', function()
        local open = {
            [1] = { id = 1, accountId = 7 }, [2] = { id = 2, accountId = 8 }, [3] = { id = 3, accountId = 7 },
        }
        assert.equal(2, rules.openCount(open, 7))
        assert.equal(0, rules.openCount(open, 9))
    end)

    describe('roundPosition', function()
        it('arrondit au mètre', function()
            assert.same({ x = 215, y = -812, z = 31 }, rules.roundPosition({ x = 214.6, y = -812.4, z = 30.5 }))
        end)

        it('refuse NaN, l\'infini et une coordonnée manquante', function()
            assert.is_nil(rules.roundPosition({ x = 0 / 0, y = 1, z = 1 }))
            assert.is_nil(rules.roundPosition({ x = 1, y = math.huge, z = 1 }))
            assert.is_nil(rules.roundPosition({ x = 1, y = 1 }))
            assert.is_nil(rules.roundPosition(nil))
        end)
    end)

    describe('witnesses', function()
        local names = { [2] = 'Mordred Vane', [3] = 'Ysolde Marchal', [4] = 'Aude Ferrand' }
        local function identify(src)
            if not names[src] then return nil end
            return src * 10, names[src]
        end

        it('garde compte et nom, auteur exclu, inconnus sautés', function()
            assert.same({ { accountId = 20, name = 'Mordred Vane' }, { accountId = 30, name = 'Ysolde Marchal' } },
                rules.witnesses({ 1, 2, 9, 3 }, 1, 8, identify))
        end)

        it('borné à max', function()
            assert.equal(2, #rules.witnesses({ 2, 3, 4 }, 1, 2, identify))
        end)

        it('liste absente : aucun témoin', function()
            assert.same({}, rules.witnesses(nil, 1, 8, identify))
        end)
    end)

    it('la config admet la bannière et les quatre natures', function()
        local requests = VavaAdmin.config.requests
        assert.same({ 'vava_pause' }, requests.callers)
        assert.same({ 'question', 'player', 'bug', 'other' }, requests.kinds)
        for _, kind in ipairs(requests.kinds) do assert.is_string(VavaAdmin.config.messages.requestKinds[kind]) end
        assert.is_string(VavaAdmin.config.messages.requestNew:format('Question', 12, 'Éloïse'))
    end)
end)
