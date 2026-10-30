local helper = require('tests.helper')

-- Grille des zones (server/core/zonegrid.lua, core 0.11.0, T-014) : cases, inscription, retrait, déplacement, candidats.
describe('vAvA.zonegrid', function()
    local grid

    before_each(function()
        helper.reset()
        helper.load('shared/init.lua')
        helper.load('server/core/zonegrid.lua')
        grid = vAvA.zonegrid.new(256.0)
    end)

    local function cell(x, y)
        return { grid:cellOf(x, y) }
    end

    it('case d’un point : bords et négatifs', function()
        assert.same({ 0, 0 }, cell(0, 0))
        assert.same({ 0, 0 }, cell(255.9, 0))
        assert.same({ 1, 0 }, cell(256, 0))
        assert.same({ -1, -1 }, cell(-0.1, -0.1))
        assert.same({ -1, 0 }, cell(-256, 0))
        assert.same({ -2, 0 }, cell(-256.1, 0))
    end)

    it('une zone de portée 300 en (0, 0) est inscrite dans les 16 cases −2..1 × −2..1', function()
        grid:insert(1, 0, 0, 300)
        local inside = 0
        for cx = -2, 1 do
            for cy = -2, 1 do
                local set = grid:candidates(cx * 256 + 1, cy * 256 + 1)
                assert.is_true(set[1], ('case %d, %d'):format(cx, cy))
                inside = inside + 1
            end
        end
        assert.equal(16, inside)
        assert.equal(16, grid:cellCount())
        assert.is_nil(grid:candidates(3 * 256 + 1, 3 * 256 + 1)[1])
        assert.is_nil(grid:candidates(2 * 256 + 1, 0)[1])
        assert.is_nil(grid:candidates(-3 * 256 + 1, 0)[1])
    end)

    it('remove la retire de toutes ses cases ; une case vidée est oubliée', function()
        grid:insert(1, 0, 0, 300)
        grid:remove(1)
        assert.equal(0, grid:cellCount())
        assert.is_nil(grid:candidates(128, 128)[1])
        -- retirer une zone absente ne fait rien
        grid:remove(1)
        grid:remove(42)
    end)

    it('move : anciennes cases vidées, nouvelles remplies', function()
        grid:insert(1, 128, 128, 10)
        grid:move(1, 5000, 5000, 10)
        assert.is_nil(grid:candidates(128, 128)[1])
        assert.is_true(grid:candidates(5000, 5000)[1])
        assert.equal(1, grid:cellCount())
        -- insert d'une zone déjà inscrite : déplacée, pas dupliquée
        grid:insert(1, 128, 128, 10)
        assert.is_nil(grid:candidates(5000, 5000)[1])
        assert.equal(1, grid:cellCount())
    end)

    it('deux zones dans la même case rendues toutes deux, sans doublon', function()
        grid:insert(1, 10, 10, 5)
        grid:insert(2, 20, 20, 5)
        local found = {}
        for handle in pairs(grid:candidates(15, 15)) do found[#found + 1] = handle end
        table.sort(found)
        assert.same({ 1, 2 }, found)
        grid:remove(1)
        found = {}
        for handle in pairs(grid:candidates(15, 15)) do found[#found + 1] = handle end
        assert.same({ 2 }, found)
    end)

    it('case vide : un ensemble vide qu’on ne peut pas remplir', function()
        local set = grid:candidates(100, 100)
        assert.is_nil(next(set))
        set[3] = true
        assert.is_nil(grid:candidates(100, 100)[3])
    end)

    it('coordonnées à ±50 000 : clés entières, valides et distinctes', function()
        local keys = {}
        for _, point in ipairs({ { 50000, 50000 }, { -50000, 50000 }, { 50000, -50000 }, { -50000, -50000 },
            { 0, 0 }, { 50000, 0 }, { 0, 50000 }, { -50000, 0 }, { 0, -50000 } }) do
            local key = grid:keyOf(point[1], point[2])
            assert.equal('integer', math.type(key))
            assert.is_nil(keys[key])
            keys[key] = true
        end
        grid:insert(7, -50000, 50000, 1000)
        assert.is_true(grid:candidates(-50000, 50000)[7])
        assert.is_true(grid:candidates(-49001, 49001)[7])
    end)
end)
