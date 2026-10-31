local helper = require('tests.helper')

-- Lieu d'une fiche de l'Atelier (T-101, shared/place.lua) : cinq formes, bornes, arrondis, type sans lieu.
describe('vava_atelier place', function()
    local place, limits

    before_each(function()
        helper.reset()
        VavaAtelier = nil
        helper.loadAll({
            'modules/vava_atelier/shared/constants.lua',
            'modules/vava_atelier/config.lua',
            'modules/vava_atelier/shared/place.lua',
        })
        place = VavaAtelier.place
        limits = VavaAtelier.config.place
    end)

    local function refused(shape, value, needle)
        local out, err = place.check(shape, value, limits)
        assert.is_nil(out, shape)
        assert.is_string(err)
        if needle then assert.truthy(err:find(needle, 1, true), err) end
    end

    local square = { { x = 0, y = 0 }, { x = 10, y = 0 }, { x = 10, y = 10 }, { x = 0, y = 10 } }

    describe('formes justes', function()
        it('point, orienté, cercle, polygone, porte', function()
            assert.same({ x = 1.0, y = 2.0, z = 3.0 }, place.check('point', { x = 1, y = 2, z = 3 }, limits))
            assert.same({ x = -250.0, y = -930.0, z = 31.2, h = 90.0 },
                place.check('oriented', { x = -250.0, y = -930.0, z = 31.2, h = 90.0 }, limits))
            assert.same({ x = 0.0, y = 0.0, z = 0.0, r = 120.0 }, place.check('circle', { x = 0, y = 0, z = 0, r = 120 }, limits))
            local poly = place.check('polygon', { z = 30, points = square }, limits)
            assert.equal(4, #poly.points)
            assert.equal(30.0, poly.z)
            assert.same({ x = 10.0, y = 0.0 }, poly.points[2])
            assert.same({ x = 1.0, y = 2.0, z = 3.0, h = 0.0, model = -1234567 },
                place.check('door', { x = 1, y = 2, z = 3, h = 0, model = -1234567 }, limits))
            assert.equal(4294967295, place.check('door', { x = 1, y = 2, z = 3, h = 0, model = 4294967295 }, limits).model)
            assert.equal(-2147483648, place.check('door', { x = 1, y = 2, z = 3, h = 0, model = -2147483648 }, limits).model)
        end)

        it('bornes atteintes acceptées', function()
            assert.is_table(place.check('point', { x = 50000, y = -50000, z = 5000 }, limits))
            assert.is_table(place.check('circle', { x = 0, y = 0, z = 0, r = 500 }, limits))
            local pts = {}
            for i = 1, 32 do
                local a = (i - 1) * 2 * math.pi / 32
                pts[i] = { x = 20 * math.cos(a), y = 20 * math.sin(a) }
            end
            assert.is_table(place.check('polygon', { z = 0, points = pts }, limits))
        end)
    end)

    describe('refus', function()
        it('NaN, infini, chaîne', function()
            refused('point', { x = 0 / 0, y = 0, z = 0 }, 'x')
            refused('point', { x = 0, y = math.huge, z = 0 }, 'y')
            refused('point', { x = 0, y = 0, z = '3' }, 'z')
            refused('oriented', { x = 0, y = 0, z = 0, h = -math.huge }, 'h')
            refused('point', 'ici')
        end)

        it('clé en trop', function()
            refused('point', { x = 0, y = 0, z = 0, h = 0 }, 'h')
            refused('circle', { x = 0, y = 0, z = 0, r = 1, w = 2 }, 'w')
            refused('polygon', { z = 0, points = { { x = 0, y = 0, z = 1 }, { x = 1, y = 0 }, { x = 1, y = 1 } } }, 'z')
        end)

        it('hors bornes', function()
            refused('point', { x = 50000.01, y = 0, z = 0 }, 'x')
            refused('point', { x = 0, y = -50000.01, z = 0 }, 'y')
            refused('point', { x = 0, y = 0, z = 5000.01 }, 'z')
            refused('circle', { x = 0, y = 0, z = 0, r = 0 }, 'r')
            refused('circle', { x = 0, y = 0, z = 0, r = 500.01 }, 'r')
            refused('circle', { x = 0, y = 0, z = 0, r = -1 }, 'r')
        end)

        it('polygone de 2 et de 33 sommets, sommets confondus, aire nulle', function()
            refused('polygon', { z = 0, points = { { x = 0, y = 0 }, { x = 1, y = 0 } } }, 'points')
            local many = {}
            for i = 1, 33 do
                local a = (i - 1) * 2 * math.pi / 33
                many[i] = { x = 20 * math.cos(a), y = 20 * math.sin(a) }
            end
            refused('polygon', { z = 0, points = many }, 'points')
            refused('polygon', { z = 0, points = { { x = 0, y = 0 }, { x = 0.02, y = 0 }, { x = 5, y = 5 } } }, 'points[2]')
            -- fermeture : le dernier sommet trop près du premier
            refused('polygon', { z = 0, points = { { x = 0, y = 0 }, { x = 5, y = 0 }, { x = 5, y = 5 }, { x = 0.01, y = 0.01 } } },
                'points[1]')
            refused('polygon', { z = 0, points = { { x = 0, y = 0 }, { x = 5, y = 0 }, { x = 10, y = 0 } } }, 'aire')
            refused('polygon', { z = 0, points = { a = 1 } }, 'points')
        end)

        it('modèle hors bornes ou non entier', function()
            refused('door', { x = 0, y = 0, z = 0, h = 0, model = 4294967296 }, 'model')
            refused('door', { x = 0, y = 0, z = 0, h = 0, model = -2147483649 }, 'model')
            refused('door', { x = 0, y = 0, z = 0, h = 0, model = 1.5 }, 'model')
            refused('door', { x = 0, y = 0, z = 0, h = 0, model = 'prop_door' }, 'model')
        end)

        it('forme inconnue', function()
            refused('sphere', { x = 0, y = 0, z = 0 })
        end)
    end)

    describe('arrondis', function()
        it('coordonnées au centimètre', function()
            assert.equal(0.01, place.check('point', { x = 0.005, y = 0, z = 0 }, limits).x)
            assert.equal(1.23, place.check('point', { x = 1.2345, y = 0, z = 0 }, limits).x)
            assert.equal(-250.0, place.check('point', { x = -250.0012, y = 0, z = 0 }, limits).x)
            assert.equal('float', math.type(place.check('point', { x = 3, y = 0, z = 0 }, limits).x))
        end)

        it('cap au dixième, ramené dans [0, 360)', function()
            assert.equal(270.0, place.check('oriented', { x = 0, y = 0, z = 0, h = -90 }, limits).h)
            assert.equal(0.0, place.check('oriented', { x = 0, y = 0, z = 0, h = 360 }, limits).h)
            assert.equal(0.0, place.check('oriented', { x = 0, y = 0, z = 0, h = 359.96 }, limits).h)
            assert.equal(12.3, place.check('oriented', { x = 0, y = 0, z = 0, h = 12.34 }, limits).h)
            assert.equal(90.0, place.check('oriented', { x = 0, y = 0, z = 0, h = 450 }, limits).h)
        end)
    end)

    describe('type sans lieu', function()
        it('la place reçue est ignorée', function()
            assert.is_nil(place.check(nil, { x = 1, y = 2, z = 3 }, limits))
            assert.is_nil(select(2, place.check(nil, { x = 1, y = 2, z = 3 }, limits)))
            assert.is_true(place.ignored(nil, { x = 1 }))
            assert.is_false(place.ignored('point', { x = 1 }))
            assert.is_false(place.ignored(nil, nil))
        end)

        it('lieu pas encore posé : rien, sans erreur', function()
            local out, err = place.check('circle', nil, limits)
            assert.is_nil(out)
            assert.is_nil(err)
        end)
    end)

    it('centre au sol', function()
        assert.same({ x = 1, y = 2, z = 3 }, place.center({ x = 1, y = 2, z = 3, h = 0 }))
        assert.same({ x = 5, y = 5, z = 30 }, place.center({ z = 30, points = square }))
        assert.is_nil(place.center(nil))
    end)
end)
