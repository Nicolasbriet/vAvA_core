local helper = require('tests.helper')

-- État d'une zone de récolte tenu par les abonnements de zone du core (modules/vava_gathering/shared/zonestate.lua,
-- 1.6.0, T-015). Règles documentées : README du module (« Zones et nœuds ») et spec T-014 § 13.2 :
--   une zone du core par zone de récolte ; centre de la zone, rayon = la plus grande distance au sol entre ce centre et
--   ses nœuds, au moins le rayon de la zone ; marge = portée des props (80 m) + streaming.subscribeSlack (20 m) ;
--   état `zone` → { band, scarred } (jamais la vitalité) et `n:<nœud>` → charges ; clés de 48 octets au plus.
--   T-102 (1.8.0, spec § 5.4) : aussi `def` → { l, k, x, y, z, r } (nom, type, lieu de la zone) et `p:<nœud>` → { r, x,
--   y, z, h } (ressource et lieu d'un point) ; ni coût, ni repos, ni charges maximales, ni repousse, ni nom d'un point ;
--   120 points au plus côté client ; différences par clés changées et retirées, en paquets de 64 ; essai de l'Atelier
--   (au seul auteur) et liste de la carte gardée en stockage local.

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

        -- T-102 : l'enregistrement porte aussi `def`, `nodes` et `count` (lieux des points) ; mêmes valeurs par défaut
        it('rend des valeurs par défaut pour un état absent ou mal formé', function()
            local empty = { zone = nil, charges = {}, def = nil, nodes = {}, count = 0 }
            assert.same(empty, zonestate.decode(nil))
            assert.same(empty, zonestate.decode('zone'))
            local record = zonestate.decode({ zone = 'normal', ['n:a'] = -1, ['n:b'] = 1.5, ['n:c'] = '3', ['n:d'] = 0 / 0,
                def = 'foret', ['p:a'] = 'chene' })
            assert.is_nil(record.zone)
            assert.same({}, record.charges)
            assert.is_nil(record.def)
            assert.same({}, record.nodes)
            assert.equal(0, record.count)
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

    -- T-102 ---------------------------------------------------------------------------------------------------------

    local ZONE = { id = 'bois', label = 'Bois des Essais', kind = 'foret', x = 10.0, y = 20.0, z = 30.0, radius = 60.0,
        cost = 2.0, regenPerHour = 4.0, scarHours = 48 }
    local function node(id, x, y, extra)
        local out = { id = id, resource = 'chene', x = x, y = y, z = 30.0, heading = 90.0, charges = 3, regenMs = 600000,
            label = 'Chêne' }
        for key, value in pairs(extra or {}) do out[key] = value end
        return out
    end

    describe('état entier avec la zone et ses points (T-102)', function()
        it('porte `def` et `p:` de chaque point, sans rien de la part serveur', function()
            local state = zonestate.build({ band = 'normal', scarred = false }, { node('chene_1', 11.0, 21.0) },
                function() return 3 end, ZONE)
            assert.same({ l = 'Bois des Essais', k = 'foret', x = 10.0, y = 20.0, z = 30.0, r = 60.0 }, state.def)
            assert.same({ r = 'chene', x = 11.0, y = 21.0, z = 30.0, h = 90.0 }, state['p:chene_1'])
            assert.equal(3, state['n:chene_1'])
            for _, value in pairs(state) do
                if type(value) == 'table' then
                    for _, forbidden in ipairs({ 'cost', 'regenPerHour', 'scarHours', 'charges', 'regenMs', 'label', 'vitality' }) do
                        assert.is_nil(value[forbidden], forbidden)
                    end
                end
            end
        end)

        it('lit la ressource d’un point du catalogue (définition) par son identifiant', function()
            local value = zonestate.placeValue({ resource = { id = 'pin' }, x = 1.0, y = 2.0, z = 3.0 })
            assert.same({ r = 'pin', x = 1.0, y = 2.0, z = 3.0, h = 0.0 }, value)
        end)

        it('sans définition de zone, garde la forme d’avant 1.8.0 (ni `def` ni `p:`)', function()
            local state = zonestate.build({ band = 'normal', scarred = false }, { node('chene_1', 11.0, 21.0) },
                function() return 3 end)
            assert.is_nil(state.def)
            assert.is_nil(state['p:chene_1'])
        end)

        it('fait la clé de lieu d’un point et la relit', function()
            assert.equal('p:chene_1', zonestate.placeKey('chene_1'))
            assert.equal('chene_1', zonestate.placeOf('p:chene_1'))
            assert.is_nil(zonestate.placeOf('n:chene_1'))
            assert.is_nil(zonestate.placeOf('p:'))
            assert.is_nil(zonestate.nodeOf('p:chene_1'))
        end)
    end)

    describe('client : `def` et `p:` reçus (T-102)', function()
        local function full()
            return zonestate.build({ band = 'normal', scarred = false },
                { node('chene_1', 11.0, 21.0), node('chene_2', 14.0, 21.0) }, function() return 3 end, ZONE)
        end

        it('lit la zone, ses points et leurs charges', function()
            local record = zonestate.decode(full())
            assert.same({ label = 'Bois des Essais', kind = 'foret', x = 10.0, y = 20.0, z = 30.0, radius = 60.0 }, record.def)
            assert.same({ resource = 'chene', x = 11.0, y = 21.0, z = 30.0, heading = 90.0 }, record.nodes.chene_1)
            assert.equal(2, record.count)
            assert.same({ chene_1 = 3, chene_2 = 3 }, record.charges)
        end)

        it('ignore une `def` mal formée (nom vide ou trop long, type invalide, lieu non fini, rayon hors bornes)', function()
            local bad = {
                { l = '', k = 'foret', x = 0.0, y = 0.0, z = 0.0, r = 10.0 },
                { l = string.rep('a', 81), k = 'foret', x = 0.0, y = 0.0, z = 0.0, r = 10.0 },
                { l = 'Bois', k = 'Forêt', x = 0.0, y = 0.0, z = 0.0, r = 10.0 },
                { l = 'Bois', k = 'foret', x = 0 / 0, y = 0.0, z = 0.0, r = 10.0 },
                { l = 'Bois', k = 'foret', x = 0.0, y = math.huge, z = 0.0, r = 10.0 },
                { l = 'Bois', k = 'foret', x = 0.0, y = 0.0, z = 0.0, r = 0.0 },
                { l = 'Bois', k = 'foret', x = 0.0, y = 0.0, z = 0.0, r = 501.0 },
                'foret',
            }
            for i, value in ipairs(bad) do assert.is_nil(zonestate.decode({ def = value }).def, tostring(i)) end
        end)

        it('ignore un point mal formé (ressource invalide, lieu non fini, identifiant trop long) et ramène un cap faux à 0', function()
            local record = zonestate.decode({
                ['p:a'] = { r = 'Chêne', x = 0.0, y = 0.0, z = 0.0 },
                ['p:b'] = { r = 'chene', x = 0 / 0, y = 0.0, z = 0.0 },
                ['p:c'] = { r = string.rep('c', 33), x = 0.0, y = 0.0, z = 0.0 },
                ['p:' .. string.rep('d', 47)] = { r = 'chene', x = 0.0, y = 0.0, z = 0.0 },
                ['p:E'] = { r = 'chene', x = 0.0, y = 0.0, z = 0.0 },
                ['p:f'] = { r = 'chene', x = 1.0, y = 2.0, z = 3.0, h = 'nord' },
            })
            assert.same({ f = { resource = 'chene', x = 1.0, y = 2.0, z = 3.0, heading = 0.0 } }, record.nodes)
            assert.equal(1, record.count)
        end)

        it('ignore le 121e point (120 au plus), et en reprend un quand une place se libère', function()
            local state = {}
            for i = 1, 121 do state[string.format('p:n%03d', i)] = { r = 'chene', x = i + 0.0, y = 0.0, z = 0.0 } end
            local record = zonestate.decode(state)
            assert.equal(120, record.count)
            local known = 0
            for _ in pairs(record.nodes) do known = known + 1 end
            assert.equal(120, known)
            -- un point connu peut toujours changer de lieu
            local someId = next(record.nodes)
            zonestate.patch(record, { ['p:' .. someId] = { r = 'pin', x = 5.0, y = 5.0, z = 5.0 } }, nil)
            assert.equal('pin', record.nodes[someId].resource)
            assert.equal(120, record.count)
            -- une place libérée : un nouveau point entre
            zonestate.patch(record, {}, { 'p:' .. someId })
            assert.equal(119, record.count)
            zonestate.patch(record, { ['p:neuf'] = { r = 'chene', x = 0.0, y = 0.0, z = 0.0 } }, nil)
            assert.equal(120, record.count)
            assert.is_not_nil(record.nodes.neuf)
        end)

        it('applique une différence : point ajouté, déplacé, retiré ; zone renommée ; `def` retirée', function()
            local record = zonestate.decode(full())
            zonestate.patch(record, {
                ['p:chene_3'] = { r = 'chene', x = 17.0, y = 21.0, z = 30.0, h = 0.0 }, ['n:chene_3'] = 3,
                ['p:chene_1'] = { r = 'chene', x = 12.0, y = 25.0, z = 30.0, h = 45.0 },
                def = { l = 'Bois Neuf', k = 'foret', x = 10.0, y = 20.0, z = 30.0, r = 80.0 },
            }, { 'p:chene_2', 'n:chene_2' })
            assert.equal(2, record.count)
            assert.is_nil(record.nodes.chene_2)
            assert.is_nil(record.charges.chene_2)
            assert.same({ resource = 'chene', x = 12.0, y = 25.0, z = 30.0, heading = 45.0 }, record.nodes.chene_1)
            assert.equal(3, record.charges.chene_3)
            assert.equal('Bois Neuf', record.def.label)
            assert.equal(80.0, record.def.radius)
            zonestate.patch(record, nil, { 'def' })
            assert.is_nil(record.def)
        end)

        it('retire un point dont le lieu reçu est mal formé', function()
            local record = zonestate.decode(full())
            zonestate.patch(record, { ['p:chene_1'] = { r = 'chene', x = 'loin', y = 0.0, z = 0.0 } }, nil)
            assert.is_nil(record.nodes.chene_1)
            assert.equal(1, record.count)
        end)
    end)

    describe('serveur : différence entre deux états (T-102)', function()
        local function state(list, zone)
            return zonestate.build({ band = 'normal', scarred = false }, list, function() return 3 end, zone or ZONE)
        end

        local function keysOf(t)
            local keys = {}
            for key in pairs(t) do keys[#keys + 1] = key end
            table.sort(keys)
            return keys
        end

        it('ne rend rien quand rien ne change (tables comparées clé par clé)', function()
            local changes, removed = zonestate.diff(state({ node('chene_1', 11.0, 21.0) }), state({ node('chene_1', 11.0, 21.0) }))
            assert.same({}, changes)
            assert.same({}, removed)
        end)

        it('rend l’état entier depuis rien', function()
            local after = state({ node('chene_1', 11.0, 21.0) })
            local changes, removed = zonestate.diff(nil, after)
            assert.same(after, changes)
            assert.same({}, removed)
        end)

        it('point ajouté : deux clés ; point retiré : deux clés retirées, triées', function()
            local one, two = state({ node('chene_1', 11.0, 21.0) }), state({ node('chene_1', 11.0, 21.0), node('chene_2', 14.0, 21.0) })
            local changes, removed = zonestate.diff(one, two)
            assert.same({ ['p:chene_2'] = { r = 'chene', x = 14.0, y = 21.0, z = 30.0, h = 90.0 }, ['n:chene_2'] = 3 }, changes)
            assert.same({}, removed)
            changes, removed = zonestate.diff(two, one)
            assert.same({}, changes)
            assert.same({ 'n:chene_2', 'p:chene_2' }, removed)
        end)

        it('point déplacé : sa seule clé de lieu ; zone renommée : la seule `def`', function()
            local before = state({ node('chene_1', 11.0, 21.0) })
            local changes = zonestate.diff(before, state({ node('chene_1', 11.5, 21.0) }))
            assert.same({ 'p:chene_1' }, keysOf(changes))
            local renamed = {}
            for key, value in pairs(ZONE) do renamed[key] = value end
            renamed.label = 'Bois Neuf'
            changes = zonestate.diff(before, state({ node('chene_1', 11.0, 21.0) }, renamed))
            assert.same({ def = { l = 'Bois Neuf', k = 'foret', x = 10.0, y = 20.0, z = 30.0, r = 60.0 } }, changes)
        end)

        it('fatigue, repos, cicatrice, charges maximales, repousse ou nom d’un point changés : rien à envoyer', function()
            local before = state({ node('chene_1', 11.0, 21.0) })
            local tired = {}
            for key, value in pairs(ZONE) do tired[key] = value end
            tired.cost, tired.regenPerHour, tired.scarHours = 9.5, 0.5, 720
            local changes, removed = zonestate.diff(before,
                state({ node('chene_1', 11.0, 21.0, { charges = 20, regenMs = 86400000, label = 'Autre nom' }) }, tired))
            assert.same({}, changes)
            assert.same({}, removed)
        end)

        it('découpe une différence en paquets de 64 clés, changées puis retirées, dans l’ordre des clés', function()
            local changes, removed = {}, {}
            for i = 1, 100 do changes[string.format('p:a%03d', i)] = i end
            for i = 1, 40 do removed[i] = string.format('p:b%03d', i) end
            local chunks = zonestate.chunks(changes, removed)
            assert.equal(3, #chunks)
            local counts = {}
            for i, chunk in ipairs(chunks) do
                local n = #chunk.removed
                for _ in pairs(chunk.changes) do n = n + 1 end
                counts[i] = n
                -- jamais une même clé changée et retirée dans un appel
                for _, key in ipairs(chunk.removed) do assert.is_nil(chunk.changes[key]) end
            end
            assert.same({ 64, 64, 12 }, counts)
            assert.equal(1, chunks[1].changes['p:a001'])
            assert.equal('p:b001', chunks[2].removed[1])
            assert.same({}, zonestate.chunks({}, {}))
        end)
    end)

    describe('client : essai de l’Atelier (T-102)', function()
        local function fullTrial()
            return {
                zone = 'bois', mode = 'full', def = { l = 'Bois des Essais', k = 'foret', x = 10.0, y = 20.0, z = 30.0, r = 60.0 },
                nodes = { chene_1 = { r = 'chene', x = 11.0, y = 21.0, z = 30.0, h = 0.0, c = 3 } },
            }
        end

        it('lit un essai entier, puis ses différences (point changé, charges seules, point caché)', function()
            local record = zonestate.trial(nil, fullTrial())
            assert.equal('Bois des Essais', record.def.label)
            assert.equal(3, record.nodes.chene_1.charges)
            record = zonestate.trial(record, { zone = 'bois', mode = 'patch',
                nodes = { chene_2 = { r = 'pin', x = 15.0, y = 21.0, z = 30.0, h = 10.0, c = 4 }, chene_1 = { c = 2 } } })
            assert.equal(2, record.nodes.chene_1.charges)
            assert.equal('pin', record.nodes.chene_2.resource)
            assert.equal(2, record.count)
            record = zonestate.trial(record, { zone = 'bois', mode = 'patch', hidden = { 'chene_1', 'inconnu' } })
            assert.is_nil(record.nodes.chene_1)
            assert.equal(1, record.count)
        end)

        it('garde les charges d’un point repositionné sans charges, et refuse un patch sans essai ou mal formé', function()
            local record = zonestate.trial(nil, fullTrial())
            record = zonestate.trial(record, { zone = 'bois', mode = 'patch',
                nodes = { chene_1 = { r = 'chene', x = 12.0, y = 21.0, z = 30.0 } } })
            assert.equal(3, record.nodes.chene_1.charges)
            assert.equal(12.0, record.nodes.chene_1.x)
            assert.is_nil(zonestate.trial(nil, { zone = 'bois', mode = 'patch' }))
            assert.is_nil(zonestate.trial(record, { zone = 'bois', mode = 'autre' }))
            assert.is_nil(zonestate.trial(record, 'full'))
        end)

        it('lit l’identifiant de zone d’un message d’essai ou d’une fin d’essai', function()
            assert.equal('bois', zonestate.trialZone(fullTrial()))
            assert.equal('bois', zonestate.trialZone('bois'))
            assert.is_nil(zonestate.trialZone({ zone = 'Bois' }))
            assert.is_nil(zonestate.trialZone(string.rep('a', 49)))
        end)
    end)

    describe('client : liste de la carte (T-102)', function()
        local function list()
            return { version = '00ff00ff00ff00ff', zones = {
                { i = 'foret_brume', l = 'Forêt de Brume', k = 'foret', x = -320, y = -880, r = 120 },
            } }
        end

        it('accepte une liste bien formée et la recopie', function()
            local raw = list()
            local checked = zonestate.mapList(raw)
            assert.same(raw, checked)
            assert.is_false(rawequal(raw.zones[1], checked.zones[1]))
            assert.same({ version = '', zones = {} }, zonestate.mapList({ version = '', zones = {} }))
        end)

        it('oublie une liste abîmée (version, zone, champ ou nombre de zones hors bornes)', function()
            local function with(change)
                local raw = list()
                change(raw, raw.zones[1])
                return zonestate.mapList(raw)
            end
            assert.is_nil(zonestate.mapList(nil))
            assert.is_nil(zonestate.mapList('{"version":""}'))
            assert.is_nil(with(function(raw) raw.version = 'xyz' end))
            assert.is_nil(with(function(raw) raw.version = string.rep('a', 17) end))
            assert.is_nil(with(function(raw) raw.zones = 'zones' end))
            assert.is_nil(with(function(_, zone) zone.i = 'Forêt' end))
            assert.is_nil(with(function(_, zone) zone.l = '' end))
            assert.is_nil(with(function(_, zone) zone.k = 7 end))
            assert.is_nil(with(function(_, zone) zone.x = 0 / 0 end))
            assert.is_nil(with(function(_, zone) zone.r = 0 end))
            assert.is_nil(with(function(_, zone) zone.r = 501 end))
            assert.is_nil(with(function(raw)
                for i = 2, VavaGathering.MAX_MAP_ZONES + 1 do
                    raw.zones[i] = { i = 'z' .. i, l = 'Z', k = 'foret', x = 0, y = 0, r = 10 }
                end
            end))
        end)
    end)
end)
