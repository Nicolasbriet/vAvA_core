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

-- Géométrie des grilles d'inventaire (modules/vava_inventory/shared/grid.lua). Le module n'a pas de README ; valeurs
-- documentées : docs/api.md (section vava_inventory : objet de `width` × `height` cases, pivotable en jeu) et
-- l'en-tête de grid.lua (coordonnées en cases à partir de 0, origine en haut à gauche ; recherche de place ligne par
-- ligne, d'abord dans le sens normal puis pivoté). Grilles de config.lua : besace 10 × 6, sac au sol 6 × 4.

describe('vava_inventory grid', function()
    local grid, cfg

    before_each(function()
        helper.reset()
        helper.loadAll({
            'modules/vava_inventory/shared/constants.lua',
            'modules/vava_inventory/config.lua',
            'modules/vava_inventory/shared/grid.lua',
        })
        grid = VavaInventory.grid
        cfg = VavaInventory.config
    end)

    local function container(width, height)
        return { width = width, height = height, occupancy = {} }
    end

    local function besace()
        return container(cfg.character.width, cfg.character.height)
    end

    local function count(t)
        local n = 0
        for _ in pairs(t) do n = n + 1 end
        return n
    end

    it('reprend les grilles de la config dans les bornes du protocole', function()
        assert.equal(10, cfg.character.width)
        assert.equal(6, cfg.character.height)
        for _, size in ipairs({ cfg.character, cfg.drop, cfg.catalog }) do
            assert.is_true(size.width <= VavaInventory.MAX_GRID and size.height <= VavaInventory.MAX_GRID)
        end
    end)

    describe('emprise', function()
        it('échange largeur et hauteur quand l’objet est pivoté', function()
            local w, h = grid.footprint({ width = 2, height = 1 }, false)
            assert.equal(2, w)
            assert.equal(1, h)
            w, h = grid.footprint({ width = 2, height = 1 }, true)
            assert.equal(1, w)
            assert.equal(2, h)
        end)
    end)

    describe('fits', function()
        it('accepte un objet qui touche le bord droit ou bas de la grille', function()
            local c = besace()
            assert.is_true(grid.fits(c, 1, 1, 9, 5))
            assert.is_true(grid.fits(c, 10, 6, 0, 0))
            assert.is_true(grid.fits(c, 1, 4, 0, 2))
        end)

        it('refuse un objet qui déborde ou part d’une coordonnée négative', function()
            local c = besace()
            assert.is_false(grid.fits(c, 1, 1, 10, 5))
            assert.is_false(grid.fits(c, 1, 1, 9, 6))
            assert.is_false(grid.fits(c, 2, 1, 9, 0))
            assert.is_false(grid.fits(c, 1, 4, 0, 3))
            assert.is_false(grid.fits(c, 1, 1, -1, 0))
            assert.is_false(grid.fits(c, 1, 1, 0, -1))
            assert.is_false(grid.fits(c, 11, 1, 0, 0))
        end)

        it('refuse de chevaucher un autre objet', function()
            local c = besace()
            grid.mark(c, 2, 2, 2, 1, 7)
            assert.is_false(grid.fits(c, 1, 1, 3, 2))
            assert.is_false(grid.fits(c, 2, 2, 1, 0))
            assert.is_true(grid.fits(c, 1, 1, 4, 1))
            assert.is_true(grid.fits(c, 2, 1, 2, 3))
        end)

        it('ignore l’objet déplacé lui-même (ignoreId), pas les autres', function()
            local c = besace()
            grid.mark(c, 2, 2, 2, 1, 7)
            grid.mark(c, 1, 1, 4, 1, 8)
            assert.is_false(grid.fits(c, 2, 2, 3, 1, 7))                -- toucherait l'objet 8
            assert.is_true(grid.fits(c, 2, 2, 2, 2, 7))                 -- glisse d'une case sur lui-même
            assert.is_false(grid.fits(c, 2, 2, 2, 2, 8))
        end)

        it('refuse une case réservée', function()
            local c = besace()
            local reserved = {}
            grid.reserve(reserved, c, 1, 1, 3, 0)
            assert.is_false(grid.fits(c, 1, 1, 3, 0, nil, reserved))
            assert.is_true(grid.fits(c, 1, 1, 3, 0))
        end)
    end)

    describe('mark, unmark et reserve', function()
        it('numérote les cases ligne par ligne : y × largeur + x', function()
            local c = besace()
            grid.mark(c, 2, 2, 3, 1, 5)
            assert.same({ [13] = 5, [14] = 5, [23] = 5, [24] = 5 }, c.occupancy)
        end)

        it('ne retire que les cases de l’objet visé', function()
            local c = besace()
            grid.mark(c, 2, 1, 0, 0, 1)
            grid.mark(c, 1, 1, 1, 0, 2)                 -- recouvre une case de l'objet 1 (état incohérent simulé)
            grid.unmark(c, 2, 1, 0, 0, 1)
            assert.same({ [1] = 2 }, c.occupancy)
        end)

        it('réserve des cases dans une table à part, sans toucher la grille', function()
            local c = besace()
            local reserved = {}
            grid.reserve(reserved, c, 3, 1, 7, 5)
            assert.same({ [57] = true, [58] = true, [59] = true }, reserved)
            assert.equal(0, count(c.occupancy))
        end)
    end)

    describe('findSpace', function()
        it('rend le coin haut gauche d’une grille vide, sans pivoter', function()
            local x, y, rotated = grid.findSpace(besace(), { width = 2, height = 1 })
            assert.equal(0, x)
            assert.equal(0, y)
            assert.is_false(rotated)
        end)

        it('cherche ligne par ligne, de gauche à droite', function()
            local c = container(4, 3)
            grid.mark(c, 3, 1, 0, 0, 1)                 -- ligne 0 : seule la case 3 reste libre
            local x, y = grid.findSpace(c, { width = 1, height = 1 })
            assert.equal(3, x)
            assert.equal(0, y)
            x, y = grid.findSpace(c, { width = 2, height = 1 })
            assert.equal(0, x)
            assert.equal(1, y)
        end)

        it('préfère le sens normal plus bas au sens pivoté plus haut', function()
            local c = container(4, 4)
            for row = 0, 2 do
                grid.mark(c, 1, 1, 1, row, 10 + row)
                grid.mark(c, 1, 1, 3, row, 20 + row)
            end
            local x, y, rotated = grid.findSpace(c, { width = 2, height = 1 })
            assert.equal(0, x)
            assert.equal(3, y)
            assert.is_false(rotated)
        end)

        it('pivote l’objet quand il ne tient que pivoté', function()
            local c = container(3, 5)
            local x, y, rotated = grid.findSpace(c, { width = 4, height = 1 })
            assert.equal(0, x)
            assert.equal(0, y)
            assert.is_true(rotated)
        end)

        it('rend nil quand l’objet ne tient dans aucun sens (8 × 1 dans un sac au sol de 6 × 4)', function()
            assert.is_nil(grid.findSpace(container(cfg.drop.width, cfg.drop.height), { width = 8, height = 1 }))
        end)

        it('rend nil pour un objet carré qui ne tient pas', function()
            local c = container(3, 3)
            grid.mark(c, 1, 1, 1, 1, 9)
            assert.is_nil(grid.findSpace(c, { width = 2, height = 2 }))
        end)

        it('tient compte des cases réservées', function()
            local c = container(3, 1)
            local reserved = {}
            grid.reserve(reserved, c, 1, 1, 0, 0)
            local x = grid.findSpace(c, { width = 1, height = 1 }, reserved)
            assert.equal(1, x)
        end)

        it('remplit la besace de 60 objets d’une case, pas d’un de plus', function()
            local c = besace()
            local def = { width = 1, height = 1 }
            for id = 1, cfg.character.width * cfg.character.height do
                local x, y, rotated = grid.findSpace(c, def)
                assert.is_number(x, 'objet ' .. id)
                local w, h = grid.footprint(def, rotated)
                grid.mark(c, w, h, x, y, id)
            end
            assert.equal(60, count(c.occupancy))
            assert.is_nil(grid.findSpace(c, def))
        end)

        it('docs/tests/inventaire.md § 3 : dix vestes de cuir (2 × 3) se rangent cinq par rangée sur deux rangées', function()
            local c = besace()
            local veste = { width = 2, height = 3 }
            for id = 1, 10 do
                local x, y, rotated = grid.findSpace(c, veste)
                assert.equal(((id - 1) % 5) * 2, x, 'veste ' .. id)
                assert.equal(id <= 5 and 0 or 3, y, 'veste ' .. id)
                assert.is_false(rotated)
                grid.mark(c, 2, 3, x, y, id)
            end
            assert.equal(60, count(c.occupancy))           -- grille pleine
            assert.is_nil(grid.findSpace(c, veste))         -- onzième veste : pas de place
            assert.is_nil(grid.findSpace(c, { width = 1, height = 1 }))
        end)

        it('place plusieurs objets d’un coup grâce aux réservations, puis refuse le suivant', function()
            local c = besace()
            local reserved = {}
            local half = { width = 5, height = 6 }
            for _ = 1, 2 do
                local x, y, rotated = grid.findSpace(c, half, reserved)
                assert.is_number(x)
                local w, h = grid.footprint(half, rotated)
                grid.reserve(reserved, c, w, h, x, y)
            end
            assert.is_nil(grid.findSpace(c, { width = 1, height = 1 }, reserved))
            assert.equal(0, count(c.occupancy))         -- rien n'est encore marqué
        end)
    end)
end)
