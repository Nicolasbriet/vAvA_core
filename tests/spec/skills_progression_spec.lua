local helper = require('tests.helper')

-- Progression des compétences (modules/vava_skills/shared/progression.lua). Valeurs documentées : README du module
-- (tableau « Règles », « Tests en jeu »), docs/api.md (section vava_skills) et commentaires de config.lua :
--   XP d'un niveau au suivant floor(50 + 1,5 × n²) : 50 au niveau 0, 3 800 au niveau 50, 5 450 au niveau 60,
--   14 751 au niveau 99, ~500 000 XP pour atteindre 100 ;
--   rangs Novice 0, Apprenti 20, Compagnon 40, Artisan 60, Maître 80, Grand Maître 95 ;
--   savoir commun 20 points, budget 200 points au-delà ;
--   rendements : plein tant que niveau − difficulté ≤ 10, décroît jusqu'à 10 % à 40 d'écart.

describe('vava_skills progression', function()
    local progression, cfg

    before_each(function()
        helper.reset()
        VavaSkills = nil
        helper.loadAll({
            'modules/vava_skills/shared/constants.lua',
            'modules/vava_skills/config.lua',
            'modules/vava_skills/shared/progression.lua',
        })
        progression = VavaSkills.progression
        cfg = VavaSkills.config
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

    describe('XP par niveau', function()
        it('donne 3 800 XP au niveau 50 (commentaire de config.lua)', function()
            assert.equal(3800, progression.xpToNext(50))
        end)

        it('arrondit à l’entier inférieur (niveau 1 : 51,5 → 51)', function()
            assert.equal(51, progression.xpToNext(1))
            assert.equal('integer', math.type(progression.xpToNext(1)))
            assert.equal('integer', math.type(progression.xpToNext(60)))
        end)

        it('demande toujours plus d’XP d’un niveau au suivant', function()
            for level = 1, 99 do
                assert.is_true(progression.xpToNext(level) > progression.xpToNext(level - 1))
            end
        end)

        it('demande environ 500 000 XP du niveau 0 au niveau 100', function()
            local total = 0
            for level = 0, 99 do total = total + progression.xpToNext(level) end
            assert.equal(497500, total)
            assert.is_true(math.abs(total - 500000) <= 5000)
        end)

        it('README, test en jeu 1 : le niveau 1 s’atteint à 50 XP', function()
            assert.equal(50, progression.xpToNext(0))
        end)
    end)

    describe('rangs', function()
        it('place les rangs aux niveaux documentés', function()
            local expected = {
                { 0, 'novice', 'Novice' }, { 19, 'novice', 'Novice' },
                { 20, 'apprenti', 'Apprenti' }, { 39, 'apprenti', 'Apprenti' },
                { 40, 'compagnon', 'Compagnon' }, { 59, 'compagnon', 'Compagnon' },
                { 60, 'artisan', 'Artisan' }, { 79, 'artisan', 'Artisan' },
                { 80, 'maitre', 'Maître' }, { 94, 'maitre', 'Maître' },
                { 95, 'grand_maitre', 'Grand Maître' }, { 100, 'grand_maitre', 'Grand Maître' },
            }
            for _, case in ipairs(expected) do
                local rank = progression.rankOf(case[1])
                assert.equal(case[2], rank.name, 'niveau ' .. case[1])
                assert.equal(case[3], rank.label, 'niveau ' .. case[1])
            end
        end)

        it('donne le premier rang à un niveau négatif', function()
            assert.equal('novice', progression.rankOf(-5).name)
        end)

        it('trouve un rang par son nom, nil pour un nom inconnu', function()
            assert.equal(80, progression.rank('maitre').min)
            assert.equal(95, progression.rank('grand_maitre').min)
            assert.is_nil(progression.rank('archimage'))
            assert.is_nil(progression.rank(nil))
        end)

        it('dit si un niveau atteint un rang (Maître à 80, mentorat ; Compagnon à 40, poinçon et pénurie)', function()
            assert.is_true(progression.hasRank(80, cfg.mentoring.minRank))
            assert.is_false(progression.hasRank(79, cfg.mentoring.minRank))
            assert.is_true(progression.hasRank(40, cfg.shortages.minRank))
            assert.is_false(progression.hasRank(39, 'compagnon'))
            assert.is_true(progression.hasRank(0, 'novice'))
        end)

        it('refuse un rang inconnu', function()
            assert.is_false(progression.hasRank(100, 'archimage'))
        end)
    end)

    describe('savoir commun et budget', function()
        it('laisse libres les 20 premiers points de chaque compétence', function()
            assert.equal(20, cfg.levels.commonKnowledge)
            assert.equal(0, progression.budgetOf(0))
            assert.equal(0, progression.budgetOf(20))
            assert.equal(1, progression.budgetOf(21))
            assert.equal(80, progression.budgetOf(100))
        end)

        it('additionne le budget consommé par toutes les compétences', function()
            assert.equal(0, progression.budgetUsed({}))
            assert.equal(45, progression.budgetUsed({ forge = { level = 50 }, peche = { level = 10 }, minage = { level = 35 } }))
        end)

        it('README, test en jeu 3 : trois compétences à 100, 100 et 60 atteignent le budget de 200', function()
            assert.equal(200, cfg.levels.budget)
            local used = progression.budgetUsed({ forge = { level = 100 }, minage = { level = 100 }, cuisine = { level = 60 } })
            assert.equal(cfg.levels.budget, used)
            -- docs/tests/metiers.md § 2-5 : Bûcheronnage 20 en plus ne coûte rien (80 + 80 + 40)
            used = progression.budgetUsed({ forge = { level = 100 }, minage = { level = 100 }, cuisine = { level = 60 },
                bucheronnage = { level = 20 } })
            assert.equal(200, used)
        end)
    end)

    describe('rendements décroissants', function()
        it('rend le plein tant que niveau − difficulté ≤ 10', function()
            assert.equal(1, progression.diminishing(30, 20))
            assert.equal(1, progression.diminishing(10, 0))
            assert.equal(1, progression.diminishing(0, 50))           -- action plus difficile que le niveau
        end)

        it('décroît linéairement au-delà', function()
            assert.is_true(progression.diminishing(31, 20) < 1)
            assert.is_near(0.97, progression.diminishing(31, 20), 1e-9)   -- 1 − 0,9 × 1/30
            assert.is_near(0.55, progression.diminishing(45, 20), 1e-9)   -- écart 25 : 1 − 0,9 × 15/30
        end)

        it('tombe à 10 % à 40 d’écart et y reste', function()
            assert.equal(0.1, progression.diminishing(60, 20))
            assert.equal(0.1, progression.diminishing(100, 0))
        end)

        it('README, test en jeu 4 : niveau 60, action de difficulté 10 → 10 % de l’XP', function()
            assert.equal(0.1, progression.diminishing(60, 10))
        end)

        it('docs/tests/metiers.md § 2-7 : Bûcheronnage 60 sur un pin (difficulté 5) → XP divisée par 10', function()
            assert.equal(0.1, progression.diminishing(60, 5))
        end)

        it('ne remonte jamais quand l’écart grandit', function()
            local previous = progression.diminishing(50, 50)
            for level = 51, 100 do
                local factor = progression.diminishing(level, 50)
                assert.is_true(factor <= previous)
                assert.is_true(factor >= 0.1)
                previous = factor
            end
        end)
    end)

    describe('bornes du niveau', function()
        it('borne le niveau entre 0 et 100 et le rend entier', function()
            assert.equal(0, progression.clampLevel(-5))
            assert.equal(100, progression.clampLevel(150))
            assert.equal(42, progression.clampLevel(42.7))
            assert.equal(100, progression.clampLevel(100))
            assert.equal('integer', math.type(progression.clampLevel(42.7)))
        end)

        it('ramène NaN et l’infini dans les bornes', function()
            assert.equal(0, progression.clampLevel(0 / 0))
            assert.equal(100, progression.clampLevel(math.huge))
            assert.equal(0, progression.clampLevel(-math.huge))
        end)

        it('reprend le niveau maximal du protocole', function()
            assert.equal(VavaSkills.MAX_LEVEL, cfg.levels.max)
        end)
    end)
end)
