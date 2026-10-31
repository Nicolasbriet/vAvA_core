local helper = require('tests.helper')

-- Chaîne de dégâts côté serveur (modules/vava_health/server/life.lua, modifiers.lua, chain.lua, journal.lua,
-- natives.lua, api.lua, main.lua ; spec T-110 § 7 et § 11.1) avec des doublures : core (hooks qui notent before et
-- after et copient leur charge comme une traversée d'export, registre en mémoire avec ses hooks, personnages, envois
-- notés, base en mémoire), natives du ped réglables, CancelEvent noté, horloge fixe, SetTimeout et CreateThread
-- déclenchés à la main.
describe('vava_health chaîne de dégâts (serveur)', function()
    local api, life, hits, journal, modifiers, cfg, EVENTS, HOOKS
    local now, peds, entityHealth, active, fields
    local sent, logs, queries, hookCalls, registered, handlers, cancelled, threads, entities
    local hooksBefore, hooksAfter, registries, propagateAfterErrors
    local dbFails, deathSource

    local A, B, C = 1, 2, 3
    local CHAR = { [A] = 101, [B] = 102, [C] = 103 }

    local function copy(value)
        if type(value) ~= 'table' then return value end
        local out = {}
        for key, item in pairs(value) do out[key] = copy(item) end
        return out
    end

    local function ratioToGame(ratio)
        return math.floor(100 + ratio * 100 + 0.5)
    end

    --- Envois vers un joueur (évènement facultatif).
    local function sentTo(target, event)
        local out = {}
        for _, s in ipairs(sent) do
            if s.target == target and (not event or s.event == event) then out[#out + 1] = s end
        end
        return out
    end

    local function logged(pattern)
        local count = 0
        for _, line in ipairs(logs) do
            if line:find(pattern, 1, true) then count = count + 1 end
        end
        return count
    end

    local function calls(name, phase)
        local out = {}
        for _, call in ipairs(hookCalls) do
            if call.name == name and (not phase or call.phase == phase) then out[#out + 1] = call end
        end
        return out
    end

    --- SetTimeout(0) en attente : déclenchés (fin du tour), les autres gardés.
    local function endTurn()
        local pending = helper.timers
        helper.timers = {}
        for _, timer in ipairs(pending) do
            if timer.ms == 0 then timer.fn() else helper.timers[#helper.timers + 1] = timer end
        end
    end

    local function fire(name, payload)
        for _, h in ipairs(hooksAfter[name] or {}) do h.fn(copy(payload)) end
    end

    local function load(src, health, spawned)
        active[src] = { id = CHAR[src] }
        peds[src] = 1000 + src
        fire('core:character:loaded', { source = src, characterId = CHAR[src] })
        if spawned ~= false then fire('core:character:spawned', { source = src, characterId = CHAR[src] }) end
        local entry = life.entry(src)
        entry.health = health or 1.0
        entityHealth[peds[src]] = ratioToGame(entry.health)
        -- délai de grâce passé
        entry.graceUntil = now - 1
        return entry
    end

    local function hit(target, packet)
        return registered.hit(target, packet)
    end

    local function addModifier(key, data, owner)
        local def = registries['vava_health:modifiers']
        local ok, reason = def.validator(key, data)
        assert.is_true(ok, reason)
        def.entries[key] = { owner = owner or 'vava_test', data = data }
        fire('core:registry:added', { registry = 'vava_health:modifiers', key = key, owner = owner or 'vava_test' })
    end

    before_each(function()
        helper.reset()
        VavaHealth = nil
        now = 100000
        peds, entityHealth, active, fields = {}, {}, {}, {}
        sent, logs, queries, hookCalls, registered, handlers, cancelled, threads, entities = {}, {}, {}, {}, {}, {}, {}, {}, {}
        hooksBefore, hooksAfter, registries, propagateAfterErrors = {}, {}, {}, false
        dbFails, deathSource = nil, 0

        local function log(level)
            return function(fmt, ...) logs[#logs + 1] = level .. ' ' .. string.format(fmt, ...) end
        end

        local function addHook(store, name, fn, priority)
            store[name] = store[name] or {}
            table.insert(store[name], { fn = fn, priority = priority or 100 })
            table.sort(store[name], function(a, b) return a.priority < b.priority end)
            return #store[name]
        end

        local core
        core = {
            log = { debug = log('debug'), info = log('info'), warn = log('warn'), error = log('error') },
            hooks = {
                before = function(name, fn, priority) return addHook(hooksBefore, name, fn, priority) end,
                after = function(name, fn, priority) return addHook(hooksAfter, name, fn, priority) end,
                runBefore = function(name, payload)
                    hookCalls[#hookCalls + 1] = { name = name, phase = 'before', payload = copy(payload) }
                    for _, h in ipairs(hooksBefore[name] or {}) do
                        local ok, result, reason = pcall(h.fn, copy(payload))
                        if not ok then return false, 'hook_error' end
                        if result == false then return false, type(reason) == 'string' and reason or 'cancelled' end
                    end
                    return true
                end,
                runAfter = function(name, payload)
                    hookCalls[#hookCalls + 1] = { name = name, phase = 'after', payload = copy(payload) }
                    for _, h in ipairs(hooksAfter[name] or {}) do
                        if propagateAfterErrors then
                            h.fn(copy(payload))
                        else
                            pcall(h.fn, copy(payload))
                        end
                    end
                end,
            },
            registry = {
                define = function(name, options)
                    registries[name] = { validator = options.validator, maxEntries = options.maxEntries, entries = {},
                        schema = options.schema }
                    return true
                end,
                exists = function(name) return registries[name] ~= nil end,
                has = function(name, key) return registries[name] ~= nil and registries[name].entries[key] ~= nil end,
                get = function(name, key)
                    local def = registries[name]
                    local entry = def and def.entries[key]
                    return entry and entry.data
                end,
                add = function() return false, 'doublure : passer par addModifier' end,
                remove = function(name, key)
                    local def = registries[name]
                    local entry = def and def.entries[key]
                    if not entry then return false, 'absente' end
                    def.entries[key] = nil
                    fire('core:registry:removed', { registry = name, key = key, owner = entry.owner, reason = 'removed' })
                    return true
                end,
            },
            characters = {
                defineField = function() return true end,
                get = function(characterId, field) return fields[characterId .. field] end,
                set = function(characterId, field, value)
                    fields[characterId .. field] = copy(value)
                    return true
                end,
                getActive = function(src) return active[src] and copy(active[src]) or nil end,
                spawn = function() return true end,
            },
            net = {
                send = function(target, event, ...)
                    assert(math.type(target) == 'integer' and target > 0, 'cible invalide : ' .. tostring(target))
                    sent[#sent + 1] = { target = target, event = event, args = { ... } }
                    return true, 1, 26, false
                end,
            },
            db = {
                query = function(sql, params)
                    queries[#queries + 1] = { sql = sql, params = params }
                    if dbFails and dbFails(sql, params) then return nil, 'refus de la base' end
                    return {}
                end,
                update = function(sql, params)
                    queries[#queries + 1] = { sql = sql, params = params }
                    return 0
                end,
            },
            rpc = { register = function() return true end },
            modules = { register = function(def) core.def = def; return true end },
        }

        local exportsTable = setmetatable({
            vAvA_core = { getApi = function() return core end },
        }, {
            __call = function(_, name, fn) registered[name] = fn end,
        })
        _G.exports = exportsTable

        _G.GetCurrentResourceName = function() return 'vava_health' end
        _G.GetResourceMetadata = function() return '1.3.0' end
        _G.GetInvokingResource = function() return 'vava_test' end
        _G.GetResourceState = function() return 'stopped' end
        _G.GetGameTimer = function() return now end
        _G.CreateThread = function(fn) threads[#threads + 1] = fn end
        _G.GetPlayers = function()
            local out = {}
            for src in pairs(active) do out[#out + 1] = tostring(src) end
            return out
        end
        _G.GetPlayerPed = function(src) return peds[src] or 0 end
        _G.DoesEntityExist = function(entity) return entity ~= nil and entity ~= 0 and (entityHealth[entity] ~= nil or entities[entity] ~= nil) end
        _G.GetEntityHealth = function(ped) return entityHealth[ped] or 0 end
        _G.GetEntityMaxHealth = function() return 200 end
        _G.GetEntityCoords = function(ped) return { x = ped + 0.5, y = 2.0, z = 3.0 } end
        _G.GetPedCauseOfDeath = function() return 0 end
        _G.GetPedSourceOfDeath = function() return deathSource end
        _G.GetPlayerPing = function() return 40 end
        _G.TriggerClientEvent = function() error('TriggerClientEvent direct interdit (core.net présent)') end
        _G.AddEventHandler = function(name, fn) handlers[name] = fn end
        _G.CancelEvent = function() cancelled[#cancelled + 1] = true end
        _G.NetworkGetEntityFromNetworkId = function(netId) return entities[netId] and netId or 0 end
        _G.GetEntityType = function(entity) return entities[entity] and entities[entity].type or 0 end
        _G.IsPedAPlayer = function(entity) return entities[entity] ~= nil and entities[entity].player == true end
        _G.NetworkGetEntityOwner = function(entity) return entities[entity] and entities[entity].owner or 0 end
        _G.RegisterCommand = function() end

        helper.loadAll({
            'modules/vava_health/shared/constants.lua',
            'modules/vava_health/config.lua',
            'modules/vava_health/shared/vitality.lua',
            'modules/vava_health/shared/packet.lua',
            'modules/vava_health/shared/chain.lua',
            'modules/vava_health/shared/sync.lua',
            'modules/vava_health/server/core.lua',
            'modules/vava_health/server/state.lua',
            'modules/vava_health/server/journal.lua',
            'modules/vava_health/server/life.lua',
            'modules/vava_health/server/modifiers.lua',
            'modules/vava_health/server/chain.lua',
            'modules/vava_health/server/natives.lua',
            'modules/vava_health/server/assist.lua',
            'modules/vava_health/server/links.lua',
            'modules/vava_health/server/api.lua',
            'modules/vava_health/server/commands.lua',
            'modules/vava_health/server/main.lua',
        })
        local ok, err = core.def.setup()
        assert.is_true(ok, err)
        api, life, hits, journal, modifiers = registered, VavaHealth.life, VavaHealth.hits, VavaHealth.journal, VavaHealth.modifiers
        cfg, EVENTS, HOOKS = VavaHealth.config, VavaHealth.EVENTS, VavaHealth.HOOKS
        -- purge du démarrage (thread) : rien à retirer
        threads = {}
        queries = {}
    end)

    after_each(function()
        for _, s in ipairs(sent) do
            assert.equal('integer', math.type(s.target))
            assert.is_true(s.target > 0)
        end
        _G.exports = nil
        VavaHealth = nil
    end)

    describe('coup appliqué', function()
        it('baisse la vie du serveur et n\'envoie la vie qu\'à la cible, en fin de tour', function()
            load(A)
            load(B)
            local result, code = hit(B, { amount = 25, kind = 'tranchant', source = A })
            assert.is_nil(code)
            assert.equal(25, result.applied)
            assert.equal(25, result.amount)
            assert.equal(0.75, result.health)
            assert.is_false(result.downed)
            assert.is_nil(result.cancelled)
            assert.equal('integer', math.type(result.id))
            assert.equal(0, #sentTo(B, EVENTS.SET))
            endTurn()
            local sets = sentTo(B, EVENTS.SET)
            assert.equal(1, #sets)
            assert.equal(0.75, sets[1].args[1])
            assert.equal(0, #sentTo(A))
        end)

        it('regroupe les coups d\'un même tour en un seul envoi, avec la valeur finale', function()
            load(B)
            hit(B, { amount = 10, kind = 'feu' })
            hit(B, { amount = 10, kind = 'feu' })
            hit(B, { amount = 5, kind = 'feu' })
            endTurn()
            local sets = sentTo(B, EVENTS.SET)
            assert.equal(1, #sets)
            assert.is_near(0.75, sets[1].args[1], 1e-9)
        end)

        it('met à terre aussitôt quand la vie du serveur atteint 0, avant le hook after', function()
            load(A)
            load(B, 0.4)
            local result = hit(B, { amount = 100, kind = 'contondant', source = A })
            assert.equal(40, result.applied)
            assert.is_true(result.downed)
            assert.equal(0, result.health)
            assert.equal(1, #sentTo(B, EVENTS.DOWN))
            local order = {}
            for _, call in ipairs(hookCalls) do
                if call.phase == 'after' and (call.name == HOOKS.DOWNED or call.name == HOOKS.HIT) then
                    order[#order + 1] = call.name
                end
            end
            assert.same({ HOOKS.DOWNED, HOOKS.HIT }, order)
            local downed = calls(HOOKS.DOWNED)[1].payload
            assert.equal('hit', downed.reason)
            assert.equal(A, downed.killer)
            assert.equal('contondant', downed.cause)
            assert.equal('vava_test', downed.origin)
            assert.equal(result.id, downed.hitId)
            endTurn()
            assert.equal(0, #sentTo(B, EVENTS.SET))
            -- champ écrit aussitôt (transition)
            assert.is_true(fields[CHAR[B] .. VavaHealth.FIELD].downed)
        end)

        it('annule un coup sur une cible à terre, sans hook ni journal', function()
            load(B)
            life.down(B, 'api')
            hookCalls = {}
            local result = hit(B, { amount = 10, kind = 'tranchant', source = A })
            assert.equal('downed', result.cancelled)
            assert.equal(0, result.applied)
            assert.equal(0, #calls(HOOKS.HIT))
            assert.equal(0, journal.pending())
        end)

        it('touche une cible dont l\'apparition n\'est pas confirmée', function()
            load(B, 1.0, false)
            local result, code = hit(B, { amount = 10, kind = 'tranchant' })
            assert.is_nil(code)
            assert.equal(10, result.applied)
        end)

        it('signe le coup du nom de la ressource appelante, jamais de celui du paquet', function()
            load(A)
            load(B)
            hit(B, { amount = 10, kind = 'tranchant', source = A, technique = 'taille_descendante', weapon = 'epee' })
            local before = calls(HOOKS.HIT, 'before')[1].payload
            local after = calls(HOOKS.HIT, 'after')[1].payload
            assert.equal('vava_test', before.origin)
            assert.equal('vava_test', after.origin)
            assert.equal(CHAR[A], after.sourceCharacter)
            assert.equal(10, after.base)
            assert.equal(10, after.applied)
            assert.equal(1, journal.pending())
            journal.flushAll()
            assert.equal(1, #queries)
            local params = queries[1].params
            assert.equal(CHAR[B], params[2])
            assert.equal(CHAR[A], params[3])
            assert.equal('vava_test', params[4])
            assert.equal('tranchant', params[5])
            assert.equal('taille_descendante', params[6])
            assert.equal('epee', params[7])
            local refused, code = hit(B, { amount = 10, kind = 'tranchant', origin = 'vava_magic' })
            assert.is_nil(refused)
            assert.equal('unknown_field', code)
        end)

        it('laisse le hook before refuser : aucun modificateur, hook after émis', function()
            load(B)
            local called = 0
            addModifier('vava_test:bouclier', { stage = 'bouclier', label = 'Bouclier', apply = function()
                called = called + 1
                return { absorbed = 5 }
            end })
            hooksBefore[HOOKS.HIT] = { { fn = function() return false, 'treve' end, priority = 100 } }
            local result = hit(B, { amount = 10, kind = 'tranchant' })
            assert.equal('treve', result.cancelled)
            assert.equal('before', result.stage)
            assert.equal(0, result.applied)
            assert.equal(0, called)
            assert.equal(1, #calls(HOOKS.HIT, 'after'))
            assert.equal(1.0, life.entry(B).health)
        end)

        it('coupe les combats entre joueurs d\'un réglage', function()
            load(A)
            load(B)
            cfg.chain.pvp = false
            assert.equal('pvp_off', hit(B, { amount = 10, kind = 'tranchant', source = A }).cancelled)
            assert.equal(10, hit(B, { amount = 10, kind = 'tranchant', source = B }).applied)
            assert.equal(10, hit(B, { amount = 10, kind = 'privation' }).applied)
            cfg.chain.pvp = true
        end)

        it('borne les coups par cible et par seconde', function()
            load(B)
            load(C)
            for i = 1, 20 do
                local result = hit(B, { amount = 0.5, kind = 'feu' })
                assert.is_table(result, 'coup ' .. i)
            end
            local refused, code = hit(B, { amount = 0.5, kind = 'feu' })
            assert.is_nil(refused)
            assert.equal('too_many_hits', code)
            assert.equal(1, logged('plus de 20 coups'))
            assert.equal(0.5, hit(C, { amount = 0.5, kind = 'feu' }).applied)
            now = now + 1000
            assert.is_table(hit(B, { amount = 0.5, kind = 'feu' }))
        end)

        it('compte le débit par paire (cible, source) : une rafale n\'épuise pas celui des autres', function()
            load(A)
            load(B)
            load(C)
            for i = 1, 20 do assert.is_table(hit(B, { amount = 0.5, kind = 'feu', source = A }), 'coup ' .. i) end
            assert.equal('too_many_hits', select(2, hit(B, { amount = 0.5, kind = 'feu', source = A })))
            assert.equal(0.5, hit(B, { amount = 0.5, kind = 'feu', source = C }).applied)
            assert.equal(0.5, hit(B, { amount = 0.5, kind = 'feu' }).applied)
            -- départ de la source : son compte disparaît
            hits.forget(A)
            assert.is_table(hit(B, { amount = 0.5, kind = 'feu', source = A }))
        end)

        it('laisse passer un coup dont un abonné before est en erreur (un refus reste un refus)', function()
            load(B)
            hooksBefore[HOOKS.HIT] = { { priority = 100, fn = function() error('abonné en panne') end } }
            for _ = 1, 2 do
                local result = hit(B, { amount = 10, kind = 'tranchant' })
                assert.is_nil(result.cancelled)
                assert.equal(10, result.applied)
            end
            assert.equal(1, logged('hook vava_health:hit before en erreur'))
            hooksBefore[HOOKS.HIT] = { { priority = 100, fn = function() return false, 'treve' end } }
            assert.equal('treve', hit(B, { amount = 10, kind = 'tranchant' }).cancelled)
        end)

        it('refuse le coup d\'une source à terre, sauf un effet qui dure ou un renvoi', function()
            load(A)
            load(B)
            life.down(A, 'api')
            hookCalls = {}
            local result = hit(B, { amount = 10, kind = 'tranchant', source = A })
            assert.equal('source_downed', result.cancelled)
            assert.equal(0, result.applied)
            assert.equal(0, #calls(HOOKS.HIT))
            assert.equal(0, journal.pending())
            assert.equal(10, hit(B, { amount = 10, kind = 'feu', source = A, tags = { overTime = true } }).applied)
            assert.equal(10, hit(B, { amount = 10, kind = 'pur', source = A, tags = { reflected = true } }).applied)
        end)

        it('coup lancé debout (1.4.0) : porte si la source tombe après, pas lancé à terre ni trop vieux', function()
            load(A)
            load(B)
            local launched = { spell = true, ranged = true, launched = true }
            -- lancé à 100000, A tombe 300 ms plus tard, l'impact arrive 1 s après le lancement
            local launchedAt = now
            now = now + 300
            life.down(A, 'api')
            now = now + 700
            local result = hit(B, { amount = 10, kind = 'feu', source = A, tags = launched, launchedAt = launchedAt })
            assert.is_nil(result.cancelled)
            assert.equal(10, result.applied)
            -- lancé alors que A était déjà à terre
            result = hit(B, { amount = 10, kind = 'feu', source = A, tags = launched, launchedAt = now - 100 })
            assert.equal('source_downed', result.cancelled)
            -- délai dépassé
            now = launchedAt + cfg.chain.launchedMaxMs + 1
            result = hit(B, { amount = 10, kind = 'feu', source = A, tags = launched, launchedAt = launchedAt })
            assert.equal('source_downed', result.cancelled)
            -- sans l'étiquette : refusé comme avant
            now = launchedAt + 1000
            assert.equal('source_downed', hit(B, { amount = 10, kind = 'feu', source = A,
                tags = { spell = true, ranged = true } }).cancelled)
            -- l'instant sans l'étiquette : paquet refusé
            local refused, code = hit(B, { amount = 10, kind = 'feu', source = A, launchedAt = launchedAt })
            assert.is_nil(refused)
            assert.equal('invalid_launch', code)
        end)

        it('réserve le type monde aux pertes natives de vava_health', function()
            load(B)
            local refused, code = hit(B, { amount = 10, kind = 'monde' })
            assert.is_nil(refused)
            assert.equal('invalid_kind', code)
        end)

        it('permet un renvoi, refuse le renvoi d\'un renvoi, et rend toujours la profondeur', function()
            load(A)
            load(B)
            local results = {}
            hooksAfter[HOOKS.HIT] = { { priority = 100, fn = function(payload)
                if not payload.source then return end
                local result, code = hit(payload.source, { amount = 5, kind = 'pur', source = payload.target,
                    tags = { reflected = true } })
                results[#results + 1] = result or code
            end } }
            local first = hit(B, { amount = 10, kind = 'tranchant', source = A })
            assert.equal(10, first.applied)
            assert.equal(2, #results)
            assert.equal('too_deep', results[1])
            assert.equal(5, results[2].applied)
            assert.equal(0, hits.depth())

            -- un abonné qui lève une erreur (doublure qui ne l'isole pas) : profondeur rendue quand même
            propagateAfterErrors = true
            hooksAfter[HOOKS.HIT] = { { priority = 100, fn = function() error('abonné en panne') end } }
            local result, code = hit(B, { amount = 1, kind = 'tranchant' })
            assert.is_nil(result)
            assert.equal('hit_error', code)
            assert.equal(0, hits.depth())
        end)
    end)

    describe('registre des modificateurs', function()
        it('retire une entrée déclarée au nom d\'un autre module', function()
            addModifier('autre:x', { stage = 'bouclier', label = 'Faux', apply = function() end }, 'vava_test')
            assert.is_nil(registries['vava_health:modifiers'].entries['autre:x'])
            assert.equal(0, #modifiers.list())
            assert.equal(1, logged("modificateur 'autre:x' ajouté par 'vava_test'"))
        end)

        it('n\'admet qu\'un modificateur par étape et par module', function()
            addModifier('vava_test:a', { stage = 'bouclier', label = 'A', apply = function() end })
            addModifier('vava_test:b', { stage = 'bouclier', label = 'B', apply = function() end })
            addModifier('vava_test:c', { stage = 'resistance', label = 'C', apply = function() end })
            addModifier('autre:b', { stage = 'bouclier', label = 'Autre', apply = function() end }, 'autre')
            local keys = {}
            for i, entry in ipairs(api.modifiers()) do keys[i] = entry.key end
            assert.same({ 'autre:b', 'vava_test:a', 'vava_test:c' }, keys)
            assert.is_nil(registries['vava_health:modifiers'].entries['vava_test:b'])
            assert.equal(1, logged("modificateur 'vava_test:b' refusé"))
        end)

        it('suit les ajouts et les retraits, dans l\'ordre des étapes', function()
            addModifier('vava_test:resistance', { stage = 'resistance', label = 'Résistance', kinds = { 'feu' },
                apply = function() end })
            addModifier('vava_test:esquive', { stage = 'esquive', label = 'Esquive', apply = function() end })
            local described = api.modifiers()
            assert.equal(2, #described)
            assert.equal('vava_test:esquive', described[1].key)
            assert.equal(50, described[1].priority)
            assert.same({ 'feu' }, described[2].kinds)
            assert.is_nil(described[1].apply)
            fire('core:registry:removed', { registry = 'vava_health:modifiers', key = 'vava_test:esquive',
                owner = 'vava_test', reason = 'owner_stopped' })
            fire('core:registry:removed', { registry = 'vava_health:modifiers', key = 'vava_test:resistance',
                owner = 'vava_test', reason = 'owner_stopped' })
            assert.equal(0, #modifiers.list())
            addModifier('vava_test:esquive', { stage = 'esquive', label = 'Esquive', apply = function() end })
            fire('core:registry:dropped', { registry = 'vava_health:modifiers', owner = 'vava_health' })
            assert.equal(0, #modifiers.list())
        end)

        it('applique les modificateurs et isole celui qui est en erreur (une ligne par intervalle)', function()
            load(B)
            addModifier('vava_test:bouclier', { stage = 'bouclier', label = 'Bouclier', apply = function()
                error('panne voulue')
            end })
            addModifier('vava_test:resistance', { stage = 'resistance', label = 'Résistance', kinds = { 'feu' },
                apply = function(ctx) return { resisted = ctx.amount * 0.5 } end })
            for _ = 1, 3 do assert.equal(10, hit(B, { amount = 10, kind = 'tranchant' }).applied) end
            assert.equal(1, logged("modificateur 'vava_test:bouclier' en erreur"))
            local result = hit(B, { amount = 10, kind = 'feu' })
            assert.equal(5, result.resisted)
            assert.equal(5, result.applied)
        end)
    end)

    describe('exports', function()
        it('damage passe par la chaîne (pur, legacy)', function()
            load(B)
            assert.is_true(api.damage(B, 0.2))
            local before = calls(HOOKS.HIT, 'before')[1].payload
            assert.equal(20, before.amount)
            assert.equal('pur', before.kind)
            assert.same({ legacy = true }, before.tags)
            assert.equal('vava_test', before.origin)
            assert.is_near(0.8, life.entry(B).health, 1e-9)
            assert.is_true(api.damage(B, 0))
            local ok, code = api.damage(B, 2)
            assert.is_false(ok)
            assert.equal('invalid_amount', code)
            life.down(B, 'api')
            ok, code = api.damage(B, 0.1)
            assert.is_false(ok)
            assert.equal('downed', code)
        end)

        it('setHealth sans condition d\'apparition ; 0 met à terre aussitôt', function()
            load(B, 1.0, false)
            assert.is_true(api.setHealth(B, 0.5))
            assert.equal(0.5, life.entry(B).health)
            assert.equal(0.5, sentTo(B, EVENTS.SET)[1].args[1])
            assert.is_true(api.setHealth(B, 0))
            assert.is_true(life.entry(B).downed)
            assert.equal('api', calls(HOOKS.DOWNED)[1].payload.reason)
            assert.equal(1, #sentTo(B, EVENTS.DOWN))
        end)

        it('borne la cause d\'une mise à terre décidée par un module', function()
            load(B)
            for _, cause in ipairs({ string.rep('a', 33), 'piège', 'a b', 12, '' }) do
                local ok, code = api.down(B, cause)
                assert.is_false(ok, tostring(cause))
                assert.equal('invalid_cause', code, tostring(cause))
            end
            assert.is_true(api.down(B, 'piege-a_loup'))
        end)

        it('get rend la vie du serveur, vocabulary des copies', function()
            load(B, 0.4)
            entityHealth[peds[B]] = 200
            assert.equal(0.4, api.get(B).health)
            local vocabulary = api.vocabulary()
            assert.equal(100, vocabulary.healthPoints)
            assert.equal(11, #vocabulary.kinds)
            assert.is_true(vocabulary.pvp)
            assert.equal(cfg.chain.launchedMaxMs, vocabulary.launchedMaxMs)
            assert.same(VavaHealth.STAGES, vocabulary.stages)
            vocabulary.kinds[1] = 'x'
            assert.equal('tranchant', cfg.chain.kinds[1])
        end)
    end)

    describe('lecture du ped', function()
        it('accepte une perte native après la fenêtre, sans journal', function()
            local entry = load(B, 0.8)
            entityHealth[peds[B]] = ratioToGame(0.6)
            life.tick(500)
            assert.is_near(0.6, entry.health, 1e-9)
            local after = calls(HOOKS.HIT, 'after')
            assert.equal(1, #after)
            assert.equal('vava_health', after[1].payload.origin)
            assert.equal('monde', after[1].payload.kind)
            assert.is_true(after[1].payload.tags.native)
            assert.is_near(20, after[1].payload.applied, 1e-6)
            assert.equal(0, journal.pending())
            assert.equal(0, #sentTo(B, EVENTS.SET))
        end)

        it('met à terre un ped lu au seuil et l\'inscrit au journal', function()
            local entry = load(B, 0.5)
            entityHealth[peds[B]] = 100
            life.tick(500)
            assert.is_true(entry.downed)
            assert.equal('death', calls(HOOKS.DOWNED)[1].payload.reason)
            assert.equal(1, journal.pending())
            journal.flushAll()
            local params = queries[1].params
            assert.equal('vava_health', params[4])
            assert.equal('monde', params[5])
            assert.equal(1, params[14])
        end)

        it('ne transmet jamais comme vrai l\'auteur d\'une mise à terre native', function()
            load(A)
            load(B, 0.5)
            deathSource = peds[A]
            entityHealth[peds[B]] = 90
            life.tick(500)
            local downed = calls(HOOKS.DOWNED)[1].payload
            assert.equal('death', downed.reason)
            assert.is_nil(downed.killer)
            assert.equal(A, downed.claimedKiller)
            assert.is_true(downed.killerUnverified)
            assert.equal(1, logged('non vérifié'))
        end)

        it('espace les corrections restées sans effet, et revient à 2 s dès l\'accord', function()
            local entry = load(B, 0.5)
            entityHealth[peds[B]] = 200
            local function sets() return #sentTo(B, EVENTS.SET) end
            life.tick(500)
            assert.equal(1, sets())
            now = now + 2000
            life.tick(500)
            assert.equal(2, sets())
            now = now + 2000
            life.tick(500)
            assert.equal(2, sets())
            now = now + 2000
            life.tick(500)
            assert.equal(3, sets())
            -- 8 s ensuite, puis 16, plafond 30
            now = now + 7999
            life.tick(500)
            assert.equal(3, sets())
            now = now + 1
            life.tick(500)
            assert.equal(4, sets())
            assert.equal(16000, entry.correctionGap)
            for _ = 1, 3 do
                now = now + 30000
                life.tick(500)
            end
            assert.equal(30000, entry.correctionGap)
            -- le client applique enfin : délai remis à zéro, une nouvelle dérive est corrigée aussitôt
            entityHealth[peds[B]] = ratioToGame(0.5)
            now = now + 3000
            life.tick(500)
            assert.is_nil(entry.correctedAt)
            local before = sets()
            entityHealth[peds[B]] = 200
            now = now + 3000
            life.tick(500)
            assert.equal(before + 1, sets())
        end)

        it('corrige un client au-dessus de la valeur du serveur, au plus toutes les 2 s', function()
            local entry = load(B, 0.5)
            entityHealth[peds[B]] = 200
            life.tick(500)
            assert.equal(1, #sentTo(B, EVENTS.SET))
            assert.equal(0.5, sentTo(B, EVENTS.SET)[1].args[1])
            now = now + 500
            life.tick(500)
            assert.equal(1, #sentTo(B, EVENTS.SET))
            now = now + 1500
            life.tick(1500)
            assert.equal(2, #sentTo(B, EVENTS.SET))
            assert.equal(1, logged('vie du client au-dessus de celle du serveur'))
            assert.equal(0.5, entry.health)
            assert.equal(2, entry.corrections)
        end)

        it('ne prend pas un soin pour une perte', function()
            local entry = load(B, 0.4)
            assert.is_true(api.heal(B, 0.3))
            assert.is_near(0.7, entry.health, 1e-9)
            -- le client n'a pas encore appliqué le soin
            entityHealth[peds[B]] = ratioToGame(0.4)
            now = now + 500
            life.tick(500)
            assert.is_near(0.7, entry.health, 1e-9)
            assert.equal(0, #calls(HOOKS.HIT, 'after'))
        end)

        it('lit d\'office une apparition jamais confirmée après 20 s', function()
            local entry = load(B, 1.0, false)
            entry.spawnOrderedAt = now
            now = now + 19000
            life.tick(500)
            assert.is_false(entry.spawned)
            now = now + 1000
            life.tick(500)
            assert.is_true(entry.spawned)
            assert.equal(1, logged('apparition non confirmée'))
            now = now + 500
            life.tick(500)
            assert.equal(1, logged('apparition non confirmée'))
        end)

        it('écrit la vie différée après des coups, puis à l\'arrêt du module', function()
            local entry = load(B)
            hit(B, { amount = 30, kind = 'tranchant' })
            assert.is_true(entry.dirty)
            assert.is_nil(fields[CHAR[B] .. VavaHealth.FIELD])
            handlers.onResourceStop('vava_health')
            assert.equal(0.7, fields[CHAR[B] .. VavaHealth.FIELD].health)
            assert.is_false(entry.dirty)
        end)
    end)

    describe('journal', function()
        it('inscrit les coups de trois sources et les écrit en une requête', function()
            load(A)
            load(B)
            load(C)
            hit(C, { amount = 5, kind = 'tranchant', source = A })
            hit(C, { amount = 5, kind = 'tranchant', source = B })
            hit(A, { amount = 5, kind = 'tranchant', source = C })
            -- coup sans source ni mise à terre : pas inscrit
            hit(A, { amount = 5, kind = 'privation' })
            assert.equal(3, journal.pending())
            journal.flushAll()
            assert.equal(1, #queries)
            local _, groups = queries[1].sql:gsub('%(%?, %?, NULLIF', '')
            assert.equal(3, groups)
            assert.equal(3 * 17, #queries[1].params)
            assert.is_nil(queries[1].sql:find('vava_test', 1, true))
        end)
    end)

    describe('journal refusé par la base', function()
        it('réessaie ligne à ligne et abandonne la seule ligne refusée, sans boucle', function()
            load(A)
            load(B)
            hit(B, { amount = 1, kind = 'tranchant', source = A, weapon = 'bonne' })
            hit(B, { amount = 1, kind = 'tranchant', source = A, weapon = 'mauvaise' })
            hit(B, { amount = 1, kind = 'tranchant', source = A, weapon = 'bonne' })
            -- la base refuse tout lot qui contient la mauvaise ligne
            dbFails = function(_, params)
                for _, value in ipairs(params) do
                    if value == 'mauvaise' then return true end
                end
                return false
            end
            journal.flush()
            -- un lot, puis trois lignes seules
            assert.equal(4, #queries)
            assert.equal(0, journal.pending())
            assert.equal(1, logged('1 ligne(s) refusée(s) par la base'))
            journal.flush()
            assert.equal(4, #queries)
        end)

        it('n\'attend la base qu\'une fois à l\'arrêt', function()
            load(A)
            load(B)
            hit(B, { amount = 1, kind = 'tranchant', source = A })
            hit(B, { amount = 1, kind = 'tranchant', source = A })
            dbFails = function() return true end
            journal.flushAll()
            assert.equal(1, #queries)
            assert.equal(0, journal.pending())
            assert.equal(1, logged('2 ligne(s) refusée(s)'))
        end)
    end)

    describe('dégâts natifs', function()
        local function weapon(sender, data)
            cancelled = {}
            handlers.weaponDamageEvent(sender, data)
            return #cancelled
        end

        it('annule un coup natif sur un autre joueur, ou introuvable ; laisse PNJ et soi-même', function()
            entities[501] = { type = 1, player = true, owner = B }
            entities[502] = { type = 1, player = false, owner = A }
            entities[503] = { type = 1, player = true, owner = A }
            assert.equal(1, weapon(A, { hitGlobalId = 501 }))
            assert.equal(0, weapon(A, { hitGlobalId = 502 }))
            assert.equal(0, weapon(A, { hitGlobalId = 503 }))
            assert.equal(1, weapon(A, { hitGlobalId = 0, hitGlobalIds = { 502, 501 } }))
            assert.equal(1, weapon(A, { hitGlobalId = 999 }))
            assert.equal(1, weapon(A, { hitGlobalId = 0 }))
            assert.equal(1, logged('dégâts natifs annulés'))
        end)

        it('annule les explosions venues d\'un joueur, sauf réglage contraire', function()
            cancelled = {}
            handlers.explosionEvent(A, {})
            assert.equal(1, #cancelled)
            cfg.natives.explosions = false
            cancelled = {}
            handlers.explosionEvent(A, {})
            assert.equal(0, #cancelled)
            cfg.natives.explosions = true
        end)

        it('décide sans natives (logique pure)', function()
            local natives = VavaHealth.natives
            assert.same({ 4, 5 }, natives.victims({ hitGlobalIds = { 4, 5, 4 }, hitGlobalId = 0 }))
            assert.same({ 0 }, natives.victims({ hitGlobalId = 0 }))
            assert.same({}, natives.victims('x'))
            local function lookup(id) return id == 7 and { ped = true, player = true, owner = 2 } or nil end
            assert.equal('player', natives.decide({ 7 }, 1, lookup, cfg.natives))
            assert.is_nil(natives.decide({ 7 }, 2, lookup, cfg.natives))
            assert.equal('unresolved', natives.decide({ 8 }, 1, lookup, cfg.natives))
            assert.is_nil(natives.decide({ 8 }, 1, lookup, { weaponDamage = true, unresolved = false }))
            assert.is_nil(natives.decide({ 7 }, 1, lookup, { weaponDamage = false, unresolved = true }))
        end)
    end)
end)
