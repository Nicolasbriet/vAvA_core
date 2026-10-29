local helper = require('tests.helper')

-- Qualité d'une pièce d'artisanat (modules/vava_crafting/shared/quality.lua). Valeurs documentées : README du module
-- (tableau « Règles », « Tests en jeu ») et docs/api.md, section vava_crafting :
--   qualité = matériaux × 0,5 + niveau × 0,4 + station × 0,1 ± 5, plafonnée par le niveau ;
--   paliers Grossier < 20, Commun, Soigné 40, Excellent 60, Chef-d'œuvre 85 ;
--   palier de matière → qualité 10, 30, 50, 72, 92.

describe('vava_crafting quality', function()
    local quality, cfg

    before_each(function()
        helper.reset()
        helper.loadAll({
            'modules/vava_crafting/shared/constants.lua',
            'modules/vava_crafting/config.lua',
            'modules/vava_crafting/shared/quality.lua',
        })
        quality = VavaCrafting.quality
        cfg = VavaCrafting.config
    end)

    local function station(id)
        for _, entry in ipairs(cfg.stations) do
            if entry.id == id then return entry end
        end
        error('station absente de la config : ' .. id)
    end

    describe('paliers', function()
        it('place les bornes documentées : Grossier < 20, Commun, Soigné 40, Excellent 60, Chef-d’œuvre 85', function()
            assert.equal(1, quality.tierOf(0))
            assert.equal(1, quality.tierOf(19))
            assert.equal(1, quality.tierOf(19.99))
            assert.equal(2, quality.tierOf(20))
            assert.equal(2, quality.tierOf(39))
            assert.equal(3, quality.tierOf(40))
            assert.equal(3, quality.tierOf(59))
            assert.equal(4, quality.tierOf(60))
            assert.equal(4, quality.tierOf(84))
            assert.equal(5, quality.tierOf(85))
            assert.equal(5, quality.tierOf(100))
        end)

        it('nomme les cinq paliers comme le README', function()
            assert.equal('Grossier', quality.tierLabel(1))
            assert.equal('Commun', quality.tierLabel(2))
            assert.equal('Soigné', quality.tierLabel(3))
            assert.equal('Excellent', quality.tierLabel(4))
            assert.equal('Chef-d\'œuvre', quality.tierLabel(5))
        end)

        it('rend le numéro du palier quand il n’a pas de libellé', function()
            assert.equal('6', quality.tierLabel(6))
            assert.equal('0', quality.tierLabel(0))
        end)

        it('chef-d’œuvre au palier 5, journal à partir d’Excellent (palier ≥ 4)', function()
            assert.equal(5, cfg.masterpiece.tier)
            assert.equal(cfg.masterpiece.tier, quality.tierOf(85))
            assert.equal(4, cfg.logTier)
            assert.equal('Excellent', quality.tierLabel(cfg.logTier))
            assert.equal(cfg.logTier, quality.tierOf(60))
        end)

        it('donne le palier 1 à une qualité négative ou NaN', function()
            assert.equal(1, quality.tierOf(-5))
            assert.equal(1, quality.tierOf(0 / 0))
        end)
    end)

    describe('matières', function()
        it('donne à chaque palier de matière la qualité documentée 10, 30, 50, 72, 92', function()
            assert.equal(10, quality.materialQuality(1))
            assert.equal(30, quality.materialQuality(2))
            assert.equal(50, quality.materialQuality(3))
            assert.equal(72, quality.materialQuality(4))
            assert.equal(92, quality.materialQuality(5))
        end)

        it('ramène un palier hors bornes au palier valide le plus proche', function()
            assert.equal(10, quality.materialQuality(0))
            assert.equal(10, quality.materialQuality(-3))
            assert.equal(92, quality.materialQuality(6))
            assert.equal(92, quality.materialQuality(99))
        end)

        it('accepte un palier flottant à équivalent entier (2.0), tel qu’il arrive d’une table réseau', function()
            assert.equal(30, quality.materialQuality(2.0))
        end)

        it('fait la moyenne des paliers choisis, pondérée par les quantités (épée courte)', function()
            -- 3 lingots de fer au palier 2 (30) et 1 bois de chêne au palier 1 (10) : (3 × 30 + 10) / 4 = 25
            local recipe = cfg.recipes.epee_courte
            assert.equal(25, quality.materials(recipe.ingredients, { 2, 1 }))
            -- tout au palier 5 : 92
            assert.equal(92, quality.materials(recipe.ingredients, { 5, 5 }))
        end)

        it('prend le palier 1 pour un ingrédient sans palier choisi', function()
            local recipe = cfg.recipes.epee_courte
            assert.equal(10, quality.materials(recipe.ingredients, {}))
            -- lingots au palier 5, bois non choisi : (3 × 92 + 10) / 4 = 71,5
            assert.equal(71.5, quality.materials(recipe.ingredients, { [1] = 5 }))
        end)

        it('rend 0 pour une recette sans ingrédient', function()
            assert.equal(0, quality.materials({}, {}))
        end)
    end)

    describe('score', function()
        it('suit la formule documentée : matériaux × 0,5 + niveau × 0,4 + station × 0,1', function()
            assert.same({ materials = 0.5, skill = 0.4, station = 0.1 }, cfg.quality.weights)
            assert.equal(5, cfg.quality.jitter)
            assert.is_true(cfg.quality.capByLevel)
            assert.is_near(70, quality.score(50, 100, 50), 1e-9)       -- 25 + 40 + 5
            assert.is_near(54, quality.score(30, 80, 70), 1e-9)        -- 15 + 32 + 7, sous le niveau 80
        end)

        it('ne dépasse jamais le niveau de l’artisan', function()
            -- 72 × 0,5 + 40 × 0,4 + 50 × 0,1 = 57, plafonné au niveau 40
            assert.equal(40, quality.score(72, 40, 50))
            -- README, test 4 : à bas niveau, matières de palier 5 → qualité plafonnée au niveau
            assert.equal(10, quality.score(92, 10, 100))
            assert.equal(0, quality.score(92, 0, 100))
        end)

        it('reste entre 0 et 100', function()
            assert.equal(100, quality.score(200, 100, 100))
            assert.equal(0, quality.score(-100, 100, 0))
            assert.equal(0, quality.score(0, 0, 0))
        end)
    end)

    describe('qualité finale', function()
        it('ajoute l’aléa puis arrondit à l’entier le plus proche', function()
            assert.equal(72, quality.finalize(70, 2.4, 100))
            assert.equal(73, quality.finalize(70, 2.6, 100))
            assert.equal(65, quality.finalize(70, -4.6, 100))
        end)

        it('rend un entier', function()
            assert.equal('integer', math.type(quality.finalize(70, 2.4, 100)))
            assert.equal('integer', math.type(quality.finalize(0, 0, 0)))
        end)

        it('garde le plafond du niveau même avec un aléa positif', function()
            assert.equal(10, quality.finalize(10, 5, 10))
            assert.equal(0, quality.finalize(0, 5, 0))
        end)

        it('borne la qualité finale entre 0 et 100', function()
            assert.equal(100, quality.finalize(98, 5, 100))
            assert.equal(0, quality.finalize(2, -5, 100))
        end)
    end)

    describe('exemples du README (« Tests en jeu »)', function()
        local function piece(recipeId, choices, level, stationId, jitter)
            local recipe = cfg.recipes[recipeId]
            local materials = quality.materials(recipe.ingredients, choices)
            local score = quality.score(materials, level, station(stationId).quality)
            local value = quality.finalize(score, jitter, level)
            return value, quality.tierOf(value)
        end

        it('test 1 : un marteau de forge façonné à bas niveau est Grossier, quel que soit l’aléa', function()
            for level = 0, 19 do
                for _, jitter in ipairs({ -5, 0, 5 }) do
                    local value, tier = piece('marteau_forge', { 5, 5 }, level, 'etabli_bourg', jitter)
                    assert.is_true(value <= level, ('qualité %d au niveau %d'):format(value, level))
                    assert.equal('Grossier', quality.tierLabel(tier))
                end
            end
        end)

        it('test 4 : au niveau 10, des matières de palier 5 donnent au plus une qualité de 10', function()
            for _, jitter in ipairs({ -5, 0, 5 }) do
                local value = piece('hache_fer', { 5, 5 }, 10, 'forge_bourg', jitter)
                assert.is_true(value <= 10)
            end
            assert.equal(10, (piece('hache_fer', { 5, 5 }, 10, 'forge_bourg', 5)))
        end)

        it('test 6 : alchimie 100, herbes de palier 5, alambic → potion de palier 5, signée (≥ 60)', function()
            -- 92 × 0,5 + 100 × 0,4 + 60 × 0,1 = 92, puis ± 5 : de 87 à 97
            local recipe = cfg.recipes.potion_de_soin
            for _, jitter in ipairs({ -5, 0, 5 }) do
                local value, tier = piece('potion_de_soin', { 5, 5 }, 100, 'alambic_bourg', jitter)
                assert.equal(5, tier)
                assert.equal(cfg.masterpiece.tier, tier)
                assert.is_true(value >= recipe.signedIfQuality)
            end
            assert.equal(87, (piece('potion_de_soin', { 5, 5 }, 100, 'alambic_bourg', -5)))
            assert.equal(97, (piece('potion_de_soin', { 5, 5 }, 100, 'alambic_bourg', 5)))
        end)
    end)

    -- docs/tests/metiers.md § 4, étape 8 : « forge 100, minerai … (palier Excellent ou mieux), lingots, puis Épée
    -- courte → qualité ≥ 85 ». Ces tests fixent ce que la formule du README donne réellement à la forge du bourg
    -- (qualité 50) : voir le rapport docs/plan/rapports/T-003.md.
    describe('chef-d’œuvre à la forge (procédure docs/tests/metiers.md § 4-8)', function()
        local function value(recipeId, choices, jitter)
            local recipe = cfg.recipes[recipeId]
            local score = quality.score(quality.materials(recipe.ingredients, choices), 100, station('forge_bourg').quality)
            return quality.finalize(score, jitter, 100)
        end

        it('épée courte toute de palier 5 au niveau 100 : chef-d’œuvre quel que soit l’aléa (86 à 96)', function()
            assert.equal(86, value('epee_courte', { 5, 5 }, -5))
            assert.equal(96, value('epee_courte', { 5, 5 }, 5))
        end)

        it('lingot de fer tiré d’un minerai Excellent (palier 4) : 81 ± 5, palier 4 sauf aléa ≥ 3,5', function()
            assert.equal(81, value('lingot_fer', { 4 }, 0))
            assert.equal(4, quality.tierOf(value('lingot_fer', { 4 }, 3.4)))
            assert.equal(5, quality.tierOf(value('lingot_fer', { 4 }, 3.5)))
        end)

        it('lingots Excellent (palier 4) : même avec du chêne de palier 5, 84 sans aléa, pas de chef-d’œuvre garanti', function()
            assert.equal(84, value('epee_courte', { 4, 5 }, 0))          -- (3 × 72 + 92) / 4 = 77 → 83,5
            assert.equal(79, value('epee_courte', { 4, 5 }, -5))
            assert.equal(78, value('epee_courte', { 4, 1 }, 5))           -- chêne de palier 1 : jamais
        end)
    end)
end)
