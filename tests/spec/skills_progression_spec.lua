local helper = require('tests.helper')

describe('vava_skills progression', function()
    local progression

    before_each(function()
        helper.reset()
        VavaSkills = nil
        helper.loadAll({
            'modules/vava_skills/shared/constants.lua',
            'modules/vava_skills/config.lua',
            'modules/vava_skills/shared/progression.lua',
        })
        progression = VavaSkills.progression
    end)

    it('suit la courbe documentée floor(50 + 1,5 × n²)', function()
        assert.equal(50, progression.xpToNext(0))
        assert.equal(5450, progression.xpToNext(60))
        assert.equal(14751, progression.xpToNext(99))
    end)

    it('donne un rang croissant avec le niveau', function()
        local previous = progression.rankOf(0).min
        for level = 1, 100 do
            local rank = progression.rankOf(level)
            assert.is_true(rank.min >= previous)
            assert.is_true(rank.min <= level)
            previous = rank.min
        end
    end)
end)
