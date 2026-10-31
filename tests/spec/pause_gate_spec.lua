local helper = require('tests.helper')

-- Porte de la bannière (vava_pause 1.0.0, T-145 § 7.1 et décision 2) : logique pure de shared/gate.lua, sur la vue
-- client (constantes et config_client.lua seuls).
describe('vava_pause : porte de la bannière', function()
    local gate

    local function facts(overrides)
        local f = {
            open = false, character = true, faded = false, native = false, focused = false, now = 10000,
            lastFocusAt = nil, graceMs = 300, cuffed = false, downed = false, blocks = {},
        }
        for key, value in pairs(overrides or {}) do f[key] = value end
        return f
    end

    before_each(function()
        helper.reset()
        helper.loadClientView('modules/vava_pause', 'VavaPause')
        helper.load('modules/vava_pause/shared/gate.lua')
        gate = VavaPause.gate
    end)

    it('rien ne s\'y oppose : bannière entière', function()
        assert.same({ true, 'full' }, { gate.decide(facts()) })
    end)

    it('à terre : bannière réduite, pas un refus', function()
        assert.same({ true, 'downed' }, { gate.decide(facts({ downed = true })) })
    end)

    it('chaque raison seule, muette ou non', function()
        local cases = {
            { { open = true }, 'open', true },
            { { character = false }, 'no_character', true },
            { { faded = true }, 'faded', true },
            { { native = true }, 'native', true },
            { { focused = true }, 'busy', true },
            { { cuffed = true }, 'restrained', false },
            { { blocks = { ['vava_x:lien'] = 'restrained' } }, 'restrained', false },
            { { blocks = { ['vava_x:duel'] = 'combat' } }, 'combat', false },
            { { blocks = { ['vava_x:outil'] = 'other' } }, 'blocked', false },
        }
        for _, case in ipairs(cases) do
            local ok, reason, muted = gate.decide(facts(case[1]))
            assert.is_false(ok)
            assert.equal(case[2], reason)
            assert.equal(case[3], muted)
            assert.equal(case[3], gate.muted(reason))
        end
    end)

    it('ordre des raisons', function()
        assert.equal('open', select(2, gate.decide(facts({ open = true, character = false, faded = true }))))
        assert.equal('no_character', select(2, gate.decide(facts({ character = false, faded = true, native = true }))))
        assert.equal('faded', select(2, gate.decide(facts({ faded = true, native = true, focused = true }))))
        assert.equal('native', select(2, gate.decide(facts({ native = true, focused = true, cuffed = true }))))
        assert.equal('busy', select(2, gate.decide(facts({ focused = true, cuffed = true }))))
        assert.equal('restrained', select(2, gate.decide(facts({ cuffed = true, blocks = { a = 'combat', b = 'other' } }))))
        assert.equal('combat', select(2, gate.decide(facts({ blocks = { a = 'combat', b = 'other' } }))))
        -- à terre et en combat (blocage) : le combat refuse, la bannière réduite ne s'ouvre pas
        assert.equal('combat', select(2, gate.decide(facts({ downed = true, blocks = { a = 'combat' } }))))
        assert.equal('restrained', select(2, gate.decide(facts({ downed = true, cuffed = true }))))
    end)

    it('délai de grâce après un focus : 299 ms refusé, 301 ms ouvert', function()
        local ok, reason, muted = gate.decide(facts({ lastFocusAt = 10000 - 299 }))
        assert.is_false(ok)
        assert.equal('busy', reason)
        assert.is_true(muted)
        assert.is_true((gate.decide(facts({ lastFocusAt = 10000 - 301 }))))
    end)

    it('sortes des blocages : inconnue comptée comme « other »', function()
        assert.same({ restrained = false, combat = false, other = false }, gate.blockKinds({}))
        assert.same({ restrained = true, combat = false, other = true }, gate.blockKinds({ a = 'restrained', b = 'bizarre' }))
        assert.same({ restrained = false, combat = false, other = false }, gate.blockKinds(nil))
    end)

    it('un même refus n\'est pas répété avant noticeMs ; les muets jamais', function()
        local shown = {}
        assert.is_true(gate.shouldNotify(shown, 'combat', 1000, 3000))
        assert.is_false(gate.shouldNotify(shown, 'combat', 3999, 3000))
        assert.is_true(gate.shouldNotify(shown, 'restrained', 3999, 3000))
        assert.is_true(gate.shouldNotify(shown, 'combat', 4000, 3000))
        assert.is_false(gate.shouldNotify(shown, 'busy', 1000, 3000))
        assert.is_nil(shown.busy)
    end)

    it('chaque refus non muet a son message dans config_client.lua', function()
        for _, reason in ipairs({ 'restrained', 'combat', 'blocked' }) do
            assert.is_string(VavaPause.config.messages.refused[reason])
        end
        assert.is_string(VavaPause.config.messages.interrupted)
        assert.is_nil(VavaPause.config.rateLimits)   -- config.lua n'est pas dans la vue client
    end)
end)
