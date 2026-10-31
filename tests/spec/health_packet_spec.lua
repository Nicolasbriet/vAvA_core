local helper = require('tests.helper')

-- Paquet de dégât de la chaîne commune (modules/vava_health/shared/packet.lua, spec T-110 § 5.1 et § 11.1) : paquet
-- fermé et borné, copie normalisée, `origin` jamais fourni par l'appelant.
describe('vava_health paquet de dégât', function()
    local packet, limits, cfg

    local function normalize(raw)
        return packet.normalize(raw, limits)
    end

    local function base(extra)
        local raw = { amount = 12, kind = 'tranchant' }
        for key, value in pairs(extra or {}) do raw[key] = value end
        return raw
    end

    before_each(function()
        helper.reset()
        VavaHealth = nil
        helper.loadAll({
            'modules/vava_health/shared/constants.lua',
            'modules/vava_health/config.lua',
            'modules/vava_health/shared/packet.lua',
        })
        packet = VavaHealth.packet
        cfg = VavaHealth.config.chain
        limits = packet.compile(cfg)
    end)

    it('rend une copie avec des étiquettes vides, indépendante de l\'entrée', function()
        local raw = base()
        local copy, code = normalize(raw)
        assert.is_nil(code)
        assert.same({ amount = 12, kind = 'tranchant', tags = {} }, copy)
        raw.amount, raw.kind = 99, 'feu'
        assert.equal(12, copy.amount)
        assert.equal('tranchant', copy.kind)

        local tags = { melee = true }
        local withTags = normalize(base({ tags = tags, source = 3, part = 'torse', weapon = 'epee_longue' }))
        tags.ranged = true
        assert.same({ melee = true }, withTags.tags)
        assert.equal(3, withTags.source)
        assert.equal('torse', withTags.part)
        assert.equal('epee_longue', withTags.weapon)
    end)

    it('borne le montant', function()
        for _, amount in ipairs({ 0, -1, 0 / 0, math.huge, -math.huge, 201, '12', true }) do
            local copy, code = normalize(base({ amount = amount }))
            assert.is_nil(copy, tostring(amount))
            assert.equal('invalid_amount', code, tostring(amount))
        end
        local missing = base()
        missing.amount = nil
        assert.equal('invalid_amount', select(2, normalize(missing)))
        assert.equal(0.5, normalize(base({ amount = 0.5 })).amount)
        assert.equal(200, normalize(base({ amount = 200 })).amount)
    end)

    it('n\'admet que les types de la liste fermée', function()
        for _, kind in ipairs({ 'perçant', 'feux', 'TRANCHANT', '', 3 }) do
            assert.equal('invalid_kind', select(2, normalize(base({ kind = kind }))), tostring(kind))
        end
        local missing = base()
        missing.kind = nil
        assert.equal('invalid_kind', select(2, normalize(missing)))
        assert.equal(11, #cfg.kinds)
        for _, kind in ipairs(cfg.kinds) do
            assert.equal(kind, normalize(base({ kind = kind })).kind)
        end
    end)

    it('borne la source et son personnage', function()
        for _, source in ipairs({ 0, -3, 1.5, 65536, '3', 0 / 0 }) do
            assert.equal('invalid_source', select(2, normalize(base({ source = source }))), tostring(source))
        end
        for _, character in ipairs({ 0, 2.5, 2147483648, -1 }) do
            assert.equal('invalid_source', select(2, normalize(base({ sourceCharacter = character }))), tostring(character))
        end
        assert.equal(65535, normalize(base({ source = 65535 })).source)
        -- un flottant de valeur entière (traversée d'un export) devient un entier
        local copy = normalize(base({ source = 7.0, sourceCharacter = 42.0 }))
        assert.equal('integer', math.type(copy.source))
        assert.equal(42, copy.sourceCharacter)
        assert.equal('integer', math.type(copy.sourceCharacter))
    end)

    it('n\'admet que les parties du corps connues', function()
        assert.equal('invalid_part', select(2, normalize(base({ part = 'queue' }))))
        assert.equal('invalid_part', select(2, normalize(base({ part = 1 }))))
        for _, part in ipairs(cfg.parts) do assert.equal(part, normalize(base({ part = part })).part) end
    end)

    it('borne les références d\'arme, de technique et de sort', function()
        for _, field in ipairs({ 'weapon', 'technique', 'spell' }) do
            for _, value in ipairs({ '', string.rep('a', 65), 'a b', '<x>', 'épée', 12 }) do
                assert.equal('invalid_ref', select(2, normalize(base({ [field] = value }))), field .. ' ' .. tostring(value))
            end
            assert.equal('vava_combat:taille_descendante',
                normalize(base({ [field] = 'vava_combat:taille_descendante' }))[field])
            assert.equal(string.rep('a', 64), normalize(base({ [field] = string.rep('a', 64) }))[field])
        end
    end)

    it('n\'admet que des étiquettes connues à true, sans liste, au plus maxTags', function()
        local nine = {}
        for i = 1, 9 do nine[cfg.tags[i]] = true end
        local refused = {
            'melee', nine, { inconnue = true }, { melee = 1 }, { melee = false }, { 'melee' },
            { melee = true, [1] = true },
        }
        for i, tags in ipairs(refused) do
            assert.equal('invalid_tags', select(2, normalize(base({ tags = tags }))), 'cas ' .. i)
        end
        local eight = {}
        for i = 1, 8 do eight[cfg.tags[i]] = true end
        assert.same(eight, normalize(base({ tags = eight })).tags)
    end)

    it('refuse toute clé hors du paquet, origin compris, et ce qui n\'est pas une table', function()
        assert.equal('unknown_field', select(2, normalize(base({ origin = 'vava_magic' }))))
        assert.equal('unknown_field', select(2, normalize(base({ foo = 1 }))))
        assert.equal('unknown_field', select(2, normalize(base({ id = 4 }))))
        assert.equal('unknown_field', select(2, normalize({ amount = 12, kind = 'feu', [1] = 'x' })))
        assert.equal('invalid_packet', select(2, normalize('x')))
        assert.equal('invalid_packet', select(2, normalize(nil)))
        assert.equal('invalid_packet', select(2, normalize(12)))
    end)
end)
