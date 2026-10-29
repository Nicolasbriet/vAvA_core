local helper = require('tests.helper')

describe('vava_health seuil de mise à terre', function()
    local vitality, DOWN

    before_each(function()
        helper.reset()
        VavaHealth = nil
        helper.loadAll({
            'modules/vava_health/shared/constants.lua',
            'modules/vava_health/config.lua',
            'modules/vava_health/shared/vitality.lua',
        })
        vitality = VavaHealth.vitality
        DOWN = VavaHealth.config.downThreshold
    end)

    it('couche le ped à 0 pour une vie nulle, jamais sur le seuil', function()
        assert.equal(0, vitality.toGame(0, 200, DOWN))
        assert.equal(0, vitality.toGame(-0.5, 200, DOWN))
        for maxHealth = DOWN - 10, DOWN + 300, 7 do
            for step = 0, 100 do
                assert.are_not.equal(DOWN, vitality.toGame(step / 100, maxHealth, DOWN))
            end
        end
    end)

    it('laisse debout, au-dessus du seuil, toute vie non nulle', function()
        assert.equal(DOWN + 1, vitality.toGame(0.001, 200, DOWN))
        assert.equal(DOWN + 25, vitality.toGame(0.25, 200, DOWN))
        assert.equal(200, vitality.toGame(1, 200, DOWN))
        -- modèle dont la vie maximale ne dépasse pas le seuil : un point au-dessus quand même
        assert.equal(DOWN + 1, vitality.toGame(0.5, DOWN, DOWN))
    end)

    it('met à terre au seuil et dessous, pas au-dessus', function()
        assert.is_true(vitality.fallen(0, DOWN))
        assert.is_true(vitality.fallen(DOWN - 1, DOWN))
        assert.is_true(vitality.fallen(DOWN, DOWN))
        assert.is_false(vitality.fallen(DOWN + 1, DOWN))
    end)

    it('recouche un ped à terre resté au seuil ou au-dessus', function()
        assert.is_true(vitality.laidDown(0, DOWN))
        assert.is_true(vitality.laidDown(DOWN - 1, DOWN))
        assert.is_false(vitality.laidDown(DOWN, DOWN))
        assert.is_false(vitality.laidDown(DOWN + 50, DOWN))
    end)

    it('au seuil seulement, à terre pour le serveur sans être couché (le client doit le coucher)', function()
        for health = 0, 300 do
            local pending = vitality.fallen(health, DOWN) and not vitality.laidDown(health, DOWN)
            assert.equal(health == DOWN, pending)
        end
    end)
end)
