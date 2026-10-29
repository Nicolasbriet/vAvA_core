local helper = require('tests.helper')

local function fixed(value)
    return function() return value end
end

describe('vava_time nuits de gel', function()
    local rules, cfg

    before_each(function()
        helper.reset()
        VavaTime = nil
        helper.loadAll({
            'modules/vava_time/shared/constants.lua',
            'modules/vava_time/config.lua',
            'modules/vava_time/shared/frost.lua',
        })
        rules = VavaTime.frostRules
        cfg = VavaTime.config.frost
    end)

    it('ne gèle qu\'en hiver, selon la probabilité de la config', function()
        assert.is_true(rules.chance('hiver') > 0)
        for _, season in ipairs({ 'printemps', 'ete', 'automne' }) do
            assert.equal(0, rules.chance(season))
            assert.is_false(rules.night(season, 1, false, fixed(0)).frosty)
        end
        assert.is_true(rules.night('hiver', 1, false, fixed(0)).frosty)
        assert.is_false(rules.night('hiver', 1, false, fixed(0.999)).frosty)
        assert.equal(0, rules.chance(nil))
    end)

    it('borne et ignore un réglage invalide', function()
        assert.equal(1, rules.chance('hiver', { seasons = { hiver = 3 } }))
        assert.equal(0, rules.chance('hiver', { seasons = { hiver = 0 / 0 } }))
        assert.equal(0, rules.chance('hiver', { seasons = { hiver = 'souvent' } }))
        assert.equal(0, rules.chance('hiver', { seasons = { hiver = -1 } }))
    end)

    it('avertit au soir puis fait tomber le gel à la tombée de la nuit, une seule fois chacun', function()
        local night = rules.night('hiver', 0, false, fixed(0))
        assert.same({ false, false }, { rules.due(night, cfg.warnHour - 0.01) })
        assert.same({ true, false }, { rules.due(night, cfg.warnHour) })
        assert.same({ false, false }, { rules.due(night, cfg.warnHour + 1) })
        assert.same({ false, true }, { rules.due(night, cfg.hour) })
        assert.same({ false, false }, { rules.due(night, 23.9) })
    end)

    it('rend les deux moments ensemble quand l\'heure saute au-delà du gel', function()
        local night = rules.night('hiver', 10, false, fixed(0))
        assert.same({ true, true }, { rules.due(night, cfg.hour + 0.5) })
    end)

    it('ne rejoue rien de ce qui était passé au démarrage', function()
        local late = rules.night('hiver', cfg.hour + 1, true, fixed(0))
        assert.same({ false, false }, { rules.due(late, cfg.hour + 1) })
        local evening = rules.night('hiver', cfg.warnHour + 1, true, fixed(0))
        assert.same({ false, true }, { rules.due(evening, cfg.hour) })
    end)

    it('ne fait rien une nuit sans gel', function()
        local night = rules.night('hiver', 0, false, fixed(0.999))
        assert.same({ false, false }, { rules.due(night, 23) })
    end)
end)
