local helper = require('tests.helper')

-- Paquet du Conseil (T-157, modules/vava_atelier/shared/digest.lua et shared/codepack.lua), logique pure. Règles
-- documentées : spec T-157 § 5.1 et § 5.2, README de vava_atelier (« Code livré au seul Conseil ») :
--   empreinte FNV-1a 64 bits sur les octets, 16 chiffres hexadécimaux ; format « VAVAPAQ1\n » puis pour chaque fichier
--   « <genre> <chemin> <octets>\n<code>\n », genres L (Lua), C (feuille), J (script), tous les L d'abord ; lecture
--   stricte et bornée (48 fichiers, 512 Ko, chemins de 96 octets et 5 segments au plus, minuscules ASCII) ; découpe en
--   morceaux dont aucune coupure ne tombe devant un octet de continuation UTF-8.
describe('vava_atelier paquet du Conseil (pur)', function()
    local digest, codepack, LIMITS

    before_each(function()
        helper.reset()
        VavaAtelier = nil
        helper.loadAll({
            'modules/vava_atelier/shared/constants.lua',
            'modules/vava_atelier/shared/bounds.lua',
            'modules/vava_atelier/shared/fingerprint.lua',
            'modules/vava_atelier/shared/digest.lua',
            'modules/vava_atelier/shared/codepack.lua',
            'modules/vava_atelier/shared/codepack_encode.lua',
        })
        digest, codepack, LIMITS = VavaAtelier.digest, VavaAtelier.codepack, VavaAtelier.CODEPACK
    end)

    after_each(function()
        VavaAtelier = nil
    end)

    local function piece(kind, name, code) return { kind = kind, name = name, code = code } end

    local SAMPLE = {
        piece('L', 'config_conseil.lua', 'local config = VavaAtelier.config\n'),
        piece('L', 'client/placer.lua', '-- « Récolte » : nœud\nreturn 1\n'),
        piece('C', 'web/css/style.css', '.a { color: #241b12; }\n'),
        piece('J', 'web/js/view-home.js', 'const é = "à";\n'),
        piece('J', 'web/js/vide.js', ''),
    }

    describe('empreinte', function()
        it('suit les vecteurs FNV-1a 64 bits publiés', function()
            assert.equal('cbf29ce484222325', digest(''))
            assert.equal('af63dc4c8601ec8c', digest('a'))
            assert.equal('85944171f73967e8', digest('foobar'))
        end)

        it('même algorithme que shared/fingerprint.lua sur les mêmes octets (codage d\'une chaîne : s<n>:<chaîne>)',
            function()
                for _, text in ipairs({ '', 'a', 'Atelier', string.rep('Récolte · nœud ', 20), string.rep('x', 1001) }) do
                    assert.equal(VavaAtelier.fingerprint(text), digest('s' .. #text .. ':' .. text))
                end
            end)

        it('300 Ko : stable, sensible à un octet, longueurs non multiples de 8', function()
            local big = string.rep('abcdefghijklmnopqrstuvwxyz0123456789', 8534)   -- 307 224 octets
            local first = digest(big)
            assert.equal(first, digest(big))
            assert.equal(LIMITS.DIGEST_LENGTH, #first)
            assert.truthy(first:find('^[0-9a-f]+$'))
            assert.not_equal(first, digest(big:sub(1, -2) .. 'X'))
            for cut = 1, 9 do assert.not_equal(digest(big:sub(1, -cut)), digest(big:sub(1, -cut - 1))) end
        end)

        it('autre chose qu\'une chaîne : nil', function()
            assert.is_nil(digest(nil))
            assert.is_nil(digest(12))
            assert.is_nil(digest({}))
        end)
    end)

    -- relecture sécurité S-1 : SHA-256 (FIPS 180-4), vecteurs publiés (NIST)
    describe('SHA-256', function()
        it('vecteurs publiés : vide, « abc », deux blocs (448 et 896 bits)', function()
            local sha = VavaAtelier.sha256
            assert.equal('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', sha(''))
            assert.equal('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad', sha('abc'))
            assert.equal('248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
                sha('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'))
            assert.equal('cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1',
                sha('abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrs'
                    .. 'mnopqrstnopqrstu'))
        end)

        it('un million de « a » (vecteur publié), avec une pause tous les 16 Ko', function()
            local pauses = 0
            assert.equal('cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0',
                VavaAtelier.sha256(string.rep('a', 1000000), function() pauses = pauses + 1 end))
            assert.equal(61, pauses)   -- 15 626 blocs de 64 octets, une pause tous les 256
        end)

        it('bords de bloc (55, 56, 63, 64 octets) et accents : distincts et stables ; autre chose qu\'une chaîne : nil',
            function()
                local seen = {}
                for _, n in ipairs({ 55, 56, 63, 64, 65 }) do
                    local value = VavaAtelier.sha256(string.rep('é', n))
                    assert.equal(64, #value)
                    assert.truthy(value:find('^[0-9a-f]+$'))
                    assert.is_nil(seen[value])
                    seen[value] = true
                    assert.equal(value, VavaAtelier.sha256(string.rep('é', n)))
                end
                assert.is_nil(VavaAtelier.sha256(nil))
                assert.is_nil(VavaAtelier.sha256(12))
            end)
    end)

    describe('noms', function()
        it('chemins permis, au genre de leur extension', function()
            assert.is_true(codepack.validName('config_conseil.lua', 'L'))
            assert.is_true(codepack.validName('client/placer.lua', 'L'))
            assert.is_true(codepack.validName('web/js/view-home.js', 'J'))
            assert.is_true(codepack.validName('web/css/style.css', 'C'))
            assert.is_true(codepack.validName('a/b/c/d/e.lua', 'L'))
        end)

        it('refusés : remontée, absolu, \\, majuscules, longueur, profondeur, extension, genre inconnu', function()
            for _, name in ipairs({ '../x.lua', '/x.lua', 'a\\b.lua', 'A.lua', 'client/../x.lua', 'client//x.lua',
                'client/', '', 'x', 'x.LUA', '.lua', 'client/x', '1x.lua', 'a/b/c/d/e/f.lua' }) do
                assert.is_false(codepack.validName(name, 'L'), name)
            end
            assert.is_false(codepack.validName(string.rep('a', 93) .. '.lua', 'L'))   -- 97 octets
            assert.is_true(codepack.validName(string.rep('a', 92) .. '.lua', 'L'))    -- 96 octets
            assert.is_false(codepack.validName('web/js/app.js', 'L'))
            assert.is_false(codepack.validName('client/a.lua', 'J'))
            assert.is_false(codepack.validName('web/css/a.css', 'J'))
            assert.is_false(codepack.validName('client/a.lua', 'X'))
            assert.is_false(codepack.validName(12, 'L'))
        end)
    end)

    describe('format', function()
        it('aller-retour (trois genres, accents, code vide) : encode(decode(t)) == t', function()
            local text = assert(codepack.encode(SAMPLE))
            assert.equal('VAVAPAQ1\nL config_conseil.lua 34\nlocal config = VavaAtelier.config\n\n',
                text:sub(1, #'VAVAPAQ1\nL config_conseil.lua 34\nlocal config = VavaAtelier.config\n\n'))
            local pieces = assert(codepack.decode(text))
            assert.same(SAMPLE, pieces)
            assert.equal(text, codepack.encode(pieces))
            assert.equal('VAVAPAQ1\n', codepack.encode({}))
            assert.same({}, codepack.decode('VAVAPAQ1\n'))
        end)

        it('encode refuse : octet nul, ordre, doublon, nom, genre, trop de fichiers, trop gros', function()
            local function encode(list) return select(2, codepack.encode(list)) end
            assert.equal('nul_byte', encode({ piece('L', 'a.lua', 'x\0y') }))
            assert.equal('bad_order', encode({ piece('J', 'web/a.js', ''), piece('L', 'a.lua', '') }))
            assert.equal('duplicate', encode({ piece('L', 'a.lua', ''), piece('L', 'a.lua', '') }))
            assert.equal('bad_name', encode({ piece('L', '../a.lua', '') }))
            assert.equal('bad_kind', encode({ piece('X', 'a.lua', '') }))
            assert.equal('not_string', encode({ piece('L', 'a.lua', 12) }))
            local many = {}
            for i = 1, 49 do many[i] = piece('L', 'f' .. i .. '.lua', '') end
            assert.equal('too_many', encode(many))
            assert.equal('too_large', encode({ piece('L', 'a.lua', string.rep('x', LIMITS.MAX_BYTES)) }))
        end)

        it('decode refuse chaque écart, sans lever d\'erreur', function()
            local good = assert(codepack.encode({ piece('L', 'a.lua', 'abc'), piece('J', 'web/b.js', 'de') }))
            local function decode(text) return select(2, codepack.decode(text)) end
            assert.equal('not_string', decode(nil))
            assert.equal('not_string', decode({}))
            assert.equal('bad_magic', decode('VAVAPAQ2\n'))
            assert.equal('bad_magic', decode(good:sub(2)))
            assert.equal('bad_kind', decode('VAVAPAQ1\nX a.lua 3\nabc\n'))
            assert.equal('bad_name', decode('VAVAPAQ1\nL a.js 3\nabc\n'))          -- extension d'un autre genre
            assert.equal('bad_order', decode('VAVAPAQ1\nJ web/b.js 2\nde\nL a.lua 3\nabc\n'))
            assert.equal('bad_name', decode('VAVAPAQ1\nL ../x.lua 3\nabc\n'))
            assert.equal('bad_name', decode('VAVAPAQ1\nL /x.lua 3\nabc\n'))
            assert.equal('bad_name', decode('VAVAPAQ1\nL a\\b.lua 3\nabc\n'))
            assert.equal('bad_name', decode('VAVAPAQ1\nL A.lua 3\nabc\n'))
            assert.equal('bad_name', decode('VAVAPAQ1\nL ' .. string.rep('a', 93) .. '.lua 3\nabc\n'))
            assert.equal('bad_name', decode('VAVAPAQ1\nL a/b/c/d/e/f.lua 3\nabc\n'))
            assert.equal('truncated', decode('VAVAPAQ1\nL a.lua 30\nabc\n'))
            assert.equal('bad_end', decode('VAVAPAQ1\nL a.lua 3\nabcd'))          -- `\n` manquant après le fichier
            assert.equal('bad_end', decode('VAVAPAQ1\nL a.lua 2\nabc\n'))
            assert.equal('bad_header', decode(good .. 'X'))                        -- octets en trop à la fin
            assert.equal('bad_header', decode(good .. '\n'))
            assert.equal('bad_header', decode('VAVAPAQ1\nL a.lua 03\nabc\n'))      -- longueur à zéro de tête
            assert.equal('bad_header', decode('VAVAPAQ1\nL a.lua  3\nabc\n'))
            assert.equal('bad_header', decode('VAVAPAQ1\nL a.lua -3\nabc\n'))
            assert.equal('duplicate', decode('VAVAPAQ1\nL a.lua 3\nabc\nL a.lua 3\nabc\n'))
            assert.equal('nul_byte', decode('VAVAPAQ1\nL a.lua 3\na\0c\n'))
            local many = { 'VAVAPAQ1\n' }
            for i = 1, 49 do many[#many + 1] = ('L f%d.lua 0\n\n'):format(i) end
            assert.equal('too_many', decode(table.concat(many)))
            assert.equal('too_large', decode('VAVAPAQ1\n' .. string.rep('x', LIMITS.MAX_BYTES)))
        end)
    end)

    describe('découpe', function()
        it('morceaux ≤ taille dont la suite redonne le texte ; texte vide : aucun morceau', function()
            local text = assert(codepack.encode(SAMPLE))
            for _, size in ipairs({ 4, 5, 7, 16, 64, #text, #text + 10 }) do
                local parts = assert(codepack.cut(text, size))
                for _, part in ipairs(parts) do assert.is_true(#part <= size and #part > 0) end
                assert.equal(text, table.concat(parts))
            end
            assert.same({}, codepack.cut('', 8))
        end)

        it('aucune coupure devant un octet de continuation UTF-8 (é, « », emoji de 4 octets à la frontière)', function()
            for _, char in ipairs({ 'é', '«', '»', '\u{1F33E}' }) do
                for offset = 0, 4 do
                    local text = string.rep('a', 8 - offset) .. char .. string.rep('b', 10) .. char
                    local parts = assert(codepack.cut(text, 8))
                    assert.equal(text, table.concat(parts))
                    for i = 2, #parts do
                        local first = parts[i]:byte(1)
                        assert.is_false(first >= 0x80 and first <= 0xBF, ('coupure dans %q'):format(char))
                    end
                end
            end
        end)

        it('taille < 4 ou autre chose qu\'un entier refusée', function()
            assert.same({ nil, 'bad_size' }, { codepack.cut('abc', 3) })
            assert.same({ nil, 'bad_size' }, { codepack.cut('abc', 4.5) })
            assert.same({ nil, 'not_string' }, { codepack.cut(nil, 8) })
        end)
    end)
end)
