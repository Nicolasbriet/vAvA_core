local helper = require('tests.helper')

local ROOT = os.getenv('VAVA_ROOT') or '.'

-- Taille d'une valeur une fois sérialisée en msgpack (même règle que tests/spec/codex_fingerprint_spec.lua) : ce que
-- pèse une réponse RPC sur le réseau, hors enveloppe du core.
local function msgpackSize(value)
    local kind = type(value)
    if kind == 'nil' or kind == 'boolean' then return 1 end
    if kind == 'number' then
        if math.type(value) == 'float' then return 9 end
        if value >= -32 and value <= 127 then return 1 end
        if value >= -32768 and value <= 65535 then return 3 end
        return 9
    end
    if kind == 'string' then
        local n = #value
        return n + (n < 32 and 1 or n < 256 and 2 or n < 65536 and 3 or 5)
    end
    local count, size = 0, 0
    for _ in pairs(value) do count = count + 1 end
    local isList = count == #value
    size = count < 16 and 1 or 3
    for key, item in pairs(value) do size = size + msgpackSize(item) + (isList and 0 or msgpackSize(key)) end
    return size
end

local function loadPages()
    helper.reset()
    VavaCodex = nil
    helper.loadAll({
        'modules/vava_codex/shared/constants.lua',
        'modules/vava_codex/config.lua',
        'modules/vava_codex/shared/fingerprint.lua',
        'modules/vava_codex/shared/pages.lua',
    })
    return VavaCodex.pages
end

--- Page valide minimale, modifiable champ par champ.
local function page(fields)
    local def = {
        id = 'essai', chapter = 'premiers_pas', order = 10, title = 'Essai', summary = 'Une page d’essai.',
        audience = 'player', permission = '', requires = '', body = 'Texte.',
    }
    for key, value in pairs(fields or {}) do def[key] = value end
    return def
end

local function chapter(fields)
    local def = { id = 'premiers_pas', label = 'Premiers pas', order = 10 }
    for key, value in pairs(fields or {}) do def[key] = value end
    return def
end

describe('vava_codex pages de lecture : analyse d\'un corps', function()
    local pages, parse

    --- code et ligne d'un refus
    local function refusal(body)
        local blocks, code, line = parse(body)
        assert.is_nil(blocks)
        return code, line
    end

    before_each(function()
        pages = loadPages()
        parse = pages.parse
    end)

    it('joint deux lignes en un paragraphe, et sépare deux paragraphes par une ligne vide', function()
        assert.same({ { 'p', 'Une ligne et la suivante.' } }, (parse('Une ligne\net la suivante.')))
        assert.same({ { 'p', 'Un.' }, { 'p', 'Deux.' } }, (parse('Un.\n\nDeux.')))
        -- espaces multiples ramenées à une, espaces de fin retirées
        assert.same({ { 'p', 'a b c' } }, (parse('a   b  \n  c   ')))
    end)

    it('lit les intertitres et refuse ceux qui sont mal formés', function()
        assert.same({ { 'h', 'Titre' }, { 'p', 'Texte.' } }, (parse('## Titre\nTexte.')))
        for _, body in ipairs({ '### x', '#x', '## [[F1]]', '##', '## #x' }) do
            assert.equal('bad_heading', (refusal(body)), body)
        end
        local code, line = refusal('Texte.\n\n#x')
        assert.equal('bad_heading', code)
        assert.equal(3, line)
        assert.equal('too_long_block', (refusal('## ' .. string.rep('a', 81))))
        assert.same({ { 'h', string.rep('a', 80) } }, (parse('## ' .. string.rep('a', 80))))
    end)

    it('lit les listes à puces et numérotées, leurs suites et leur fin', function()
        assert.same({ { 'ul', { 'a' }, { 'b' } } }, (parse('- a\n- b')))
        assert.same({ { 'ul', { 'a suite' } } }, (parse('- a\n  suite')))
        assert.same({ { 'ol', { 'a' }, { 'b' } } }, (parse('1. a\n2. b')))
        -- le numéro écrit est ignoré : l'ordre fait foi
        assert.same({ { 'ol', { 'a' }, { 'b' } } }, (parse('7. a\n12. b')))
        -- liste puis paragraphe sans ligne vide : deux blocs
        assert.same({ { 'ul', { 'a' } }, { 'p', 'Texte.' } }, (parse('- a\nTexte.')))
        -- une puce change de genre : deux listes
        assert.same({ { 'ul', { 'a' } }, { 'ol', { 'b' } } }, (parse('- a\n1. b')))
        -- trois chiffres : un paragraphe
        assert.same({ { 'p', '100. a' } }, (parse('100. a')))
    end)

    it('lit les notes, jointes ligne à ligne, et ignore « > » seul', function()
        assert.same({ { 'note', 'a b' } }, (parse('> a\n> b')))
        assert.same({ { 'note', 'a' } }, (parse('>a')))
        assert.same({ { 'note', 'a' }, { 'p', 'Texte.' } }, (parse('> a\nTexte.')))
        assert.same({ { 'p', 'a b' } }, (parse('a\n>\nb')))
    end)

    describe('jetons', function()
        local function segmentsOf(text)
            local blocks = parse(text)
            assert.is_table(blocks, text)
            return blocks[1]
        end

        it('lit chaque genre de jeton', function()
            assert.same({ 'p', 'Ouvrez (', { 'kbd', 'F1' }, ').' }, segmentsOf('Ouvrez ([[F1]]).'))
            assert.same({ 'p', { 'kbd', 'Clic droit' } }, segmentsOf('[[Clic droit]]'))
            assert.same({ 'p', { 'key', 'vava_inventory' } }, segmentsOf('[[touche:vava_inventory]]'))
            assert.same({ 'p', { 'cmd', 'metiers', 'voir' } }, segmentsOf('[[commande:metiers voir]]'))
            assert.same({ 'p', { 'cmd', 'me', '' } }, segmentsOf('[[commande:me]]'))
            assert.same({ 'p', { 'page', 'troquer', 'le troc' } }, segmentsOf('[[page:troquer|le troc]]'))
            assert.same({ 'p', { 'page', 'troquer', '' } }, segmentsOf('[[page:troquer]]'))
            assert.same({ 'p', 'un ', { 'em', 'mot' }, ' ici' }, segmentsOf('un *mot* ici'))
            assert.same({ 'p', { 'em', 'un groupe de mots' } }, segmentsOf('*un groupe de mots*'))
        end)

        it('laisse les astérisques sans pendant, et les crochets seuls, en texte', function()
            assert.same({ 'p', '2 * 3' }, segmentsOf('2 * 3'))
            assert.same({ 'p', 'a * b *' }, segmentsOf('a * b *'))
            assert.same({ 'p', '** et [ ou ] ou |' }, segmentsOf('** et [ ou ] ou |'))
            -- un jeton dans un italique : l'italique n'en est pas un
            assert.same({ 'p', '*a ', { 'kbd', 'F1' }, '*' }, segmentsOf('*a [[F1]]*'))
        end)

        it('lit un jeton coupé par un saut de ligne', function()
            assert.same({ 'p', { 'kbd', 'Clic droit' } }, segmentsOf('[[Clic\ndroit]]'))
        end)

        it('refuse un jeton mal formé', function()
            local bad = {
                '[[F1', '[[foo:bar]]', '[[]]', '[[touche:a b]]', '[[touche:]]', '[[' .. string.rep('x', 17) .. ']]',
                '[[page:troquer|' .. string.rep('x', 49) .. ']]', '[[page:Bad]]', '[[page:vava_x]]', '[[page:x|]]',
                '[[commande:a b c]]', '[[commande:metiers vo.ir]]', '[[a|b]]', '[[a*b]]', '[[ F1]]', '[[[F1]]',
            }
            for _, text in ipairs(bad) do
                local code, line = refusal('Avant.\n\n' .. text)
                assert.equal('bad_token', code, text)
                assert.equal(3, line, text)
            end
            -- bornes exactes acceptées
            assert.same({ 'p', { 'kbd', string.rep('x', 16) } }, segmentsOf('[[' .. string.rep('x', 16) .. ']]'))
            assert.same({ 'p', { 'page', 'troquer', string.rep('x', 48) } },
                segmentsOf('[[page:troquer|' .. string.rep('x', 48) .. ']]'))
        end)
    end)

    describe('bornes', function()
        it('refuse un corps trop long', function()
            assert.equal('too_long', (refusal(string.rep('a', 6001))))
            assert.is_table((parse(string.rep('a', 1200))))
        end)

        it('refuse trop de blocs', function()
            local list = {}
            for i = 1, 41 do list[i] = 'p' .. i end
            local code, line = refusal(table.concat(list, '\n\n'))
            assert.equal('too_many_blocks', code)
            assert.equal(81, line)
            assert.equal(40, #parse(table.concat(list, '\n\n', 1, 40)))
        end)

        it('refuse une liste trop longue', function()
            local list = {}
            for i = 1, 13 do list[i] = '- x' end
            local code, line = refusal(table.concat(list, '\n'))
            assert.equal('too_many_items', code)
            assert.equal(13, line)
            assert.is_table((parse(table.concat(list, '\n', 1, 12))))
        end)

        it('refuse un paragraphe, un élément ou une note trop longs', function()
            assert.equal('too_long_block', (refusal(string.rep('a', 1201))))
            assert.equal('too_long_block', (refusal('> ' .. string.rep('a', 1201))))
            assert.equal('too_long_block', (refusal('- ' .. string.rep('a', 401))))
            assert.is_table((parse('- ' .. string.rep('a', 400))))
            -- borné tel qu'écrit, jetons compris
            assert.equal('too_long_block', (refusal(string.rep('a', 1195) .. ' [[F1]]')))
        end)

        it('refuse trop de jetons dans la page', function()
            assert.equal('too_many_tokens', (refusal(string.rep('[[F1]] ', 41))))
            assert.is_table((parse(string.rep('[[F1]] ', 40))))
            -- comptés sur toute la page
            assert.equal('too_many_tokens', (refusal(string.rep('*a* ', 30) .. '\n\n' .. string.rep('*b* ', 11))))
        end)

        it('refuse un corps vide', function()
            for _, body in ipairs({ '', '\n\n', '   \n\n  ', '>\n>' }) do
                local code, line = refusal(body)
                assert.equal('empty_body', code)
                assert.equal(0, line)
            end
        end)
    end)

    describe('caractères', function()
        it('refuse « < » partout et « > » ailleurs qu\'en tête de ligne', function()
            assert.equal('bad_char', (refusal('a < b')))
            local code, line = refusal('Texte.\na > b')
            assert.equal('bad_char', code)
            assert.equal(2, line)
            assert.equal('bad_char', (refusal('> a > b')))
            assert.equal('bad_char', (refusal('  > a')))
            assert.equal('bad_char', (refusal('## a <b>')))
            assert.is_table((parse('> note')))
        end)

        it('refuse les caractères de contrôle, avec leur ligne', function()
            for _, char in ipairs({ '\1', '\t', '\127', '\0', '\31', '\11' }) do
                local code, line = refusal('un\ndeux\ntrois ' .. char .. ' quatre')
                assert.equal('bad_char', code)
                assert.equal(3, line)
            end
        end)

        it('accepte les fins de ligne Windows', function()
            assert.same({ { 'p', 'a b' }, { 'p', 'c' } }, (parse('a\r\nb\r\n\r\nc\r\n')))
        end)

        it('refuse un texte illisible, sans ligne', function()
            local code, line = refusal('ab\xC3\x28cd')
            assert.equal('bad_utf8', code)
            assert.equal(0, line)
            assert.equal('bad_utf8', (refusal(nil)))
            assert.equal('bad_utf8', (refusal(12)))
        end)

        it('accepte les lettres accentuées et la typographie française', function()
            local text = 'À l’été, « Œuvre » : déjà Ça — fin…'
            assert.same({ { 'p', text } }, (parse(text)))
            -- l'octet 0xA0 de « à » n'est pas une espace
            assert.same({ { 'p', 'déjà à' } }, (parse('déjà à')))
        end)
    end)
end)

describe('vava_codex pages de lecture : chapitres et pages', function()
    local pages

    before_each(function()
        pages = loadPages()
    end)

    local function codeOf(ok, code)
        if ok then return 'ok' end
        return code
    end

    it('valide un chapitre champ par champ', function()
        local check = function(fields) return codeOf(pages.validateChapter(chapter(fields))) end
        assert.equal('ok', check({}))
        assert.equal('ok', check({ id = string.rep('a', 32), label = string.rep('a', 32), order = 999 }))
        assert.equal('ok', check({ order = 0 }))
        assert.equal('bad_id', check({ id = string.rep('a', 33) }))
        assert.equal('bad_id', check({ id = 'vava_x' }))
        assert.equal('bad_id', check({ id = 'Premiers' }))
        assert.equal('bad_id', check({ id = '1er' }))
        assert.equal('bad_id', check({ id = '' }))
        assert.equal('bad_label', check({ label = '' }))
        assert.equal('bad_label', check({ label = string.rep('a', 33) }))
        assert.equal('bad_label', check({ label = 'a<b' }))
        for _, order in ipairs({ 1.5, -1, 1000, '10' }) do
            assert.equal('bad_order', check({ order = order }), tostring(order))
        end
        assert.equal('unknown_field', check({ color = 'red' }))
        assert.equal('bad_id', codeOf(pages.validateChapter('premiers_pas')))
    end)

    it('valide une page champ par champ', function()
        local check = function(fields) return codeOf(pages.validatePage(page(fields))) end
        assert.equal('ok', check({}))
        assert.equal('ok', check({ title = string.rep('a', 48), summary = string.rep('a', 120) }))
        assert.equal('ok', check({ summary = '' }))
        assert.equal('ok', check({ id = string.rep('a', 32), order = 999 }))
        assert.equal('bad_id', check({ id = string.rep('a', 33) }))
        assert.equal('bad_id', check({ id = 'vava_x' }))
        assert.equal('bad_chapter', check({ chapter = 12 }))
        assert.equal('bad_title', check({ title = '' }))
        assert.equal('bad_title', check({ title = string.rep('a', 49) }))
        assert.equal('bad_title', check({ title = 'a\nb' }))
        assert.equal('bad_title', check({ title = 'a>b' }))
        assert.equal('bad_title', check({ title = '\xC3\x28' }))
        assert.equal('bad_summary', check({ summary = string.rep('a', 121) }))
        assert.equal('bad_summary', check({ summary = 'a<b' }))
        assert.equal('bad_audience', check({ audience = 'staff' }))
        local noAudience = page()
        noAudience.audience = nil
        assert.equal('bad_audience', codeOf(pages.validatePage(noAudience)))
        assert.equal('ok', check({ audience = 'admin', permission = 'metiers' }))
        assert.equal('ok', check({ audience = 'admin', permission = string.rep('a', 32) }))
        assert.equal('bad_permission', check({ audience = 'admin', permission = string.rep('a', 33) }))
        assert.equal('bad_permission', check({ audience = 'admin', permission = 'Metiers' }))
        assert.equal('bad_permission', check({ permission = 'metiers' }))   -- audience player
        assert.equal('ok', check({ requires = 'vava_magic' }))
        assert.equal('ok', check({ requires = string.rep('a', 64) }))
        assert.equal('bad_requires', check({ requires = string.rep('a', 65) }))
        assert.equal('bad_requires', check({ requires = 'vava magic' }))
        assert.equal('bad_requires', check({ requires = 3 }))
        for _, order in ipairs({ 1.5, -1, 1000 }) do
            assert.equal('bad_order', check({ order = order }), tostring(order))
        end
        assert.equal('unknown_field', check({ color = 'red' }))
        assert.equal('unknown_field', check({ [1] = 'x' }))
        assert.equal('bad_summary', check({ summary = false }))
        -- facultatifs absents : ''
        local bare = page()
        bare.summary, bare.permission, bare.requires = nil, nil, nil
        assert.is_true((pages.validatePage(bare)))
    end)

    describe('construction', function()
        local function build(pageList, chapterList)
            return pages.build({ chapters = chapterList or { chapter() }, pages = pageList })
        end

        local function ids(list)
            local out = {}
            for i, item in ipairs(list) do out[i] = item.id end
            return out
        end

        local function codes(refused)
            local out = {}
            for _, entry in ipairs(refused) do out[entry.id] = entry.code end
            return out
        end

        it('refuse un identifiant déjà pris par une page ou un chapitre', function()
            local book, refused = build({ page({ id = 'a', title = 'Premier' }), page({ id = 'a', title = 'Second' }),
                page({ id = 'premiers_pas' }) })
            assert.same({ 'a' }, ids(book.pages))
            assert.equal('Premier', book.byId.a.title)
            assert.equal(2, #refused)
            assert.same({ kind = 'page', id = 'a', code = 'id_taken', line = 0 }, refused[1])
            assert.equal('id_taken', refused[2].code)
            assert.equal('premiers_pas', refused[2].id)
        end)

        it('refuse un chapitre inconnu, et un chapitre en double', function()
            local book, refused = build({ page({ chapter = 'inconnu' }) },
                { chapter(), chapter({ label = 'Encore' }) })
            assert.same({}, book.pages)
            assert.equal(1, #book.chapters)
            assert.same({ kind = 'chapter', id = 'premiers_pas', code = 'id_taken', line = 0 }, refused[1])
            assert.same({ kind = 'page', id = 'essai', code = 'bad_chapter', line = 0 }, refused[2])
        end)

        it('écarte une page dont le corps est fautif, avec sa ligne, et garde les autres', function()
            local book, refused = build({ page({ id = 'a' }), page({ id = 'b', body = 'Un.\n\nDeux [[foo:bar]].' }) })
            assert.same({ 'a' }, ids(book.pages))
            assert.same({ { kind = 'page', id = 'b', code = 'bad_token', line = 3 } }, refused)
        end)

        it('refuse un lien vers une page absente, ou d\'une page publique vers une page du Conseil', function()
            local book, refused = build({
                page({ id = 'a', body = 'Voir [[page:absente]].' }),
                page({ id = 'b', body = 'Un.\n\nVoir [[page:c]].' }),
                page({ id = 'c', audience = 'admin', body = 'Voir [[page:d]] et [[page:c]].' }),
                page({ id = 'd', body = 'Voir [[page:d|ici]].' }),
            })
            assert.same({ 'c', 'd' }, ids(book.pages))
            assert.same({ a = 'bad_link', b = 'bad_link' }, codes(refused))
            assert.equal(1, refused[1].line)
            assert.equal(3, refused[2].line)
        end)

        it('fait refuser en chaîne une page qui mène à une page refusée', function()
            local book, refused = build({
                page({ id = 'a', order = 1, body = 'Voir [[page:b]].' }),
                page({ id = 'b', order = 2, body = 'Voir [[page:c]].' }),
                page({ id = 'c', order = 3, body = '[[foo:bar]]' }),
                page({ id = 'd', order = 4, body = 'Voir [[page:a]].' }),
            })
            assert.same({}, book.pages)
            assert.same({ a = 'bad_link', b = 'bad_link', c = 'bad_token', d = 'bad_link' }, codes(refused))
        end)

        it('trie chapitres et pages (rang, puis identifiant) et donne à chaque page empreinte, réponse et poids', function()
            local book = build({
                page({ id = 'zz', chapter = 'b', order = 5 }),
                page({ id = 'yy', chapter = 'a', order = 20 }),
                page({ id = 'xb', chapter = 'a', order = 10 }),
                page({ id = 'xa', chapter = 'a', order = 10 }),
                page({ id = 'ww', chapter = 'c', order = 0 }),
            }, { chapter({ id = 'c', order = 30 }), chapter({ id = 'b', order = 10 }), chapter({ id = 'a', order = 10 }) })
            assert.same({ 'a', 'b', 'c' }, ids(book.chapters))
            assert.same({ 'xa', 'xb', 'yy', 'zz', 'ww' }, ids(book.pages))
            local first = book.pages[1]
            assert.equal(16, #first.hash)
            assert.equal(VavaCodex.fingerprint({ title = first.title, body = first.blocks }), first.hash)
            assert.same({ id = 'xa', chapter = 'a', title = 'Essai', hash = first.hash, body = first.blocks }, first.response)
            assert.equal(msgpackSize(first.response), first.wire)
            assert.equal(first, book.byId.xa)
            assert.is_nil(first.lines)
        end)

        it('ne garde que les 40 premières pages dans l\'ordre du tri, et 8 chapitres', function()
            local list = {}
            for i = 41, 1, -1 do list[#list + 1] = page({ id = string.format('p%02d', i), order = i }) end
            local book, refused = build(list)
            assert.equal(40, #book.pages)
            assert.equal('p01', book.pages[1].id)
            assert.equal('p40', book.pages[40].id)
            assert.same({ { kind = 'page', id = 'p41', code = 'too_many_pages', line = 0 } }, refused)

            local chapters = {}
            for i = 1, 9 do chapters[i] = chapter({ id = 'c' .. i, order = i }) end
            book, refused = build({}, chapters)
            assert.equal(8, #book.chapters)
            assert.same({ { kind = 'chapter', id = 'c9', code = 'too_many_chapters', line = 0 } }, refused)
        end)

        it('refuse une page trop lourde pour un envoi', function()
            local book = build({ page({ body = string.rep('Un texte assez long. ', 50) }) })
            local wire = book.pages[1].wire
            VavaCodex.READING.MAX_WIRE = wire - 1
            local refused
            book, refused = build({ page({ body = string.rep('Un texte assez long. ', 50) }) })
            assert.same({}, book.pages)
            assert.same({ { kind = 'page', id = 'essai', code = 'too_large', line = 0 } }, refused)
            VavaCodex.READING.MAX_WIRE = wire
            book = build({ page({ body = string.rep('Un texte assez long. ', 50) }) })
            assert.equal(1, #book.pages)
        end)

        it('rend un ensemble vide pour une graine absente ou informe', function()
            for _, seed in ipairs({ false, 'x', {} }) do
                local book, refused = pages.build(seed)
                assert.same({ chapters = {}, pages = {}, byId = {} }, book)
                assert.same({}, refused)
            end
            local _, refused = pages.build({ chapters = { 'x' }, pages = { 12 } })
            assert.same({ { kind = 'chapter', id = '?', code = 'bad_id', line = 0 },
                { kind = 'page', id = '?', code = 'bad_id', line = 0 } }, refused)
        end)
    end)

    it('estime le poids réseau comme msgpack', function()
        local samples = {
            '', string.rep('a', 31), string.rep('a', 32), string.rep('a', 255), string.rep('a', 256), 0, 127, 128, -32,
            -33, 65535, 65536, 1.5, true, false, {}, { 'a', 'b' }, { a = 1, b = { 'c' } },
            { id = 'x', chapter = 'y', title = 'z', hash = '0123456789abcdef', body = { { 'p', 'a', { 'kbd', 'F1' } } } },
        }
        local big = {}
        for i = 1, 20 do big[i] = i end
        samples[#samples + 1] = big
        for i, value in ipairs(samples) do
            assert.equal(msgpackSize(value), pages.wireSize(value), 'témoin ' .. i)
        end
    end)

    it('rend les touches, commandes et pages citées, sans doublon', function()
        local blocks = assert(pages.parse(table.concat({
            '[[touche:codex]] [[touche:codex]] [[F1]] [[commande:me]] [[commande:metiers voir]]',
            '',
            '- [[commande:me]] [[page:troquer]]',
            '- [[page:troquer|le troc]] [[commande:metiers]] [[touche:vava_skills]] *em*',
            '',
            '> [[page:apprendre]]',
        }, '\n')))
        assert.same({
            keys = { 'codex', 'vava_skills' },
            commands = { { name = 'me', action = '' }, { name = 'metiers', action = 'voir' }, { name = 'metiers', action = '' } },
            pages = { 'troquer', 'apprendre' },
        }, pages.references(blocks))
        assert.same({ keys = {}, commands = {}, pages = {} }, pages.references({ { 'h', 'Titre' } }))
    end)
end)

describe('vava_codex pages de lecture : la graine du dépôt', function()
    local pages, book, refused

    -- Touches déclarées aujourd'hui au registre `core:commands` (fichier qui déclare chaque nom). Renommer une touche
    -- fait échouer ce test : relire la page qui la cite.
    local KEYS = {
        codex = true,                     -- modules/vava_codex/server/commands.lua (cfg.command, touche F1)
        conseil = true,                   -- modules/vava_admin/server/commands.lua
        atelier = true,                   -- modules/vava_atelier/server/commands.lua
        vava_inventory = true,            -- modules/vava_inventory/server/commands.lua
        vava_inventory_slot = true,       -- modules/vava_inventory/server/commands.lua
        vava_skills = true,               -- modules/vava_skills/server/commands.lua
        vava_chat_ouvrir = true,          -- modules/vava_chat/server/commands.lua (nom dans config.lua)
        vava_voice_portee = true,         -- modules/vava_voice/server/commands.lua (nom dans config.lua)
        vava_gathering_interact = true,   -- modules/vava_gathering/server/commands.lua
        vava_gathering_zones = true,      -- modules/vava_gathering/server/commands.lua
        vava_crafting_interact = true,    -- modules/vava_crafting/server/commands.lua
        vava_farming_interact = true,     -- modules/vava_farming/server/commands.lua
        vava_health_assist = true,        -- modules/vava_health/server/commands.lua
        vava_health_giveup = true,        -- modules/vava_health/server/commands.lua
        vava_magic_roue = true,           -- modules/vava_magic/server/commands.lua (noms dans config.lua)
        vava_magic_viser = true,
        vava_magic_lancer = true,
        vava_magic_verrou = true,
        vava_magic_annuler = true,
    }
    -- Commandes (et sous-commandes) déclarées aujourd'hui, même règle.
    local COMMANDS = {
        ['date'] = true,                  -- modules/vava_time/server/commands.lua
        ['me'] = true,                    -- modules/vava_chat/server/commands.lua
        ['do'] = true,                    -- modules/vava_chat/server/commands.lua
        ['mp'] = true,                    -- modules/vava_chat/server/commands.lua
        ['r'] = true,                     -- modules/vava_chat/server/commands.lua
        ['signaler'] = true,              -- modules/vava_admin/server/commands.lua
        ['grimoire'] = true,              -- modules/vava_magic/server/commands.lua
        ['sigil offrir'] = true,          -- modules/vava_magic/server/commands.lua (sigilActions.offer)
        ['recolte zones'] = true,         -- modules/vava_gathering/server/commands.lua
        ['artisanat stations'] = true,    -- modules/vava_crafting/server/commands.lua
        ['agriculture parcelles'] = true, -- modules/vava_farming/server/commands.lua
        ['metiers voir'] = true,          -- modules/vava_skills/server/commands.lua
        ['accueil etat'] = true,          -- modules/vava_arrival/server/commands.lua
        ['magie fiche'] = true,           -- modules/vava_magic/server/commands.lua (adminActions.sheet)
        ['ciel'] = true,                  -- modules/vava_time/server/commands.lua
    }
    -- Mots qui n'ont rien à faire à Eldoria (spec T-023, § 5.2), cherchés en mots entiers, casse ASCII ignorée.
    local FORBIDDEN_WORDS = { 'argent', 'boutique', 'magasin', 'banque', 'police', 'téléphone', 'voiture', 'dollar', 'euro' }
    local FORBIDDEN_SIGNS = { '$', '€' }

    -- ponctuation écrite en plusieurs octets (’ ‘ « » — – … espaces insécables) : un séparateur, comme une espace
    local SEPARATORS = { '’', '‘', '«', '»', '—', '–', '…', '\u{A0}', '\u{202F}' }

    --- Casse ASCII abaissée, ponctuation typographique changée en espaces.
    local function asciiLower(text)
        for _, sign in ipairs(SEPARATORS) do text = text:gsub(sign, ' ') end
        return (text:gsub('[A-Z]', function(c) return string.char(c:byte() + 32) end))
    end

    --- Le mot `word` est-il dans `text`, en mot entier ? Une lettre ASCII ou un octet d'un caractère UTF-8 accolé
    --- ne fait pas un mot entier (« argentée » ne compte pas).
    local function hasWord(text, word)
        local start = 1
        while true do
            local s, e = text:find(word, start, true)
            if not s then return false end
            local before, after = text:byte(s - 1), text:byte(e + 1)
            local function letter(b) return b and ((b >= 65 and b <= 90) or (b >= 97 and b <= 122) or b >= 128) end
            if not letter(before) and not letter(after) then return true end
            start = s + 1
        end
    end

    --- Toutes les chaînes d'une page rendue (titre, résumé, segments).
    local function texts(p)
        local out = { p.title, p.summary }
        local function visit(segment)
            if type(segment) == 'string' then
                out[#out + 1] = segment
            else
                for i = 2, #segment do out[#out + 1] = segment[i] end
            end
        end
        for _, block in ipairs(p.blocks) do
            for i = 2, #block do
                if block[1] == 'ul' or block[1] == 'ol' then
                    for _, segment in ipairs(block[i]) do visit(segment) end
                else
                    visit(block[i])
                end
            end
        end
        return out
    end

    --- Index d'un joueur, comme server/reading.lua le compose (toutes les pages visibles de ce public).
    local function index(staff)
        local chapters, list, shown = {}, {}, {}
        for _, p in ipairs(book.pages) do
            if p.audience == 'player' or staff then
                list[#list + 1] = { id = p.id, chapter = p.chapter, title = p.title, summary = p.summary, hash = p.hash,
                    staff = p.audience == 'admin' or nil }
                shown[p.chapter] = true
            end
        end
        for _, c in ipairs(book.chapters) do
            if shown[c.id] then chapters[#chapters + 1] = { id = c.id, label = c.label } end
        end
        return { chapters = chapters, pages = list }
    end

    before_each(function()
        pages = loadPages()
        -- dans l'ordre du manifeste
        helper.loadAll({
            'modules/vava_codex/content/chapters.lua',
            'modules/vava_codex/content/premiers_pas.lua',
            'modules/vava_codex/content/metiers.lua',
            'modules/vava_codex/content/royaume.lua',
        })
        book, refused = pages.build(VavaCodex.seed)
    end)

    it('ne refuse aucune page', function()
        local lines = {}
        for _, entry in ipairs(refused) do
            lines[#lines + 1] = string.format('%s %s : %s (ligne %d)', entry.kind, entry.id, entry.code, entry.line)
        end
        assert.same({}, lines)
    end)

    it('a trois chapitres, douze pages dont une seule du Conseil, et commence par « Vivre à Eldoria »', function()
        local chapterIds = {}
        for i, c in ipairs(book.chapters) do chapterIds[i] = c.id end
        assert.same({ 'premiers_pas', 'metiers', 'royaume' }, chapterIds)
        assert.equal(12, #book.pages)
        assert.equal('bienvenue', book.pages[1].id)
        assert.equal('premiers_pas', book.pages[1].chapter)
        local admin = {}
        for _, p in ipairs(book.pages) do
            if p.audience == 'admin' then admin[#admin + 1] = p.id end
        end
        assert.same({ 'conseil_sieger' }, admin)
        for _, id in ipairs({ 'bienvenue', 'se_parler', 'troquer', 'faim_soif', 'a_terre', 'apprendre', 'recolte',
            'artisanat', 'agriculture', 'magie', 'conseil', 'conseil_sieger' }) do
            assert.is_table(book.byId[id], id)
        end
    end)

    it('tient chaque page et chaque index sous leurs bornes réseau', function()
        for _, p in ipairs(book.pages) do
            assert.is_true(msgpackSize(p.response) <= VavaCodex.READING.MAX_WIRE, p.id)
        end
        assert.is_true(msgpackSize(index(false)) <= 3000, 'index d\'un joueur : ' .. msgpackSize(index(false)))
        assert.is_true(msgpackSize(index(true)) <= 3300, 'index du Conseil : ' .. msgpackSize(index(true)))
        assert.equal(11, #index(false).pages)
        assert.equal(12, #index(true).pages)
    end)

    it('ne dépend que de modules du dépôt, et chaque page hors de « Vivre à Eldoria » suit un module', function()
        for _, p in ipairs(book.pages) do
            if p.id == 'bienvenue' then
                assert.equal('', p.requires)
            else
                assert.are_not.equal('', p.requires, p.id)
                local manifest = io.open(ROOT .. '/modules/' .. p.requires .. '/fxmanifest.lua', 'r')
                assert.is_not_nil(manifest, p.id .. ' : ' .. p.requires)
                manifest:close()
            end
        end
    end)

    it('ne cite que des touches et des commandes déclarées aujourd\'hui', function()
        for _, p in ipairs(book.pages) do
            for _, name in ipairs(p.refs.keys) do
                assert.is_true(KEYS[name] == true, p.id .. ' : touche ' .. name)
            end
            for _, command in ipairs(p.refs.commands) do
                local shown = command.action ~= '' and (command.name .. ' ' .. command.action) or command.name
                assert.is_true(COMMANDS[shown] == true, p.id .. ' : commande ' .. shown)
            end
        end
    end)

    it('n\'emploie aucun mot moderne', function()
        for _, p in ipairs(book.pages) do
            for _, text in ipairs(texts(p)) do
                local lowered = asciiLower(text)
                for _, word in ipairs(FORBIDDEN_WORDS) do
                    assert.is_false(hasWord(lowered, word), p.id .. ' : « ' .. word .. ' »')
                end
                for _, sign in ipairs(FORBIDDEN_SIGNS) do
                    assert.is_nil(text:find(sign, 1, true), p.id .. ' : « ' .. sign .. ' »')
                end
            end
        end
    end)

    it('repère bien un mot interdit en mot entier', function()
        assert.is_true(hasWord(asciiLower('Pas d’Argent ici'), 'argent'))
        assert.is_false(hasWord(asciiLower('une coupe argentée'), 'argent'))
        assert.is_false(hasWord(asciiLower('l’Europe'), 'euro'))
        assert.is_true(hasWord(asciiLower('« Euro »'), 'euro'))
        assert.is_true(hasWord(asciiLower('Téléphone'), 'téléphone'))
    end)
end)
