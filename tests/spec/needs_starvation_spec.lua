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

    -- Avec vava_health (T-029) : le serveur passe à l'export damage la part de la vie au-dessus du seuil que représente
    -- la perte. Valeurs documentées : README du module, § À zéro (2 points pour la faim, 4 pour la soif, 6 les deux ;
    -- vie GTA 200, seuil 100 : 2 %, 4 %, 6 % de la vie).
    describe('part de la vie retirée par le serveur', function()
        local function near(expected, actual)
            assert.is_true(math.abs(expected - actual) < 1e-9, ('attendu %s, obtenu %s'):format(expected, actual))
        end

        it('rapporte la perte à la vie au-dessus du seuil (200 → 100 : 2 %, 4 %, 6 %)', function()
            local down = health.downThreshold
            assert.equal(100, down)
            near(0.02, starvation.share(2, 200, down))
            near(0.04, starvation.share(4, 200, down))
            near(0.06, starvation.share(6, 200, down))
        end)

        it('reprend les pertes de la config : faim 2, soif 4', function()
            local byName = {}
            for _, need in ipairs(VavaNeeds.config.needs) do byName[need.name] = need.damage end
            assert.equal(2, byName.hunger)
            assert.equal(4, byName.thirst)
        end)

        it('suit une vie maximale différente (300 → 200 au-dessus du seuil : 6 points = 3 %)', function()
            near(0.03, starvation.share(6, 300, 100))
        end)

        it('plafonne la part à 1', function()
            assert.equal(1, starvation.share(150, 200, 100))
            assert.equal(1, starvation.share(100, 200, 100))
        end)

        it('ne retire rien pour une perte nulle, négative ou invalide', function()
            assert.is_nil(starvation.share(0, 200, 100))
            assert.is_nil(starvation.share(-4, 200, 100))
            assert.is_nil(starvation.share(0 / 0, 200, 100))
            assert.is_nil(starvation.share(math.huge, 200, 100))
            assert.is_nil(starvation.share('4', 200, 100))
            assert.is_nil(starvation.share(nil, 200, 100))
        end)

        it('ne retire rien quand la vie maximale n’est pas au-dessus du seuil ou est invalide', function()
            assert.is_nil(starvation.share(4, 100, 100))
            assert.is_nil(starvation.share(4, 0, 100))
            assert.is_nil(starvation.share(4, 0 / 0, 100))
            assert.is_nil(starvation.share(4, math.huge, 100))
            assert.is_nil(starvation.share(4, 200, 0 / 0))
        end)
    end)
end)
