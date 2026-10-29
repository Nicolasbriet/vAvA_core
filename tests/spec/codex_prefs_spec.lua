local helper = require('tests.helper')

describe('vava_codex préférences', function()
    local fit
    local LIMITS = { favorites = 2, recent = 3 }

    before_each(function()
        helper.reset()
        VavaCodex = nil
        helper.loadAll({
            'modules/vava_codex/shared/constants.lua',
            'modules/vava_codex/config.lua',
            'modules/vava_codex/shared/prefs.lua',
        })
        fit = VavaCodex.fitPrefs
    end)

    it('rend des préférences vides pour une valeur absente ou illisible', function()
        local values = { nil, false, 'texte', 12 }
        for i = 1, 4 do
            local prefs = fit(values[i], LIMITS, true)
            assert.same({ favorites = {}, recent = {}, keepOpen = true }, prefs)
        end
    end)

    it('garde tout sous les maximums', function()
        local value = {
            favorites = { 'metiers' },
            recent = { { name = 'me', at = 10 }, { name = 'metiers', action = 'voir', at = 5 } },
            keepOpen = false,
        }
        local prefs = fit(value, LIMITS, true)
        assert.same({ 'metiers' }, prefs.favorites)
        assert.same({ { name = 'me', at = 10 }, { name = 'metiers', action = 'voir', at = 5 } }, prefs.recent)
        assert.is_false(prefs.keepOpen)
    end)

    it('tronque un maximum abaissé : premiers signets, dernières pages les plus récentes', function()
        local value = {
            favorites = { 'a', 'b', 'c', 'd' },
            recent = { { name = 'r1', at = 5 }, { name = 'r2', at = 4 }, { name = 'r3', at = 3 }, { name = 'r4', at = 2 }, { name = 'r5', at = 1 } },
        }
        local prefs = fit(value, LIMITS, true)
        assert.same({ 'a', 'b' }, prefs.favorites)
        assert.equal(3, #prefs.recent)
        assert.equal('r1', prefs.recent[1].name)
        assert.equal('r3', prefs.recent[3].name)
    end)

    it('rend une valeur qui passe de nouveau le schéma du champ (taille des listes)', function()
        local value = { favorites = {}, recent = {} }
        for i = 1, 30 do
            value.favorites[i] = 'f' .. i
            value.recent[i] = { name = 'r' .. i, at = i }
        end
        local cfg = VavaCodex.config
        local prefs = fit(value, { favorites = cfg.favorites.max, recent = cfg.recent.max }, cfg.keepOpenDefault)
        assert.equal(cfg.favorites.max, #prefs.favorites)
        assert.equal(cfg.recent.max, #prefs.recent)
    end)

    it('ne partage aucune table avec la valeur lue (copie défensive)', function()
        local entry = { name = 'me', at = 1 }
        local value = { favorites = { 'me' }, recent = { entry } }
        local prefs = fit(value, LIMITS, true)
        prefs.recent[1].name = 'autre'
        prefs.favorites[1] = 'autre'
        assert.equal('me', entry.name)
        assert.equal('me', value.favorites[1])
    end)

    it('écarte les entrées illisibles sans dépasser les maximums', function()
        local value = { favorites = { 'a', 12, 'b', 'c' }, recent = { 'x', { name = 'r1', at = 1 }, 7, { name = 'r2', at = 2 } } }
        local prefs = fit(value, LIMITS, true)
        assert.same({ 'a', 'b' }, prefs.favorites)
        assert.same({ { name = 'r1', at = 1 }, { name = 'r2', at = 2 } }, prefs.recent)
    end)

    it('ignore un réglage qui n\'est pas un booléen', function()
        assert.is_true(fit({ keepOpen = 'non' }, LIMITS, true).keepOpen)
        assert.is_false(fit({ keepOpen = 1 }, LIMITS, false).keepOpen)
    end)
end)
