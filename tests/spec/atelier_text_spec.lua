local helper = require('tests.helper')

-- Textes de l'Atelier (T-100) : UTF-8, longueur en caractères, jeux de caractères, recherche sans accents ni casse,
-- coupe sans briser un caractère, nombres et durées à la française.
describe('vava_atelier text', function()
    local text, previousLocale

    before_each(function()
        -- T-133 : sous une locale Windows à octet unique si le système en a une (voir plus bas)
        previousLocale = helper.legacyLocale()
        helper.reset()
        VavaAtelier = nil
        helper.loadAll({ 'modules/vava_atelier/shared/constants.lua', 'modules/vava_atelier/shared/bounds.lua',
            'modules/vava_atelier/shared/text.lua' })
        text = VavaAtelier.text
    end)

    after_each(function()
        helper.restoreLocale(previousLocale)
    end)

    it('refuse un UTF-8 invalide et ce qui n\'est pas une chaîne', function()
        assert.is_true(text.isUtf8('Forêt de Brume'))
        assert.is_true(text.isUtf8(''))
        for _, bad in ipairs({ '\xC3', 'a\xFFb', '\xE2\x82', '\xED\xA0\x80', '\xF8\x88\x80\x80\x80' }) do
            assert.is_false(text.isUtf8(bad), bad)
        end
        assert.is_false(text.isUtf8(nil))
        assert.is_false(text.isUtf8(12))
    end)

    it('compte la longueur en caractères, pas en octets', function()
        assert.equal(1, text.length('é'))
        assert.equal(5, text.length('Forêt'))
        assert.equal(6, #'Forêt')
        assert.equal(2, text.length('œŒ'))
        assert.is_nil(text.length('\xC3'))
    end)

    it('repère les caractères de contrôle et de sens d\'écriture', function()
        assert.is_false(text.hasControl('Panneau de la place'))
        assert.is_true(text.hasControl('a\tb'))
        assert.is_true(text.hasControl('a\0b'))
        assert.is_true(text.hasControl('a\x7Fb'))
        assert.is_true(text.hasControl('a\xC2\x85b'))          -- U+0085, contrôle C1
        assert.is_true(text.hasControl('a\xE2\x80\xAEb'))      -- U+202E, écriture de droite à gauche
        assert.is_true(text.hasControl('a\xE2\x81\xA6b'))      -- U+2066
        assert.is_true(text.hasControl('ligne\nsuivante'))
        assert.is_false(text.hasControl('ligne\nsuivante', true))
        assert.is_true(text.hasControl('ligne\r\nsuivante', true))
    end)

    it('repère les caractères invisibles : sans largeur, marques de sens, séparateurs, BOM', function()
        for _, code in ipairs({ 0x200B, 0x200C, 0x200D, 0x200E, 0x200F, 0x2028, 0x2029, 0xFEFF, 0x061C }) do
            local probe = 'Pan' .. utf8.char(code) .. 'neau'
            assert.is_true(text.hasControl(probe), string.format('U+%04X', code))
            assert.is_true(text.hasControl(probe, true), string.format('U+%04X (retours permis)', code))
        end
        -- leurs voisins imprimables restent permis : espace ultrafine (U+200A), tiret (U+2010), apostrophe (U+2019),
        -- points de suspension (U+2026), point de coupure (U+2027), espace fine insécable (U+202F), ponctuation arabe
        -- (U+061B, U+061F), ligature arabe (U+FEFC), é
        for _, code in ipairs({ 0x200A, 0x2010, 0x2019, 0x2026, 0x2027, 0x202F, 0x061B, 0x061F, 0xFEFC, 0x00E9 }) do
            assert.is_false(text.hasControl('Pan' .. utf8.char(code) .. 'neau'), string.format('U+%04X', code))
        end
    end)

    it('ne dépend pas de la locale : aucune lettre latine accentuée n\'est prise pour un contrôle', function()
        -- chaque caractère de U+00A0 à U+017F (lettres accentuées, œ, ligatures) : octets de suite 0x80 à 0xBF
        for code = 0xA0, 0x17F do
            assert.is_false(text.hasControl('a' .. utf8.char(code) .. 'b'), string.format('U+%04X', code))
        end
        assert.is_false(text.hasControl('Ïle d\'Ídrë, Ðan et Ýves'))
        -- même règle pour le motif du filtre et de la recherche (schéma des RPC)
        local QUERY = VavaAtelier.QUERY_PATTERN
        assert.truthy(('Ïle d\'Ídrë'):find(QUERY))
        assert.truthy((''):find(QUERY))
        for _, bad in ipairs({ 'a\tb', 'a\0b', 'a\x7Fb', '<b>', 'a>b', 'ligne\n' }) do
            assert.is_nil(bad:find(QUERY), bad)
        end
    end)

    it('jeu de caractères name : lettres accentuées, chiffres, espace et ponctuation légère', function()
        for _, good in ipairs({ 'Forêt de Brume', 'L\'Ancre-Rouge', 'Œuvre, 2e partie.', 'Château d’Ys', 'Noël' }) do
            assert.is_true(text.isName(good), good)
        end
        for _, bad in ipairs({ '<b>Essai</b>', 'a;b', 'a/b', 'a_b', 'a!', 'x × y', 'quarante%', 'ligne\nsuivante' }) do
            assert.is_false(text.isName(bad), bad)
        end
    end)

    it('jeux de caractères id et free', function()
        assert.is_true(text.isId('foret_brume_2'))
        assert.is_false(text.isId('Foret'))
        assert.is_false(text.isId('forêt'))
        assert.is_false(text.isId('a-b'))
        assert.is_false(text.isId(''))
        assert.is_true(text.isFree('Tout, ou presque : 3 € & « guillemets » !'))
        assert.is_false(text.isFree('<b>'))
        assert.is_false(text.isFree('a > b'))
    end)

    it('normalise pour la recherche : accents, casse, blancs', function()
        assert.equal('foret', text.normalize('Forêt'))
        assert.equal('eclat', text.normalize('ÉCLAT'))
        assert.equal('coeur de la cite', text.normalize('  Cœur   de la Cité '))
        assert.equal('pancarte de la porte nord', text.normalize('PANCARTE de la Porte Nord'))
        assert.equal("l'ancre", text.normalize('L’Ancre'))
    end)

    -- T-133 : `%s` et `string.lower` suivent la locale du système ; sous Windows (cp1252), l'octet 0xA0 de « à » ou
    -- de « Š » passait pour un blanc et le premier octet d'un caractère accentué pour une majuscule (0xC5 → 0xE5).
    -- Ils tournent sous une telle locale si le système en a une (before_each) et échouent alors avec l'ancien code ;
    -- sinon, ils fixent la règle.
    local function latinCodes()
        local codes = {}
        for code = 0xA0, 0x17F do codes[#codes + 1] = code end
        codes[#codes + 1] = 0x2010
        return codes
    end

    it('trim garde entier chaque caractère de U+00A0 à U+017F et U+2010', function()
        for _, code in ipairs(latinCodes()) do
            local c, label = utf8.char(code), string.format('U+%04X', code)
            assert.equal(c, text.trim(c), label)
            assert.equal('a ' .. c, text.trim(' \ta ' .. c .. ' \r\n'), label)
            assert.equal(c .. ' a', text.trim(c .. ' a'), label)
        end
    end)

    it('trim ne retire que les blancs ASCII : tabulation à retour chariot, espace', function()
        for b = 0, 127 do
            local c = string.char(b)
            local blank = b == 32 or (b >= 9 and b <= 13)
            assert.equal(blank and '' or c, text.trim(c), string.format('0x%02X', b))
            assert.equal(blank and 'x' or 'x' .. c, text.trim('x' .. c), string.format('0x%02X', b))
        end
    end)

    it('normalise sans briser un caractère de U+00A0 à U+017F ni U+2010', function()
        for _, code in ipairs(latinCodes()) do
            local normalized = text.normalize('A ' .. utf8.char(code) .. ' ')
            assert.is_not_nil(utf8.len(normalized), string.format('U+%04X', code))
        end
        -- caractères sans repli : gardés tels quels, majuscules non ASCII comprises
        for _, c in ipairs({ 'Š', 'š', 'Ł', 'Ġ', 'ı', 'Ŧ', '¡', '§', '\u{00A0}', '\u{2010}' }) do
            assert.equal('a ' .. c, text.normalize('A  ' .. c .. ' '), c)
        end
        -- casse : seules les 26 majuscules ASCII sont baissées ; blancs ASCII réduits à une espace
        assert.equal('abcxyz', text.normalize('ABCxyz'))
        assert.equal('a b', text.normalize('A\t\n\v\f\rB'))
    end)

    it('cherche par sous-chaîne normalisée', function()
        local hay = text.normalize('Panneau de la place')
        assert.is_true(text.contains(hay, text.normalize('PLACE')))
        assert.is_true(text.contains(hay, text.normalize('pan')))
        assert.is_true(text.contains(hay, ''))
        assert.is_false(text.contains(hay, text.normalize('porte')))
        -- motif Lua sans effet : recherche littérale
        assert.is_false(text.contains(hay, '.*'))
    end)

    it('coupe sans briser un caractère UTF-8', function()
        assert.equal('abc', text.truncate('abc', 10))
        assert.equal('ab', text.truncate('abc', 2))
        assert.equal('a', text.truncate('aé', 2))           -- « é » fait deux octets : retiré entier
        assert.equal('aé', text.truncate('aéb', 3))
        assert.equal('', text.truncate('€', 2))              -- trois octets
        local long = string.rep('é', 100)
        local cut = text.truncate(long, 159)
        assert.equal(158, #cut)
        assert.is_true(text.isUtf8(cut))
    end)

    it('écrit les nombres à la française', function()
        assert.equal('1,5', text.number(1.5))
        assert.equal('3', text.number(3))
        assert.equal('3', text.number(3.0))
        assert.equal('0,1', text.number(0.1))
        assert.equal('1,5', text.number(1.5, 1))
        assert.equal('2,0', text.number(2, 1))
        assert.equal('-0,25', text.number(-0.25))
        assert.equal('31\u{00A0}536\u{00A0}000', text.number(31536000))
        assert.equal('1\u{00A0}000,5', text.number(1000.5))
    end)

    it('écrit les durées lisiblement', function()
        assert.equal('7 jours', text.duration(7 * 86400))
        assert.equal('1 jour', text.duration(86400))
        assert.equal('10 minutes', text.duration(600))
        assert.equal('1 minute', text.duration(60))
        assert.equal('1 h 30 min', text.duration(5400))
        assert.equal('1 h', text.duration(3600))
        assert.equal('45 s', text.duration(45))
        assert.equal('1 j 2 h', text.duration(93600))
        assert.equal('0 s', text.duration(0))
    end)
end)
