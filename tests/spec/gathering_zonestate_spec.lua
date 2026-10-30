local helper = require('tests.helper')

-- État d'une zone de récolte tenu par les abonnements de zone du core (modules/vava_gathering/shared/zonestate.lua,
-- 1.6.0, T-015). Règles documentées : README du module (« Zones et nœuds ») et spec T-014 § 13.2 :
--   une zone du core par zone de récolte ; centre de la zone, rayon = la plus grande distance au sol entre ce centre et
--   ses nœuds, au moins le rayon de la zone ; marge = portée des props (80 m) + streaming.subscribeSlack (20 m) ;
--   état `zone` → { band, scarred } (jamais la vitalité) et `n:<nœud>` → charges ; clés de 48 octets au plus.

describe('vava_gathering zonestate', function()
    local zonestate, cfg

    before_each(function()
        helper.reset()
        helper.loadAll({
            'modules/vava_gathering/shared/constants.lua',
            'modules/vava_gathering/config.lua',
            'modules/vava_gathering/shared/zonestate.lua',
        })
        zonestate = VavaGathering.zonestate
        cfg = VavaGathering.config
    end)

    describe('clés', function()
        it('fait la clé d’un nœud et la relit', function()
            assert.equal('n:foret_brume_chene_1', zonestate.nodeKey('foret_brume_chene_1'))
            assert.equal('foret_brume_chene_1', zonestate.nodeOf('n:foret_brume_chene_1'))
        end)

        it('ne lit aucun nœud dans la clé de la zone ni dans une clé mal formée', function()
            assert.is_nil(zonestate.nodeOf('zone'))
            assert.is_nil(zonestate.nodeOf('n:'))
            assert.is_nil(zonestate.nodeOf('x:chene'))
            assert.is_nil(zonestate.nodeOf(12))
            assert.is_nil(zonestate.nodeOf(nil))
        end)

        it('tient une clé de nœud dans les 48 octets du core pour l’identifiant le plus long permis', function()
            assert.equal(46, VavaGathering.MAX_NODE_ID)
            assert.equal(48, #zonestate.nodeKey(string.rep('a', VavaGathering.MAX_NODE_ID)))
        end)

        it('donne à chaque nœud et à chaque zone de la config un identifiant permis par le core', function()
            for _, zone in ipairs(cfg.zones) do
                assert.is_true(#zone.id <= VavaGathering.MAX_ZONE_ID, zone.id)
                assert.is_truthy(zone.id:find('^[%w_%-%.:]+$'), zone.id)
            end
            for _, node in ipairs(cfg.nodes) do
                local key = zonestate.nodeKey(node.id)
                assert.is_true(#key <= 48, key)
                assert.is_truthy(key:find('^[%w_%-%.:]+$'), key)
            end
        end)
    end)

    describe('valeur publiée d’une zone', function()
        it('ne porte que la bande et la cicatrice, jamais la vitalité', function()
            local value = zonestate.zoneValue('reduced', true)
            assert.same({ band = 'reduced', scarred = true }, value)
            assert.is_nil(value.vitality)
        end)

        it('rend la cicatrice booléenne', function()
            assert.is_false(zonestate.zoneValue('normal', nil).scarred)
            assert.is_false(zonestate.zoneValue('normal', 1).scarred)
        end)

        it('compare deux valeurs : la même bande et la même cicatrice ne font rien partir', function()
            assert.is_true(zonestate.sameZone({ band = 'normal', scarred = false }, { band = 'normal', scarred = false }))
            assert.is_false(zonestate.sameZone({ band = 'normal', scarred = false }, { band = 'reduced', scarred = false }))
            assert.is_false(zonestate.sameZone({ band = 'depleted', scarred = false }, { band = 'depleted', scarred = true }))
            assert.is_false(zonestate.sameZone(nil, { band = 'normal', scarred = false }))
        end)
    end)

    describe('cercle de la zone du core', function()
        local zone = { x = -320.0, y = -880.0, z = 31.0, radius = 120.0 }

        it('garde le rayon de la zone quand tous ses nœuds sont dedans', function()
            local area = zonestate.area(zone, { { x = -300.0, y = -900.0, z = 31.0 } }, 100.0)
            assert.same({ x = -320.0, y = -880.0, z = 31.0, radius = 120.0, margin = 100.0 }, area)
        end)

        it('s’élargit jusqu’au nœud le plus éloigné, mesuré au sol', function()
            local area = zonestate.area(zone, { { x = -320.0, y = -730.0, z = 31.0 }, { x = -170.0, y = -880.0, z = 31.0 } }, 100.0)
            assert.equal(150.0, area.radius)
        end)

        it('ignore la hauteur (un nœud au-dessus du centre ne l’élargit pas)', function()
            local area = zonestate.area(zone, { { x = -320.0, y = -880.0, z = 531.0 } }, 100.0)
            assert.equal(120.0, area.radius)
        end)

        it('ignore un nœud sans position finie', function()
            local area = zonestate.area(zone, { { x = 0 / 0, y = 0.0 }, { x = math.huge, y = 0.0 } }, 100.0)
            assert.equal(120.0, area.radius)
        end)

        it('rend un rayon nul pour une zone sans rayon valide ni nœud (le core la refusera)', function()
            assert.equal(0.0, zonestate.area({ x = 0.0, y = 0.0, z = 0.0, radius = -5 }, {}, 100.0).radius)
        end)

        it('reste dans les bornes du core pour chaque zone de la config, nœuds compris', function()
            local margin = cfg.streaming.radius + cfg.streaming.subscribeSlack
            assert.equal(100.0, margin)
            for _, def in ipairs(cfg.zones) do
                local nodes = {}
                for _, node in ipairs(cfg.nodes) do
                    if node.zone == def.id then nodes[#nodes + 1] = node end
                end
                local area = zonestate.area(def, nodes, margin)
                assert.is_true(area.radius > 0 and area.radius <= 500, def.id)
                for _, node in ipairs(nodes) do
                    local dx, dy = node.x - def.x, node.y - def.y
                    assert.is_true(math.sqrt(dx * dx + dy * dy) <= area.radius + 1e-9, node.id)
                end
            end
        end)

        it('reçoit l’état avant les props : un nœud à portée des props est toujours dans le cercle d’intérêt', function()
            local margin = cfg.streaming.radius + cfg.streaming.subscribeSlack
            local area = zonestate.area(zone, { { x = -320.0, y = -730.0, z = 31.0 } }, margin)
            -- joueur à 80 m du nœud le plus éloigné, dans l'axe : à 230 m du centre, intérêt jusqu'à 250 m
            local distance = 150.0 + cfg.streaming.radius
            assert.is_true(distance <= area.radius + area.margin)
            assert.equal(cfg.streaming.subscribeSlack, area.radius + area.margin - distance)
        end)
    end)

    describe('état entier', function()
        it('porte la zone et les charges de chaque nœud, à clés chaînes seulement', function()
            local nodes = { { id = 'chene_1' }, { id = 'pin_1' } }
            local charges = { chene_1 = 3, pin_1 = 0 }
            local state = zonestate.build({ band = 'normal', scarred = false }, nodes, function(node) return charges[node.id] end)
            assert.same({ zone = { band = 'normal', scarred = false }, ['n:chene_1'] = 3, ['n:pin_1'] = 0 }, state)
            for key in pairs(state) do assert.equal('string', type(key)) end
        end)

        it('omet un nœud dont les charges ne sont pas encore connues', function()
            local state = zonestate.build({ band = 'reduced', scarred = false }, { { id = 'chene_1' } }, function() return nil end)
            assert.same({ zone = { band = 'reduced', scarred = false } }, state)
        end)

        it('copie la valeur de la zone (l’état gardé par le core ne la partage pas)', function()
            local value = { band = 'normal', scarred = false }
            local state = zonestate.build(value, {}, function() return nil end)
            value.band = 'depleted'
            assert.equal('normal', state.zone.band)
        end)
    end)

    describe('client : état reçu', function()
        it('lit la zone et les charges', function()
            local record = zonestate.decode({ zone = { band = 'depleted', scarred = true }, ['n:chene_1'] = 2, ['n:pin_1'] = 0 })
            assert.same({ band = 'depleted', scarred = true }, record.zone)
            assert.same({ chene_1 = 2, pin_1 = 0 }, record.charges)
        end)

        it('rend des valeurs par défaut pour un état absent ou mal formé', function()
            assert.same({ zone = nil, charges = {} }, zonestate.decode(nil))
            assert.same({ zone = nil, charges = {} }, zonestate.decode('zone'))
            local record = zonestate.decode({ zone = 'normal', ['n:a'] = -1, ['n:b'] = 1.5, ['n:c'] = '3', ['n:d'] = 0 / 0 })
            assert.is_nil(record.zone)
            assert.same({}, record.charges)
        end)

        it('ramène une bande inconnue à la pleine et une cicatrice non booléenne à faux', function()
            local record = zonestate.decode({ zone = { band = 'brulee', scarred = 'oui' } })
            assert.same({ band = 'normal', scarred = false }, record.zone)
        end)

        it('accepte des charges entières écrites en flottant', function()
            local record = zonestate.decode({ ['n:a'] = 3.0 })
            assert.equal(3, record.charges.a)
            assert.equal('integer', math.type(record.charges.a))
        end)

        it('ignore les clés inconnues et ne garde jamais la vitalité', function()
            local record = zonestate.decode({ zone = { band = 'normal', scarred = false, vitality = 73 }, autre = 1 })
            assert.same({ band = 'normal', scarred = false }, record.zone)
            assert.same({}, record.charges)
        end)
    end)

    describe('client : différence reçue', function()
        local function followed()
            return zonestate.decode({ zone = { band = 'normal', scarred = false }, ['n:chene_1'] = 3, ['n:pin_1'] = 4 })
        end

        it('applique une récolte : bande et charges dans la même différence', function()
            local record = zonestate.patch(followed(), { zone = { band = 'reduced', scarred = false }, ['n:chene_1'] = 2 }, {})
            assert.same({ band = 'reduced', scarred = false }, record.zone)
            assert.same({ chene_1 = 2, pin_1 = 4 }, record.charges)
        end)

        it('retire une clé : la zone et le nœud reviennent à leurs valeurs par défaut', function()
            local record = zonestate.patch(followed(), {}, { 'zone', 'n:pin_1', 'n:inconnu', 'autre' })
            assert.is_nil(record.zone)
            assert.same({ chene_1 = 3 }, record.charges)
        end)

        it('retire une charge mal formée plutôt que de garder une valeur fausse', function()
            local record = zonestate.patch(followed(), { ['n:chene_1'] = -2 }, nil)
            assert.is_nil(record.charges.chene_1)
        end)

        it('ignore une différence vide ou mal formée', function()
            local record = zonestate.patch(followed(), nil, 'zone')
            assert.same(followed(), record)
        end)
    end)
end)
