local helper = require('tests.helper')

-- Vivres côté serveur (modules/vava_provisions/server/points.lua, draw.lua, containers.lua, items.lua, admin.lua, T-130)
-- avec des doublures du bridge : position, personnage actif, à terre, inventaire (compte, échange, ajout), besoins
-- (soif lue et ajoutée), zones du core, envois, droits, journaux, hooks, horloges fixes ; CreateThread exécuté aussitôt
-- (ou retenu, pour un personnage qui change avant le thread) ; math.random fixé. Puis le démarrage réel (bridge et
-- main.lua) sur un core simulé : registres, zones, RPC, hooks, exports. Règles documentées : README du module et
-- docs/plan/specs/T-130.md § 6, § 7 et § 11.1.

local SOURCE, OTHER, CHARACTER, CHARACTER2 = 5, 6, 100, 200
local NOW, TIMER = 1761832800, 500000

local function copy(value)
    if type(value) ~= 'table' then return value end
    local out = {}
    for key, item in pairs(value) do out[key] = copy(item) end
    return out
end

local function newLogs()
    local logs = { error = {}, warn = {}, info = {}, debug = {} }
    local log = {}
    for level in pairs(logs) do
        log[level] = function(fmt, ...) logs[level][#logs[level] + 1] = fmt:format(...) end
    end
    return logs, log
end

local BASE_FILES = {
    'modules/vava_provisions/shared/constants.lua',
    'modules/vava_provisions/config.lua',
    'modules/vava_provisions/shared/texts.lua',
    'modules/vava_provisions/shared/rules.lua',
    'modules/vava_provisions/shared/pointzone.lua',
}

describe('vava_provisions server', function()
    local cfg, points, draw, containers, items, admin, EVENTS, HOOKS
    local logs, active, positions, downed, counts, thirsts, thirstAdds
    local exchanges, exchangeAnswers, exchangeDuring, adds, addAnswers, piles, pileReads
    local zoneCalls, zoneAnswers, sent, befores, beforeAnswer, beforeDuring, afters
    local allowed, adminLogs, chats, itemsKnown, itemsAdded, recipeAnswers
    local now, timer, roll, deferred, queue
    local realRandom = math.random

    local function at(source, pointId, offset)
        local def
        for _, entry in ipairs(cfg.points) do if entry.id == pointId then def = entry end end
        positions[source] = { def.x + (offset or 0), def.y, def.z }
    end

    before_each(function()
        helper.reset()
        VavaProvisions = nil
        logs, active, positions, downed = nil, { [SOURCE] = CHARACTER, [OTHER] = CHARACTER2 }, {}, {}
        counts, thirsts, thirstAdds = { [SOURCE] = {}, [OTHER] = {} }, { [SOURCE] = 50, [OTHER] = 50 }, {}
        exchanges, exchangeAnswers, exchangeDuring, adds, addAnswers = {}, {}, nil, {}, {}
        piles, pileReads = { [SOURCE] = {}, [OTHER] = {} }, {}
        zoneCalls, zoneAnswers, sent, befores, beforeAnswer, beforeDuring, afters = {}, {}, {}, {}, nil, nil, {}
        allowed, adminLogs, chats, itemsKnown, itemsAdded, recipeAnswers = { [8] = true }, {}, {}, {}, {}, {}
        now, timer, roll, deferred, queue = NOW, TIMER, 0.5, false, {}
        _G.CreateThread = function(fn)
            if deferred then queue[#queue + 1] = fn else fn() end
        end
        math.random = function() return roll end

        helper.loadAll(BASE_FILES)
        cfg = VavaProvisions.config
        EVENTS, HOOKS = VavaProvisions.EVENTS, VavaProvisions.HOOKS
        local log
        logs, log = newLogs()
        VavaProvisions.resource = 'vava_provisions'
        VavaProvisions.log = log
        VavaProvisions.bridge = {
            CONSOLE = 0, INVENTORY = 'vava_inventory', CRAFTING = 'vava_crafting', SKILLS = 'vava_skills',
            ActiveCharacterId = function(src) return active[src] end,
            Position = function(src)
                local p = positions[src]
                if not p then return nil end
                return p[1], p[2], p[3]
            end,
            IsDowned = function(src) return downed[src] == true end,
            Count = function(src, item)
                if counts[src] == false then return nil end
                return counts[src][item] or 0
            end,
            Exchange = function(src, removals, additions)
                exchanges[#exchanges + 1] = { source = src, removals = copy(removals), additions = copy(additions) }
                if exchangeDuring then
                    local fn = exchangeDuring
                    exchangeDuring = nil
                    fn()
                end
                return table.unpack(table.remove(exchangeAnswers, 1) or { true })
            end,
            Piles = function(src, item)
                -- piles posées par l'essai, sinon une seule pile sans palier de la quantité de `counts`
                pileReads[#pileReads + 1] = { source = src, item = item }
                if counts[src] == false then return nil end
                local own = piles[src] and piles[src][item]
                if own == false then return nil end
                if own then return copy(own) end
                local quantity = counts[src][item] or 0
                if quantity < 1 then return {} end
                return { { id = 1, item = item, quantity = quantity, metadata = {} } }
            end,
            Add = function(src, item, quantity, metadata)
                adds[#adds + 1] = { source = src, item = item, quantity = quantity, metadata = copy(metadata) }
                return table.unpack(table.remove(addAnswers, 1) or { true })
            end,
            Thirst = function(src) return thirsts[src] end,
            AddThirst = function(src, amount)
                thirstAdds[#thirstAdds + 1] = { source = src, amount = amount }
                return true
            end,
            ItemsReady = function() return true end,
            HasItem = function(name) return itemsKnown[name] == true end,
            AddItem = function(name, def)
                itemsAdded[#itemsAdded + 1] = { name = name, def = copy(def) }
                itemsKnown[name] = true
                return true
            end,
            DeclareRecipe = function(recipe)
                return table.unpack(table.remove(recipeAnswers, 1) or { true, recipe.id })
            end,
            Zones = {
                define = function(id, area, state)
                    zoneCalls[#zoneCalls + 1] = { kind = 'define', id = id, area = copy(area), state = copy(state) }
                    return table.unpack(zoneAnswers[id] or { true, #zoneCalls })
                end,
                move = function(id, area)
                    zoneCalls[#zoneCalls + 1] = { kind = 'move', id = id, area = copy(area) }
                    return true
                end,
                replace = function(id, state)
                    zoneCalls[#zoneCalls + 1] = { kind = 'replace', id = id, state = copy(state) }
                    return true
                end,
                remove = function(id)
                    zoneCalls[#zoneCalls + 1] = { kind = 'remove', id = id }
                    return true
                end,
            },
            Send = function(target, event, ...)
                -- jamais à tous, jamais une liste, jamais un autre joueur que celui qui a un personnage
                assert.equal('integer', math.type(target))
                assert.is_true(target > 0)
                assert.is_not_nil(active[target])
                sent[#sent + 1] = { target = target, event = event, args = table.pack(...) }
                return true
            end,
            RunBefore = function(name, payload)
                -- un abonné qui cède la main (déplacement, changement de personnage) ou modifie le payload
                if beforeDuring then beforeDuring(payload) end
                befores[#befores + 1] = { name = name, payload = copy(payload) }
                if beforeAnswer then return table.unpack(beforeAnswer) end
                return true
            end,
            RunAfter = function(name, payload) afters[#afters + 1] = { name = name, payload = copy(payload) } end,
            IsAllowed = function(src) return src == 0 or allowed[src] == true end,
            AdminLog = function(src, label, details) adminLogs[#adminLogs + 1] = { source = src, label = label, details = copy(details) } end,
            Chat = function(src, text) chats[#chats + 1] = { source = src, text = text } end,
            Now = function() return now end,
            Timer = function() return timer end,
        }
        helper.loadAll({
            'modules/vava_provisions/server/items.lua',
            'modules/vava_provisions/server/points.lua',
            'modules/vava_provisions/server/draw.lua',
            'modules/vava_provisions/server/containers.lua',
            'modules/vava_provisions/server/admin.lua',
        })
        points, draw, containers = VavaProvisions.points, VavaProvisions.draw, VavaProvisions.containers
        items, admin = VavaProvisions.items, VavaProvisions.admin
    end)

    after_each(function()
        math.random = realRandom
        VavaProvisions = nil
    end)

    local function reserveOf(id)
        local point = points.get(id)
        local reserve = points.reserve(point, now)
        return reserve and reserve.level or nil
    end

    describe('démarrage', function()
        it('déclare une zone du core par point : centre, rayon 2 m, marge 100 m, état { def }', function()
            assert.equal(3, points.loadConfig())
            assert.equal(3, #zoneCalls)
            for index, def in ipairs(cfg.points) do
                local call = zoneCalls[index]
                assert.equal('define', call.kind)
                assert.equal(def.id, call.id)
                assert.same({ x = def.x, y = def.y, radius = 2.0, margin = 100.0 }, call.area)
                assert.same({ 'def' }, (function() local keys = {} for k in pairs(call.state) do keys[#keys + 1] = k end return keys end)())
                assert.equal(def.label, call.state.def.label)
                assert.equal(def.kind, call.state.def.kind)
                assert.is_nil(call.state.def.reserve)
            end
            assert.equal(40, reserveOf('puits_lavoir'))
            assert.equal(15, reserveOf('source_claire'))
            assert.is_nil(reserveOf('fontaine_bourg'))
            assert.same({ 'fontaine_bourg', 'puits_lavoir', 'source_claire' },
                { points.list()[1].id, points.list()[2].id, points.list()[3].id })
        end)

        it('oublie un point dont la zone est refusée par le core, et le dit en console', function()
            zoneAnswers.puits_lavoir = { false, 'full' }
            assert.equal(2, points.loadConfig())
            assert.is_nil(points.get('puits_lavoir'))
            assert.is_not_nil(points.get('fontaine_bourg'))
            assert.equal(1, #logs.error)
            assert.matches('puits_lavoir', logs.error[1])
            assert.matches('full', logs.error[1])
        end)

        it('put déplace un point connu et garde sa réserve ; drop le retire', function()
            points.loadConfig()
            points.setReserve(points.get('puits_lavoir'), 12, now)
            local moved = copy(cfg.points[2])
            moved.x = moved.x + 3
            assert.is_true(points.put(moved))
            assert.same({ 'move', 'replace' }, { zoneCalls[4].kind, zoneCalls[5].kind })
            assert.equal(12, reserveOf('puits_lavoir'))
            assert.equal(moved.x, points.get('puits_lavoir').x)
            assert.equal(3, #points.list())
            assert.is_true(points.drop('puits_lavoir'))
            assert.equal('remove', zoneCalls[6].kind)
            assert.is_nil(points.get('puits_lavoir'))
            assert.equal(2, #points.list())
            assert.same({ false, 'unknown_point' }, { points.drop('puits_lavoir') })
            assert.same({ false, 'unknown_kind', 'kind' }, { points.put({ id = 'x', kind = 'citerne', label = 'X', x = 0, y = 0, z = 0 }) })
        end)
    end)

    describe('puiser', function()
        before_each(function()
            points.loadConfig()
        end)

        it('remplit les outres vides en un seul échange, réserve et hook à jour', function()
            at(SOURCE, 'puits_lavoir')
            counts[SOURCE].outre = 2
            assert.same({ true, { action = 'fill', count = 2 } }, { draw.handle(SOURCE, 'puits_lavoir') })
            assert.equal(1, #exchanges)
            -- la pile d'outres visée par son identifiant, relue après le hook ; eau sans palier pour une outre sans palier
            assert.same({ source = SOURCE, removals = { { instanceId = 1, quantity = 2 } }, additions = { { item = 'eau', quantity = 2 } } }, exchanges[1])
            assert.same({ { source = SOURCE, item = 'outre' } }, pileReads)
            assert.equal(38, reserveOf('puits_lavoir'))
            assert.equal(1, #befores)
            assert.same({ source = SOURCE, characterId = CHARACTER, point = 'puits_lavoir', kind = 'puits', action = 'fill', count = 2 }, befores[1].payload)
            assert.equal(HOOKS.DRAWING, befores[1].name)
            assert.equal(1, #afters)
            assert.equal(HOOKS.DRAWN, afters[1].name)
            assert.same({ source = SOURCE, characterId = CHARACTER, point = 'puits_lavoir', kind = 'puits', action = 'fill', count = 2, reserve = 38 }, afters[1].payload)
            assert.equal(0, #thirstAdds)
            assert.equal(0, #sent)
        end)

        it('remplit au plus maxPerDraw outres, puis le reste au geste suivant', function()
            at(SOURCE, 'puits_lavoir')
            counts[SOURCE].outre = 7
            assert.same({ true, { action = 'fill', count = 5 } }, { draw.handle(SOURCE, 'puits_lavoir') })
            counts[SOURCE].outre = 2
            timer = timer + cfg.cooldownMs
            assert.same({ true, { action = 'fill', count = 2 } }, { draw.handle(SOURCE, 'puits_lavoir') })
            assert.equal(33, reserveOf('puits_lavoir'))
        end)

        it('ne touche aucune réserve à la fontaine (sans fond)', function()
            at(SOURCE, 'fontaine_bourg')
            counts[SOURCE].outre = 3
            assert.same({ true, { action = 'fill', count = 3 } }, { draw.handle(SOURCE, 'fontaine_bourg') })
            assert.is_nil(reserveOf('fontaine_bourg'))
            assert.is_nil(afters[1].payload.reserve)
            assert.equal(40, reserveOf('puits_lavoir'))
        end)

        it('rend la réserve si l\'échange échoue, sans délai', function()
            at(SOURCE, 'puits_lavoir')
            counts[SOURCE].outre = 2
            thirsts[SOURCE] = 99  -- pas soif : aucune gorgée de repli
            exchangeAnswers = { { false, 'no_space' } }
            assert.same({ false, 'no_space' }, { draw.handle(SOURCE, 'puits_lavoir') })
            assert.equal(40, reserveOf('puits_lavoir'))
            assert.equal(0, #afters)
            exchangeAnswers = { { false, 'too_heavy' } }
            assert.same({ false, 'too_heavy' }, { draw.handle(SOURCE, 'puits_lavoir') })
            exchangeAnswers = { { false, 'inventory_unavailable' } }
            assert.same({ false, 'unavailable' }, { draw.handle(SOURCE, 'puits_lavoir') })
            assert.equal(40, reserveOf('puits_lavoir'))
            -- aucun délai posé : le geste suivant passe tout de suite
            assert.same({ true, { action = 'fill', count = 2 } }, { draw.handle(SOURCE, 'puits_lavoir') })
            assert.equal(0, #thirstAdds)
        end)

        it('besace pleine ou trop lourde et soif : on boit sur place, réserve rendue, délai posé', function()
            at(SOURCE, 'puits_lavoir')
            counts[SOURCE].outre = 2
            exchangeAnswers = { { false, 'no_space' } }
            assert.same({ true, { action = 'drink', dry = false, blocked = 'no_space' } }, { draw.handle(SOURCE, 'puits_lavoir') })
            assert.same({ { source = SOURCE, amount = 20 } }, thirstAdds)
            assert.equal(40, reserveOf('puits_lavoir'))
            -- deux hooks drawing (remplir, puis boire), un seul drawn (boire)
            assert.same({ 'fill', 'drink' }, { befores[1].payload.action, befores[2].payload.action })
            assert.equal(1, #afters)
            assert.same({ source = SOURCE, characterId = CHARACTER, point = 'puits_lavoir', kind = 'puits', action = 'drink', count = 0, reserve = 40 },
                afters[1].payload)
            assert.same({ false, 'wait' }, { draw.handle(SOURCE, 'puits_lavoir') })

            timer = timer + cfg.cooldownMs
            exchangeAnswers = { { false, 'too_heavy' } }
            assert.same({ true, { action = 'drink', dry = false, blocked = 'too_heavy' } }, { draw.handle(SOURCE, 'puits_lavoir') })
            assert.equal(2, #thirstAdds)

            -- un hook qui refuse de laisser boire : le refus de la besace
            timer = timer + cfg.cooldownMs
            exchangeAnswers = { { false, 'no_space' } }
            local calls = 0
            beforeDuring = function()
                calls = calls + 1
                if calls == 2 then beforeAnswer = { false, 'non' } end
            end
            assert.same({ false, 'no_space' }, { draw.handle(SOURCE, 'puits_lavoir') })
            assert.equal(2, #thirstAdds)
        end)

        it('relit personnage et distance après le hook drawing (qui a pu céder la main)', function()
            at(SOURCE, 'puits_lavoir')
            counts[SOURCE].outre = 2
            beforeDuring = function() at(SOURCE, 'puits_lavoir', 10) end
            assert.same({ false, 'too_far' }, { draw.handle(SOURCE, 'puits_lavoir') })
            at(SOURCE, 'puits_lavoir')
            beforeDuring = function() active[SOURCE] = 999 end
            assert.same({ false, 'unavailable' }, { draw.handle(SOURCE, 'puits_lavoir') })
            assert.equal(0, #exchanges)
            assert.equal(0, #thirstAdds)
            assert.equal(0, #afters)
            assert.equal(40, reserveOf('puits_lavoir'))
        end)

        it('reconstruit le payload du hook drawn : un abonné de drawing qui le modifie n\'y change rien', function()
            at(SOURCE, 'puits_lavoir')
            counts[SOURCE].outre = 2
            beforeDuring = function(payload) payload.count, payload.point, payload.reserve, payload.source = 99, 'autre', 0, 1 end
            assert.is_true(draw.handle(SOURCE, 'puits_lavoir'))
            assert.same({ source = SOURCE, characterId = CHARACTER, point = 'puits_lavoir', kind = 'puits', action = 'fill', count = 2, reserve = 38 },
                afters[1].payload)
            assert.same({ { instanceId = 1, quantity = 2 } }, exchanges[1].removals)
        end)

        it('deux joueurs sur la dernière unité : un seul remplissage, l\'autre à sec', function()
            points.setReserve(points.get('puits_lavoir'), 1, now)
            at(SOURCE, 'puits_lavoir')
            at(OTHER, 'puits_lavoir', 0.5)
            counts[SOURCE].outre, counts[OTHER].outre = 1, 1
            thirsts[SOURCE], thirsts[OTHER] = 99, 99
            local second
            -- l'échange du premier cède la main : le second puise pendant ce temps
            exchangeDuring = function() second = { draw.handle(OTHER, 'puits_lavoir') } end
            assert.same({ true, { action = 'fill', count = 1 } }, { draw.handle(SOURCE, 'puits_lavoir') })
            assert.same({ false, 'dry', 60 }, second)
            assert.equal(1, #exchanges)
            assert.equal(0, reserveOf('puits_lavoir'))
        end)

        it('à sec : attente en secondes jusqu\'au prochain puisage entier', function()
            -- réserve à 0,4 : 0 il y a 24 s, un puisage par minute
            points.setReserve(points.get('puits_lavoir'), 0, now - 24)
            at(SOURCE, 'puits_lavoir')
            counts[SOURCE].outre = 3
            thirsts[SOURCE] = 99
            assert.same({ false, 'dry', 36 }, { draw.handle(SOURCE, 'puits_lavoir') })
            assert.equal(0, #exchanges)
        end)

        -- T-135 : chaque outre d'eau garde le palier de son outre vide
        it('garde le palier de chaque outre : piles prises une à une, eau regroupée par palier', function()
            at(SOURCE, 'puits_lavoir')
            counts[SOURCE].outre = 8
            piles[SOURCE].outre = {
                { id = 21, item = 'outre', quantity = 2, metadata = { tier = 3 } },
                { id = 22, item = 'outre', quantity = 1, metadata = {} },
                { id = 23, item = 'outre', quantity = 5, metadata = { tier = 1 } },
            }
            assert.same({ true, { action = 'fill', count = 5 } }, { draw.handle(SOURCE, 'puits_lavoir') })
            assert.equal(1, #exchanges)
            assert.same({ { instanceId = 21, quantity = 2 }, { instanceId = 22, quantity = 1 }, { instanceId = 23, quantity = 2 } },
                exchanges[1].removals)
            assert.same({
                { item = 'eau', quantity = 2, metadata = { tier = 3 } },
                { item = 'eau', quantity = 1 },
                { item = 'eau', quantity = 2, metadata = { tier = 1 } },
            }, exchanges[1].additions)
            assert.equal(35, reserveOf('puits_lavoir'))
        end)

        it('relit les outres après le hook drawing : moins d\'outres, moins de puisages ; plus aucune, rien de pris', function()
            at(SOURCE, 'puits_lavoir')
            counts[SOURCE].outre = 3
            thirsts[SOURCE] = 99
            -- deux outres troquées pendant le hook : une seule est remplie, un seul puisage
            beforeDuring = function()
                piles[SOURCE].outre = { { id = 31, item = 'outre', quantity = 1, metadata = { tier = 4 } } }
            end
            assert.same({ true, { action = 'fill', count = 1 } }, { draw.handle(SOURCE, 'puits_lavoir') })
            assert.same({ { instanceId = 31, quantity = 1 } }, exchanges[1].removals)
            assert.same({ { item = 'eau', quantity = 1, metadata = { tier = 4 } } }, exchanges[1].additions)
            assert.equal(39, reserveOf('puits_lavoir'))
            assert.equal(1, #pileReads)

            -- toutes parties : refus « il vous faut une outre », réserve et délai intacts
            timer = timer + cfg.cooldownMs
            beforeDuring = function() piles[SOURCE].outre = {} end
            assert.same({ false, 'no_container' }, { draw.handle(SOURCE, 'puits_lavoir') })
            -- inventaire muet après le hook : indisponible
            beforeDuring = function() piles[SOURCE].outre = false end
            assert.same({ false, 'unavailable' }, { draw.handle(SOURCE, 'puits_lavoir') })
            assert.equal(1, #exchanges)
            assert.equal(39, reserveOf('puits_lavoir'))
            assert.equal(1, #afters)
        end)
    end)

    describe('boire au point d\'eau', function()
        before_each(function()
            points.loadConfig()
            at(SOURCE, 'puits_lavoir')
        end)

        it('sans outre et assoiffé : quelques gorgées, réserve intacte', function()
            assert.same({ true, { action = 'drink', dry = false } }, { draw.handle(SOURCE, 'puits_lavoir') })
            assert.same({ { source = SOURCE, amount = 20 } }, thirstAdds)
            assert.equal(40, reserveOf('puits_lavoir'))
            assert.equal(0, #exchanges)
            assert.same({ source = SOURCE, characterId = CHARACTER, point = 'puits_lavoir', kind = 'puits', action = 'drink', count = 0, reserve = 40 },
                afters[1].payload)
        end)

        it('puits à sec, outres vides et soif : on y boit (dry vrai)', function()
            points.setReserve(points.get('puits_lavoir'), 0, now)
            counts[SOURCE].outre = 3
            assert.same({ true, { action = 'drink', dry = true } }, { draw.handle(SOURCE, 'puits_lavoir') })
            assert.equal(1, #thirstAdds)
        end)

        it('refuse quand on n\'a pas soif, et sans besoins on ne boit pas', function()
            thirsts[SOURCE] = 95
            assert.same({ false, 'not_thirsty' }, { draw.handle(SOURCE, 'puits_lavoir') })
            thirsts[SOURCE] = nil
            assert.same({ false, 'no_container' }, { draw.handle(SOURCE, 'puits_lavoir') })
            assert.equal(0, #thirstAdds)
        end)
    end)

    describe('refus', function()
        before_each(function()
            points.loadConfig()
            at(SOURCE, 'puits_lavoir')
            counts[SOURCE].outre = 1
        end)

        local function nothingDone()
            assert.equal(0, #exchanges)
            assert.equal(0, #thirstAdds)
            assert.equal(0, #afters)
        end

        it('sans personnage', function()
            active[SOURCE] = nil
            assert.same({ false, 'no_character' }, { draw.handle(SOURCE, 'puits_lavoir') })
            nothingDone()
        end)

        it('à terre', function()
            downed[SOURCE] = true
            assert.same({ false, 'downed' }, { draw.handle(SOURCE, 'puits_lavoir') })
            nothingDone()
        end)

        it('point inconnu', function()
            assert.same({ false, 'unknown_point' }, { draw.handle(SOURCE, 'citerne') })
            nothingDone()
        end)

        it('trop loin (3,6 m) ou sans ped ; à 3,5 m c\'est permis', function()
            at(SOURCE, 'puits_lavoir', 3.6)
            assert.same({ false, 'too_far' }, { draw.handle(SOURCE, 'puits_lavoir') })
            positions[SOURCE] = nil
            assert.same({ false, 'too_far' }, { draw.handle(SOURCE, 'puits_lavoir') })
            nothingDone()
            at(SOURCE, 'puits_lavoir', 3.5)
            assert.is_true(draw.handle(SOURCE, 'puits_lavoir'))
        end)

        it('inventaire muet', function()
            counts[SOURCE] = false
            assert.same({ false, 'unavailable' }, { draw.handle(SOURCE, 'puits_lavoir') })
            nothingDone()
        end)

        it('délai : un second appel 2 s après est refusé, 3 s après il passe', function()
            assert.is_true(draw.handle(SOURCE, 'puits_lavoir'))
            timer = timer + 2000
            assert.same({ false, 'wait' }, { draw.handle(SOURCE, 'puits_lavoir') })
            assert.equal(1, #exchanges)
            timer = timer + 1000
            assert.is_true(draw.handle(SOURCE, 'puits_lavoir'))
            assert.equal(2, #exchanges)
        end)

        it('une demande à la fois par joueur', function()
            local second
            exchangeDuring = function() second = { draw.handle(SOURCE, 'puits_lavoir') } end
            assert.is_true(draw.handle(SOURCE, 'puits_lavoir'))
            assert.same({ false, 'busy' }, second)
            assert.equal(1, #exchanges)
            -- rendu après le traitement, même en erreur
            timer = timer + cfg.cooldownMs
            VavaProvisions.bridge.Count = function() error('boum') end
            assert.same({ false, 'unavailable' }, { draw.handle(SOURCE, 'puits_lavoir') })
            assert.equal(1, #logs.error)
            VavaProvisions.bridge.Count = function() return 1 end
            assert.is_true(draw.handle(SOURCE, 'puits_lavoir'))
        end)

        it('hook drawing qui refuse : la raison (coupée à 200 octets) va au joueur', function()
            beforeAnswer = { false, 'Ce puits est gardé par la milice.' }
            assert.same({ false, 'refused', 'Ce puits est gardé par la milice.' }, { draw.handle(SOURCE, 'puits_lavoir') })
            beforeAnswer = { false, string.rep('x', 300) }
            local ok, code, reason = draw.handle(SOURCE, 'puits_lavoir')
            assert.same({ false, 'refused', 200 }, { ok, code, #reason })
            beforeAnswer = { false, 'hook_error' }
            assert.same({ false, 'unavailable' }, { draw.handle(SOURCE, 'puits_lavoir') })
            nothingDone()
            assert.equal(40, reserveOf('puits_lavoir'))
        end)

        it('oublie délai et demande en cours d\'un joueur parti', function()
            assert.is_true(draw.handle(SOURCE, 'puits_lavoir'))
            draw.forget(SOURCE)
            assert.is_true(draw.handle(SOURCE, 'puits_lavoir'))
        end)
    end)

    describe('outre rendue', function()
        local function drink(fields)
            local payload = { source = SOURCE, instanceId = 9, item = 'eau', consumed = true }
            for key, value in pairs(fields or {}) do payload[key] = value end
            containers.onUse(payload)
        end

        it('rend une outre vide au buveur, sans métadonnées', function()
            roll = 0.5
            drink()
            assert.same({ { source = SOURCE, item = 'outre', quantity = 1 } }, adds)
            assert.equal(0, #sent)
        end)

        it('une fois sur dix, l\'outre se fend : aucun ajout, un avis au seul buveur', function()
            roll = 0.05
            drink()
            assert.equal(0, #adds)
            assert.equal(1, #sent)
            assert.same({ target = SOURCE, event = EVENTS.NOTICE, args = { n = 1, 'torn' } }, sent[1])
        end)

        it('besace pleine : l\'outre est abandonnée, un avis au seul buveur', function()
            addAnswers = { { false, 'no_space' } }
            drink()
            assert.equal(1, #adds)
            assert.same({ target = SOURCE, event = EVENTS.NOTICE, args = { n = 1, 'lost' } }, sent[1])
            assert.equal(1, #logs.debug)
        end)

        it('rien si l\'unité n\'a pas été consommée, pour un autre objet, ou sans personnage', function()
            drink({ consumed = false })
            drink({ item = 'pain' })
            containers.onUse({ source = SOURCE, instanceId = 9, item = 'eau' })
            active[SOURCE] = nil
            drink()
            assert.equal(0, #adds)
            assert.equal(0, #sent)
        end)

        it('rien si le joueur a changé de personnage avant le thread', function()
            deferred = true
            drink()
            assert.equal(1, #queue)
            active[SOURCE] = 999
            queue[1]()
            assert.equal(0, #adds)
            assert.equal(0, #sent)
        end)

        -- T-135 : palier relevé avant la gorgée (la pile part avec sa dernière unité), outre rendue au même palier,
        -- risque de fente selon le palier
        describe('selon le palier', function()
            local function sip(instanceId, fields)
                local payload = { source = SOURCE, instanceId = instanceId, item = 'eau' }
                assert.is_nil(containers.beforeUse(payload))   -- jamais de refus
                payload.consumed = true
                for key, value in pairs(fields or {}) do payload[key] = value end
                containers.onUse(payload)
            end

            before_each(function()
                piles[SOURCE].eau = {
                    { id = 40, item = 'eau', quantity = 1, metadata = {} },
                    { id = 41, item = 'eau', quantity = 2, metadata = { tier = 1 } },
                    { id = 43, item = 'eau', quantity = 1, metadata = { tier = 3 } },
                    { id = 44, item = 'eau', quantity = 1, metadata = { tier = 4 } },
                }
            end)

            it('rend l\'outre vide au palier de l\'outre d\'eau bue, sans palier pour une outre sans palier', function()
                roll = 0.5
                sip(43)
                sip(41)
                sip(40)
                assert.same({
                    { source = SOURCE, item = 'outre', quantity = 1, metadata = { tier = 3 } },
                    { source = SOURCE, item = 'outre', quantity = 1, metadata = { tier = 1 } },
                    { source = SOURCE, item = 'outre', quantity = 1 },
                }, adds)
                assert.same({ { source = SOURCE, item = 'eau' }, { source = SOURCE, item = 'eau' }, { source = SOURCE, item = 'eau' } }, pileReads)
            end)

            it('même tirage : la Soignée tient, l\'outre sans palier se fend ; la Grossière se fend, l\'Excellente tient', function()
                roll = 0.06
                sip(43)
                sip(40)
                assert.same({ { source = SOURCE, item = 'outre', quantity = 1, metadata = { tier = 3 } } }, adds)
                assert.same({ target = SOURCE, event = EVENTS.NOTICE, args = { n = 1, 'torn' } }, sent[1])
                roll = 0.12
                sip(41)
                sip(44)
                assert.equal(2, #adds)
                assert.same({ tier = 4 }, adds[2].metadata)
                assert.equal(2, #sent)
            end)

            it('sans relevé (pile inconnue, inventaire muet, gorgée d\'avant un redémarrage) : risque et outre sans palier', function()
                roll = 0.5
                sip(99)                    -- pile absente de la besace
                piles[SOURCE].eau = false  -- inventaire muet
                sip(43)
                drink({ instanceId = 44 }) -- aucun relevé
                assert.equal(3, #adds)
                for _, add in ipairs(adds) do assert.is_nil(add.metadata) end
                roll = 0.06                -- risque sans palier (0,1) : fendue
                drink({ instanceId = 43 })
                assert.equal(3, #adds)
            end)

            it('un relevé ne sert qu\'une fois, et pas pour une autre pile', function()
                roll = 0.5
                containers.beforeUse({ source = SOURCE, instanceId = 43, item = 'eau' })
                drink({ instanceId = 41 })
                drink({ instanceId = 43 })
                drink({ instanceId = 43 })
                assert.same({ nil, { tier = 3 }, nil }, { adds[1].metadata, adds[2].metadata, adds[3].metadata })
            end)

            it('ne relève rien pour un autre objet ou un payload mal formé ; oublie les relevés d\'un joueur parti', function()
                roll = 0.5
                assert.is_nil(containers.beforeUse({ source = SOURCE, instanceId = 43, item = 'pain' }))
                assert.is_nil(containers.beforeUse({ source = SOURCE, instanceId = '43', item = 'eau' }))
                assert.is_nil(containers.beforeUse({ source = -1, instanceId = 43, item = 'eau' }))
                assert.is_nil(containers.beforeUse('eau'))
                assert.equal(0, #pileReads)
                containers.beforeUse({ source = SOURCE, instanceId = 43, item = 'eau' })
                containers.forget(SOURCE)
                drink({ instanceId = 43 })
                assert.is_nil(adds[1].metadata)
            end)

            it('gorgées refusées par un autre abonné : au plus 8 relevés gardés par joueur', function()
                roll = 0.5
                local list = {}
                for id = 101, 109 do list[#list + 1] = { id = id, item = 'eau', quantity = 1, metadata = { tier = 2 } } end
                piles[SOURCE].eau = list
                -- huit relevés jamais bus, puis un neuvième : la table du joueur repart de zéro
                for id = 101, 109 do containers.beforeUse({ source = SOURCE, instanceId = id, item = 'eau' }) end
                drink({ instanceId = 101 })
                drink({ instanceId = 109 })
                assert.is_nil(adds[1].metadata)
                assert.same({ tier = 2 }, adds[2].metadata)
            end)
        end)
    end)

    describe('objets et recette', function()
        it('déclare les objets manquants avec l\'image du module, sans remplacer ceux d\'une autre ressource', function()
            itemsKnown.eau = true
            items.declare()
            assert.equal(1, #itemsAdded)
            assert.equal('outre', itemsAdded[1].name)
            assert.equal('nui://vava_provisions/web/items/outre.svg', itemsAdded[1].def.image)
            assert.equal('Outre vide', itemsAdded[1].def.label)
            assert.equal(1, #logs.warn)
            assert.matches("'eau'", logs.warn[1])
            -- relancé : rien de plus, pas de second avertissement
            items.declare()
            assert.equal(1, #itemsAdded)
            assert.equal(1, #logs.warn)
        end)

        it('redéclare ses objets au retour de l\'inventaire', function()
            items.declare()
            assert.equal(2, #itemsAdded)
            itemsKnown = {}
            items.onInventoryReady()
            assert.equal(4, #itemsAdded)
            assert.equal(0, #logs.warn)
        end)

        it('recette sans artisanat : un avertissement, rien d\'autre', function()
            recipeAnswers = { { false, 'artisanat absent (vava_crafting)' } }
            assert.is_false(items.declareRecipe())
            assert.equal(1, #logs.warn)
            assert.matches("recette de l'outre non déclarée", logs.warn[1])
            assert.is_true(items.declareRecipe())
            assert.equal(1, #logs.warn)
        end)
    end)

    describe('/eau', function()
        local MEMBER = 8

        before_each(function()
            points.loadConfig()
            active[MEMBER] = 300
        end)

        it('sans droit : rien, ni réponse ni journal', function()
            admin.command(SOURCE, { 'reserve', 'puits_lavoir', '2' })
            admin.command(SOURCE, { 'points' })
            assert.equal(0, #chats)
            assert.equal(0, #adminLogs)
            assert.equal(40, reserveOf('puits_lavoir'))
        end)

        it('points : une ligne par point, dans la console', function()
            admin.command(0, { 'points' })
            assert.same({
                { source = 0, text = 'Fontaine du bourg (fontaine_bourg, fontaine) : sans fond.\n'
                    .. 'Puits du lavoir (puits_lavoir, puits) : 40 / 40 puisages.\n'
                    .. 'Source de la Rivière Claire (source_claire, source) : 15 / 15 puisages.' },
            }, chats)
            assert.equal(0, #adminLogs)
        end)

        it('reserve : fixée, au journal du Registre, réponse au seul membre', function()
            admin.command(MEMBER, { 'reserve', 'puits_lavoir', '2' })
            assert.equal(2, reserveOf('puits_lavoir'))
            assert.same({ { source = MEMBER, label = 'Réserve d\'eau fixée', details = { point = 'puits_lavoir', reserve = 2, before = 40 } } }, adminLogs)
            assert.same({ { source = MEMBER, text = 'Réserve de Puits du lavoir : 2 / 40.' } }, chats)
        end)

        it('refuse une sorte sans fond, une réserve hors bornes, un point inconnu, une ligne mal formée', function()
            admin.command(0, { 'reserve', 'fontaine_bourg', '3' })
            admin.command(0, { 'reserve', 'puits_lavoir', '41' })
            admin.command(0, { 'reserve', 'citerne', '3' })
            admin.command(0, { 'remplir' })
            assert.same({
                'Fontaine du bourg est sans fond : rien à régler.',
                'La réserve de Puits du lavoir va de 0 à 40.',
                'Point d\'eau inconnu : citerne.',
                'usage : /eau points | reserve <point> <nombre>',
            }, { chats[1].text, chats[2].text, chats[3].text, chats[4].text })
            assert.equal(0, #adminLogs)
            assert.equal(40, reserveOf('puits_lavoir'))
        end)

        it('points : regroupées en messages de 480 octets au plus, 60 points au plus puis « … et N autres »', function()
            for i = 1, 67 do
                assert.is_true(points.put({ id = 'puits_' .. i, kind = 'puits', label = 'Puits numéro ' .. i, x = i * 10.0, y = 0.0, z = 0.0 }))
            end
            admin.command(0, { 'points' })
            assert.is_true(#chats > 1)
            local lines = 0
            for _, chat in ipairs(chats) do
                assert.is_true(#chat.text <= 480, #chat.text .. ' octets')
                for _ in chat.text:gmatch('[^\n]+') do lines = lines + 1 end
            end
            assert.equal(61, lines)
            assert.matches('… et 10 autres points d\'eau%.$', chats[#chats].text)
        end)

        it('délai entre deux commandes d\'un même membre (console exceptée)', function()
            admin.command(MEMBER, { 'points' })
            timer = timer + 500
            admin.command(MEMBER, { 'reserve', 'puits_lavoir', '2' })
            assert.equal('Patientez un instant.', chats[#chats].text)
            assert.equal(0, #adminLogs)
            timer = timer + 500
            admin.command(MEMBER, { 'reserve', 'puits_lavoir', '2' })
            assert.equal(1, #adminLogs)
            admin.command(0, { 'points' })
            admin.command(0, { 'points' })
            assert.equal(1 + 1 + 1 + 1 + 1, #chats)
        end)
    end)
end)

-- Démarrage réel : bridge/server.lua et server/main.lua sur un core simulé (registres, zones, RPC, hooks, réseau,
-- exports des autres ressources).
describe('vava_provisions démarrage', function()
    local core, registries, regAdds, hooks, rpcs, zones, sent, exported, resources, setup, logs
    local active, peds, inventoryCalls, needsCalls, stock, befores
    local realRandom = math.random

    local function registry(name)
        registries[name] = registries[name] or {}
        return registries[name]
    end

    local function fire(name, payload)
        for _, fn in ipairs(hooks[name] or {}) do fn(payload) end
    end

    before_each(function()
        helper.reset()
        VavaProvisions = nil
        registries, regAdds, hooks, rpcs, zones, sent, exported = {}, {}, {}, {}, {}, {}, {}
        active, peds, inventoryCalls, needsCalls = { [5] = 100 }, {}, {}, {}
        -- piles de la besace lues par getItems : deux outres sans palier
        stock, befores = { outre = { { id = 7, item = 'outre', quantity = 2, metadata = {} } } }, {}
        local log
        logs, log = newLogs()
        resources = {
            vava_inventory = {
                count = function(_, _, item) inventoryCalls[#inventoryCalls + 1] = { 'count', item } return 2 end,
                exchange = function(_, src, removals, additions)
                    inventoryCalls[#inventoryCalls + 1] = { 'exchange', src, copy(removals), copy(additions) }
                    return true
                end,
                add = function(_, src, item, quantity, metadata)
                    inventoryCalls[#inventoryCalls + 1] = { 'add', src, item, quantity, copy(metadata) }
                    return true
                end,
                getItems = function(_, src, filter)
                    inventoryCalls[#inventoryCalls + 1] = { 'getItems', src, copy(filter) }
                    return copy(stock[filter.item] or {})
                end,
            },
            vava_needs = {
                get = function() return { hunger = 80, thirst = 50 } end,
                add = function(_, src, values) needsCalls[#needsCalls + 1] = { src, copy(values) } return true, values end,
            },
        }
        _G.GetResourceState = function(name) return resources[name] and 'started' or 'missing' end
        _G.exports = setmetatable({}, {
            __call = function(_, name, fn) exported[name] = fn end,
            __index = function(_, name) return resources[name] end,
        })
        _G.GetPlayerPed = function(src) return peds[src] and src or 0 end
        _G.DoesEntityExist = function(ped) return ped ~= 0 end
        _G.GetEntityCoords = function(ped)
            local p = peds[ped]
            return { x = p[1], y = p[2], z = p[3] }
        end
        _G.TriggerClientEvent = function() error('TriggerClientEvent ne doit pas servir : core.net est là') end
        _G.IsPlayerAceAllowed = function() return false end
        _G.RegisterCommand = function() end

        core = {
            log = log,
            registry = {
                exists = function(name) return registries[name] ~= nil end,
                has = function(name, key) return registries[name] ~= nil and registries[name][key] ~= nil end,
                add = function(name, key, data)
                    local reg = registries[name]
                    if not reg then return false, 'unknown_registry' end
                    if reg[key] ~= nil then return false, 'exists' end
                    reg[key] = copy(data)
                    regAdds[#regAdds + 1] = name .. '/' .. key
                    return true
                end,
            },
            players = { get = function(src) return active[src] and { state = 'active' } or nil end },
            characters = { getActive = function(src) return active[src] and { id = active[src] } or nil end },
            zones = {
                define = function(id, area, state)
                    zones[#zones + 1] = { id = id, area = copy(area), state = copy(state) }
                    return true, #zones
                end,
            },
            net = {
                send = function(target, event, ...)
                    assert.equal('integer', math.type(target))
                    sent[#sent + 1] = { target = target, event = event, args = table.pack(...) }
                    return true
                end,
            },
            hooks = {
                after = function(name, fn)
                    hooks[name] = hooks[name] or {}
                    hooks[name][#hooks[name] + 1] = fn
                    return #hooks[name]
                end,
                before = function(name, fn, priority)
                    befores[#befores + 1] = { name = name, fn = fn, priority = priority }
                    return #befores
                end,
                runBefore = function() return true end,
                runAfter = function() end,
            },
            rpc = {
                register = function(name, options, handler)
                    rpcs[name] = { options = copy(options), handler = handler }
                    return true
                end,
            },
            modules = { register = function(def) setup = def.setup return true end },
        }
        registry('core:commands')
        registry('vava_inventory:items')
        -- tirage fixé avant le chargement (containers.lua le garde en local) : l'outre est gardée
        math.random = function() return 0.5 end

        helper.loadAll(BASE_FILES)
        VavaProvisions.core, VavaProvisions.log, VavaProvisions.resource, VavaProvisions.ready = core, log, 'vava_provisions', false
        helper.loadAll({
            'modules/vava_provisions/bridge/server.lua',
            'modules/vava_provisions/server/items.lua',
            'modules/vava_provisions/server/points.lua',
            'modules/vava_provisions/server/draw.lua',
            'modules/vava_provisions/server/containers.lua',
            'modules/vava_provisions/server/admin.lua',
            'modules/vava_provisions/server/commands.lua',
            'modules/vava_provisions/server/api.lua',
            'modules/vava_provisions/server/main.lua',
        })
    end)

    after_each(function()
        math.random = realRandom
        VavaProvisions = nil
    end)

    it('démarre sans artisanat : objets, zones, RPC borné, hooks, Codex ; un avertissement pour la recette', function()
        assert.is_function(setup)
        assert.same({ true }, { setup() })
        assert.is_true(VavaProvisions.ready)
        assert.is_table(registries['core:commands'].eau)
        assert.is_table(registries['core:commands'].vava_provisions_interact)
        assert.equal('Vivres', registries['core:commands'].eau.chapter)
        assert.equal('E', registries['core:commands'].vava_provisions_interact.key)
        assert.equal('nui://vava_provisions/web/items/eau.svg', registries['vava_inventory:items'].eau.image)
        assert.equal('nui://vava_provisions/web/items/outre.svg', registries['vava_inventory:items'].outre.image)
        assert.equal(3, #zones)
        local draw = rpcs['vava_provisions:draw']
        assert.same({ { type = 'string', min = 1, max = 32, pattern = '^[a-z0-9_]+$' } }, draw.options.args)
        assert.same({ capacity = 3, refillPerSecond = 0.5 }, draw.options.rateLimit)
        for _, name in ipairs({ 'vava_inventory:use', 'core:module:ready', 'core:character:unloading', 'core:player:dropped' }) do
            assert.equal(1, #(hooks[name] or {}), name)
        end
        -- palier de l'outre relevé avant la gorgée : un seul abonné before, le dernier de la chaîne (T-135)
        assert.equal(1, #befores)
        assert.same({ 'vava_inventory:use', 1000 }, { befores[1].name, befores[1].priority })
        assert.equal(1, #logs.warn)
        assert.matches("recette de l'outre non déclarée", logs.warn[1])
    end)

    it('refuse une config invalide avec le chemin fautif', function()
        VavaProvisions.config.points[2].label = ''
        assert.same({ false, 'config : points[2].label : invalid_label' }, { setup() })
        assert.is_false(VavaProvisions.ready)
    end)

    -- T-143 : textes du Conseil passés de config_client.lua à config.lua en 1.2.0
    it('refuse un config.lua de 1.1.0 gardé, sans les textes du Conseil', function()
        VavaProvisions.config.messages.journal = nil
        local ok, why = setup()
        assert.is_false(ok)
        assert.matches("config.lua d'avant 1.2.0 : messages.admin et messages.journal", why, 1, true)
        assert.is_false(VavaProvisions.ready)
    end)

    it('signale un config_client.lua de 1.1.0 gardé qui sert encore les textes du Conseil (relecture S-2)', function()
        assert.is_false(VavaProvisions.legacyClientTexts)
        VavaProvisions.legacyClientTexts = true
        assert.same({ true }, { setup() })
        local found = 0
        for _, line in ipairs(logs.warn) do
            if line:find('config_client.lua garde les textes du Conseil', 1, true) then found = found + 1 end
        end
        assert.equal(1, found)
    end)

    it('config.lua relève les textes du Conseil laissés dans config_client.lua avant de poser les siens', function()
        helper.reset()
        VavaProvisions = nil
        local root = (os.getenv('VAVA_ROOT') or '.') .. '/modules/vava_provisions/'
        assert(loadfile(root .. 'shared/constants.lua'))()
        assert(loadfile(root .. 'config_client.lua'))()
        VavaProvisions.config.messages.admin = { usage = 'ancien texte' }   -- forme de 1.1.0
        assert(loadfile(root .. 'config.lua'))()
        assert.is_true(VavaProvisions.legacyClientTexts)
        assert.equal('usage : /%s points | reserve <point> <nombre>', VavaProvisions.config.messages.admin.usage)
    end)

    it('déclare la recette une fois quand l\'artisanat (puis les compétences) arrive', function()
        setup()
        registry('vava_crafting:recipes')
        registry('vava_crafting:stations').tannerie = { label = 'Tannerie' }
        registry('vava_skills:recipes')
        regAdds = {}
        fire('core:module:ready', { name = 'vava_crafting' })
        assert.same({ 'vava_crafting:recipes/outre', 'vava_skills:recipes/outre' }, regAdds)
        assert.is_nil(registries['vava_crafting:recipes'].outre.id)
        assert.equal('tannerie', registries['vava_crafting:recipes'].outre.station)
        assert.same({ label = 'Outre', skill = 'tannerie', level = 0, transmission = false }, registries['vava_skills:recipes'].outre)
        fire('core:module:ready', { name = 'vava_skills' })
        fire('core:module:ready', { name = 'vava_crafting' })
        assert.equal(2, #regAdds)
    end)

    it('sans tannerie à l\'artisanat : avertissement, rien de déclaré', function()
        registry('vava_crafting:recipes')
        registry('vava_crafting:stations')
        setup()
        assert.is_nil(registries['vava_crafting:recipes'].outre)
        assert.matches('tannerie', logs.warn[1])
    end)

    it('redéclare ses objets au retour de l\'inventaire', function()
        setup()
        registries['vava_inventory:items'] = {}
        fire('core:module:ready', { name = 'vava_inventory' })
        assert.is_table(registries['vava_inventory:items'].eau)
        assert.is_table(registries['vava_inventory:items'].outre)
        fire('core:module:ready', { name = 'vava_codex' })
    end)

    it('puise, boit et rend l\'outre par les exports des autres modules ; avis par core.net au seul buveur', function()
        setup()
        local fontaine = VavaProvisions.config.points[1]
        peds[5] = { fontaine.x + 1, fontaine.y, fontaine.z }
        local handler = rpcs['vava_provisions:draw'].handler
        assert.same({ true, { action = 'fill', count = 2 } }, { handler(5, 'fontaine_bourg') })
        assert.same({ 'count', 'outre' }, inventoryCalls[1])
        assert.same({ 'getItems', 5, { item = 'outre' } }, inventoryCalls[2])
        assert.same({ 'exchange', 5, { { instanceId = 7, quantity = 2 } }, { { item = 'eau', quantity = 2 } } }, inventoryCalls[3])

        resources.vava_inventory.count = function() return 0 end
        assert.same({ false, 'wait' }, { handler(5, 'fontaine_bourg') })

        -- exports serveur
        local list = exported.getPoints()
        assert.equal(3, #list)
        assert.same({ level = 40, capacity = 40 }, list[2].reserve)
        assert.is_nil(list[1].reserve)
        assert.same({ nil, 'unknown_point' }, { exported.getPoint('citerne') })
        assert.equal('Puits du lavoir', exported.getPoint('puits_lavoir').label)
        local id, distance = exported.pointNear(5)
        assert.equal('fontaine_bourg', id)
        assert.is_near(1, distance, 1e-9)
        assert.is_nil(exported.pointNear(5, 0.5))
        assert.same({ nil, 'invalid_target' }, { exported.pointNear(-1) })
        assert.same({ { value = 'fontaine_bourg', label = 'Fontaine du bourg' }, { value = 'puits_lavoir', label = 'Puits du lavoir' },
            { value = 'source_claire', label = 'Source de la Rivière Claire' } }, exported.codexList('points'))

        -- outre bue : thread exécuté aussitôt, outre vide ajoutée par l'inventaire, rien d'envoyé
        fire('vava_inventory:use', { source = 5, item = 'eau', consumed = true })
        assert.same({ 'add', 5, 'outre', 1 }, inventoryCalls[#inventoryCalls])
        assert.equal(0, #sent)
        -- outre d'eau Soignée : palier relevé par l'abonné before (getItems), outre vide Soignée rendue (T-135)
        stock.eau = { { id = 12, item = 'eau', quantity = 1, metadata = { tier = 3 } } }
        assert.is_nil(befores[1].fn({ source = 5, instanceId = 12, item = 'eau' }))
        assert.same({ 'getItems', 5, { item = 'eau' } }, inventoryCalls[#inventoryCalls])
        fire('vava_inventory:use', { source = 5, instanceId = 12, item = 'eau', consumed = true })
        assert.same({ 'add', 5, 'outre', 1, { tier = 3 } }, inventoryCalls[#inventoryCalls])
        assert.equal(0, #sent)
        -- besace pleine : avis par core.net au seul buveur
        resources.vava_inventory.add = function() return false, 'no_space' end
        fire('vava_inventory:use', { source = 5, item = 'eau', consumed = true })
        assert.same({ { target = 5, event = 'vava_provisions:notice', args = { n = 1, 'lost' } } }, sent)
    end)

    it('boit par vava_needs, sans lui on ne boit pas', function()
        setup()
        local puits = VavaProvisions.config.points[2]
        peds[5] = { puits.x, puits.y, puits.z }
        resources.vava_inventory.count = function() return 0 end
        local handler = rpcs['vava_provisions:draw'].handler
        assert.same({ true, { action = 'drink', dry = false } }, { handler(5, 'puits_lavoir') })
        assert.same({ { 5, { thirst = 20 } } }, needsCalls)
        resources.vava_needs = nil
        VavaProvisions.draw.forget(5)
        assert.same({ false, 'no_container' }, { handler(5, 'puits_lavoir') })
    end)
end)
