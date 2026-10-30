local helper = require('tests.helper')

-- Estimation de la taille msgpack (server/core/netsize.lua, core 0.10.0), repli de core.net quand le runtime n'offre
-- pas la sérialisation à part. Les tailles attendues sont celles du format msgpack (fixint, uint8…, fixstr, str8…,
-- fixarray, array16…), les flottants comptés à 9 (float64, majorant).
-- `type` est remplacé pendant le chargement par une doublure qui compte ses appels (une visite par valeur) et nomme
-- `vector3` les tables marquées, comme le runtime FiveM nomme ses vecteurs.
describe('vAvA.netsize', function()
    local netsize, visits, vectors
    local realType = type

    before_each(function()
        helper.reset()
        visits, vectors = 0, setmetatable({}, { __mode = 'k' })
        _G.type = function(value)
            visits = visits + 1
            if vectors[value] then return 'vector3' end
            return realType(value)
        end
        local ok, err = pcall(helper.loadAll, { 'shared/init.lua', 'server/core/netsize.lua' })
        _G.type = realType
        assert(ok, err)
        netsize = vAvA.netsize
    end)

    local LIMIT = 1 << 30

    --- Taille d'une seule valeur passée comme unique argument : en-tête de liste (1) + valeur.
    local function one(value)
        return netsize.args(LIMIT, value) - 1
    end

    it('nil et booléens : 1 octet', function()
        assert.equal(1, one(nil))
        assert.equal(1, one(true))
        assert.equal(1, one(false))
    end)

    it('entiers positifs : 1, 2, 3, 5 ou 9 octets selon leur grandeur', function()
        assert.equal(1, one(0))
        assert.equal(1, one(127))
        assert.equal(2, one(128))
        assert.equal(2, one(255))
        assert.equal(3, one(256))
        assert.equal(3, one(65535))
        assert.equal(5, one(65536))
        assert.equal(5, one(4294967295))
        assert.equal(9, one(1 << 32))
    end)

    it('entiers négatifs : 1, 2, 3, 5 ou 9 octets selon leur grandeur', function()
        assert.equal(1, one(-1))
        assert.equal(1, one(-32))
        assert.equal(2, one(-33))
        assert.equal(2, one(-128))
        assert.equal(3, one(-129))
        assert.equal(3, one(-32768))
        assert.equal(5, one(-32769))
        assert.equal(5, one(-(1 << 31)))
        assert.equal(9, one(-(1 << 31) - 1))
    end)

    it('flottants : 9 octets (majorant)', function()
        assert.equal(9, one(0.5))
        assert.equal(9, one(3.0))
        assert.equal(9, one(-1e300))
    end)

    it('chaînes : 1, 2, 3 ou 5 octets d’en-tête plus la longueur', function()
        assert.equal(1, one(''))
        assert.equal(1 + 31, one(string.rep('a', 31)))
        assert.equal(2 + 32, one(string.rep('a', 32)))
        assert.equal(2 + 255, one(string.rep('a', 255)))
        assert.equal(3 + 256, one(string.rep('a', 256)))
        assert.equal(3 + 65535, one(string.rep('a', 65535)))
        assert.equal(5 + 65536, one(string.rep('a', 65536)))
    end)

    it('listes : en-tête 1 jusqu’à 15 éléments, 3 au-delà', function()
        local fifteen, sixteen = {}, {}
        for i = 1, 15 do fifteen[i] = 1 end
        for i = 1, 16 do sixteen[i] = 1 end
        assert.equal(1 + 15, one(fifteen))
        assert.equal(3 + 16, one(sixteen))
    end)

    it('tables à clés : en-tête 1 jusqu’à 15 paires, 3 au-delà ; table vide : 1', function()
        assert.equal(1, one({}))
        assert.equal(1 + (2 + 1) * 2, one({ a = 1, b = true }))
        local fifteen, sixteen = {}, {}
        for i = 1, 15 do fifteen['k' .. string.char(96 + i)] = 0 end
        for i = 1, 16 do sixteen['k' .. string.char(96 + i)] = 0 end
        assert.equal(1 + 15 * (3 + 1), one(fifteen))
        assert.equal(3 + 16 * (3 + 1), one(sixteen))
    end)

    it('table mixte : comptée comme sa liste (les clés nommées sont perdues à la traversée)', function()
        assert.equal(one({ 'a', 'b' }), one({ 'a', 'b', label = 'perdue' }))
    end)

    it('vecteur3 : 15 octets', function()
        local v = { x = 1.0, y = 2.0, z = 3.0 }
        vectors[v] = true
        assert.equal(15, one(v))
    end)

    it('liste d’arguments : en-tête du nombre de valeurs, nil finaux compris', function()
        assert.equal(1, netsize.args(LIMIT))
        assert.equal(1 + 1 + 1, netsize.args(LIMIT, 1, nil))
        assert.equal(1 + 3 * 1, netsize.args(LIMIT, nil, nil, nil))
        local many = {}
        for i = 1, 16 do many[i] = 0 end
        assert.equal(3 + 16, netsize.args(LIMIT, table.unpack(many, 1, 16)))
    end)

    it('une même table à deux endroits n’est pas un cycle : comptée deux fois', function()
        local shared = { 1, 2, 3 }
        assert.equal(1 + 2 * (1 + 3), one({ shared, shared }))
    end)

    it('refuse un cycle, une profondeur au-delà de 32, une fonction', function()
        local loop = {}
        loop.self = loop
        assert.same({ nil, 'cycle' }, { netsize.args(LIMIT, loop) })
        local function nest(depth)
            local root = {}
            local node = root
            for _ = 2, depth do
                local child = {}
                node[1] = child
                node = child
            end
            return root
        end
        assert.is_number(netsize.args(LIMIT, nest(32)))
        assert.same({ nil, 'depth' }, { netsize.args(LIMIT, nest(33)) })
        assert.same({ nil, 'type' }, { netsize.args(LIMIT, function() end) })
        assert.same({ nil, 'type' }, { netsize.args(LIMIT, { fn = print }) })
    end)

    it('s’arrête dès que la limite est dépassée, sans parcourir le reste', function()
        local list = {}
        for i = 1, 10000 do list[i] = 'chaine-de-vingt-oct' end
        visits = 0
        assert.same({ nil, 'too_large' }, { netsize.args(200, list) })
        assert.is_true(visits < 50, 'visites : ' .. visits)
        assert.same({ nil, 'too_large' }, { netsize.args(10, string.rep('x', 20)) })
        assert.equal(1 + 1 + 20, netsize.args(22, string.rep('x', 20)))
    end)
end)
