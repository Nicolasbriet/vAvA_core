local helper = require('tests.helper')

-- Règles pures des vivres (modules/vava_provisions/shared/rules.lua, T-130 ; textes montrés au joueur :
-- shared/texts.lua, T-143) et config du module. Règles documentées :
-- README du module (« Règles ») et docs/plan/specs/T-130.md § 4, § 7 et § 11.1.

describe('vava_provisions rules', function()
    local rules, texts, cfg

    before_each(function()
        helper.reset()
        VavaProvisions = nil
        helper.loadAll({
            'modules/vava_provisions/shared/constants.lua',
            'modules/vava_provisions/config.lua',
            'modules/vava_provisions/shared/texts.lua',
            'modules/vava_provisions/shared/rules.lua',
        })
        rules, texts, cfg = VavaProvisions.rules, VavaProvisions.texts, VavaProvisions.config
    end)

    after_each(function()
        VavaProvisions = nil
    end)

    local function copy(value)
        if type(value) ~= 'table' then return value end
        local out = {}
        for key, item in pairs(value) do out[key] = copy(item) end
        return out
    end

    local function point(fields)
        local base = { id = 'puits_test', kind = 'puits', label = 'Puits d\'essai', x = 10.0, y = -20.0, z = 30.0, heading = 0.0 }
        for key, value in pairs(fields or {}) do base[key] = value end
        return base
    end

    local function code(def)
        local ok, result, field = rules.validatePoint(def, cfg.kinds)
        assert.is_false(ok)
        return result, field
    end

    describe('validatePoint', function()
        it('accepte chaque point de la config et le rend normalisé, modèle de la sorte résolu', function()
            for _, def in ipairs(cfg.points) do
                local ok, normalized = rules.validatePoint(def, cfg.kinds)
                assert.is_true(ok, def.id)
                assert.equal(def.id, normalized.id)
                assert.equal(cfg.kinds[def.kind].model, normalized.model)
            end
        end)

        it('refuse un identifiant vide, avec une espace, en capitales ou de 33 octets', function()
            for _, id in ipairs({ '', 'A b', 'Puits', string.rep('a', 33), 42 }) do
                assert.equal('invalid_id', code(point({ id = id })), tostring(id))
            end
            assert.is_true(rules.validatePoint(point({ id = string.rep('a', 32) }), cfg.kinds))
        end)

        it('refuse une sorte inconnue', function()
            assert.same({ 'unknown_kind', 'kind' }, { code(point({ kind = 'citerne' })) })
        end)

        it('refuse un nom vide, de 49 octets, ou avec un caractère de contrôle', function()
            for _, label in ipairs({ '', '   ', string.rep('a', 49), 'Puits\nfaux', 'Puits\127', 'Puits\0', 12 }) do
                assert.equal('invalid_label', code(point({ label = label })), tostring(label))
            end
            assert.equal('invalid_label', code(point({ label = 'Puits \xC3' })))  -- UTF-8 brisé
        end)

        it('accepte les accents (U+00A0 à U+017F) et nettoie les bords', function()
            local ok, normalized = rules.validatePoint(point({ label = '  Fontaine de l\'Âtre  ' }), cfg.kinds)
            assert.is_true(ok)
            assert.equal('Fontaine de l\'Âtre', normalized.label)
            for _, label in ipairs({ 'Source Ïgrande', 'Puits d\u{00A0}en bas', 'Œil de Łódź', 'Fontaine í' }) do
                assert.is_true(rules.validatePoint(point({ label = label }), cfg.kinds), label)
            end
            assert.is_true(rules.validatePoint(point({ label = string.rep('é', 24) }), cfg.kinds))
        end)

        it('refuse une position non finie ou hors de la carte', function()
            for _, value in ipairs({ 0 / 0, math.huge, -math.huge, 50001, -50001, '1' }) do
                assert.equal('invalid_position', code(point({ x = value })), tostring(value))
                assert.equal('invalid_position', code(point({ y = value })), tostring(value))
            end
            assert.equal('invalid_position', code(point({ z = 5001 })))
            assert.equal('invalid_position', code(point({ z = 0 / 0 })))
            assert.is_true(rules.validatePoint(point({ x = 50000, y = -50000, z = -5000 }), cfg.kinds))
        end)

        it('ramène le cap dans [0, 360) et refuse un cap non fini', function()
            local _, a = rules.validatePoint(point({ heading = 370 }), cfg.kinds)
            assert.equal(10, a.heading)
            local _, b = rules.validatePoint(point({ heading = -90 }), cfg.kinds)
            assert.equal(270, b.heading)
            local _, c = rules.validatePoint(point({ heading = nil }), cfg.kinds)
            assert.equal(0, c.heading)
            assert.equal('invalid_heading', code(point({ heading = 0 / 0 })))
        end)

        it('modèle : vide accepté (aucun prop), absent pris de la sorte, invalide refusé', function()
            local _, empty = rules.validatePoint(point({ model = '' }), cfg.kinds)
            assert.equal('', empty.model)
            local _, own = rules.validatePoint(point({ model = 'prop_well_01' }), cfg.kinds)
            assert.equal('prop_well_01', own.model)
            local _, kindModel = rules.validatePoint(point({ model = nil }), cfg.kinds)
            assert.equal(cfg.kinds.puits.model, kindModel.model)
            for _, model in ipairs({ 'a b', string.rep('a', 65), 'modèle', 5 }) do
                assert.equal('invalid_model', code(point({ model = model })), tostring(model))
            end
        end)
    end)

    describe('validateConfig', function()
        it('accepte la config livrée', function()
            assert.same({ true }, { rules.validateConfig(cfg) })
        end)

        it('refuse deux points de même identifiant, avec le chemin', function()
            local bad = copy(cfg)
            bad.points[2].id = bad.points[1].id
            assert.same({ false, 'duplicate', 'points[2].id' }, { rules.validateConfig(bad) })
        end)

        it('rend le chemin du champ fautif', function()
            local bad = copy(cfg)
            bad.points[2].label = ''
            assert.same({ false, 'invalid_label', 'points[2].label' }, { rules.validateConfig(bad) })
        end)

        it('refuse plus de maxPoints points', function()
            local bad = copy(cfg)
            bad.points = {}
            for i = 1, 257 do bad.points[i] = point({ id = 'p' .. i }) end
            assert.same({ false, 'too_many', 'points' }, { rules.validateConfig(bad) })
            bad.points[257] = nil
            assert.is_true(rules.validateConfig(bad))
        end)

        it('borne fill.maxPerDraw de 1 à 20', function()
            for _, value in ipairs({ 0, 21, 2.5 }) do
                local bad = copy(cfg)
                bad.fill.maxPerDraw = value
                assert.same({ false, 'invalid_count', 'fill.maxPerDraw' }, { rules.validateConfig(bad) }, tostring(value))
            end
        end)

        it('borne tearChance de 0 à 1', function()
            for _, value in ipairs({ -0.1, 1.1, 0 / 0, '0.1' }) do
                local bad = copy(cfg)
                bad.containers.eau.tearChance = value
                assert.same({ false, 'invalid_chance', 'containers.eau.tearChance' }, { rules.validateConfig(bad) }, tostring(value))
            end
            for _, value in ipairs({ 0, 1 }) do
                local ok = copy(cfg)
                ok.containers.eau.tearChance = value
                assert.is_true(rules.validateConfig(ok))
            end
        end)

        it('refuse un contenant vide absent des objets', function()
            local bad = copy(cfg)
            bad.containers.eau.empty = 'gourde'
            assert.same({ false, 'unknown_item', 'containers.eau.empty' }, { rules.validateConfig(bad) })
        end)

        it('refuse une sorte de capacité 1 001, de remplissage nul, ou un texte à deux %d', function()
            local bad = copy(cfg)
            bad.kinds.puits.reserve.capacity = 1001
            assert.same({ false, 'invalid_capacity', 'kinds.puits.reserve.capacity' }, { rules.validateConfig(bad) })
            bad = copy(cfg)
            bad.kinds.puits.reserve.refillSeconds = 0
            assert.same({ false, 'invalid_refill', 'kinds.puits.reserve.refillSeconds' }, { rules.validateConfig(bad) })
            bad = copy(cfg)
            bad.kinds.source.dry = 'À sec : %d min, %d s.'
            assert.same({ false, 'invalid_dry', 'kinds.source.dry' }, { rules.validateConfig(bad) })
            bad = copy(cfg)
            bad.kinds.source.dry = 'À sec : %s.'
            assert.same({ false, 'invalid_dry', 'kinds.source.dry' }, { rules.validateConfig(bad) })
            local ok = copy(cfg)
            ok.kinds.source.dry = 'À sec, 100 %% vide.'
            assert.is_true(rules.validateConfig(ok))
        end)

        it('refuse une image écrite en dur dans un objet', function()
            local bad = copy(cfg)
            bad.items.outre.image = 'nui://autre/outre.svg'
            assert.same({ false, 'image_set', 'items.outre.image' }, { rules.validateConfig(bad) })
        end)

        it('borne les gorgées et le délai', function()
            for _, case in ipairs({ { 'thirst', 0 }, { 'thirst', 101 }, { 'fullAt', 0 } }) do
                local bad = copy(cfg)
                bad.drink[case[1]] = case[2]
                assert.is_false(rules.validateConfig(bad), case[1])
            end
            local bad = copy(cfg)
            bad.cooldownMs = 100
            assert.same({ false, 'invalid_delay', 'cooldownMs' }, { rules.validateConfig(bad) })
        end)
    end)

    describe('réserve', function()
        local PUITS = { capacity = 40, refillSeconds = 60 }
        local T = 1761832800

        it('sans fond : infinie', function()
            assert.equal(math.huge, rules.level(0, T, T, { capacity = 0 }))
            assert.equal(0, rules.waitSeconds(math.huge, { capacity = 0 }))
        end)

        it('se remplit d\'un puisage par refillSeconds, plafonnée à la capacité', function()
            assert.equal(12, rules.level(10, T, T + 120, PUITS))
            assert.equal(40, rules.level(39, T, T + 600, PUITS))
            assert.equal(10.5, rules.level(10, T, T + 30, PUITS))
        end)

        it('ne bouge pas si l\'horloge revient en arrière', function()
            assert.equal(10, rules.level(10, T, T - 500, PUITS))
        end)

        it('attente : arrondie à la seconde au-dessus, nulle dès un puisage entier', function()
            assert.equal(36, rules.waitSeconds(0.4, PUITS))
            assert.equal(60, rules.waitSeconds(0, PUITS))
            assert.equal(0, rules.waitSeconds(1, PUITS))
            assert.equal('integer', math.type(rules.waitSeconds(0.4, PUITS)))
        end)

        it('puisages entiers disponibles', function()
            assert.equal(0, rules.available(0.9))
            assert.equal(3, rules.available(3.7))
            assert.equal('integer', math.type(rules.available(3.7)))
            assert.equal(math.huge, rules.available(math.huge))
        end)
    end)

    describe('decide', function()
        local function ctx(fields)
            local base = { empties = 0, maxPerDraw = 5, available = 40, drinkable = true, thirst = 50, fullAt = 95 }
            for key, value in pairs(fields) do base[key] = value end
            return base
        end

        it('1. remplit les outres vides quand il y a de quoi', function()
            assert.same({ action = 'fill', count = 2 }, rules.decide(ctx({ empties = 2 })))
            assert.same({ action = 'fill', count = 5 }, rules.decide(ctx({ empties = 7 })))
            assert.same({ action = 'fill', count = 2 }, rules.decide(ctx({ empties = 7, available = 2 })))
            assert.same({ action = 'fill', count = 3 }, rules.decide(ctx({ empties = 3, available = math.huge, thirst = 99 })))
            assert.equal('integer', math.type(rules.decide(ctx({ empties = 3, available = math.huge })).count))
        end)

        it('2. sinon boit quand on a soif', function()
            assert.same({ action = 'drink', dry = false }, rules.decide(ctx({ empties = 0, thirst = 94 })))
            assert.same({ action = 'drink', dry = true }, rules.decide(ctx({ empties = 3, available = 0, thirst = 50 })))
        end)

        it('3. à sec avec des outres et sans soif', function()
            assert.same({ nil, 'dry' }, { rules.decide(ctx({ empties = 3, available = 0, thirst = 96 })) })
            assert.same({ nil, 'dry' }, { rules.decide(ctx({ empties = 1, available = 0, drinkable = false })) })
        end)

        it('4. pas soif sans outre', function()
            assert.same({ nil, 'not_thirsty' }, { rules.decide(ctx({ empties = 0, thirst = 95 })) })
        end)

        it('5. sans outre là où l\'on ne boit pas, ou sans besoins', function()
            assert.same({ nil, 'no_container' }, { rules.decide(ctx({ empties = 0, drinkable = false })) })
            local unknown = ctx({ empties = 0 })
            unknown.thirst = nil  -- vava_needs absent : soif non lue
            assert.same({ nil, 'no_container' }, { rules.decide(unknown) })
        end)
    end)

    it('contenant gardé ou fendu', function()
        assert.is_false(rules.keepsContainer(0.05, 0.1))
        assert.is_true(rules.keepsContainer(0.1, 0.1))
        assert.is_true(rules.keepsContainer(0.99, 0))
        assert.is_true(rules.keepsContainer(0, 0))
        assert.is_false(rules.keepsContainer(0.99, 1))
    end)

    -- T-135 : le palier de l'outre (savoir du tanneur) passe de l'outre vide à l'outre d'eau et revient, et fixe le
    -- risque de fente.
    describe('palier de l\'outre', function()
        local CONTAINER = { empty = 'outre', tearChance = 0.1, tearChanceByTier = { 0.15, 0.1, 0.05, 0.025, 0.01 } }

        it('lit le palier d\'une pile : entier de 1 à 5, 3.0 compte pour 3, le reste n\'en est pas un', function()
            for tier = 1, 5 do assert.equal(tier, rules.tierOf({ tier = tier })) end
            assert.equal(3, rules.tierOf({ tier = 3.0 }))
            assert.equal('integer', math.type(rules.tierOf({ tier = 3.0 })))
            assert.equal(2, rules.tierOf({ tier = 2, origin = 'foret' }))
            for _, metadata in ipairs({ {}, { tier = 0 }, { tier = 6 }, { tier = -1 }, { tier = 2.5 }, { tier = '3' },
                { tier = 0 / 0 }, { tier = math.huge }, { quality = 80 } }) do
                assert.is_nil(rules.tierOf(metadata), tostring(metadata.tier))
            end
            assert.is_nil(rules.tierOf(nil))
            assert.is_nil(rules.tierOf('tier'))
        end)

        it('métadonnées d\'une outre : { tier } comme un produit simple de l\'artisanat, rien sans palier', function()
            assert.same({ tier = 3 }, rules.tierMetadata(3))
            assert.is_nil(rules.tierMetadata(nil))
        end)

        it('risque de fente selon le palier, celui d\'une outre sans palier sinon', function()
            assert.equal(0.15, rules.tearChance(CONTAINER, 1))
            assert.equal(0.1, rules.tearChance(CONTAINER, 2))
            assert.equal(0.05, rules.tearChance(CONTAINER, 3))
            assert.equal(0.025, rules.tearChance(CONTAINER, 4))
            assert.equal(0.01, rules.tearChance(CONTAINER, 5))
            assert.equal(0.1, rules.tearChance(CONTAINER, nil))
            -- liste plus courte que les paliers, ou absente (config.lua d'avant 1.3.0) : le risque sans palier
            assert.equal(0.1, rules.tearChance({ tearChance = 0.1, tearChanceByTier = { 0.2, 0.1 } }, 4))
            assert.equal(0.1, rules.tearChance({ tearChance = 0.1 }, 3))
            -- même tirage : l'outre Soignée tient, l'outre sans palier se fend ; la Grossière se fend, la Commune tient
            assert.is_true(rules.keepsContainer(0.06, rules.tearChance(CONTAINER, 3)))
            assert.is_false(rules.keepsContainer(0.06, rules.tearChance(CONTAINER, nil)))
            assert.is_false(rules.keepsContainer(0.12, rules.tearChance(CONTAINER, 1)))
            assert.is_true(rules.keepsContainer(0.12, rules.tearChance(CONTAINER, 2)))
        end)

        it('valide la liste des risques : 1 à 5 valeurs de 0 à 1, jamais plus haut qu\'au palier d\'avant', function()
            assert.is_true(rules.validateTearChances(nil))
            assert.is_true(rules.validateTearChances({ 0.1 }))
            assert.is_true(rules.validateTearChances({ 0.2, 0.2, 0.1, 0, 0 }))
            assert.same({ false, 'invalid_list' }, { rules.validateTearChances({}) })
            assert.same({ false, 'invalid_list' }, { rules.validateTearChances({ 0.5, 0.4, 0.3, 0.2, 0.1, 0 }) })
            assert.same({ false, 'invalid_list' }, { rules.validateTearChances({ 0.1, nil, 0.05 }) })
            assert.same({ false, 'invalid_list' }, { rules.validateTearChances({ 0.1, soigne = 0.05 }) })
            assert.same({ false, 'invalid_list' }, { rules.validateTearChances(0.1) })
            assert.same({ false, 'invalid_chance', '[2]' }, { rules.validateTearChances({ 0.1, -0.1 }) })
            assert.same({ false, 'invalid_chance', '[1]' }, { rules.validateTearChances({ 1.5 }) })
            assert.same({ false, 'invalid_chance', '[3]' }, { rules.validateTearChances({ 0.1, 0.1, 0 / 0 }) })
            assert.same({ false, 'invalid_chance', '[2]' }, { rules.validateTearChances({ 0.1, '0.05' }) })
            assert.same({ false, 'invalid_order', '[3]' }, { rules.validateTearChances({ 0.15, 0.1, 0.12 }) })
        end)

        it('la config refuse une liste fautive avec son chemin, et accepte son absence', function()
            local bad = copy(cfg)
            bad.containers.eau.tearChanceByTier = { 0.1, 0.2 }
            assert.same({ false, 'invalid_order', 'containers.eau.tearChanceByTier[2]' }, { rules.validateConfig(bad) })
            bad.containers.eau.tearChanceByTier = { 0.1, 0.05, 0.02, 0.01, 0.005, 0 }
            assert.same({ false, 'invalid_list', 'containers.eau.tearChanceByTier' }, { rules.validateConfig(bad) })
            local old = copy(cfg)
            old.containers.eau.tearChanceByTier = nil
            assert.is_true(rules.validateConfig(old))
        end)

        it('remplit pile par pile, les plus anciennes d\'abord, chaque outre d\'eau au palier de son outre', function()
            local piles = {
                { id = 11, item = 'outre', quantity = 2, metadata = { tier = 3 } },
                { id = 12, item = 'outre', quantity = 1, metadata = {} },
                { id = 13, item = 'outre', quantity = 4, metadata = { tier = 1 } },
                { id = 14, item = 'outre', quantity = 1, metadata = { tier = 3 } },
            }
            local removals, additions, total = rules.planFill(piles, 5, 'eau')
            assert.equal(5, total)
            assert.same({ { instanceId = 11, quantity = 2 }, { instanceId = 12, quantity = 1 }, { instanceId = 13, quantity = 2 } }, removals)
            assert.same({
                { item = 'eau', quantity = 2, metadata = { tier = 3 } },
                { item = 'eau', quantity = 1 },
                { item = 'eau', quantity = 2, metadata = { tier = 1 } },
            }, additions)
            -- deux piles du même palier : un seul ajout, une seule pile d'eau
            removals, additions, total = rules.planFill(piles, 20, 'eau')
            assert.equal(8, total)
            assert.equal(4, #removals)
            assert.same({ item = 'eau', quantity = 3, metadata = { tier = 3 } }, additions[1])
            assert.equal(3, #additions)
        end)

        it('autant d\'outres d\'eau que d\'outres prises, jamais plus que demandé', function()
            local piles = { { id = 1, quantity = 3, metadata = { tier = 2 } }, { id = 2, quantity = 3 } }
            for count = 1, 6 do
                local removals, additions, total = rules.planFill(piles, count, 'eau')
                local taken, given = 0, 0
                for _, removal in ipairs(removals) do taken = taken + removal.quantity end
                for _, addition in ipairs(additions) do given = given + addition.quantity end
                assert.equal(count, total)
                assert.equal(count, taken)
                assert.equal(count, given)
            end
        end)

        it('ignore une pile mal formée ; sans pile, rien', function()
            local removals, additions, total = rules.planFill({
                { id = 0, quantity = 1 }, { id = 'x', quantity = 1 }, { id = 3, quantity = 0 }, { id = 4, quantity = 1.5 },
                'pile', { id = 5, quantity = 1, metadata = { tier = 9 } },
            }, 5, 'eau')
            assert.equal(1, total)
            assert.same({ { instanceId = 5, quantity = 1 } }, removals)
            assert.same({ { item = 'eau', quantity = 1 } }, additions)
            assert.same({ {}, {}, 0 }, { rules.planFill({}, 5, 'eau') })
            assert.same({ {}, {}, 0 }, { rules.planFill(nil, 5, 'eau') })
            assert.same({ {}, {}, 0 }, { rules.planFill({ { id = 1, quantity = 2 } }, 0, 'eau') })
        end)
    end)

    describe('parseCommand', function()
        it('lit points et reserve', function()
            assert.same({ 'points' }, { rules.parseCommand({ 'points' }) })
            assert.same({ 'reserve', 'puits_lavoir', 12 }, { rules.parseCommand({ 'reserve', 'puits_lavoir', '12' }) })
            assert.same({ 'reserve', 'puits_lavoir', 0 }, { rules.parseCommand({ 'reserve', 'puits_lavoir', '0' }) })
        end)

        it('refuse le reste', function()
            for _, args in ipairs({ { 'reserve', 'puits_lavoir', '1.5' }, { 'reserve', 'x y', '3' }, { 'x' }, {},
                { 'reserve', 'puits_lavoir' }, { 'reserve', 'puits_lavoir', '-3' }, { 'reserve', 'puits_lavoir', '12345' },
                { 'reserve', 'Puits', '3' } }) do
                assert.same({ nil, 'usage' }, { rules.parseCommand(args) }, table.concat(args, ' '))
            end
            assert.same({ nil, 'usage' }, { rules.parseCommand(nil) })
        end)
    end)

    describe('textes', function()
        local messages

        before_each(function()
            messages = cfg.messages
        end)

        it('résultats', function()
            assert.equal('Vous remplissez une outre.', texts.successText({ action = 'fill', count = 1 }))
            assert.equal('Vous remplissez 5 outres.', texts.successText({ action = 'fill', count = 5 }))
            assert.equal(messages.drank, texts.successText({ action = 'drink', dry = false }))
            assert.equal(messages.drankDry, texts.successText({ action = 'drink', dry = true }))
            assert.equal(messages.noSpace .. ' ' .. messages.drank, texts.successText({ action = 'drink', dry = false, blocked = 'no_space' }))
            assert.equal(messages.tooHeavy .. ' ' .. messages.drank, texts.successText({ action = 'drink', dry = false, blocked = 'too_heavy' }))
            assert.equal(messages.drank, texts.successText({ action = 'drink', dry = false, blocked = 'autre' }))
            assert.is_true(#texts.successText({ action = 'drink', blocked = 'too_heavy' }) <= VavaProvisions.MAX_NOTIFICATION)
            assert.is_nil(texts.successText({ action = 'autre' }))
            assert.is_nil(texts.successText(nil))
        end)

        it('refus', function()
            assert.equal(messages.wait, texts.refusalText('wait', nil, nil))
            assert.equal(messages.tooFar, texts.refusalText('too_far', nil, nil))
            assert.equal(messages.noSpace, texts.refusalText('no_space', nil, nil))
            assert.equal('Le seau racle le fond : le puits doit se remplir (environ 1 min).', texts.refusalText('dry', 36, cfg.kinds.puits))
            assert.equal('La source ne coule plus qu\'en filet : revenez dans environ 3 min.', texts.refusalText('dry', 121, cfg.kinds.source))
            assert.equal('Gardé par la milice.', texts.refusalText('refused', 'Gardé par la milice.', nil))
            assert.equal(200, #texts.refusalText('refused', string.rep('a', 300), nil))
            for _, silent in ipairs({ 'no_character', 'downed', 'busy', 'unknown_point', 'autre' }) do
                assert.is_nil(texts.refusalText(silent, nil, nil), silent)
            end
        end)

        it('coupe un texte sans briser un caractère et sans contrôle', function()
            local cut = texts.cutText(string.rep('é', 150), 200)
            assert.equal(200, #cut)
            assert.is_not_nil(utf8.len(cut))
            cut = texts.cutText('a' .. string.rep('é', 150), 200)
            assert.equal(199, #cut)
            assert.equal('a b', texts.cutText('a\nb', 200))
            assert.is_nil(texts.cutText('   ', 200))
            assert.is_nil(texts.cutText(42, 200))
        end)

        it('avis et verbe de l\'invite', function()
            assert.equal(messages.torn, texts.noticeText('torn'))
            assert.equal(messages.lost, texts.noticeText('lost'))
            assert.is_nil(texts.noticeText('autre'))
            assert.equal('Puiser ou boire', texts.promptVerb(cfg.kinds.puits))
            assert.equal('Puiser', texts.promptVerb({ drink = false }))
        end)

        it('regroupe les lignes en messages bornés, puis « … et N autres »', function()
            assert.same({ 'a\nb', 'cc' }, rules.packLines({ 'a', 'b', 'cc' }, 3, 10, '%d de plus'))
            assert.same({ 'a\nb', '1 de plus' }, rules.packLines({ 'a', 'b', 'c' }, 9, 2, '%d de plus'))
            assert.same({}, rules.packLines({}, 480, 60, '%d'))
            -- une ligne trop longue est coupée sans briser un caractère
            local packed = rules.packLines({ string.rep('é', 10) }, 5, 10, '%d')
            assert.same({ 'éé' }, packed)
            local lines = {}
            for i = 1, 100 do lines[i] = string.rep('x', 50) .. i end
            packed = rules.packLines(lines, 480, 60, messages.admin.more)
            local count = 0
            for _, text in ipairs(packed) do
                assert.is_true(#text <= 480)
                for _ in text:gmatch('[^\n]+') do count = count + 1 end
            end
            assert.equal(61, count)
            assert.equal('… et 40 autres points d\'eau.', packed[#packed]:match('[^\n]+$'))
        end)

        it('ligne de /eau points', function()
            local admin = messages.admin
            assert.equal('Puits du lavoir (puits_lavoir, puits) : 40 / 40 puisages.',
                rules.describePoint({ id = 'puits_lavoir', kind = 'puits', label = 'Puits du lavoir' }, { level = 40, capacity = 40 }, admin))
            assert.equal('Fontaine du bourg (fontaine_bourg, fontaine) : sans fond.',
                rules.describePoint({ id = 'fontaine_bourg', kind = 'fontaine', label = 'Fontaine du bourg' }, nil, admin))
        end)

        it('tient dans une notification du HUD et dans le journal du Registre', function()
            local function check(text, key)
                assert.is_string(text, key)
                assert.is_not_nil(utf8.len(text), key)
                assert.is_true(#text <= VavaProvisions.MAX_NOTIFICATION, key .. ' : ' .. #text .. ' octets')
            end
            for key, text in pairs(messages) do
                if type(text) == 'string' then check(text, key) end
            end
            for key, text in pairs(messages.prompt) do check(text, 'prompt.' .. key) end
            for key, text in pairs(messages.admin) do check(text, 'admin.' .. key) end
            for id, kind in pairs(cfg.kinds) do check(kind.dry, 'kinds.' .. id .. '.dry') end
            for key, label in pairs(messages.journal) do
                assert.is_true(#label <= VavaProvisions.MAX_JOURNAL_LABEL, key)
            end
        end)
    end)

    describe('config', function()
        it('déclare des objets à la forme attendue par l\'inventaire, sans image écrite en dur', function()
            for name, def in pairs(cfg.items) do
                assert.is_true(rules.validateItem(name, def), name)
                assert.is_nil(def.image, name)
            end
        end)

        it('garde la définition de l\'eau des piles déjà en jeu', function()
            local eau = cfg.items.eau
            assert.equal(1, eau.width)
            assert.equal(2, eau.height)
            assert.equal(5, eau.stack)
            assert.equal(700, eau.weight)
            assert.equal('boisson', eau.category)
            assert.same({ thirst = 40 }, eau.effects)
            assert.equal('Outre d\'eau', eau.label)
        end)

        it('remplit des outres en eau et rend une outre vide qui se fend une fois sur dix sans palier, moins si elle est mieux faite', function()
            assert.same({ from = 'outre', to = 'eau', maxPerDraw = 5 }, cfg.fill)
            -- valeurs provisoires de T-135 (Grossier, Commun, Soigné, Excellent, Chef-d'œuvre), à trancher
            assert.same({ empty = 'outre', tearChance = 0.1, tearChanceByTier = { 0.15, 0.1, 0.05, 0.025, 0.01 } }, cfg.containers.eau)
            -- une outre Soignée ou Excellente se fend moins qu'une outre sans palier ou Commune
            local eau = cfg.containers.eau
            assert.is_true(rules.tearChance(eau, 3) < rules.tearChance(eau, nil))
            assert.is_true(rules.tearChance(eau, 4) < rules.tearChance(eau, 3))
            assert.is_true(rules.tearChance(eau, 3) < rules.tearChance(eau, 2))
            assert.is_true(rules.tearChance(eau, 5) > 0)
            assert.equal('outre', cfg.recipe.output.item)
            assert.equal('tannerie', cfg.recipe.station)
        end)

        it('a des bornes sensées', function()
            assert.is_true(cfg.cooldownMs >= cfg.anims.fill.durationMs and cfg.cooldownMs >= cfg.anims.drink.durationMs)
            assert.equal(3.5, cfg.interact.distance + cfg.interact.serverTolerance)
            assert.is_true(cfg.rateLimits.draw.capacity >= 1 and cfg.rateLimits.draw.refillPerSecond > 0)
            assert.equal(cfg.admin.permission, 'metiers')
            assert.equal(0, cfg.kinds.fontaine.reserve.capacity)
        end)
    end)
end)
