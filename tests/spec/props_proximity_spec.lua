local helper = require('tests.helper')

-- Streaming des props par groupes (shared/proximity.lua, même fichier dans vava_gathering, vava_farming,
-- vava_crafting et vava_provisions ; T-018, T-130). Ce qui compte : un groupe écarté ne cache jamais une cible à
-- portée (sinon un prop manquerait), l'intervalle ne s'allonge que loin de tout, et les valeurs de la config sont
-- celles des README (80 m, 1 s près d'un groupe, 2,5 s au-delà de 80 + 60 m).

local MODULES = {
    { name = 'vava_gathering', global = 'VavaGathering' },
    { name = 'vava_farming', global = 'VavaFarming' },
    { name = 'vava_crafting', global = 'VavaCrafting' },
    { name = 'vava_provisions', global = 'VavaProvisions' },
}

--- Distance réelle, pour comparer à la borne du groupe.
local function distance(ax, ay, az, bx, by, bz)
    local dx, dy, dz = ax - bx, ay - by, az - bz
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

for _, module in ipairs(MODULES) do
    describe(module.name .. ' proximity', function()
        local proximity, cfg

        before_each(function()
            helper.reset()
            -- réglages du streaming lus par le client : sur la seule vue client (constantes et config_client.lua, T-132)
            helper.loadClientView('modules/' .. module.name, module.global)
            helper.load('modules/' .. module.name .. '/shared/proximity.lua')
            proximity = _G[module.global].proximity
            cfg = _G[module.global].config
        end)

        it('regroupe par clé, dans l\'ordre de la première cible, avec centre et étendue', function()
            local a = { id = 'a', x = 0, y = 0, z = 0 }
            local b = { id = 'b', x = 10, y = 0, z = 0 }
            local c = { id = 'c', x = 500, y = 500, z = 10 }
            local d = { id = 'd', x = 0, y = 10, z = 0 }
            local keys = { a = 'nord', b = 'nord', c = 'sud', d = 'nord' }
            local groups = proximity.group({ a, b, c, d }, function(t) return keys[t.id] end)
            assert.equal(2, #groups)
            assert.equal('nord', groups[1].key)
            assert.same({ a, b, d }, groups[1].targets)
            assert.near(10 / 3, groups[1].x, 1e-9)
            assert.near(10 / 3, groups[1].y, 1e-9)
            assert.near(distance(10, 0, 0, 10 / 3, 10 / 3, 0), groups[1].extent, 1e-9)
            assert.equal('sud', groups[2].key)
            assert.equal(500, groups[2].x)
            assert.equal(0, groups[2].extent)
        end)

        it('ignore une cible sans position numérique ou sans clé', function()
            local groups = proximity.group({
                { x = 1, y = 2, z = 3 },
                { x = 1, y = '2', z = 3 },
                { x = 1, y = 2 },
                'pas une table',
                { x = 5, y = 5, z = 5, skip = true },
                { x = 0 / 0, y = 2, z = 3 },
                { x = 1, y = math.huge, z = 3 },
                { x = 1, y = 2, z = -math.huge },
            }, function(t) if not t.skip then return 'k' end end)
            assert.equal(1, #groups)
            assert.equal(1, #groups[1].targets)
        end)

        it('rend une liste vide sans cible, et la distance la plus proche est alors infinie', function()
            local groups = proximity.group({}, function() return 'k' end)
            assert.same({}, groups)
            assert.equal(math.huge, proximity.closest(groups, 0, 0, 0))
        end)

        it('range dans la même case les points d\'un même carré, et sépare les autres (négatifs compris)', function()
            assert.equal(proximity.cell(10, 10, 200), proximity.cell(199.9, 0, 200))
            assert.not_equal(proximity.cell(199.9, 0, 200), proximity.cell(200, 0, 200))
            assert.equal(proximity.cell(-1, -1, 200), proximity.cell(-199, -199, 200))
            assert.not_equal(proximity.cell(-1, 0, 200), proximity.cell(1, 0, 200))
            assert.equal('-2:-5', proximity.cell(-255.0, -945.0, 200))
        end)

        it('borne la distance au groupe par le bas : 0 dans son étendue, centre moins étendue au-delà', function()
            local group = proximity.group({ { x = -10, y = 0, z = 0 }, { x = 10, y = 0, z = 0 } },
                function() return 'k' end)[1]
            assert.equal(10, group.extent)
            assert.equal(0, proximity.gap(group, 0, 0, 0))
            assert.equal(0, proximity.gap(group, 5, 5, 0))
            assert.equal(90, proximity.gap(group, 100, 0, 0))
            local reachable, gap = proximity.reachable(group, 100, 0, 0, 90)
            assert.is_true(reachable)
            assert.equal(90, gap)
            assert.is_false((proximity.reachable(group, 100.01, 0, 0, 90)))
        end)

        it('un groupe écarté n\'a jamais de cible à portée (balayage autour de groupes irréguliers)', function()
            local targets, seed = {}, 7
            local function rand()
                seed = (seed * 1103515245 + 12345) % 2147483648
                return seed / 2147483648
            end
            for i = 1, 60 do
                targets[i] = { id = i, x = rand() * 600 - 300, y = rand() * 600 - 300, z = rand() * 40 }
            end
            local groups = proximity.group(targets, function(t) return proximity.cell(t.x, t.y, 200) end)
            local reach = 80
            for px = -450, 450, 37 do
                for py = -450, 450, 41 do
                    local pz = 15
                    for _, group in ipairs(groups) do
                        if not proximity.reachable(group, px, py, pz, reach) then
                            for _, t in ipairs(group.targets) do
                                assert.is_true(distance(px, py, pz, t.x, t.y, t.z) > reach)
                            end
                        end
                    end
                    -- la plus petite borne ne dépasse jamais la distance réelle à la cible la plus proche
                    local nearest = math.huge
                    for _, t in ipairs(targets) do nearest = math.min(nearest, distance(px, py, pz, t.x, t.y, t.z)) end
                    assert.is_true(proximity.closest(groups, px, py, pz) <= nearest + 1e-9)
                end
            end
        end)

        it('choisit l\'intervalle court près d\'un groupe, le long au-delà de la portée et de la marge', function()
            assert.equal(1000, proximity.interval(0, 80, 60, 1000, 2500))
            assert.equal(1000, proximity.interval(140, 80, 60, 1000, 2500))
            assert.equal(2500, proximity.interval(140.01, 80, 60, 1000, 2500))
            assert.equal(2500, proximity.interval(math.huge, 80, 60, 1000, 2500))
            -- sans marge réglée : la portée seule
            assert.equal(2500, proximity.interval(80.5, 80, nil, 1000, 2500))
            -- sans intervalle long réglé, ou plus court que le court : jamais plus vite qu'avant
            assert.equal(1000, proximity.interval(math.huge, 80, 60, 1000, nil))
            assert.equal(1000, proximity.interval(math.huge, 80, 60, 1000, 500))
        end)

        it('README : props à 80 m, 1 s près d\'un groupe, 2,5 s au-delà de 140 m', function()
            local s = cfg.streaming
            assert.equal(80.0, s.radius)
            assert.equal(1000, s.pollMs)
            assert.equal(2500, s.idlePollMs)
            assert.equal(60.0, s.idleMargin)
            assert.is_true(s.idlePollMs >= 2000 and s.idlePollMs <= 3000)
            -- la marge couvre au moins 20 m/s (cavalier au galop) pendant l'intervalle long
            assert.is_true(s.idleMargin >= 20 * s.idlePollMs / 1000)
            -- l'invite ne peut pas porter plus loin que les props : un groupe écarté n'a pas de cible à l'invite
            assert.is_true(cfg.interact.distance <= s.radius)
            if module.name ~= 'vava_gathering' then assert.is_true(s.groupCell > 0) end
        end)
    end)
end

describe('vava_gathering proximity : zones de la config', function()
    -- client/props.lua passe cfg.nodes à proximity.group au chargement : essai sur la seule vue client (T-132, relecture
    -- réseau R-2), constantes et config_client.lua comme chez un joueur
    it('chaque nœud est dans le groupe de sa zone, et l\'étendue de chaque zone tient dans son rayon', function()
        helper.reset()
        helper.loadClientView('modules/vava_gathering', 'VavaGathering')
        assert.is_nil(VavaGathering.config.items, 'vue client : config.lua ne doit pas être chargé')
        helper.load('modules/vava_gathering/shared/proximity.lua')
        local cfg, proximity = VavaGathering.config, VavaGathering.proximity
        local groups = proximity.group(cfg.nodes, function(node) return node.zone end)
        local zones = {}
        for _, zone in ipairs(cfg.zones) do zones[zone.id] = zone end
        local count = 0
        for _, group in ipairs(groups) do
            local zone = zones[group.key]
            assert.is_table(zone, group.key)
            assert.is_true(group.extent <= zone.radius, group.key)
            for _, node in ipairs(group.targets) do assert.equal(group.key, node.zone) end
            count = count + #group.targets
        end
        assert.equal(#cfg.nodes, count)
    end)
end)
