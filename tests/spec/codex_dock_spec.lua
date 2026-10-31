local helper = require('tests.helper')

-- Codex en panneau (vava_codex 1.7.0, T-145 § 9.3) : rectangle du livre donné par l'hôte, en vw et vh.
describe('vava_codex : rectangle du panneau', function()
    local rect

    before_each(function()
        helper.reset()
        VavaCodex = nil
        helper.loadAll({
            'modules/vava_codex/shared/constants.lua',
            'modules/vava_codex/config.lua',
            'modules/vava_codex/shared/dock.lua',
        })
        rect = VavaCodex.dock.rect
    end)

    it('rend une copie d\'un rectangle valide', function()
        local given = { left = 32.6, top = 10.7, width = 58.3, height = 71.1 }
        local clean = rect(given)
        assert.same(given, clean)
        assert.are_not.equal(given, clean)
    end)

    it('accepte les bords exacts : 0, 10 et 100', function()
        assert.is_table(rect({ left = 0, top = 0, width = 100, height = 100 }))
        assert.is_table(rect({ left = 90, top = 90, width = 10, height = 10 }))
    end)

    it('refuse ce qui n\'est pas une table, un champ manquant ou de mauvais type', function()
        for _, value in ipairs({ 'x', 12, true }) do
            local clean, code = rect(value)
            assert.is_nil(clean)
            assert.equal('invalid_rect', code)
        end
        assert.is_nil(rect(nil))
        assert.is_nil(rect({ left = 1, top = 1, width = 50 }))
        assert.is_nil(rect({ left = '1', top = 1, width = 50, height = 50 }))
    end)

    it('refuse NaN et l\'infini', function()
        assert.is_nil(rect({ left = 0 / 0, top = 1, width = 50, height = 50 }))
        assert.is_nil(rect({ left = 1, top = math.huge, width = 50, height = 50 }))
        assert.is_nil(rect({ left = 1, top = 1, width = -math.huge, height = 50 }))
    end)

    it('refuse un bord négatif et une taille sous 10', function()
        assert.is_nil(rect({ left = -0.1, top = 1, width = 50, height = 50 }))
        assert.is_nil(rect({ left = 1, top = -5, width = 50, height = 50 }))
        assert.is_nil(rect({ left = 1, top = 1, width = 9.9, height = 50 }))
        assert.is_nil(rect({ left = 1, top = 1, width = 50, height = 9 }))
    end)

    it('refuse un débordement à droite et en bas', function()
        assert.is_nil(rect({ left = 50, top = 1, width = 50.5, height = 50 }))
        assert.is_nil(rect({ left = 1, top = 60, width = 50, height = 41 }))
    end)

    it('refuse un champ en trop', function()
        local clean, code = rect({ left = 1, top = 1, width = 50, height = 50, zIndex = 9 })
        assert.is_nil(clean)
        assert.equal('invalid_rect', code)
    end)

    it('la config réserve le panneau à la bannière', function()
        assert.equal('vava_pause', VavaCodex.config.docked.host)
    end)
end)
