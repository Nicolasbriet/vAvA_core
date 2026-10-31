local helper = require('tests.helper')

-- Règles pures du bouclier accroché (modules/vava_combat/shared/shield.lua, T-111) avec la config livrée : position
-- (bras ou dos) selon l'objet en main, placement lu dans la config, valeur du statebag, numéro réseau d'un statebag,
-- délai de la garde. Règles documentées : README du module et docs/plan/specs/T-111.md § 5.3, § 7.5 et § 11.1.

describe('vava_combat shared/shield', function()
    local shield, cfg

    before_each(function()
        helper.reset()
        VavaCombat = nil
        helper.loadAll({
            'modules/vava_combat/shared/constants.lua',
            'modules/vava_combat/config.lua',
            'modules/vava_combat/shared/shield.lua',
        })
        shield, cfg = VavaCombat.shield, VavaCombat.config
    end)

    after_each(function() VavaCombat = nil end)

    describe('position', function()
        local function at(item, rules) return shield.position(item, cfg.weapons, rules or cfg.shield) end

        it('mains vides : dans le dos, ou au bras avec armWithEmptyHand', function()
            assert.equal('back', at(nil))
            assert.equal('arm', at(nil, { armWith = cfg.shield.armWith, armWithEmptyHand = true }))
        end)

        it('au bras avec une arme à une main ou une dague', function()
            assert.equal('arm', at('epee_courte'))
            assert.equal('arm', at('hache_d_armes'))
            assert.equal('arm', at('masse_d_armes'))
            assert.equal('arm', at('dague'))
        end)

        it('dans le dos avec une arme à deux mains, un bâton, un outil ou un objet inconnu', function()
            assert.equal('back', at('epee_longue'))
            assert.equal('back', at('baton_ferre'))
            assert.equal('back', at('hache_fer'))
            assert.equal('back', at('inconnu'))
            assert.equal('back', at(42))
        end)
    end)

    describe('placement', function()
        it('lit le modèle et l\'os de la position dans la config', function()
            local arm = shield.placement('bouclier_rond', 'arm', cfg.shields)
            assert.equal(61163, arm.bone)
            assert.equal('prop_ballistic_shield', arm.model)
            assert.same({ 0.05, 0.05, 0.0 }, arm.offset)
            assert.equal(24818, shield.placement('bouclier_rond', 'back', cfg.shields).bone)
            assert.is_nil(shield.placement('epee_courte', 'arm', cfg.shields))
            assert.is_nil(shield.placement(nil, 'arm', cfg.shields))
        end)
    end)

    describe('valid et same', function()
        it('n\'admet que nil ou { id, item } bien formés', function()
            assert.is_true(shield.valid(nil))
            assert.is_true(shield.valid({ id = 3, item = 'bouclier_rond' }))
            assert.is_true(shield.valid({ id = 3.0, item = 'bouclier_rond' }))
            assert.is_false(shield.valid({ id = 0, item = 'bouclier_rond' }))
            assert.is_false(shield.valid({ id = 1.5, item = 'bouclier_rond' }))
            assert.is_false(shield.valid({ id = 2 ^ 53, item = 'bouclier_rond' }))
            assert.is_false(shield.valid({ id = 0 / 0, item = 'bouclier_rond' }))
            assert.is_false(shield.valid({ id = 3, item = '' }))
            assert.is_false(shield.valid({ id = 3, item = string.rep('a', 65) }))
            assert.is_false(shield.valid({ id = 3, item = 'bouclier_rond', model = 'prop_x' }))
            assert.is_false(shield.valid('bouclier_rond'))
        end)

        it('compare deux valeurs ; deux valeurs mal formées ne sont jamais égales', function()
            assert.is_true(shield.same(nil, nil))
            assert.is_true(shield.same({ id = 3, item = 'bouclier_rond' }, { id = 3.0, item = 'bouclier_rond' }))
            assert.is_false(shield.same({ id = 3, item = 'bouclier_rond' }, nil))
            assert.is_false(shield.same({ id = 3, item = 'bouclier_rond' }, { id = 4, item = 'bouclier_rond' }))
            local bad = { id = 0, item = 'bouclier_rond' }
            assert.is_false(shield.same(bad, bad))
            assert.is_false(shield.same(bad, { id = 0, item = 'bouclier_rond' }))
            assert.same({ id = 7, item = 'bouclier_rond' }, shield.value(7, 'bouclier_rond'))
        end)
    end)

    describe('netIdOf', function()
        it('lit le numéro réseau d\'un statebag d\'entité', function()
            assert.equal(42, shield.netIdOf('entity:42'))
            assert.is_nil(shield.netIdOf('player:3'))
            assert.is_nil(shield.netIdOf('entity:0'))
            assert.is_nil(shield.netIdOf('entity:1234567890'))
            assert.is_nil(shield.netIdOf(nil))
        end)
    end)

    describe('guardDelay', function()
        -- même règle que vava_inventory/shared/held.lua : remises 0 à 2 → 250 ms ; la quatrième remise (3 déjà faites)
        -- → 500 ms ; puis 1 000 ms, plafond
        it('espace les remises après guardMaxCorrections, jusqu\'au plafond', function()
            local delays = {}
            for streak = 0, 6 do delays[#delays + 1] = shield.guardDelay(streak, cfg.shield) end
            assert.same({ 250, 250, 250, 500, 1000, 1000, 1000 }, delays)
            assert.equal(1000, shield.guardDelay(40, cfg.shield))
        end)
    end)
end)
