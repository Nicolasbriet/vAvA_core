local helper = require('tests.helper')

-- Taille d'une valeur une fois sérialisée en msgpack (même règle que tests/spec/codex_fingerprint_spec.lua).
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
    local count = 0
    for _ in pairs(value) do count = count + 1 end
    local isList = count == #value
    local size = count < 16 and 1 or 3
    for key, item in pairs(value) do size = size + msgpackSize(item) + (isList and 0 or msgpackSize(key)) end
    return size
end

-- Bornes d'une zone du core vérifiées à l'indexation (modules/vava_gathering/server/catalog.lua, T-015 reprise) et
-- publication des charges d'une récolte avec sa zone (server/nodes.lua). Règles documentées : README du module (« Ce
-- qui part chez les joueurs ») :
--   une zone dont les nœuds sont à plus de 500 m de son centre, qui a plus de 120 nœuds (1.8.0, T-102 : deux clés
--   d'état par point, `p:` et `n:`, plus `zone` et `def`, 256 clés au plus par zone du core ; 255 avant 1.8.0, une
--   clé par nœud), ou une marge (portée des props + jeu) de plus de 500 m refuse le module avec la zone en cause ; une
--   charge prise par une récolte n'est publiée qu'à sa fin (avec la zone), et une charge prise puis rendue ne fait
--   rien partir.

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

    -- T-102 : la borne passe de 255 à 120 nœuds (deux clés d'état par point) ; l'essai garde la frontière exacte
    it('accepte 120 nœuds dans une zone et en refuse 121', function()
        local own = 0
        for _, node in ipairs(cfg.nodes) do
            if node.zone == 'foret_brume' then own = own + 1 end
        end
        addNodes('foret_brume', 120 - own)
        assert.is_true(define())
        cfg.nodes[#cfg.nodes + 1] = {
            id = 'foret_brume_essai_de_trop', zone = 'foret_brume', resource = 'chene', x = -320.0, y = -880.0, z = 31.0,
            charges = 1, prop = { model = 'prop_tree_oak_01' },
        }
        local ok, err = define()
        assert.is_false(ok)
        assert.truthy(err:find('121 nœuds, 120 au plus', 1, true))
    end)

    it('tient les clés d’une zone de 120 points dans les 256 du core, réglage de l’atelier compris', function()
        assert.equal(120, VavaGathering.ZONE_MAX_NODES)
        assert.equal(VavaGathering.ZONE_MAX_NODES, cfg.editor.maxNodesPerZone)
        -- `zone`, `def`, puis `p:` et `n:` par point
        assert.is_true(2 + 2 * VavaGathering.ZONE_MAX_NODES <= 256)
    end)

    it('tient l’état d’une zone de 120 points aux identifiants les plus longs sous les 32 Ko du core', function()
        local zonestate = VavaGathering.zonestate
        local zone = { id = 'z', label = string.rep('é', 40), kind = 'prairie', x = -12345.678, y = 23456.789,
            z = 123.456, radius = 300.0 }
        local list = {}
        for i = 1, VavaGathering.ZONE_MAX_NODES do
            list[i] = { id = string.format('%s%03d', string.rep('n', VavaGathering.MAX_NODE_ID - 3), i),
                resource = 'piste_lievre', x = -12345.678 + i, y = 23456.789 - i, z = 123.456, heading = 359.9 }
        end
        local state = zonestate.build({ band = 'reduced', scarred = true }, list, function() return 20 end, zone)
        local keys = 0
        for key in pairs(state) do
            keys = keys + 1
            assert.is_true(#key <= 48, key)
        end
        assert.equal(2 + 2 * VavaGathering.ZONE_MAX_NODES, keys)
        -- pire des cas (identifiants de 46 octets, nombres flottants partout) : ≈ 19 Ko, latent au-delà de 8 Ko
        local size = msgpackSize(state)
        assert.is_true(size < 32 * 1024, tostring(size))
        -- cas courant de la spec (§ 5.4 : identifiants de 7 octets) : ≈ 9 Ko pour 120 points
        local short = {}
        for i = 1, VavaGathering.ZONE_MAX_NODES do
            short[i] = { id = string.format('pt_%03d', i), resource = 'chene', x = -320.5 + i, y = -880.25 - i,
                z = 31.0, heading = 90.0 }
        end
        local typical = msgpackSize(zonestate.build({ band = 'normal', scarred = false }, short, function() return 3 end,
            { label = 'Forêt de Brume', kind = 'foret', x = -320.0, y = -880.0, z = 31.0, radius = 120.0 }))
        assert.is_true(typical > 8 * 1024 and typical < 10 * 1024, tostring(typical))
    end)

    it('tient un identifiant de point de 46 octets dans les clés `p:` et `n:` de 48', function()
        local zonestate = VavaGathering.zonestate
        local id = string.rep('a', VavaGathering.MAX_NODE_ID)
        assert.equal(48, #zonestate.placeKey(id))
        assert.equal(48, #zonestate.nodeKey(id))
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
