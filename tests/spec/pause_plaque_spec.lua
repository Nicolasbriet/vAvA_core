local helper = require('tests.helper')

-- Plaque du royaume (vava_pause 1.0.0, T-145 § 9.7) : logique pure de shared/plaque.lua, sur la vue client.
describe('vava_pause : plaque du royaume', function()
    local plaque, P

    before_each(function()
        helper.reset()
        helper.loadClientView('modules/vava_pause', 'VavaPause')
        helper.load('modules/vava_pause/shared/plaque.lua')
        plaque, P = VavaPause.plaque, VavaPause.config.plaque
    end)

    it('chaque bord des périodes', function()
        local expected = {
            [0] = 'Nuit', [4] = 'Nuit', [5] = 'Aube', [6] = 'Aube', [7] = 'Matin', [11] = 'Matin', [12] = 'Midi',
            [13] = 'Midi', [14] = 'Après-midi', [17] = 'Après-midi', [18] = 'Soir', [21] = 'Soir', [22] = 'Nuit',
            [23] = 'Nuit',
        }
        for hour, label in pairs(expected) do assert.equal(label, plaque.period(hour, P.periods), 'heure ' .. hour) end
    end)

    it('heure écrite, minuit compris', function()
        assert.equal('Soir, 19 h', plaque.time(19, P.periods, P.timeFormat))
        assert.equal('Nuit, 0 h', plaque.time(0, P.periods, P.timeFormat))
    end)

    it('heure invalide : rien', function()
        assert.is_nil(plaque.time(24, P.periods, P.timeFormat))
        assert.is_nil(plaque.time(-1, P.periods, P.timeFormat))
        assert.is_nil(plaque.time(12.5, P.periods, P.timeFormat))
        assert.is_nil(plaque.period(nil, P.periods))
    end)

    it('saison connue, inconnue ou absente', function()
        assert.equal('Automne', plaque.season('automne', P.seasons))
        assert.equal('Été', plaque.season('ete', P.seasons))
        assert.is_nil(plaque.season('mousson', P.seasons))
        assert.is_nil(plaque.season(nil, P.seasons))
    end)

    it('habitants : 0, 1, 28 ; invalide omis', function()
        assert.equal('0 habitants présents', plaque.people(0, P.people))
        assert.equal('1 habitant présent', plaque.people(1, P.people))
        assert.equal('28 habitants présents', plaque.people(28, P.people))
        assert.is_nil(plaque.people(-1, P.people))
        assert.is_nil(plaque.people(2.5, P.people))
        assert.is_nil(plaque.people(nil, P.people))
    end)

    it('chaque saison de vava_time a son libellé', function()
        for _, season in ipairs({ 'printemps', 'ete', 'automne', 'hiver' }) do
            assert.is_string(plaque.season(season, P.seasons))
        end
    end)
end)
