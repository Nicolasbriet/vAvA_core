local helper = require('tests.helper')

-- Blessures des sorts sur la chaîne de dégâts (modules/vava_magic/shared/harm.lua, T-116), essayées avec les règles
-- pures de vava_health (shared/packet.lua, shared/chain.lua) pour prouver que rien ne change en jeu :
--   avant 2.9.0, un sort appelait vava_health:damage(cible, min(1, points / 100)), que vava_health 1.3.0 change en
--   hit { amount = part × 100, kind = 'pur', tags = { legacy } } ; désormais le sort appelle hit lui-même avec
--   amount = points (une vie pleine au plus), le type de son élément, sa source et ses étiquettes ;
--   sans protection, le montant appliqué est le même pour les onze sorts, à chaque niveau, éclats, brûlures,
--   combinaisons (séchage, roche ardente, vapeur) compris ;
--   boucliers (étape bouclier) et résistances (étape resistance) de la magie : le plus proche de sa fin absorbe
--   d'abord ; la plus forte résistance et la plus forte faiblesse l'emportent, jamais cumulées
--   (README de vava_magic, « Blessures et chaîne de dégâts » ; docs/api.md, § vava_magic).
describe('vava_magic blessures sur la chaîne de dégâts', function()
    local harm, magicCfg, packet, chain, limits, healthCfg

    -- chemin d'avant 2.9.0 : part de vie passée à damage, que vava_health multiplie par ses points
    local function legacyAmount(points)
        return math.min(1, points / magicCfg.combat.healthPoints) * healthCfg.chain.healthPoints
    end

    local function applied(amount, health)
        return math.min(amount, health)
    end

    local DAMAGING = {
        boule_de_feu = { 'impact' }, trait_de_glace = { 'impact' }, projectile_de_roche = { 'impact' },
        nova_ardente = { 'zone' }, secousse = { 'zone' }, mur_de_flammes = { 'aura' },
    }
    local HARMLESS = { 'vague', 'brume', 'rempart', 'lueur', 'murmure' }

    before_each(function()
        helper.reset()
        VavaMagic, VavaHealth = nil, nil
        helper.loadAll({
            'modules/vava_magic/shared/constants.lua',
            'modules/vava_magic/config.lua',
            'modules/vava_magic/shared/harm.lua',
            'modules/vava_health/shared/constants.lua',
            'modules/vava_health/config.lua',
            'modules/vava_health/shared/packet.lua',
            'modules/vava_health/shared/chain.lua',
        })
        harm, magicCfg = VavaMagic.harm, VavaMagic.config
        packet, chain, healthCfg = VavaHealth.packet, VavaHealth.chain, VavaHealth.config
        limits = packet.compile(healthCfg.chain)
    end)

    describe('montant', function()
        it('garde les points du sort, une vie pleine au plus, à l’échelle de la chaîne', function()
            assert.equal(8, harm.amount(8, 100))
            assert.equal(8, harm.amount(8, 100, 100))
            assert.equal(100, harm.amount(150, 100, 100))
            assert.equal(16, harm.amount(8, 100, 200))
            assert.equal(200, harm.amount(150, 100, 200))
            assert.equal(8.5, harm.amount(8.5, 100, 100))
        end)

        it('refuse un montant nul, négatif ou non fini', function()
            for _, points in ipairs({ 0, -3, 0 / 0, math.huge, -math.huge, '8', nil, {} }) do
                assert.is_nil(harm.amount(points, 100, 100))
            end
            assert.is_nil(harm.amount(8, 0, 100))
        end)

        it('une chaîne aux points inconnus ou invalides garde l’échelle de la magie', function()
            assert.equal(12, harm.amount(12, 100, nil))
            assert.equal(12, harm.amount(12, 100, 0))
            assert.equal(12, harm.amount(12, 100, 0 / 0))
        end)

        it('les deux modules comptent une vie pleine pareil (100 points)', function()
            assert.equal(magicCfg.combat.healthPoints, healthCfg.chain.healthPoints)
        end)
    end)

    describe('mêmes dégâts qu’avant pour les onze sorts', function()
        --- Tous les coups d'un sort à un niveau : { points, nature, élément forcé? }.
        local function hitsOf(name, levelCfg, spellCfg)
            local list = {}
            local main = DAMAGING[name][1]
            if levelCfg.damage and levelCfg.damage > 0 then list[#list + 1] = { levelCfg.damage, main } end
            if levelCfg.aoeRadius and levelCfg.aoeRadius > 0 then
                list[#list + 1] = { levelCfg.damage * levelCfg.aoeShare, 'zone' }
            end
            local burn = levelCfg.burn
            if type(burn) == 'table' and (spellCfg.burnEnabled ~= false) then
                list[#list + 1] = { burn.damage, 'brulure', 'feu' }
            end
            return list
        end

        it('chaque niveau de chaque sort offensif : même montant, paquet admis par la chaîne', function()
            local checked = 0
            for name in pairs(DAMAGING) do
                local spellCfg = magicCfg.spells[name]
                assert.is_table(spellCfg, name)
                for level, levelCfg in ipairs(spellCfg.levels) do
                    for _, hit in ipairs(hitsOf(name, levelCfg, spellCfg)) do
                        local points, nature, element = hit[1], hit[2], hit[3]
                        local amount = harm.amount(points, magicCfg.combat.healthPoints, healthCfg.chain.healthPoints)
                        local label = ('%s N%d %s'):format(name, level, nature)
                        assert.is_near(legacyAmount(points), amount, 1e-9, label)
                        for _, health in ipairs({ 100, 37, 5 }) do
                            assert.is_near(applied(legacyAmount(points), health), applied(amount, health), 1e-9, label)
                        end
                        local p, code = packet.normalize(harm.packet({
                            amount = amount, kind = harm.kindOf(element or spellCfg.element, magicCfg.combat.kinds),
                            nature = nature, source = 3, sourceCharacter = 42, spell = name,
                        }), limits)
                        assert.is_nil(code, label)
                        assert.equal(amount, p.amount)
                        assert.equal(name, p.spell)
                        assert.equal(3, p.source)
                        assert.equal(42, p.sourceCharacter)
                        checked = checked + 1
                    end
                end
            end
            -- 6 sorts × 5 niveaux, plus les éclats (boule N3-5, roche N5) et les brûlures (boule N4-5, nova N4-5,
            -- mur N1-5)
            assert.equal(30 + 4 + (2 + 2 + 5), checked)
        end)

        it('les cinq autres sorts ne blessent pas (aucun dégât à leurs niveaux)', function()
            for _, name in ipairs(HARMLESS) do
                local spellCfg = magicCfg.spells[name]
                assert.is_table(spellCfg, name)
                for level, levelCfg in ipairs(spellCfg.levels) do
                    assert.is_nil(levelCfg.damage, ('%s N%d'):format(name, level))
                end
            end
            local count = 0
            for _ in pairs(magicCfg.spells) do count = count + 1 end
            assert.equal(11, count)
        end)

        it('combinaisons : séchage (moitié), roche ardente (feu en plus), vapeur (un point par seconde)', function()
            local share = magicCfg.combos.sechage.result.damageShare
            for _, name in ipairs({ 'boule_de_feu', 'nova_ardente', 'mur_de_flammes' }) do
                for _, levelCfg in ipairs(magicCfg.spells[name].levels) do
                    local points = levelCfg.damage * share
                    assert.is_near(legacyAmount(points), harm.amount(points, 100, 100), 1e-9)
                end
            end
            local carry = magicCfg.combos.roche_ardente.result.carry
            assert.equal(legacyAmount(carry.damage), harm.amount(carry.damage, 100, 100))
            assert.equal('feu', harm.kindOf('feu', magicCfg.combat.kinds))
            local steam = magicCfg.combos.vapeur.result
            assert.equal(legacyAmount(steam.damage), harm.amount(steam.damage, 100, 100))
            local p = packet.normalize(harm.packet({
                amount = steam.damage, kind = harm.kindOf(steam.element, magicCfg.combat.kinds), nature = 'aura',
                source = 3, spell = 'vapeur',
            }), limits)
            assert.equal('eau', p.kind)
            assert.equal('vapeur', p.spell)
        end)

        it('sans protection, la chaîne applique le montant du sort quel que soit son type', function()
            local list = chain.sort({
                { key = 'vava_magic:protections', stage = 'bouclier', label = 'b',
                    apply = function(ctx)
                        local absorbed = harm.absorb({}, ctx.amount, ctx.kind, 0)
                        return absorbed > 0 and { absorbed = absorbed } or nil
                    end },
                { key = 'vava_magic:resistances', stage = 'resistance', label = 'r',
                    apply = function(ctx) return harm.resist({}, ctx.kind, ctx.amount, 0) end },
            })
            for _, kind in ipairs({ 'feu', 'eau', 'terre', 'pur' }) do
                local state = chain.newState(12)
                chain.run(list, { kind = kind }, state, {
                    maxAmount = 200, slowMs = 5, clock = function() return 0 end,
                    invoke = function(entry, ctx) return pcall(entry.apply, ctx) end,
                })
                assert.equal(12, state.amount)
                assert.equal(0, state.absorbed)
                assert.equal(0, state.resisted)
                assert.equal(0, state.added)
            end
        end)
    end)

    describe('type, étiquettes, source, paquet', function()
        it('l’élément d’un sort donne son type ; sans élément connu : pur', function()
            local kinds = magicCfg.combat.kinds
            assert.equal('feu', harm.kindOf(magicCfg.spells.boule_de_feu.element, kinds))
            assert.equal('feu', harm.kindOf(magicCfg.spells.mur_de_flammes.element, kinds))
            assert.equal('feu', harm.kindOf(magicCfg.spells.nova_ardente.element, kinds))
            assert.equal('eau', harm.kindOf(magicCfg.spells.trait_de_glace.element, kinds))
            assert.equal('terre', harm.kindOf(magicCfg.spells.projectile_de_roche.element, kinds))
            assert.equal('terre', harm.kindOf(magicCfg.spells.secousse.element, kinds))
            assert.equal('pur', harm.kindOf('glace', kinds))
            assert.equal('pur', harm.kindOf(nil, kinds))
            assert.equal('pur', harm.kindOf(12, kinds))
            -- chaque type de la magie est un type de la chaîne
            for element, kind in pairs(kinds) do
                assert.is_true(limits.kinds[kind], element)
                assert.is_table(magicCfg.elements[element], element)
            end
            for _, kind in ipairs(magicCfg.protections.kinds) do assert.is_true(limits.kinds[kind], kind) end
        end)

        it('étiquettes selon la nature : seules zone qui dure et brûlure passent un lanceur à terre', function()
            assert.same({ spell = true, ranged = true }, harm.tags('impact'))
            assert.same({ spell = true, area = true }, harm.tags('zone'))
            assert.same({ spell = true, area = true, overTime = true }, harm.tags('aura'))
            assert.same({ spell = true, overTime = true }, harm.tags('brulure'))
            assert.same({ spell = true }, harm.tags('autre'))
            for _, nature in ipairs({ 'impact', 'zone', 'aura', 'brulure' }) do
                local p, code = packet.normalize({ amount = 1, kind = 'feu', tags = harm.tags(nature) }, limits)
                assert.is_nil(code, nature)
                assert.is_table(p.tags)
            end
            -- deux appels ne partagent pas la même table
            local a = harm.tags('impact')
            a.melee = true
            assert.is_nil(harm.tags('impact').melee)
        end)

        it('source : le lanceur toujours là ou parti ; plus la source s’il joue un autre personnage', function()
            local source, character = harm.source(3, 42, 42)
            assert.equal(3, source)
            assert.equal(42, character)
            source, character = harm.source(3, nil, 42)
            assert.equal(3, source)
            assert.equal(42, character)
            source, character = harm.source(3, 42, nil)
            assert.equal(3, source)
            assert.equal(42, character)
            source, character = harm.source(3, 42, 77)
            assert.is_nil(source)
            assert.equal(42, character)
            source, character = harm.source(0, 0, nil)
            assert.is_nil(source)
            assert.is_nil(character)
            source, character = harm.source(70000, 42, nil)
            assert.is_nil(source)
            assert.equal(42, character)
            source = harm.source(2.5, 42, 42)
            assert.is_nil(source)
        end)

        it('paquet : seuls les champs de la chaîne, un sort mal formé est omis', function()
            local p = harm.packet({ amount = 8, kind = 'feu', nature = 'impact', source = 3, spell = 'boule_de_feu' })
            for key in pairs(p) do
                assert.is_true(key == 'amount' or key == 'kind' or key == 'source' or key == 'sourceCharacter'
                    or key == 'spell' or key == 'tags', key)
            end
            assert.is_not_nil(packet.normalize(p, limits))
            assert.is_nil(harm.packet({ amount = 8, kind = 'feu', nature = 'impact', spell = 'a b' }).spell)
            assert.is_nil(harm.packet({ amount = 8, kind = 'feu', nature = 'impact', spell = ('x'):rep(65) }).spell)
            assert.is_nil(harm.packet({ amount = 8, kind = 'feu', nature = 'impact', spell = 12 }).spell)
            local copy = packet.normalize(harm.packet({ amount = 8, kind = 'feu', nature = 'impact', spell = 'a b' }), limits)
            assert.is_not_nil(copy)
        end)
    end)

    describe('boucliers (étape bouclier)', function()
        it('un bouclier absorbe jusqu’à sa réserve, sans rien modifier', function()
            local shields = { { points = 20, untilMs = 5000 } }
            local absorbed, takes = harm.absorb(shields, 30, 'tranchant', 1000)
            assert.equal(20, absorbed)
            assert.same({ 20 }, takes)
            assert.equal(20, shields[1].points)
            absorbed, takes = harm.absorb(shields, 12, 'feu', 1000)
            assert.equal(12, absorbed)
            assert.same({ 12 }, takes)
        end)

        it('le plus proche de sa fin d’abord, puis le plus ancien', function()
            local shields = {
                { points = 10, untilMs = 9000 },
                { points = 5, untilMs = 3000 },
                { points = 8, untilMs = 9000 },
            }
            local absorbed, takes = harm.absorb(shields, 12, 'feu', 1000)
            assert.equal(12, absorbed)
            assert.same({ 7, 5, 0 }, takes)
            absorbed, takes = harm.absorb(shields, 40, 'feu', 1000)
            assert.equal(23, absorbed)
            assert.same({ 10, 5, 8 }, takes)
        end)

        it('un bouclier fini, vide ou d’un autre type ne prend rien', function()
            local shields = {
                { points = 10, untilMs = 1000 },
                { points = 0, untilMs = 9000 },
                { points = 10, untilMs = 9000, kinds = harm.kindSet({ 'feu' }) },
            }
            local absorbed, takes = harm.absorb(shields, 6, 'tranchant', 1000)
            assert.equal(0, absorbed)
            assert.same({ 0, 0, 0 }, takes)
            absorbed, takes = harm.absorb(shields, 6, 'feu', 1000)
            assert.equal(6, absorbed)
            assert.same({ 0, 0, 6 }, takes)
        end)

        it('montant invalide : rien', function()
            for _, amount in ipairs({ 0, -1, 0 / 0, math.huge }) do
                local absorbed = harm.absorb({ { points = 10, untilMs = 9000 } }, amount, 'feu', 0)
                assert.equal(0, absorbed)
            end
        end)

        it('ensemble de types', function()
            assert.same({ feu = true, eau = true }, harm.kindSet({ 'feu', 'eau' }))
            assert.is_nil(harm.kindSet({}))
            assert.is_nil(harm.kindSet(nil))
            assert.is_nil(harm.kindSet('feu'))
        end)
    end)

    describe('résistances (étape resistance)', function()
        it('retire la part d’une résistance au type du coup', function()
            local list = { { kind = 'feu', share = 0.4, untilMs = 9000 } }
            assert.same({ resisted = 24 }, harm.resist(list, 'feu', 60, 0))
            assert.is_nil(harm.resist(list, 'eau', 60, 0))
            assert.is_nil(harm.resist(list, 'feu', 60, 9000))
        end)

        it('la plus forte résistance et la plus forte faiblesse, jamais cumulées', function()
            local list = {
                { kind = 'feu', share = 0.3, untilMs = 9000 },
                { kind = 'feu', share = 0.5, untilMs = 9000 },
                { kind = 'feu', share = -0.2, untilMs = 9000 },
                { kind = 'feu', share = -0.1, untilMs = 9000 },
            }
            local result = harm.resist(list, 'feu', 10, 0)
            assert.is_near(3, result.resisted, 1e-9)
            assert.same({ added = 5 }, harm.resist({ { kind = 'eau', share = -0.5, untilMs = 9000 } }, 'eau', 10, 0))
            assert.is_nil(harm.resist({
                { kind = 'eau', share = -0.5, untilMs = 9000 }, { kind = 'eau', share = 0.5, untilMs = 9000 },
            }, 'eau', 10, 0))
        end)

        it('une part au-delà de 1 est bornée, une part non finie ignorée', function()
            assert.same({ resisted = 10 }, harm.resist({ { kind = 'feu', share = 3, untilMs = 9000 } }, 'feu', 10, 0))
            assert.same({ added = 10 }, harm.resist({ { kind = 'feu', share = -3, untilMs = 9000 } }, 'feu', 10, 0))
            assert.is_nil(harm.resist({ { kind = 'feu', share = 0 / 0, untilMs = 9000 } }, 'feu', 10, 0))
            assert.is_nil(harm.resist({ { kind = 'feu', share = 0.5, untilMs = 9000 } }, 'feu', 0, 0))
        end)

        it('sur la vraie chaîne : bouclier de 20 puis 40 % de résistance sur 60 de feu → 24 (COMBAT_V1)', function()
            local shields = { { points = 20, untilMs = 9000 } }
            local resistances = { { kind = 'feu', share = 0.4, untilMs = 9000 } }
            local list = chain.sort({
                { key = 'vava_magic:resistances', stage = 'resistance', label = 'r',
                    apply = function(ctx) return harm.resist(resistances, ctx.kind, ctx.amount, 0) end },
                { key = 'vava_magic:protections', stage = 'bouclier', label = 'b',
                    apply = function(ctx)
                        local absorbed, takes = harm.absorb(shields, ctx.amount, ctx.kind, 0)
                        for i, take in ipairs(takes) do shields[i].points = shields[i].points - take end
                        return absorbed > 0 and { absorbed = absorbed } or nil
                    end },
            })
            local options = {
                maxAmount = 200, slowMs = 5, clock = function() return 0 end,
                invoke = function(entry, ctx) return pcall(entry.apply, ctx) end,
            }
            local state = chain.run(list, { kind = 'feu' }, chain.newState(60), options)
            assert.equal(20, state.absorbed)
            assert.is_near(16, state.resisted, 1e-9)
            assert.is_near(24, state.amount, 1e-9)
            -- le bouclier est vide : le coup suivant, d'épée, passe entier (la résistance ne vaut que pour le feu)
            assert.equal(0, shields[1].points)
            state = chain.run(list, { kind = 'tranchant' }, chain.newState(30), options)
            assert.equal(30, state.amount)
            -- une faiblesse de 50 % au feu ajoute la moitié du coup
            resistances[1].share = -0.5
            state = chain.run(list, { kind = 'feu' }, chain.newState(20), options)
            assert.equal(10, state.added)
            assert.equal(30, state.amount)
        end)
    end)
end)
