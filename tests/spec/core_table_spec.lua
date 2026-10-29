local helper = require('tests.helper')

describe('vAvA.lib.table', function()
    local tbl

    before_each(function()
        helper.reset()
        helper.loadAll({ 'shared/init.lua', 'config/shared.lua', 'shared/lib/table.lua' })
        tbl = vAvA.lib.table
    end)

    describe('copyArray', function()
        it('rend une nouvelle liste aux mêmes éléments, dans le même ordre', function()
            local source = { 'a', 'b', 'c' }
            local copie = tbl.copyArray(source)
            assert.same({ 'a', 'b', 'c' }, copie)
            assert.are_not.equal(source, copie)
        end)

        it('est superficielle : modifier la copie ne touche pas la source, les éléments sont partagés', function()
            local element = { n = 1 }
            local source = { element }
            local copie = tbl.copyArray(source)
            copie[2] = 'ajout'
            assert.equal(1, #source)
            assert.equal(element, copie[1])
        end)

        it('copie une liste vide', function()
            assert.same({}, tbl.copyArray({}))
        end)
    end)

    describe('removeValue', function()
        it('retire la première occurrence et décale la suite', function()
            local list = { 'a', 'b', 'a', 'c' }
            assert.is_true(tbl.removeValue(list, 'a'))
            assert.same({ 'b', 'a', 'c' }, list)
        end)

        it('renvoie false et ne touche à rien quand la valeur est absente', function()
            local list = { 1, 2, 3 }
            assert.is_false(tbl.removeValue(list, 4))
            assert.is_false(tbl.removeValue(list, '1'))
            assert.same({ 1, 2, 3 }, list)
            assert.is_false(tbl.removeValue({}, 1))
        end)

        it('compare par identité pour les tables', function()
            local a, b = { id = 1 }, { id = 1 }
            local list = { a, b }
            assert.is_true(tbl.removeValue(list, b))
            assert.equal(a, list[1])
            assert.equal(1, #list)
        end)
    end)

    describe('sortedKeys', function()
        it('trie les clés par représentation textuelle', function()
            assert.same({ 'ble', 'orge', 'seigle' }, tbl.sortedKeys({ seigle = 1, ble = 2, orge = 3 }))
            -- '1' < '10' < '2' en texte, nombres et chaînes mêlés
            assert.same({ 1, 10, 2, 'a' }, tbl.sortedKeys({ [2] = true, a = true, [10] = true, [1] = true }))
        end)

        it('rend une liste vide pour une table vide', function()
            assert.same({}, tbl.sortedKeys({}))
        end)

        it('donne le même ordre à chaque appel', function()
            local map = {}
            for i = 1, 50 do map['cle' .. i] = i end
            assert.same(tbl.sortedKeys(map), tbl.sortedKeys(map))
        end)
    end)
end)
