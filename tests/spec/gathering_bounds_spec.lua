local helper = require('tests.helper')

-- Bornes d'une zone du core vérifiées à l'indexation (modules/vava_gathering/server/catalog.lua, T-015 reprise) et
-- publication des charges d'une récolte avec sa zone (server/nodes.lua). Règles documentées : README du module (« Ce
-- qui part chez les joueurs ») :
--   une zone dont les nœuds sont à plus de 500 m de son centre, qui a plus de 255 nœuds, ou une marge (portée des
--   props + jeu) de plus de 500 m refuse le module avec la zone en cause ; une charge prise par une récolte n'est
--   publiée qu'à sa fin (avec la zone), et une charge prise puis rendue ne fait rien partir.

describe('vava_gathering bornes des zones du core', function()
    local cfg

    before_each(function()
        helper.reset()
        VavaGathering = nil
        helper.loadAll({
            'modules/vava_gathering/shared/constants.lua',
            'modules/vava_gathering/config.lua',
            'modules/vava_gathering/shared/zonestate.lua',
        })
        VavaGathering.resource = 'vava_gathering'
        VavaGathering.log = { warn = function() end }
        VavaGathering.core = {
            registry = { define = function() return true end, add = function() return true end, all = function() return {} end },
            hooks = { after = function() return 1 end },
        }
        VavaGathering.bridge = { DeclareItem = function() end, ItemExists = function() return true end }
        cfg = VavaGathering.config
    end)

    local function define()
        helper.load('modules/vava_gathering/server/catalog.lua')
        return VavaGathering.catalog.define()
    end

    ---@param zone string
    ---@param count integer
    local function addNodes(zone, count)
        for i = 1, count do
            cfg.nodes[#cfg.nodes + 1] = {
                id = zone .. '_essai_' .. i, zone = zone, resource = 'chene', x = -320.0, y = -880.0, z = 31.0,
                charges = 1, prop = { model = 'prop_tree_oak_01' },
            }
        end
    end

    it('accepte la config livrée', function()
        assert.is_true(define())
    end)

    it('refuse une zone dont un nœud est à plus de 500 m du centre', function()
        cfg.nodes[1].x = cfg.zones[1].x + 501.0
        local ok, err = define()
        assert.is_false(ok)
        assert.truthy(err:find("zone 'foret_brume'", 1, true))
        assert.truthy(err:find('500 m au plus', 1, true))
    end)

    it('accepte 255 nœuds dans une zone et en refuse 256', function()
        local own = 0
        for _, node in ipairs(cfg.nodes) do
            if node.zone == 'foret_brume' then own = own + 1 end
        end
        addNodes('foret_brume', 255 - own)
        assert.is_true(define())
        cfg.nodes[#cfg.nodes + 1] = {
            id = 'foret_brume_essai_de_trop', zone = 'foret_brume', resource = 'chene', x = -320.0, y = -880.0, z = 31.0,
            charges = 1, prop = { model = 'prop_tree_oak_01' },
        }
        local ok, err = define()
        assert.is_false(ok)
        assert.truthy(err:find('256 nœuds, 255 au plus', 1, true))
    end)

    it('refuse une marge de plus de 500 m', function()
        cfg.streaming.subscribeSlack = 421.0
        local ok, err = define()
        assert.is_false(ok)
        assert.truthy(err:find('subscribeSlack', 1, true))
    end)

    it('refuse une zone sans position', function()
        cfg.zones[2].y = nil
        local ok, err = define()
        assert.is_false(ok)
        assert.truthy(err:find("zone 'mine_du_val' : x, y, z requis", 1, true))
    end)
end)

describe('vava_gathering charges publiées à la fin d’une récolte', function()
    local nodes, sets, DEF

    before_each(function()
        helper.reset()
        VavaGathering = nil
        helper.loadAll({
            'modules/vava_gathering/shared/constants.lua',
            'modules/vava_gathering/config.lua',
            'modules/vava_gathering/shared/zonestate.lua',
        })
        sets = {}
        DEF = { id = 'chene_1', zone = { id = 'foret_brume' }, charges = 3, regenMs = 600000, resource = { skill = 'bucheronnage' } }
        VavaGathering.bridge = {
            SeasonFactor = function() return 1 end,
            Integer = function(value, default) return math.tointeger(value) or default end,
            db = { query = function() return {} end },
        }
        VavaGathering.catalog = { nodes = function() return { chene_1 = DEF } end }
        VavaGathering.share = { set = function(zone, key, value) sets[#sets + 1] = { zone, key, value } end }
        helper.load('modules/vava_gathering/server/nodes.lua')
        nodes = VavaGathering.nodes
        assert.is_true(nodes.load())
        nodes.tick()
        sets = {}
    end)

    it('ne publie rien pendant la récolte, puis une seule fois à la fin', function()
        assert.is_true(nodes.consume(DEF, true))
        assert.same({}, sets)
        nodes.flush(DEF)
        assert.same({ { 'foret_brume', 'n:chene_1', 2 } }, sets)
        nodes.flush(DEF)
        assert.equal(1, #sets)
    end)

    it('ne publie rien pour une charge prise puis rendue (besace pleine)', function()
        assert.is_true(nodes.consume(DEF, true))
        nodes.restore(DEF, true)
        nodes.flush(DEF)
        assert.same({}, sets)
    end)

    it('publie aussitôt sans report (Conseil, autres appels)', function()
        assert.is_true(nodes.consume(DEF))
        assert.same({ { 'foret_brume', 'n:chene_1', 2 } }, sets)
        nodes.restore(DEF)
        assert.same({ 'foret_brume', 'n:chene_1', 3 }, sets[2])
    end)
end)
