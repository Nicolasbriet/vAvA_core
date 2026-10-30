local helper = require('tests.helper')

-- Prise d'un poisson tirée par le serveur (modules/vava_gathering/shared/catch.lua), décision du 30 octobre 2026 : la
-- barre de tension ne peut que faire rater ; ligne tenue, le serveur tire la prise. Valeurs documentées : README du
-- module, tableau « Règles », ligne « Prise » :
--   poisson décroché : 25 % au niveau 0 de Pêche, 2 % au niveau 100, linéaire entre les deux (13,5 % au niveau 50) ;
--   + 5 points en eaux fatiguées, + 10 en eaux épuisées ; parts invalides comptées pour 0, chance dans [0, 1].

describe('vava_gathering catch', function()
    local catch, rules

    before_each(function()
        helper.reset()
        helper.loadAll({
            'modules/vava_gathering/shared/constants.lua',
            'modules/vava_gathering/config.lua',
            'modules/vava_gathering/shared/catch.lua',
        })
        catch = VavaGathering.catch
        rules = VavaGathering.config.fishing.catch
    end)

    local function near(expected, actual)
        assert.is_true(math.abs(expected - actual) < 1e-9, ('attendu %s, obtenu %s'):format(expected, actual))
    end

    describe('réglages documentés', function()
        it('reprend les valeurs du README', function()
            assert.equal(0.25, rules.novice)
            assert.equal(0.02, rules.master)
            assert.equal(100, rules.masterLevel)
            assert.same({ normal = 0.0, reduced = 0.05, depleted = 0.10 }, rules.bands)
        end)

        it('couvre chaque bande de vitalité du module', function()
            for _, band in pairs(VavaGathering.BANDS) do
                assert.is_number(rules.bands[band], band)
            end
        end)
    end)

    describe('chance que le poisson se décroche', function()
        it('vaut 25 % au niveau 0 et 2 % au niveau 100 en eaux pleines', function()
            near(0.25, catch.escapeChance(0, 'normal', rules))
            near(0.02, catch.escapeChance(100, 'normal', rules))
        end)

        it('descend en ligne droite avec le niveau (13,5 % au niveau 50)', function()
            near(0.135, catch.escapeChance(50, 'normal', rules))
            near(0.25 - 0.23 * 0.2, catch.escapeChance(20, 'normal', rules))
            local previous = catch.escapeChance(0, 'normal', rules)
            for level = 1, 100 do
                local chance = catch.escapeChance(level, 'normal', rules)
                assert.is_true(chance < previous, 'niveau ' .. level)
                previous = chance
            end
        end)

        it('ajoute le supplément de la bande : + 5 points fatiguée, + 10 épuisée', function()
            near(0.30, catch.escapeChance(0, 'reduced', rules))
            near(0.35, catch.escapeChance(0, 'depleted', rules))
            near(0.07, catch.escapeChance(100, 'reduced', rules))
            near(0.12, catch.escapeChance(100, 'depleted', rules))
        end)

        it('ne compte aucun supplément pour une bande inconnue ou absente', function()
            near(0.25, catch.escapeChance(0, 'inconnue', rules))
            near(0.25, catch.escapeChance(0, nil, rules))
        end)

        it('ramène un niveau hors bornes dans 0 à masterLevel', function()
            near(0.25, catch.escapeChance(-40, 'normal', rules))
            near(0.02, catch.escapeChance(250, 'normal', rules))
        end)

        it('compte un niveau invalide (texte, NaN, infini) pour 0 : la chance du débutant', function()
            near(0.25, catch.escapeChance('100', 'normal', rules))
            near(0.25, catch.escapeChance(0 / 0, 'normal', rules))
            near(0.25, catch.escapeChance(math.huge, 'normal', rules))
            near(0.25, catch.escapeChance(nil, 'normal', rules))
        end)

        it('reste dans [0, 1] quelle que soit la config', function()
            assert.equal(1, catch.escapeChance(0, 'depleted', { novice = 0.95, master = 0.5, masterLevel = 100, bands = { depleted = 0.5 } }))
            assert.equal(0, catch.escapeChance(100, 'normal', { novice = 0.2, master = -0.5, masterLevel = 100, bands = {} }))
            assert.equal(1, catch.escapeChance(0, 'normal', { novice = 7, master = 0, masterLevel = 100 }))
        end)

        it('compte une part invalide pour 0 et une config absente pour aucune perte', function()
            -- débutant invalide (0) → maître 2 % : la chance remonte de 0 à 2 % avec le niveau
            near(0, catch.escapeChance(0, 'normal', { novice = 'beaucoup', master = 0.02, masterLevel = 100, bands = {} }))
            near(0.01, catch.escapeChance(50, 'normal', { novice = 'beaucoup', master = 0.02, masterLevel = 100, bands = {} }))
            assert.equal(0, catch.escapeChance(0, 'normal', nil))
            near(0.25, catch.escapeChance(0, 'reduced', { novice = 0.25, master = 0.02, masterLevel = 100, bands = { reduced = 0 / 0 } }))
        end)

        it('donne la chance du maître à tout niveau quand masterLevel est nul ou invalide', function()
            near(0.02, catch.escapeChance(0, 'normal', { novice = 0.25, master = 0.02, masterLevel = 0, bands = {} }))
            near(0.02, catch.escapeChance(0, 'normal', { novice = 0.25, master = 0.02, masterLevel = 0 / 0, bands = {} }))
        end)
    end)

    describe('tirage', function()
        it('décroche quand le tirage tombe sous la chance, pas au-dessus', function()
            assert.is_true(catch.escapes(0, 'normal', rules, 0.0))
            assert.is_true(catch.escapes(0, 'normal', rules, 0.249))
            assert.is_false(catch.escapes(0, 'normal', rules, 0.25))
            assert.is_false(catch.escapes(0, 'normal', rules, 0.9))
            assert.is_true(catch.escapes(100, 'normal', rules, 0.019))
            assert.is_false(catch.escapes(100, 'normal', rules, 0.02))
        end)

        it('ne décroche jamais à chance nulle, même avec un tirage invalide', function()
            local none = { novice = 0, master = 0, masterLevel = 100, bands = {} }
            assert.is_false(catch.escapes(0, 'normal', none, 0.0))
            assert.is_false(catch.escapes(0, 'normal', none, 0 / 0))
        end)

        it('compte un tirage invalide pour 0 : le poisson se décroche dès que la chance n’est pas nulle', function()
            assert.is_true(catch.escapes(100, 'normal', rules, 0 / 0))
            assert.is_true(catch.escapes(100, 'normal', rules, nil))
        end)

        it('ne laisse aucun niveau assurer la prise ni la rendre impossible avec la config livrée', function()
            for level = 0, 100, 10 do
                for _, band in pairs(VavaGathering.BANDS) do
                    local chance = catch.escapeChance(level, band, rules)
                    assert.is_true(chance > 0 and chance < 1, ('niveau %d, bande %s'):format(level, band))
                end
            end
        end)
    end)
end)
