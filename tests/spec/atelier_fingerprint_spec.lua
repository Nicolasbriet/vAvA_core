local helper = require('tests.helper')

-- Empreinte de l'Atelier (T-100) : copie de vava_codex/shared/fingerprint.lua. Mêmes vecteurs que
-- codex_fingerprint_spec.lua, et pour toute valeur la même empreinte que celle du Codex.
describe('vava_atelier empreinte', function()
    local fingerprint, codexFingerprint

    before_each(function()
        helper.reset()
        VavaAtelier, VavaCodex = nil, nil
        helper.loadAll({
            'modules/vava_codex/shared/constants.lua',
            'modules/vava_codex/shared/fingerprint.lua',
            'modules/vava_atelier/shared/constants.lua',
            'modules/vava_atelier/shared/bounds.lua',
            'modules/vava_atelier/shared/fingerprint.lua',
        })
        fingerprint, codexFingerprint = VavaAtelier.fingerprint, VavaCodex.fingerprint
    end)

    after_each(function()
        VavaCodex = nil
    end)

    it('rend 16 chiffres hexadécimaux, au motif accepté par le RPC', function()
        for _, value in ipairs({ '', 'Atelier', 0, -1, 1.5, true, false, {}, { a = { 1, 2, { b = 'c' } } } }) do
            local version = fingerprint(value)
            assert.equal(VavaAtelier.VERSION_LENGTH, #version)
            assert.truthy(version:find(VavaAtelier.VERSION_PATTERN))
        end
    end)

    it('suit FNV-1a 64 bits sur le codage canonique (valeurs de référence du Codex)', function()
        assert.equal('818753195c48e144', fingerprint(''))
        assert.equal('37e0166994ef71cc', fingerprint('Codex'))
        assert.equal('3ec51810f8a1ab41', fingerprint({ 'a', 'b' }))
        assert.equal('46330131d62edf53', fingerprint(string.rep('abcdefghij', 100)))
        assert.equal('b5225d328897b74d', fingerprint(string.rep('Récolte · nœud ', 20)))
    end)

    it('donne la même empreinte que le Codex pour toute valeur', function()
        local values = {
            '', 'Forêt de Brume', 42, -7, 0.1, true, false, {}, { 1, 2, 3 },
            { families = { { id = 'monde', label = 'Le monde' } }, cards = { { editor = 'a:b', upcoming = false, tag = '2 panneaux' } } },
            { [true] = 1, [false] = 2, [3] = 'x', [0.5] = 'y', z = 4 },
        }
        for i, value in ipairs(values) do
            assert.equal(codexFingerprint(value), fingerprint(value), 'valeur ' .. i)
        end
    end)

    it('ne dépend pas de l\'ordre dans lequel une table a été remplie', function()
        local first = { label = 'Panneaux', kinds = { { id = 'panneau' }, { id = 'affiche' } }, hasCompare = true }
        local second = {}
        for _, key in ipairs({ 'hasCompare', 'kinds', 'label' }) do second[key] = first[key] end
        assert.equal(fingerprint(first), fingerprint(second))
        assert.are_not.equal(fingerprint({ 1, 2 }), fingerprint({ 2, 1 }))
        assert.are_not.equal(fingerprint('1'), fingerprint(1))
    end)

    it('refuse sans lever d\'erreur ce qu\'il ne sait pas coder', function()
        local version, err = fingerprint(function() end)
        assert.is_nil(version)
        assert.equal('unsupported', err)
        local loop = {}
        loop.self = loop
        assert.equal('cycle', select(2, fingerprint(loop)))
        local deep = {}
        local node = deep
        for _ = 1, 20 do
            node.next = {}
            node = node.next
        end
        assert.equal('too_deep', select(2, fingerprint(deep)))
    end)
end)
