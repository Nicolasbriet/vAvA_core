local helper = require('tests.helper')

-- Retour des piles gardées à part (T-005, I1) : après `restart vava_inventory`, les piles dont l'objet n'était pas
-- encore redéclaré sont gardées à part, puis replacées par grid.planReturn quand la définition revient.
describe('vava_inventory grid.planReturn', function()
    local grid
    local ONE = { width = 1, height = 1 }
    local LOG = { width = 1, height = 2 }   -- bûche : 1 × 2, 2 × 1 pivotée

    local function newGrid(width, height)
        return { width = width, height = height, occupancy = {} }
    end

    local function pile(id, x, y, rotated)
        return { id = id, x = x, y = y, rotated = rotated == true }
    end

    local function count(map)
        local n = 0
        for _ in pairs(map) do n = n + 1 end
        return n
    end

    before_each(function()
        helper.reset()
        VavaInventory = nil
        helper.loadAll({
            'modules/vava_inventory/shared/constants.lua',
            'modules/vava_inventory/shared/grid.lua',
        })
        grid = VavaInventory.grid
    end)

    it('rend sa place d\'origine à une pile dont la place est libre', function()
        local g = newGrid(4, 3)
        local placed, left = grid.planReturn(g, { pile(10, 2, 1) }, ONE)
        assert.equal(1, #placed)
        assert.equal(0, #left)
        assert.same({ x = 2, y = 1, rotated = false, moved = false }, {
            x = placed[1].x, y = placed[1].y, rotated = placed[1].rotated, moved = placed[1].moved,
        })
        assert.equal(10, placed[1].instance.id)
    end)

    it('ne recouvre jamais une pile en place : place d\'origine prise, première place libre', function()
        local g = newGrid(3, 1)
        grid.mark(g, 1, 1, 0, 0, 99)    -- une autre pile occupe la case d'origine
        local placed, left = grid.planReturn(g, { pile(10, 0, 0) }, ONE)
        assert.equal(0, #left)
        assert.equal(1, placed[1].x)
        assert.is_true(placed[1].moved)
        assert.equal(99, g.occupancy[0])
    end)

    it('ne donne jamais la place d\'origine d\'une pile à une autre replacée ailleurs', function()
        -- B (la plus ancienne) a perdu sa place ; la première place libre est celle d'origine de A
        local g = newGrid(3, 1)
        grid.mark(g, 1, 1, 1, 0, 99)
        local b, a = pile(5, 1, 0), pile(6, 0, 0)
        local placed, left = grid.planReturn(g, { b, a }, ONE)
        assert.equal(0, #left)
        local at = {}
        for _, entry in ipairs(placed) do at[entry.instance.id] = entry end
        assert.equal(0, at[6].x)
        assert.is_false(at[6].moved)
        assert.equal(2, at[5].x)
        assert.is_true(at[5].moved)
    end)

    it('deux piles sur la même place d\'origine : la première la garde, la seconde va ailleurs', function()
        local g = newGrid(2, 1)
        local placed, left = grid.planReturn(g, { pile(1, 0, 0), pile(2, 0, 0) }, ONE)
        assert.equal(0, #left)
        assert.equal(0, placed[1].x)
        assert.is_false(placed[1].moved)
        assert.equal(1, placed[2].x)
        assert.is_true(placed[2].moved)
    end)

    it('garde le sens d\'une pile pivotée à sa place d\'origine', function()
        local g = newGrid(3, 2)
        local placed = grid.planReturn(g, { pile(1, 1, 1, true) }, LOG)
        assert.is_true(placed[1].rotated)
        assert.equal(1, placed[1].x)
        assert.equal(1, placed[1].y)
        assert.is_false(placed[1].moved)
    end)

    it('place hors d\'une grille réduite : replacée dans la grille', function()
        local g = newGrid(2, 2)
        local placed, left = grid.planReturn(g, { pile(1, 5, 5) }, ONE)
        assert.equal(0, #left)
        assert.is_true(placed[1].moved)
        assert.is_true(placed[1].x < 2 and placed[1].y < 2)
    end)

    it('sans place : la pile reste à part, dans l\'ordre reçu', function()
        local g = newGrid(2, 1)
        grid.mark(g, 1, 1, 0, 0, 98)
        local placed, left = grid.planReturn(g, { pile(1, 0, 0), pile(2, 0, 0), pile(3, 0, 0) }, ONE)
        assert.equal(1, #placed)
        assert.equal(1, placed[1].instance.id)
        assert.equal(1, placed[1].x)
        assert.equal(2, #left)
        assert.equal(2, left[1].id)
        assert.equal(3, left[2].id)
    end)

    it('après une première recherche vaine, les piles restantes vont à part sans nouvelle recherche', function()
        local g = newGrid(3, 1)
        grid.mark(g, 1, 1, 0, 0, 97)
        local searches = 0
        local findSpace = grid.findSpace
        grid.findSpace = function(...)
            searches = searches + 1
            return findSpace(...)
        end
        -- place d'origine prise pour toutes : la première trouve (1,0), la deuxième (2,0), puis plus rien
        local list = {}
        for id = 1, 50 do list[id] = pile(id, 0, 0) end
        local placed, left = grid.planReturn(g, list, ONE)
        grid.findSpace = findSpace
        assert.equal(2, #placed)
        assert.equal(48, #left)
        assert.equal(3, left[1].id)
        assert.equal(50, left[48].id)
        assert.equal(3, searches)
    end)

    it('ne modifie ni la grille ni les piles', function()
        local g = newGrid(3, 3)
        grid.mark(g, 1, 1, 0, 0, 99)
        local instance = pile(1, 0, 0)
        grid.planReturn(g, { instance }, ONE)
        assert.equal(1, count(g.occupancy))
        assert.equal(0, instance.x)
        assert.equal(0, instance.y)
    end)

    it('les places rendues ne se chevauchent pas et évitent les piles en place', function()
        local g = newGrid(4, 4)
        grid.mark(g, 2, 2, 1, 1, 99)
        local list = {}
        for id = 1, 8 do list[id] = pile(id, 1, 1) end
        local placed = grid.planReturn(g, list, LOG)
        local taken = {}
        for index in pairs(g.occupancy) do taken[index] = 99 end
        for _, entry in ipairs(placed) do
            local w, h = grid.footprint(LOG, entry.rotated)
            for dy = 0, h - 1 do
                for dx = 0, w - 1 do
                    local index = (entry.y + dy) * g.width + entry.x + dx
                    assert.is_nil(taken[index])
                    taken[index] = entry.instance.id
                end
            end
        end
        assert.is_true(#placed >= 1)
    end)
end)
