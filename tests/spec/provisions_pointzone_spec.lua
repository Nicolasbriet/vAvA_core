local helper = require('tests.helper')

-- Points d'eau partagés par les abonnements de zone du core (modules/vava_provisions/shared/pointzone.lua, T-130).
-- Valeurs documentées : README du module (« Réseau ») et docs/plan/specs/T-130.md § 5.4 :
--   une zone du core par point, rayon 2 m, marge = portée des props (80 m) + 20 m = 100 m ;
--   état { def = { kind, label, x, y, z, heading, model } }, sans réserve ;
--   le client ignore ce qui est mal formé (jamais d'erreur) et ne connaît que les points des zones qu'il suit.

describe('vava_provisions pointzone', function()
    local pointzone, rules, cfg

    before_each(function()
        helper.reset()
        VavaProvisions = nil
        helper.loadAll({
            'modules/vava_provisions/shared/constants.lua',
            'modules/vava_provisions/config.lua',
            'modules/vava_provisions/shared/rules.lua',
            'modules/vava_provisions/shared/pointzone.lua',
        })
        pointzone, rules, cfg = VavaProvisions.pointzone, VavaProvisions.rules, VavaProvisions.config
    end)

    after_each(function()
        VavaProvisions = nil
    end)

    --- Point de la config tel que le valide le serveur.
    local function validated(index)
        local ok, point = rules.validatePoint(cfg.points[index], cfg.kinds)
        assert.is_true(ok)
        return point
    end

    describe('serveur', function()
        it('zone d\'un point : centre du point, rayon 2 m, marge 100 m (80 + 20) avec la config livrée', function()
            local s = cfg.streaming
            local area = pointzone.area(validated(1), s.zoneRadius, s.radius + s.subscribeSlack)
            assert.same({ x = -250.0, y = -960.0, radius = 2.0, margin = 100.0 }, area)
        end)

        it('dessin : sorte, nom, lieu, cap, modèle résolu, rien d\'autre (ni réserve)', function()
            local drawing = pointzone.drawing(validated(1))
            assert.same({ kind = 'fontaine', label = 'Fontaine du bourg', x = -250.0, y = -960.0, z = 31.2, heading = 0.0,
                model = 'prop_barrel_01a' }, drawing)
            assert.is_nil(drawing.reserve)
            assert.is_nil(drawing.id)
        end)
    end)

    describe('client', function()
        it('relit le dessin publié : le même point', function()
            for index, def in ipairs(cfg.points) do
                local point = validated(index)
                local read = pointzone.readDrawing(def.id, pointzone.drawing(point))
                assert.same(point, read, def.id)
            end
        end)

        it('ignore un dessin mal formé, sans erreur', function()
            local good = pointzone.drawing(validated(2))
            local function with(key, value)
                local raw = {}
                for k, v in pairs(good) do raw[k] = v end
                raw[key] = value
                return raw
            end
            assert.is_nil(pointzone.readDrawing('puits_lavoir', with('label', nil)))
            assert.is_nil(pointzone.readDrawing('puits_lavoir', with('label', string.rep('a', 49))))
            assert.is_nil(pointzone.readDrawing('puits_lavoir', with('x', 0 / 0)))
            assert.is_nil(pointzone.readDrawing('puits_lavoir', with('z', math.huge)))
            assert.is_nil(pointzone.readDrawing('puits_lavoir', with('model', string.rep('a', 65))))
            assert.is_nil(pointzone.readDrawing('puits_lavoir', with('model', 'a b')))
            assert.is_nil(pointzone.readDrawing('puits_lavoir', with('kind', 'Puits')))
            assert.is_nil(pointzone.readDrawing('puits_lavoir', with('heading', 'nord')))
            assert.is_nil(pointzone.readDrawing('Puits Lavoir', good))
            assert.is_nil(pointzone.readDrawing('puits_lavoir', 'def'))
            assert.is_not_nil(pointzone.readDrawing('puits_lavoir', with('model', '')))
            assert.equal('', pointzone.readDrawing('puits_lavoir', with('model', nil)).model)
            assert.equal(0.0, pointzone.readDrawing('puits_lavoir', with('heading', nil)).heading)
        end)

        it('carnet : entrée, changement, sortie, taille et liste triée', function()
            local book = pointzone.book()
            local puits = { def = pointzone.drawing(validated(2)) }
            local fontaine = { def = pointzone.drawing(validated(1)) }
            assert.is_true(book:enter('puits_lavoir', puits))
            assert.is_false(book:enter('puits_lavoir', puits))   -- état renvoyé entier, identique
            assert.is_true(book:enter('fontaine_bourg', fontaine))
            assert.equal(2, book:size())
            assert.same({ 'fontaine_bourg', 'puits_lavoir' }, { book:list()[1].id, book:list()[2].id })

            -- changement du dessin (Atelier, plus tard)
            local moved = pointzone.drawing(validated(2))
            moved.x = moved.x + 5
            assert.is_true(book:change('puits_lavoir', { def = moved }, {}))
            assert.equal(moved.x, book:point('puits_lavoir').x)
            assert.is_false(book:change('puits_lavoir', { def = moved }, {}))
            assert.is_false(book:change('puits_lavoir', {}, {}))
            -- point inconnu : ignoré (le core envoie l'état entier d'abord)
            assert.is_false(book:change('source_claire', { def = moved }, {}))
            -- dessin mal formé : oublié
            assert.is_true(book:change('fontaine_bourg', { def = { kind = 'fontaine' } }, {}))
            assert.is_nil(book:point('fontaine_bourg'))
            assert.equal(1, book:size())
            -- clé retirée : oublié
            assert.is_true(book:change('puits_lavoir', {}, { 'def' }))
            assert.equal(0, book:size())
            assert.same({}, book:list())

            assert.is_true(book:enter('puits_lavoir', puits))
            assert.is_true(book:leave('puits_lavoir'))
            assert.is_false(book:leave('puits_lavoir'))
            assert.is_false(book:enter('source_claire', { def = 'mauvais' }))
            assert.equal(0, book:size())

            book:enter('puits_lavoir', puits)
            book:clear()
            assert.equal(0, book:size())
            assert.is_nil(book:point('puits_lavoir'))
            assert.is_nil(book:point(42))
        end)
    end)
end)
