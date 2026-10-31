local helper = require('tests.helper')

-- Demande au Conseil (vava_pause 1.0.0, T-145 § 7.3) : logique pure de shared/council.lua.
describe('vava_pause : texte d\'une demande au Conseil', function()
    local council, opts

    before_each(function()
        helper.reset()
        VavaPause = nil
        helper.loadAll({
            'modules/vava_pause/shared/constants.lua',
            'modules/vava_pause/config.lua',
            'modules/vava_pause/shared/council.lua',
        })
        council = VavaPause.council
        local cfg = VavaPause.config.council
        opts = { minChars = cfg.minChars, maxBytes = VavaPause.MAX_COUNCIL_TEXT, maxLines = cfg.maxLines }
    end)

    it('compte en caractères : 9 accentués refusés, 10 acceptés', function()
        assert.same({ nil, 'too_short' }, { council.normalize('ééééééééé', opts) })
        assert.equal('éééééééééé', council.normalize('éééééééééé', opts))
    end)

    it('500 octets acceptés, 501 refusés', function()
        assert.is_string(council.normalize(string.rep('a', 500), opts))
        assert.same({ nil, 'invalid_text' }, { council.normalize(string.rep('a', 501), opts) })
    end)

    it('UTF-8 invalide refusé', function()
        assert.same({ nil, 'invalid_text' }, { council.normalize('bonjour le \255 Conseil', opts) })
    end)

    it('contrôles refusés : \\0, \\r, tabulation, C1', function()
        for _, text in ipairs({ 'bonjour\0le Conseil', 'bonjour\r\nle Conseil', 'bonjour\tle Conseil',
            'bonjour \194\133 le Conseil' }) do
            assert.same({ nil, 'invalid_text' }, { council.normalize(text, opts) })
        end
    end)

    it('12 lignes acceptées, 13 refusées', function()
        local twelve = table.concat({ 'une', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf', 'dix',
            'onze', 'douze' }, '\n')
        assert.is_string(council.normalize(twelve, opts))
        assert.same({ nil, 'invalid_text' }, { council.normalize(twelve .. '\ntreize', opts) })
    end)

    it('espaces répétés, bords et sauts de ligne répétés retirés', function()
        assert.equal('Un joueur me bloque\n\nà la porte',
            council.normalize('   Un   joueur  me bloque  \n\n\n\n   à la porte \n\n', opts))
    end)

    it('les sauts retirés ne comptent plus comme lignes', function()
        local text = 'Une demande\n\n\n\n\n\n\n\n\n\n\n\n\n\nbien longue'
        assert.equal('Une demande\n\nbien longue', council.normalize(text, opts))
    end)

    it('pas une chaîne : invalid_text', function()
        assert.same({ nil, 'invalid_text' }, { council.normalize(12, opts) })
    end)

    it('nature hors liste', function()
        for _, kind in ipairs({ 'question', 'player', 'bug', 'other' }) do assert.is_true(council.isKind(kind)) end
        assert.is_false(council.isKind('plainte'))
        assert.is_false(council.isKind(nil))
    end)
end)
