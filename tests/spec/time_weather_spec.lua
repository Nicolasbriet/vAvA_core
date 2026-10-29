local helper = require('tests.helper')

--- Aléa fixe : rend toujours la même valeur.
local function fixed(value)
    return function() return value end
end

describe('vava_time météo', function()
    local rules, cfg

    before_each(function()
        helper.reset()
        VavaTime = nil
        helper.loadAll({
            'modules/vava_time/shared/constants.lua',
            'modules/vava_time/config.lua',
            'modules/vava_time/shared/weather.lua',
        })
        rules = VavaTime.weatherRules
        cfg = VavaTime.config.weather
    end)

    --- Copie de la config de la météo avec quelques clés remplacées.
    local function variant(overrides)
        local copy = {}
        for key, value in pairs(cfg) do copy[key] = value end
        for key, value in pairs(overrides) do copy[key] = value end
        return copy
    end

    local SEASONS = { 'printemps', 'ete', 'automne', 'hiver' }

    it('connaît chaque ciel, son nom GTA et ses successeurs', function()
        for _, def in ipairs(cfg.types) do
            assert.is_string(def.gta)
            assert.is_string(def.label)
            assert.is_string(def.phrase)
            assert.is_table(cfg.next[def.id], def.id .. ' sans successeurs')
            for _, id in ipairs(cfg.next[def.id]) do assert.is_table(rules.get(id), id .. ' inconnu') end
        end
        for _, season in ipairs(SEASONS) do
            for id in pairs(cfg.seasons[season]) do assert.is_table(rules.get(id), id .. ' inconnu') end
        end
        assert.is_nil(rules.get('grele'))
        assert.equal(#cfg.types, #rules.ids())
    end)

    it('tire selon les poids, dans l\'ordre des successeurs', function()
        -- après un ciel clair en été : clair 4, soleil 4, nuages 2, brume 1 (le brouillard n'est pas de saison)
        local list, total = rules.candidates('clair', 'ete')
        assert.equal(11, total)
        assert.same({ 'clair', 'soleil', 'nuages', 'brume' }, { list[1].id, list[2].id, list[3].id, list[4].id })
        assert.equal('clair', rules.pick('clair', 'ete', fixed(0)))
        assert.equal('soleil', rules.pick('clair', 'ete', fixed(0.5)))
        assert.equal('nuages', rules.pick('clair', 'ete', fixed(0.8)))
        assert.equal('brume', rules.pick('clair', 'ete', fixed(0.99)))
    end)

    it('respecte les successeurs : pas d\'orage sous un ciel clair', function()
        for step = 0, 99 do
            local id = rules.pick('clair', 'automne', fixed(step / 100))
            local allowed = false
            for _, successor in ipairs(cfg.next.clair) do allowed = allowed or successor == id end
            assert.is_true(allowed, id)
            assert.is_not.equal('orage', id)
        end
    end)

    it('ne tire jamais de neige hors de l\'hiver', function()
        for _, season in ipairs({ 'printemps', 'ete', 'automne' }) do
            for _, current in ipairs(rules.ids()) do
                for step = 0, 99 do
                    local id = rules.pick(current, season, fixed(step / 100))
                    assert.is_falsy(rules.get(id).snow, ('%s après %s en %s'):format(id, current, season))
                    assert.is_true(rules.allowed(id, season))
                end
            end
        end
    end)

    it('tire de la neige en hiver, jamais la neige au sol, et aucune avec snow = false', function()
        local snowed = false
        for _, current in ipairs(rules.ids()) do
            for step = 0, 99 do
                local id = rules.pick(current, 'hiver', fixed(step / 100))
                snowed = snowed or rules.get(id).snow == true
                assert.is_not.equal('neige_au_sol', id)
            end
        end
        assert.is_true(snowed)
        local noSnow = variant({ snow = false })
        for _, current in ipairs(rules.ids()) do
            for step = 0, 99 do
                local id = rules.pick(current, 'hiver', fixed(step / 100), noSnow)
                assert.is_falsy(rules.get(id, noSnow).snow, id)
            end
        end
        assert.is_false(rules.allowed('neige', 'hiver', noSnow))
        assert.is_true(rules.allowed('neige', 'hiver'))
    end)

    it('se rabat sur les ciels de la saison quand aucun successeur ne l\'est', function()
        -- après une tempête de neige au printemps : ni neige ni neige légère ne sont de saison
        local list, total = rules.candidates('tempete', 'printemps')
        assert.is_true(total > 0)
        assert.equal(#list, 8)
        for step = 0, 99 do
            local id = rules.pick('tempete', 'printemps', fixed(step / 100))
            assert.is_true(rules.allowed(id, 'printemps'), id)
        end
        -- ciel inconnu ou absent : tous les ciels de la saison
        assert.is_string(rules.pick(nil, 'ete', fixed(0.3)))
        assert.is_string(rules.pick('grele', 'ete', fixed(0.3)))
    end)

    it('ne tire rien dans une saison sans ciel', function()
        assert.is_nil(rules.pick('clair', 'inconnue', fixed(0.5)))
        assert.is_nil(rules.pick('clair', nil, fixed(0.5)))
        assert.equal(0, rules.weight('clair', 'inconnue'))
    end)

    it('ignore un poids nul, négatif ou invalide', function()
        local odd = variant({ seasons = { ete = { clair = 0, soleil = -2, nuages = 0 / 0, couvert = 'x', pluie = 1 } } })
        for step = 0, 9 do
            assert.equal('pluie', rules.pick('clair', 'ete', fixed(step / 10), odd))
        end
    end)

    it('donne une durée dans la fourchette, propre à l\'orage', function()
        assert.equal(25 * 60, rules.duration('pluie', fixed(0)))
        assert.equal(37 * 60 + 30, rules.duration('pluie', fixed(0.5)))
        assert.is_true(rules.duration('pluie', fixed(0.9999)) < 50 * 60)
        assert.equal(10 * 60, rules.duration('orage', fixed(0)))
        assert.is_true(rules.duration('orage', fixed(0.9999)) < 20 * 60)
        assert.equal(60, rules.duration('pluie', fixed(0), variant({ durationMinutes = { 0, 0 } })))
    end)

    it('mesure l\'avancement d\'une transition', function()
        assert.equal(0.5, rules.progress(100, 90, 145))
        assert.equal(0, rules.progress(100, 90, 50))
        assert.equal(1, rules.progress(100, 90, 500))
        assert.equal(1, rules.progress(100, 0, 100))
        assert.equal(1, rules.progress(100, nil, 100))
    end)
end)
