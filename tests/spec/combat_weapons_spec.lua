local helper = require('tests.helper')

-- Règles pures des armes (modules/vava_combat/shared/weapons.lua, T-111) avec la config livrée du module : contrôle du
-- catalogue (en deux parts depuis 1.2.0, T-112), qualité, solidité, montant d'un coup, usure, options de strike, paquet
-- hit. Règles documentées : README du module et docs/plan/specs/T-111.md § 5.1, § 7.1 à § 7.3 et § 11.1, T-112.md § 4.

describe('vava_combat shared/weapons', function()
    local weapons, cfg, CATEGORIES

    local function copy(value)
        if type(value) ~= 'table' then return value end
        local out = {}
        for key, item in pairs(value) do out[key] = copy(item) end
        return out
    end

    --- Config modifiée par `change` (copie de la config livrée).
    local function variant(change)
        local c = copy(cfg)
        change(c)
        return c
    end

    local function refused(change, pattern)
        local ok, err = weapons.check(variant(change), CATEGORIES)
        assert.is_false(ok)
        assert.is_string(err)
        if pattern then assert.matches(pattern, err) end
    end

    before_each(function()
        helper.reset()
        VavaCombat = nil
        helper.loadAll({
            'modules/vava_combat/shared/constants.lua',
            'modules/vava_combat/config.lua',
            'modules/vava_combat/shared/weapons.lua',
        })
        weapons, cfg, CATEGORIES = VavaCombat.weapons, VavaCombat.config, VavaCombat.CATEGORIES
    end)

    after_each(function() VavaCombat = nil end)

    describe('check', function()
        it('accepte la config livrée', function()
            assert.same({ true }, { weapons.check(cfg, CATEGORIES) })
        end)

        it('refuse une fiche mal formée, avec sa raison', function()
            refused(function(c) c.weaponClasses.dague.category = 'arc' end, 'catégorie inconnue')
            refused(function(c) c.weaponClasses.dague.family = 'fleau' end, 'famille inconnue')
            refused(function(c) c.weapons.dague.kind = 'perçant' end, 'type de dégâts inconnu')
            refused(function(c) c.weapons.dague.damage = 0 end, 'damage')
            refused(function(c) c.weapons.dague.damage = 101 end, 'damage')
            refused(function(c) c.weapons.dague.damage = 0 / 0 end, 'damage')
            refused(function(c) c.weapons.dague.reachBonus = 2 end, 'reachBonus')
            refused(function(c) c.weapons.dague.durability = 1.5 end, 'durability')
            refused(function(c) c.weapons.dague.durability = 0 end, 'durability')
            refused(function(c) c.weapons.dague.block = 1.2 end, 'block')
            refused(function(c) c.weapons.dague.tranchant = true end, 'clé inconnue')
        end)

        it('refuse un bouclier sans placement ou tenu en main, une arme déclarée sans held', function()
            refused(function(c) c.shields.bouclier_rond = nil end, 'placement absent')
            refused(function(c) c.shields.bouclier_rond.arm.bone = 1.5 end, 'arm et back')
            refused(function(c) c.shields.bouclier_rond.back.offset = { 0, 0 } end, 'arm et back')
            refused(function(c) c.items.bouclier_rond.held = { model = 'prop_ballistic_shield' } end, 'held interdit')
            refused(function(c) c.items.dague.held = nil end, 'sans held')
            refused(function(c) c.shields.dague = copy(c.shields.bouclier_rond) end, "n'est pas un bouclier")
        end)

        it('refuse une recette qui porte sa solidité, ou dont le produit n\'est pas une arme déclarée', function()
            refused(function(c) c.recipes.dague.durability = 100 end, 'posés par le code')
            refused(function(c) c.recipes.dague.signed = true end, 'posés par le code')
            refused(function(c)
                c.recipes.pain = copy(c.recipes.dague)
                c.recipes.pain.output.item = 'pain'
            end, 'arme du catalogue')
            refused(function(c) c.recipes.dague.output.item = 'epee_longue' end, 'même nom')
            -- l'Épée courte est adoptée : pas déclarée dans items, sa recette reste celle de vava_crafting
            refused(function(c)
                c.recipes.epee_courte = copy(c.recipes.dague)
                c.recipes.epee_courte.output.item = 'epee_courte'
            end, 'déclarée dans items')
        end)

        -- 1.2.0 (T-112, relecture réseau R-2 de T-142) : classe dans config_client.lua, fiche dans config.lua
        it('refuse une config en deux parts qui ne vont pas ensemble, avec la marche à suivre', function()
            refused(function(c) c.weaponClasses.pain = { category = 'une_main', family = 'epee' } end, 'classe sans fiche')
            refused(function(c) c.weapons.pain = copy(c.weapons.dague) end, 'fiche sans classe')
            refused(function(c) c.weapons.dague.category = 'dague' end, "config.lua d'avant 1%.2%.0")
            refused(function(c) c.weapons.dague.family = 'dague' end, "config.lua d'avant 1%.2%.0")
            refused(function(c) c.weaponClasses = nil end, "config_client.lua d'avant 1%.2%.0")
            refused(function(c) c.shield.toggleMs = nil end, "config.lua d'avant 1%.2%.0")
            refused(function(c) c.weaponClasses.dague.kind = 'percant' end, 'hors de la classe')
        end)

        it('fusionne la classe et la fiche d\'une arme', function()
            local merged = weapons.merge(cfg.weaponClasses.dague, cfg.weapons.dague)
            assert.equal('dague', merged.category)
            assert.equal('percant', merged.kind)
            assert.equal(8, merged.damage)
            assert.is_nil(weapons.merge(nil, cfg.weapons.dague))
        end)

        it('exige exactement les catégories de COMBAT_V1', function()
            refused(function(c) c.categories.baton = nil end, "'baton' manquante")
            refused(function(c) c.categories.arc = { label = 'Arc', order = 6 } end, "n'est pas une catégorie")
        end)

        it('refuse un objet déclaré qui n\'est pas une arme', function()
            refused(function(c) c.items.pain = { label = 'Pain', width = 1, height = 1, weight = 1, stack = 1 } end, 'pas une arme')
        end)
    end)

    describe('qualité', function()
        it('facteur linéaire de 0,85 à 1,15, qualité absente ou illisible : 50', function()
            local function f(q) return weapons.qualityFactor(q, cfg) end
            assert.near(0.85, f(0), 1e-9)
            assert.near(1.00, f(50), 1e-9)
            assert.near(1.15, f(100), 1e-9)
            assert.near(1.042, f(64), 1e-9)
            assert.near(1.00, f(nil), 1e-9)
            assert.near(1.00, f('x'), 1e-9)
            assert.near(1.00, f(0 / 0), 1e-9)
            assert.near(0.85, f(-5), 1e-9)
            assert.near(1.15, f(150), 1e-9)
        end)
    end)

    describe('durabilityOf', function()
        local courte
        before_each(function() courte = cfg.weapons.epee_courte end)

        it('lit la solidité d\'une pile, ou celle de la fiche', function()
            assert.same({ current = 150, max = 150, dull = false, hasMax = false }, weapons.durabilityOf({}, courte))
            assert.is_true(weapons.durabilityOf({ durability = 0, max_durability = 150 }, courte).dull)
            assert.is_true(weapons.durabilityOf({ broken = true }, courte).dull)
            assert.equal(150, weapons.durabilityOf({ durability = 1.5 }, courte).current)
            assert.equal(150, weapons.durabilityOf({ durability = 200, max_durability = 150 }, courte).current)
            assert.same({ current = 37, max = 145, dull = false, hasMax = true },
                weapons.durabilityOf({ durability = 37, max_durability = 145 }, courte))
        end)
    end)

    describe('amount', function()
        local function amount(item, meta, damage) return (weapons.amount(cfg.weapons[item], meta, damage, cfg)) end

        it('dégâts × qualité × usure × technique, arrondis au dixième, bornés', function()
            assert.equal(12.0, amount('epee_courte', { quality = 50 }, 1))
            assert.equal(13.8, amount('epee_courte', { quality = 100 }, 1))
            assert.equal(10.2, amount('epee_courte', { quality = 0 }, 1))
            assert.equal(12.5, amount('epee_courte', { quality = 64 }, 1))
            assert.equal(6.0, amount('epee_courte', { quality = 50, durability = 0, max_durability = 150 }, 1))
            assert.equal(18.0, amount('epee_courte', { quality = 50 }, 1.5))
            -- plancher : un paquet hit exige un montant > 0
            assert.equal(0.5, amount('dague', { quality = 0, durability = 0 }, 0.1))
            assert.equal(51.0, amount('epee_longue', { quality = 50 }, 3))
            assert.equal(12.0, amount('epee_courte', nil, 1))
        end)

        it('plafonne à 200, jamais au-dessus', function()
            local def = { damage = 100, kind = 'tranchant', durability = 100 }
            assert.equal(200, (weapons.amount(def, { quality = 100 }, 3, cfg)))
        end)

        it('rend aussi le facteur de la pièce', function()
            local _, factor = weapons.amount(cfg.weapons.epee_courte, { quality = 64, durability = 0 }, 1, cfg)
            assert.near(0.521, factor, 1e-9)
        end)
    end)

    describe('usure', function()
        it('chance d\'user selon la qualité', function()
            assert.near(1.0, weapons.wearChance(0, cfg), 1e-9)
            assert.near(0.8, weapons.wearChance(50, cfg), 1e-9)
            assert.near(0.6, weapons.wearChance(100, cfg), 1e-9)
        end)

        it('use un coup arrivé, paré, bloqué ou absorbé ; jamais une esquive ni un coup refusé', function()
            local function wears(result) return weapons.shouldWear(result, cfg) end
            assert.is_false(wears(nil))
            assert.is_true(wears({ applied = 5 }))
            assert.is_true(wears({ applied = 0, blocked = 12 }))
            assert.is_false(wears({ cancelled = 'esquive', stage = 'esquive' }))
            assert.is_true(wears({ cancelled = 'parade', stage = 'parade' }))
            assert.is_true(wears({ cancelled = 'mur', stage = 'blocage' }))
            assert.is_true(wears({ cancelled = 'egide', stage = 'bouclier' }))
            assert.is_false(wears({ cancelled = 'downed' }))
            assert.is_false(wears({ cancelled = 'treve', stage = 'before' }))
            assert.is_false(wears({ cancelled = 'zone', stage = 'annulation' }))
        end)

        it('pas d\'usure (qualité 50, chance 0,8)', function()
            local courte = cfg.weapons.epee_courte
            local function step(meta, roll) return weapons.wearStep(meta, courte, roll, cfg) end
            local s = step({ quality = 50, durability = 150, max_durability = 150 }, 0.5)
            assert.is_true(s.worn)
            assert.equal(149, s.durability)
            assert.same({ durability = 149 }, s.patch)
            s = step({ quality = 50, durability = 150, max_durability = 150 }, 0.9)
            assert.is_false(s.worn)
            assert.is_nil(s.patch)
            assert.equal(150, s.durability)
            s = step({ quality = 50, durability = 38, max_durability = 150 }, 0.5)
            assert.equal(37, s.durability)
            assert.is_true(s.crossedWarn)
            s = step({ quality = 50, durability = 37, max_durability = 150 }, 0.5)
            assert.equal(36, s.durability)
            assert.is_false(s.crossedWarn)
            s = step({ quality = 50, durability = 1, max_durability = 150 }, 0.5)
            assert.equal(0, s.durability)
            assert.is_true(s.dulled)
            assert.is_false(s.crossedWarn)
            s = step({ quality = 50, durability = 0, max_durability = 150 }, 0.0)
            assert.is_false(s.worn)
            assert.is_nil(s.patch)
            s = step({}, 0.5)
            assert.same({ durability = 149, max_durability = 150 }, s.patch)
        end)

        it('lower baisse de plusieurs points sans descendre sous 0, et ne monte jamais', function()
            local courte = cfg.weapons.epee_courte
            local s = weapons.lower({ durability = 149, max_durability = 150 }, courte, 110, cfg)
            assert.same({ durability = 39 }, s.patch)
            assert.equal(149, s.before)
            assert.is_false(s.crossedWarn)
            s = weapons.lower({ durability = 39, max_durability = 150 }, courte, 1000, cfg)
            assert.equal(0, s.durability)
            assert.is_true(s.dulled)
            assert.is_nil(weapons.lower({ durability = 39 }, courte, 0, cfg).patch)
            assert.is_nil(weapons.lower({ durability = 39 }, courte, -5, cfg).patch)
        end)
    end)

    describe('options', function()
        local function opt(value) return weapons.options(value, cfg) end

        it('rend le multiplicateur par défaut sans options', function()
            assert.same({ damage = 1 }, opt(nil))
        end)

        it('refuse toute option hors bornes ou inconnue', function()
            for _, bad in ipairs({
                { damage = 0.05 }, { damage = 4 }, { damage = 0 / 0 }, { technique = 'a b' },
                { technique = string.rep('a', 65) }, { tags = { melee = true } }, { tags = { foo = true } },
                { tags = { parryable = 1 } }, { tags = { 'parryable' } }, { part = 'queue' }, { foo = 1 }, 'x',
            }) do
                assert.same({ nil, 'invalid_options' }, { opt(bad) })
            end
        end)

        it('accepte une option complète', function()
            assert.same({ technique = 'vava_combat:taille_descendante', damage = 1.2, tags = { parryable = true }, part = 'torse' },
                opt({ technique = 'vava_combat:taille_descendante', damage = 1.2, tags = { parryable = true }, part = 'torse' }))
            assert.same({ technique = string.rep('a', 64), damage = 1 }, opt({ technique = string.rep('a', 64) }))
        end)
    end)

    describe('packet', function()
        it('paquet fermé de vava_health : melee toujours posé, rien de plus que demandé', function()
            local courte = cfg.weapons.epee_courte
            assert.same({ amount = 12.5, kind = 'tranchant', source = 3, weapon = 'epee_courte', tags = { melee = true } },
                weapons.packet('epee_courte', courte, 12.5, 3, { damage = 1 }))
            assert.same({ amount = 6, kind = 'tranchant', source = 3, weapon = 'epee_courte', technique = 'taille',
                part = 'tete', tags = { melee = true, parryable = true } },
                weapons.packet('epee_courte', courte, 6, 3, { damage = 1, technique = 'taille', part = 'tete', tags = { parryable = true } }))
        end)
    end)

    describe('sortKey', function()
        it('trie « Épée » avec les « e », casse ignorée, sous toute locale', function()
            local previous = helper.legacyLocale()
            local ok, err = pcall(function()
                assert.equal('epee longue', weapons.sortKey('Épée longue'))
                assert.equal('baton ferre', weapons.sortKey('Bâton ferré'))
                assert.equal('hache d\'armes', weapons.sortKey('Hache d\'armes'))
                assert.equal('', weapons.sortKey(nil))
                assert.is_true(weapons.sortKey('Épée courte') < weapons.sortKey('Hache d\'armes'))
            end)
            helper.restoreLocale(previous)
            assert(ok, err)
        end)
    end)

    describe('groupLines', function()
        it('regroupe des lignes en messages bornés, dans l\'ordre', function()
            assert.same({ 'aa\nbb', 'cc' }, weapons.groupLines({ 'aa', 'bb', 'cc' }, 6, '\n'))
            assert.same({ 'aa\nbb\ncc' }, weapons.groupLines({ 'aa', 'bb', 'cc' }, 8, '\n'))
            -- une ligne trop longue part seule
            assert.same({ 'a', 'bbbbbbbbbb', 'c' }, weapons.groupLines({ 'a', 'bbbbbbbbbb', 'c' }, 4, ' · '))
            assert.same({}, weapons.groupLines({}, 10, '\n'))
        end)
    end)

    describe('versionAtLeast', function()
        it('compare des versions semver', function()
            assert.is_true(weapons.versionAtLeast('1.5.0', '1.5.0'))
            assert.is_true(weapons.versionAtLeast('1.10.0', '1.5.0'))
            assert.is_true(weapons.versionAtLeast('2.0.0', '1.9.9'))
            assert.is_false(weapons.versionAtLeast('1.4.9', '1.5.0'))
            assert.is_false(weapons.versionAtLeast(nil, '1.0.0'))
            assert.is_false(weapons.versionAtLeast('abc', '1.0.0'))
        end)
    end)
end)
