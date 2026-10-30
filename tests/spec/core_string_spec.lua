local helper = require('tests.helper')

-- T-133 : `%s` et `%c` suivent la locale du système ; sous Windows (cp1252), `%c` prenait les octets 0x81, 0x8D,
-- 0x8F, 0x90, 0x9D, 0xAD (« Á », « Í », « Ï », « Ð », « Ý », « í », U+2010) et `%s` l'octet 0xA0 (« à », « Š »). Les
-- essais sur U+00A0 à U+017F échouent avec l'ancien code sous une telle locale ; sous la locale « C », ils fixent la
-- règle.
local function latinCodes()
    local codes = {}
    for code = 0xA0, 0x17F do codes[#codes + 1] = code end
    codes[#codes + 1] = 0x2010
    return codes
end

describe('vAvA.lib.string', function()
    local str

    before_each(function()
        helper.reset()
        helper.loadAll({ 'shared/init.lua', 'config/shared.lua', 'shared/lib/string.lua' })
        str = vAvA.lib.string
    end)

    describe('isIdentifier', function()
        it('accepte les noms de hooks, RPC et registres du dépôt', function()
            assert.is_true(str.isIdentifier('vava_inventory:move'))
            assert.is_true(str.isIdentifier('core:player:joined'))
            assert.is_true(str.isIdentifier('vava_atelier:editors'))
            assert.is_true(str.isIdentifier('a'))
            assert.is_true(str.isIdentifier('x-y.z_1:2'))
        end)

        it('borne la longueur à identifiers.maxLength (64), borne incluse', function()
            assert.equal(64, vAvA.config.shared.identifiers.maxLength)
            assert.is_true(str.isIdentifier(('a'):rep(64)))
            assert.is_false(str.isIdentifier(('a'):rep(65)))
        end)

        it('refuse la chaîne vide, les espaces, les accents et les caractères hors motif', function()
            assert.is_false(str.isIdentifier(''))
            assert.is_false(str.isIdentifier('vava inventory'))
            assert.is_false(str.isIdentifier('épée'))
            assert.is_false(str.isIdentifier('<global>'))
            assert.is_false(str.isIdentifier('vava:move\n'))
            assert.is_false(str.isIdentifier('vava:move\0'))
            assert.is_false(str.isIdentifier('^1rouge'))
        end)

        it('refuse ce qui n’est pas une chaîne', function()
            assert.is_false(str.isIdentifier(nil))
            assert.is_false(str.isIdentifier(42))
            assert.is_false(str.isIdentifier({}))
        end)
    end)

    describe('hasPrefix', function()
        it('reconnaît un préfixe, y compris vide ou égal à la chaîne', function()
            assert.is_true(str.hasPrefix('vava_inventory:move', 'vava_inventory:'))
            assert.is_true(str.hasPrefix('vava_inventory:move', ''))
            assert.is_true(str.hasPrefix('core:', 'core:'))
        end)

        it('refuse un préfixe absent ou plus long que la chaîne', function()
            assert.is_false(str.hasPrefix('vava_inventory:move', 'vava_inv:'))
            assert.is_false(str.hasPrefix('vava_ab:x', 'vava_a:'))
            assert.is_false(str.hasPrefix('core', 'core:'))
        end)
    end)

    describe('trim', function()
        it('retire les blancs des deux bords et garde ceux du milieu', function()
            assert.equal('Aldric le Brun', str.trim('  \tAldric le Brun \n'))
            assert.equal('x', str.trim('x'))
        end)

        it('rend une chaîne vide pour une chaîne de blancs', function()
            assert.equal('', str.trim('   \t\r\n'))
            assert.equal('', str.trim(''))
        end)

        it('garde entier chaque caractère de U+00A0 à U+017F et U+2010 (« à » final d’un nom)', function()
            for _, code in ipairs(latinCodes()) do
                local c, label = utf8.char(code), string.format('U+%04X', code)
                assert.equal(c, str.trim(c), label)
                assert.equal('Il' .. c, str.trim(' \tIl' .. c .. ' \r\n'), label)
                assert.equal(c .. ' a', str.trim(c .. ' a'), label)
            end
            assert.equal('Ída Ýr – í', str.trim('  Ída Ýr – í '))
        end)

        it('ne retire que les blancs ASCII : tabulation à retour chariot, espace', function()
            for b = 0, 127 do
                local c = string.char(b)
                local blank = b == 32 or (b >= 9 and b <= 13)
                assert.equal(blank and '' or c, str.trim(c), string.format('0x%02X', b))
                assert.equal(blank and 'x' or 'x' .. c, str.trim('x' .. c), string.format('0x%02X', b))
            end
        end)
    end)

    describe('sanitize', function()
        it('retire les codes couleur FiveM ^0 à ^9', function()
            assert.equal('Rouge puis blanc', str.sanitize('^1Rouge^7 puis ^0blanc', 100))
            -- un ^ qui n'est pas suivi d'un chiffre reste
            assert.equal('2^n', str.sanitize('2^n', 100))
        end)

        it('ne laisse aucun code couleur reconstitué par le retrait (^^11 → ^1)', function()
            local texte = str.sanitize('^^11joueur^^77', 100)
            assert.is_nil(texte:find('%^%d'), 'code couleur restant dans « ' .. texte .. ' »')
        end)

        it('remplace les caractères de contrôle par une espace', function()
            assert.equal('a b c d e', str.sanitize('a\nb\rc\td\0e', 100))
            assert.equal('ligne  forgée', str.sanitize('ligne\r\nforgée', 100))
        end)

        it('garde entier chaque caractère de U+00A0 à U+017F et U+2010 (« Á », « Í », « í »…)', function()
            local all = {}
            for _, code in ipairs(latinCodes()) do
                local c = utf8.char(code)
                all[#all + 1] = c
                assert.equal('a' .. c .. 'b', str.sanitize('a' .. c .. 'b', 100), string.format('U+%04X', code))
            end
            local joined = table.concat(all)
            assert.equal(joined, str.sanitize(joined, #joined))
            assert.equal('Ída Ýr – í', str.sanitize('Ída Ýr – í', 100))
        end)

        it('remplace chaque contrôle ASCII (0x00 à 0x1F, 0x7F) et lui seul', function()
            for b = 0, 127 do
                local c = string.char(b)
                local expected = (b <= 31 or b == 127) and 'a b' or 'a' .. c .. 'b'
                assert.equal(expected, str.sanitize('a' .. c .. 'b', 100), string.format('0x%02X', b))
            end
        end)

        it('tronque au-delà de maxLength octets et le signale par « … »', function()
            assert.equal('abc…', str.sanitize('abcdef', 3))
            assert.equal('abc', str.sanitize('abc', 3))
        end)

        it('rend affichable une valeur qui n’est pas une chaîne', function()
            assert.equal('nil', str.sanitize(nil, 10))
            assert.equal('42', str.sanitize(42, 10))
            assert.equal('false', str.sanitize(false, 10))
        end)
    end)

    describe('utf8Length', function()
        it('compte les caractères et non les octets', function()
            assert.equal(8, str.utf8Length('Éléonore'))
            assert.equal(3, str.utf8Length('abc'))
            assert.equal(0, str.utf8Length(''))
        end)

        it('renvoie nil pour une chaîne qui n’est pas de l’UTF-8 valide', function()
            assert.is_nil(str.utf8Length('\255'))
            assert.is_nil(str.utf8Length('caf\195'))
        end)
    end)

    describe('codepointSet', function()
        it('donne l’ensemble des points de code, accents compris', function()
            assert.same({ [97] = true, [233] = true, [39] = true }, str.codepointSet("aé'é"))
        end)

        it('rend un ensemble vide pour une chaîne vide', function()
            assert.same({}, str.codepointSet(''))
        end)
    end)

    describe('fnv1a', function()
        it('suit les vecteurs de référence FNV-1a 32 bits', function()
            assert.equal(0x811c9dc5, str.fnv1a(''))
            assert.equal(0xe40c292c, str.fnv1a('a'))
            assert.equal(0xbf9cf968, str.fnv1a('foobar'))
        end)

        it('reste un entier non signé de 32 bits et change avec le contenu', function()
            local hash = str.fnv1a(('CREATE TABLE x (id INT);\n'):rep(200))
            assert.equal('integer', math.type(hash))
            assert.is_true(hash >= 0 and hash <= 0xFFFFFFFF)
            assert.are_not.equal(str.fnv1a('0001_accounts.sql'), str.fnv1a('0001_accounts.sqm'))
        end)
    end)
end)
