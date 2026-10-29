local helper = require('tests.helper')

describe('vava_needs perte de vie d\'un besoin épuisé', function()
    local starvation, health

    before_each(function()
        helper.reset()
        VavaNeeds = nil
        helper.loadAll({
            'modules/vava_needs/shared/constants.lua',
            'modules/vava_needs/config.lua',
            'modules/vava_needs/shared/starvation.lua',
        })
        starvation = VavaNeeds.starvation
        health = VavaNeeds.config.health
    end)

    local function lose(current, amount, downing)
        return starvation.health(current, amount, 200, health.downThreshold, health.floor, downing)
    end

    it('retire la perte au-dessus du seuil', function()
        assert.equal(194, lose(200, 6, true))
        assert.equal(194, lose(200, 6, false))
    end)

    it('avec la mise à terre, couche le ped (0) dès que la perte atteint le seuil', function()
        local down = health.downThreshold
        assert.equal(0, lose(down + 6, 6, true))
        assert.equal(0, lose(down + 2, 6, true))
        assert.equal(down + 1, lose(down + 7, 6, true))
    end)

    it('ne pose jamais une vie exactement sur le seuil quand la mise à terre tourne', function()
        local down = health.downThreshold
        for current = down + 1, 200 do
            for amount = 1, 12 do
                assert.are_not.equal(down, lose(current, amount, true))
            end
        end
    end)

    it('sans la mise à terre, s\'arrête au plancher', function()
        local down = health.downThreshold
        local floor = math.ceil(down + health.floor * (200 - down))
        assert.equal(floor, lose(floor + 2, 6, false))
        assert.is_nil(lose(floor, 6, false))
    end)

    it('ne fait rien au seuil ou dessous', function()
        local down = health.downThreshold
        assert.is_nil(lose(down, 6, true))
        assert.is_nil(lose(0, 6, true))
    end)
end)
