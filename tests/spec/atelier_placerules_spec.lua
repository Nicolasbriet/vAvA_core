local helper = require('tests.helper')

-- Règles de placement de l'outil de l'Atelier (T-102, modules/vava_atelier/shared/placerules.lua), les mêmes chez le
-- client (aperçu) et au serveur (décision). Règles documentées : spec T-102 § 7.2 et README de vava_atelier :
--   portée : centre à 60 m au plus (3D), sommets d'un tracé à 60 × 2 = 120 m au plus (au sol) ; `inside` : dans le
--   cercle du parent + slack (au sol), ou dans son tracé, ou à slack m de son bord ; `spacing` : 2 m au moins des
--   frères (la fiche elle-même, les retraits et les frères d'un autre parent ignorés) ; `radius`, `vertices` ; un
--   tracé ne se croise pas ; textes formatés comme ceux du serveur.
describe('vava_atelier placerules', function()
    local rules, texts, limits

    before_each(function()
        helper.reset()
        VavaAtelier = nil
        helper.loadAll({
            'modules/vava_atelier/shared/constants.lua',
            'modules/vava_atelier/config_client.lua',
            'modules/vava_atelier/shared/placerules.lua',
        })
        rules = VavaAtelier.placerules
        texts = VavaAtelier.config.placement.texts
        limits = { reach = VavaAtelier.config.placement.reach, polygonFactor = VavaAtelier.config.placement.polygonFactor }
    end)

    local ORIGIN = { x = 0.0, y = 0.0, z = 0.0 }

    local function at(x, y, z) return { x = x, y = y, z = z or 0.0 } end

    local function check(r, shape, where, ctx)
        return rules.check(r, shape, where, ctx or {})
    end

    describe('portée', function()
        it('60 m au plus du personnage : 59,9 m oui, 60,1 m non (distance 3D)', function()
            assert.equal(60.0, limits.reach)
            assert.is_nil(rules.reach('point', at(59.9, 0), ORIGIN, limits))
            local far = rules.reach('point', at(60.1, 0), ORIGIN, limits)
            assert.same({ code = 'far', args = { 60 } }, far)
            assert.is_nil(rules.reach('oriented', { x = 0, y = 0, z = 59.9, h = 0 }, ORIGIN, limits))
            assert.equal('far', rules.reach('circle', { x = 0, y = 0, z = 60.1, r = 10 }, ORIGIN, limits).code)
        end)

        it('60 m atteints exactement : acceptés', function()
            assert.is_nil(rules.reach('point', at(60, 0), ORIGIN, limits))
        end)

        it('un sommet de tracé à 119 m oui, à 121 m non (au sol, reach × polygonFactor)', function()
            local near = { z = 0, points = { { x = 119, y = 0 }, { x = -60, y = 1 }, { x = -59, y = -1 } } }
            assert.is_nil(rules.reach('polygon', near, ORIGIN, limits))
            local far = { z = 0, points = { { x = 121, y = 0 }, { x = -60, y = 1 }, { x = -60, y = -1 } } }
            assert.same({ code = 'far', args = { 121 } }, rules.reach('polygon', far, ORIGIN, limits))
            -- tracé en cours : seuls les sommets comptent
            assert.is_nil(rules.reach('polygon', { z = 0, points = { { x = 100, y = 0 } } }, ORIGIN, limits, true))
        end)

        it('le contrôle de portée passe par check quand le personnage est donné', function()
            local found = check(nil, 'point', at(80, 0), { origin = ORIGIN, reach = 60, polygonFactor = 2 })
            assert.equal('far', found.code)
            assert.is_nil(check(nil, 'point', at(80, 0)))
        end)
    end)

    describe('dedans', function()
        local circle = { title = 'Bois des Essais', shape = 'circle', place = { x = 0, y = 0, z = 0, r = 100 } }
        local inside = { inside = { slack = 5 } }

        it('cercle du parent : bord + slack accepté, + 0,01 m refusé', function()
            assert.is_nil(check(inside, 'oriented', { x = 105, y = 0, z = 0, h = 0 }, { parent = circle }))
            local found = check(inside, 'oriented', { x = 105.01, y = 0, z = 0, h = 0 }, { parent = circle })
            assert.same({ code = 'inside', args = { 'Bois des Essais' } }, found)
            assert.equal('Hors de Bois des Essais.', rules.text(found, texts))
        end)

        it('mesuré au sol : un point haut au-dessus du centre reste dedans', function()
            assert.is_nil(check(inside, 'point', { x = 0, y = 0, z = 300 }, { parent = circle }))
        end)

        local square = { title = 'Enclos', shape = 'polygon',
            place = { z = 0, points = { { x = 0, y = 0 }, { x = 10, y = 0 }, { x = 10, y = 10 }, { x = 0, y = 10 } } } }

        it('tracé du parent : dedans, dehors, sur un sommet, à slack du bord', function()
            local r = { inside = { slack = 2 } }
            assert.is_nil(check(r, 'point', at(5, 5), { parent = square }))
            assert.is_nil(check(r, 'point', at(10, 10), { parent = square }))
            assert.is_nil(check(r, 'point', at(12, 5), { parent = square }))
            assert.equal('inside', check(r, 'point', at(12.01, 5), { parent = square }).code)
            assert.equal('inside', check({ inside = {} }, 'point', at(20, 20), { parent = square }).code)
        end)

        it('sans lieu du parent, rien à juger', function()
            assert.is_nil(check(inside, 'point', at(900, 0), {}))
        end)
    end)

    describe('écart', function()
        local siblings = {
            { id = 'chene_2', title = 'Chêne 2', x = 0, y = 0, parent = 'bois' },
            { id = 'chene_5', title = 'Chêne 5', x = 50, y = 0, parent = 'bois', removal = true },
            { id = 'autre_1', title = 'Autre 1', x = 30, y = 0, parent = 'ailleurs' },
        }
        local r = { spacing = 2 }

        it('1,99 m refusé, 2,00 m accepté (au sol)', function()
            local found = check(r, 'oriented', { x = 1.99, y = 0, z = 0, h = 0 },
                { siblings = siblings, parentId = 'bois' })
            assert.equal('spacing', found.code)
            assert.equal('Chêne 2', found.args[1])
            assert.equal('Trop près de « Chêne 2 » (2 m).', rules.text(found, texts))
            assert.is_nil(check(r, 'oriented', { x = 2.0, y = 0, z = 9, h = 0 }, { siblings = siblings, parentId = 'bois' }))
            local close = check(r, 'point', at(1.4, 0), { siblings = siblings, parentId = 'bois' })
            assert.equal('Trop près de « Chêne 2 » (1,4 m).', rules.text(close, texts))
        end)

        it('la fiche elle-même, les retirés et les frères d\'un autre parent ignorés', function()
            assert.is_nil(check(r, 'point', at(0.5, 0), { siblings = siblings, parentId = 'bois', self = 'chene_2' }))
            assert.is_nil(check(r, 'point', at(50, 0.5), { siblings = siblings, parentId = 'bois' }))
            assert.is_nil(check(r, 'point', at(30, 0.5), { siblings = siblings, parentId = 'bois' }))
        end)

        it('le frère le plus proche est nommé', function()
            local two = { { id = 'a', title = 'A', x = 1.5, y = 0 }, { id = 'b', title = 'B', x = 0.5, y = 0 } }
            assert.equal('B', check(r, 'point', at(0, 0), { siblings = two }).args[1])
        end)
    end)

    describe('rayon et sommets', function()
        local r = { radius = { min = 10, max = 300, default = 60 }, vertices = { min = 3, max = 6 } }

        it('rayon dans ses bornes, bornes atteintes acceptées', function()
            assert.is_nil(check(r, 'circle', { x = 0, y = 0, z = 0, r = 10 }))
            assert.is_nil(check(r, 'circle', { x = 0, y = 0, z = 0, r = 300 }))
            local found = check(r, 'circle', { x = 0, y = 0, z = 0, r = 9.9 })
            assert.same({ code = 'radius', args = { 10, 300 } }, found)
            assert.equal('Rayon de 10 à 300 m.', rules.text(found, texts))
            assert.equal('radius', check(r, 'circle', { x = 0, y = 0, z = 0, r = 300.1 }).code)
        end)

        it('nombre de sommets ; un tracé en cours n\'a pas encore de minimum', function()
            local two = { z = 0, points = { { x = 0, y = 0 }, { x = 5, y = 0 } } }
            local found = check(r, 'polygon', two)
            assert.equal('De 3 à 6 sommets.', rules.text(found, texts))
            assert.is_nil(check(r, 'polygon', two, { open = true }))
            local seven = { z = 0, points = {} }
            for i = 1, 7 do
                local a = (i - 1) * 2 * math.pi / 7
                seven.points[i] = { x = 10 * math.cos(a), y = 10 * math.sin(a) }
            end
            assert.equal('vertices', check(r, 'polygon', seven).code)
        end)
    end)

    describe('tracé qui se croise', function()
        it('nœud papillon refusé, polygone concave accepté', function()
            local bow = { { x = 0, y = 0 }, { x = 10, y = 10 }, { x = 10, y = 0 }, { x = 0, y = 10 } }
            assert.is_true(rules.crosses(bow))
            local found = check(nil, 'polygon', { z = 0, points = bow })
            assert.equal('Le tracé se croise.', rules.text(found, texts))
            local concave = { { x = 0, y = 0 }, { x = 10, y = 0 }, { x = 10, y = 10 }, { x = 5, y = 3 }, { x = 0, y = 10 } }
            assert.is_false(rules.crosses(concave))
            assert.is_nil(check(nil, 'polygon', { z = 0, points = concave }))
        end)

        it('tracé en cours : le côté qui le refermerait ne compte pas', function()
            local open = { { x = 0, y = 0 }, { x = 10, y = 0 }, { x = 10, y = 10 }, { x = 5, y = -5 } }
            assert.is_true(rules.crosses(open, true))
            local fine = { { x = 0, y = 0 }, { x = 10, y = 0 }, { x = 10, y = 10 } }
            assert.is_false(rules.crosses(fine, true))
        end)

        it('un triangle ne se croise jamais', function()
            assert.is_false(rules.crosses({ { x = 0, y = 0 }, { x = 1, y = 0 }, { x = 0, y = 1 } }))
        end)
    end)

    describe('valeurs piégées', function()
        it('NaN, infini, table vide : refusés sans erreur', function()
            assert.equal('ground', check(nil, 'point', {}).code)
            assert.equal('ground', check(nil, 'point', nil).code)
            assert.equal('ground', check(nil, 'point', { x = 0 / 0, y = 0, z = 0 }, { origin = ORIGIN, reach = 60 }).code)
            assert.equal('ground', check(nil, 'point', { x = math.huge, y = 0, z = 0 }, { origin = ORIGIN, reach = 60 }).code)
            assert.equal('radius', check({ radius = { min = 1, max = 5, default = 2 } }, 'circle',
                { x = 0, y = 0, z = 0, r = 0 / 0 }).code)
            assert.is_nil(rules.center({ points = {} }))
        end)
    end)

    describe('textes', function()
        it('formatés comme ceux du serveur', function()
            assert.equal('Trop loin de vous : approchez-vous (72 m).', rules.text({ code = 'far', args = { 72 } }, texts))
            assert.equal('Visez le sol.', rules.text({ code = 'ground', args = {} }, texts))
            assert.equal('1,4', rules.number(1.44))
            assert.equal('81,5', rules.number(81.5))
            assert.equal('2', rules.number(1.999))
        end)

        it('titre d\'un enfant nouveau : numéro libre parmi les frères', function()
            assert.equal('Chêne 1', rules.autoTitle('Chêne', {}))
            assert.equal('Chêne 4', rules.autoTitle('Chêne', { 'Chêne 1', 'Chêne 2', 'Chêne 3', 'Pin 4' }))
            assert.equal('Chêne 2', rules.autoTitle('Chêne', { 'Chêne 1', 'Chêne 3' }))
        end)
    end)
end)
