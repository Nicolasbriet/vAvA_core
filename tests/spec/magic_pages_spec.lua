local helper = require('tests.helper')

-- Registre des murmures envoyé par lots (modules/vava_magic/shared/pages.lua). Valeurs documentées : README du module
-- (« Registre des murmures ») et config.lua (`registers`) : 200 pages au plus, correspondant de 160 signes, lots de
-- 20 pages au plus et de 7 500 octets estimés au plus, au moins une page par lot ; texte d'un murmure borné à
-- 1 400 octets (`spells.murmure.textMaxBytes`). Critère de T-048 : un registre plein s'ouvre avec moins de 12 Ko.

local function load()
    helper.reset()
    helper.loadAll({
        'modules/vava_magic/shared/constants.lua',
        'modules/vava_magic/config.lua',
        'modules/vava_magic/shared/pages.lua',
    })
    return VavaMagic
end

--- Taille msgpack (octets) d'une valeur, comme la sérialise FiveM : entiers positifs, textes, booléens, tables
--- (liste ou clés nommées).
local function packed(value)
    local kind = type(value)
    if value == nil or kind == 'boolean' then return 1 end
    if kind == 'number' then
        assert(math.type(value) == 'integer' and value >= 0, 'entier positif attendu')
        if value < 128 then return 1 elseif value <= 0xFF then return 2 elseif value <= 0xFFFF then return 3
        elseif value <= 0xFFFFFFFF then return 5 end
        return 9
    end
    if kind == 'string' then
        local n = #value
        if n <= 31 then return 1 + n elseif n <= 0xFF then return 2 + n elseif n <= 0xFFFF then return 3 + n end
        return 5 + n
    end
    assert(kind == 'table', 'type inattendu : ' .. kind)
    local total, count = 0, 0
    if #value > 0 or next(value) == nil then
        for _, item in ipairs(value) do total, count = total + packed(item), count + 1 end
    else
        for key, item in pairs(value) do total, count = total + packed(key) + packed(item), count + 1 end
    end
    return total + (count <= 15 and 1 or 3)
end

--- Lignes lues en base (les plus récentes d'abord), du numéro `from` en descendant.
local function rows(n, from, contact, body)
    local list = {}
    for i = 1, n do
        list[i] = { id = from - i + 1, written_at = 1793000000 + i, direction = 1 + i % 2, contact = contact or 'Aldric', body = body or 'Bonjour.' }
    end
    return list
end

describe('vava_magic pages', function()
    local pages, limits, murmure

    before_each(function()
        local magic = load()
        pages, limits, murmure = magic.pages, magic.config.registers, magic.config.spells.murmure
    end)

    describe('entry', function()
        it('remet au propre une ligne de la base (nombres lus en texte)', function()
            local entry = pages.entry({ id = '41', written_at = '1793000000', direction = 2, contact = 'Mage du moulin', body = 'Viens seul.' })
            assert.same({ id = 41, at = 1793000000, direction = 2, contact = 'Mage du moulin', text = 'Viens seul.' }, entry)
            assert.equal('integer', math.type(entry.id))
        end)

        it('refuse une ligne sans numéro valable', function()
            assert.is_nil(pages.entry(nil))
            assert.is_nil(pages.entry('ligne'))
            assert.is_nil(pages.entry({ body = 'x' }))
            assert.is_nil(pages.entry({ id = 0, body = 'x' }))
            assert.is_nil(pages.entry({ id = -3, body = 'x' }))
            assert.is_nil(pages.entry({ id = 0 / 0, body = 'x' }))
            assert.is_nil(pages.entry({ id = math.huge, body = 'x' }))
        end)

        it('rend des textes vides plutôt que « nil » (présence inconnue), une date nulle à défaut', function()
            local entry = pages.entry({ id = 3 })
            assert.equal('', entry.contact)
            assert.equal('', entry.text)
            assert.equal(0, entry.at)
        end)
    end)

    describe('size', function()
        it('compte les octets, pas les signes, plus le poids fixe d’une page', function()
            assert.equal(5 + 4 + pages.ENTRY_OVERHEAD, pages.size({ contact = 'Aline', text = 'abcd' }))
            assert.equal(2 + 4 + pages.ENTRY_OVERHEAD, pages.size({ contact = 'é', text = 'éé' }))
        end)

        it('ne sous-estime jamais une page sérialisée (numéro sur 8 octets, textes les plus longs)', function()
            for _, entry in ipairs({
                { id = math.tointeger(2 ^ 53), at = 0xFFFFFFFF, direction = 2, contact = string.rep('é', 160), text = string.rep('x', murmure.textMaxBytes) },
                { id = 1, at = 0, direction = 1, contact = '', text = '' },
                { id = 70000, at = 1793000000, direction = 1, contact = string.rep('a', 31), text = string.rep('a', 255) },
            }) do
                -- dans une liste : la page n'ajoute que sa table
                assert.is_true(packed(entry) <= pages.size(entry), 'page ' .. entry.id)
            end
        end)
    end)

    describe('take', function()
        it('rend un lot vide sans lignes', function()
            local list, more = pages.take(nil, 20, 7500)
            assert.same({}, list)
            assert.is_false(more)
            list, more = pages.take({}, 20, 7500)
            assert.same({}, list)
            assert.is_false(more)
        end)

        it('garde tout un registre court, sans suite', function()
            local list, more = pages.take(rows(3, 10), 20, 7500)
            assert.equal(3, #list)
            assert.same({ 10, 9, 8 }, { list[1].id, list[2].id, list[3].id })
            assert.is_false(more)
            list, more = pages.take(rows(20, 40), 20, 7500)
            assert.equal(20, #list)
            assert.is_false(more)
        end)

        it('s’arrête au nombre de pages et annonce la suite (une ligne de plus lue)', function()
            local list, more = pages.take(rows(21, 200), 20, 7500)
            assert.equal(20, #list)
            assert.is_true(more)
            assert.equal(181, list[20].id)
        end)

        it('s’arrête avant de dépasser le poids, et annonce la suite', function()
            local body = string.rep('a', 1000 - 6 - pages.ENTRY_OVERHEAD) -- 1 000 octets par page avec 'Aldric'
            local list, more = pages.take(rows(10, 50, 'Aldric', body), 20, 3500)
            assert.equal(3, #list)
            assert.is_true(more)
            list, more = pages.take(rows(3, 50, 'Aldric', body), 20, 3000)
            assert.equal(3, #list)
            assert.is_false(more)
        end)

        it('envoie toujours la première page, même plus lourde que le lot', function()
            local list, more = pages.take(rows(2, 9, 'Aldric', string.rep('x', 5000)), 20, 1000)
            assert.equal(1, #list)
            assert.equal(9, list[1].id)
            assert.is_true(more)
        end)

        it('écarte les lignes abîmées sans perdre la suite', function()
            local list = rows(21, 100)
            list[5].id = nil
            local taken, more = pages.take(list, 20, 7500)
            assert.equal(20, #taken)
            assert.is_true(more)
            for _, entry in ipairs(taken) do assert.is_not_equal(96, entry.id) end
        end)

        it('rend une liste pure, aux pages décroissantes', function()
            local list = pages.take(rows(21, 500), 20, 7500)
            for key in pairs(list) do assert.equal('integer', math.type(key)) end
            for i = 2, #list do assert.is_true(list[i].id < list[i - 1].id) end
        end)
    end)

    describe('cursor', function()
        it('donne la plus ancienne page du lot, nil pour un lot vide', function()
            assert.equal(181, pages.cursor((pages.take(rows(21, 200), 20, 7500))))
            assert.is_nil(pages.cursor({}))
        end)

        it('enchaîne les lots d’un registre plein sans trou ni doublon', function()
            local all = rows(limits.maxPages, 5000)
            local seen, lots, before = {}, 0, nil
            repeat
                local slice = {}
                for _, row in ipairs(all) do
                    if (not before or row.id < before) and #slice <= limits.pageSize then slice[#slice + 1] = row end
                end
                local list, more = pages.take(slice, limits.pageSize, limits.pageBytes)
                for _, entry in ipairs(list) do
                    assert.is_nil(seen[entry.id])
                    seen[entry.id] = true
                end
                before = pages.cursor(list)
                lots = lots + 1
            until not more or lots > limits.maxPages
            local total = 0
            for _ in pairs(seen) do total = total + 1 end
            assert.equal(limits.maxPages, total)
            assert.equal(math.ceil(limits.maxPages / limits.pageSize), lots)
        end)
    end)

    describe('config', function()
        it('borne les lots', function()
            assert.equal('integer', math.type(limits.pageSize))
            assert.is_true(limits.pageSize >= 1 and limits.pageSize <= limits.maxPages)
            assert.is_true(limits.pageBytes >= 1024 and limits.pageBytes < 8 * 1024)
        end)

        it('ouvre un registre plein avec moins de 12 Ko envoyés, quels que soient les murmures', function()
            for _, case in ipairs({
                { contact = 'Aldric', body = 'Au moulin ce soir.' },                                          -- courts
                { contact = string.rep('a', limits.contactMax), body = string.rep('a', 300) },                 -- les plus longs, sans accent
                { contact = string.rep('é', limits.contactMax), body = string.rep('é', 300) },                 -- tout accentué
                { contact = string.rep('😀', limits.contactMax), body = string.rep('x', murmure.textMaxBytes) }, -- au plus lourd
            }) do
                local list, more = pages.take(rows(limits.pageSize + 1, 0x7FFFFFFF, case.contact, case.body), limits.pageSize, limits.pageBytes)
                local payload = { id = 0x7FFFFFFF, pages = list, more = more, count = limits.maxPages, max = limits.maxPages }
                local bytes = packed(payload)
                assert.is_true(#list >= 1)
                assert.is_true(bytes < 12 * 1024, ('%d octets'):format(bytes))
                assert.is_true(bytes <= limits.pageBytes + 64, ('%d octets'):format(bytes))
            end
        end)
    end)
end)
