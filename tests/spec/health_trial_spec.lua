local helper = require('tests.helper')

-- Coup d'essai de vava_health (1.6.0, spec T-156 § 7.1, § 7.2 et § 11.1) : `hits.trial` réel et l'export `trial`, avec
-- les doublures du core de health_hit_spec (hooks espionnés, journal en mémoire, envois notés, registre en mémoire).
-- Rien de ce qu'un vrai coup déclenche ne doit se déclencher : vie, mise à terre, hooks before et after, journal, numéro
-- de coup, envoi de la vie, débit par paire, chain.pvp, modificateurs non inscrits. Chaque garde a son contre-essai : le
-- même paquet passé à `hit` déclenche bien ce que l'essai ne déclenche pas (les espions voient donc quelque chose).
describe('vava_health coup d\'essai (serveur)', function()
    local api, life, hits, journal, cfg, EVENTS, HOOKS
    local now, peds, entityHealth, active, fields
    local sent, logs, hookCalls, registered, registries

    local A, B = 1, 2
    local CHAR = { [A] = 101, [B] = 102 }
    local PLACE = { x = -437.5, y = 6011.0, z = 32.49 }

    local function copy(value)
        if type(value) ~= 'table' then return value end
        local out = {}
        for key, item in pairs(value) do out[key] = copy(item) end
        return out
    end

    local function logged(pattern)
        local count = 0
        for _, line in ipairs(logs) do
            if line:find(pattern, 1, true) then count = count + 1 end
        end
        return count
    end

    local function hookCount(name)
        local count = 0
        for _, call in ipairs(hookCalls) do
            if call.name == name then count = count + 1 end
        end
        return count
    end

    --- SetTimeout en attente à 0 ms : déclenchés (fin du tour), comme l'envoi de la vie.
    local function endTurn()
        local pending = helper.timers
        helper.timers = {}
        for _, timer in ipairs(pending) do
            if timer.ms == 0 then timer.fn() else helper.timers[#helper.timers + 1] = timer end
        end
    end

    local hooksAfter

    local function fire(name, payload)
        for _, h in ipairs(hooksAfter[name] or {}) do h.fn(copy(payload)) end
    end

    local function load(src, health)
        active[src] = { id = CHAR[src] }
        peds[src] = 1000 + src
        fire('core:character:loaded', { source = src, characterId = CHAR[src] })
        fire('core:character:spawned', { source = src, characterId = CHAR[src] })
        local entry = life.entry(src)
        entry.health = health or 1.0
        entityHealth[peds[src]] = math.floor(100 + entry.health * 100 + 0.5)
        entry.graceUntil = now - 1
        return entry
    end

    local function addModifier(key, data)
        local def = registries['vava_health:modifiers']
        local ok, reason = def.validator(key, data)
        assert.is_true(ok, reason)
        def.entries[key] = { owner = 'vava_test', data = data }
        fire('core:registry:added', { registry = 'vava_health:modifiers', key = key, owner = 'vava_test' })
    end

    local function trial(packet, place)
        return registered.trial(packet, place == nil and copy(PLACE) or place)
    end

    local function packet(extra)
        local p = { amount = 12, kind = 'tranchant', source = A, weapon = 'epee_courte', technique = 'taille_descendante',
            tags = { melee = true, parryable = true } }
        for k, v in pairs(extra or {}) do p[k] = v end
        return p
    end

    before_each(function()
        helper.reset()
        VavaHealth = nil
        now = 100000
        peds, entityHealth, active, fields = {}, {}, {}, {}
        sent, logs, hookCalls, registered, registries = {}, {}, {}, {}, {}
        hooksAfter = {}
        local hooksBefore = {}

        local function log(level)
            return function(fmt, ...) logs[#logs + 1] = level .. ' ' .. string.format(fmt, ...) end
        end
        local function addHook(store, name, fn)
            store[name] = store[name] or {}
            table.insert(store[name], { fn = fn })
            return #store[name]
        end

        local core
        core = {
            log = { debug = log('debug'), info = log('info'), warn = log('warn'), error = log('error') },
            hooks = {
                before = function(name, fn) return addHook(hooksBefore, name, fn) end,
                after = function(name, fn) return addHook(hooksAfter, name, fn) end,
                runBefore = function(name, payload)
                    hookCalls[#hookCalls + 1] = { name = name, phase = 'before', payload = copy(payload) }
                    return true
                end,
                runAfter = function(name, payload)
                    hookCalls[#hookCalls + 1] = { name = name, phase = 'after', payload = copy(payload) }
                end,
            },
            registry = {
                define = function(name, options)
                    registries[name] = { validator = options.validator, entries = {}, schema = options.schema }
                    return true
                end,
                exists = function(name) return registries[name] ~= nil end,
                has = function(name, key) return registries[name] ~= nil and registries[name].entries[key] ~= nil end,
                get = function(name, key)
                    local def = registries[name]
                    local entry = def and def.entries[key]
                    return entry and entry.data
                end,
                remove = function(name, key)
                    registries[name].entries[key] = nil
                    fire('core:registry:removed', { registry = name, key = key, owner = 'vava_test' })
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
                    sent[#sent + 1] = { target = target, event = event, args = { ... } }
                    return true, 1, 26, false
                end,
            },
            db = {
                query = function() return {} end,
                update = function() return 0 end,
            },
            rpc = { register = function() return true end },
            modules = { register = function(def) core.def = def; return true end },
        }

        _G.exports = setmetatable({ vAvA_core = { getApi = function() return core end } }, {
            __call = function(_, name, fn) registered[name] = fn end,
        })
        _G.GetCurrentResourceName = function() return 'vava_health' end
        _G.GetResourceMetadata = function() return '1.6.0' end
        _G.GetInvokingResource = function() return 'vava_combat' end
        _G.GetResourceState = function() return 'stopped' end
        _G.GetGameTimer = function() return now end
        _G.CreateThread = function() end
        _G.GetPlayers = function()
            local out = {}
            for src in pairs(active) do out[#out + 1] = tostring(src) end
            return out
        end
        _G.GetPlayerPed = function(src) return peds[src] or 0 end
        _G.DoesEntityExist = function(entity) return entity ~= nil and entity ~= 0 and entityHealth[entity] ~= nil end
        _G.GetEntityHealth = function(ped) return entityHealth[ped] or 0 end
        _G.GetEntityMaxHealth = function() return 200 end
        _G.GetEntityCoords = function(ped) return { x = ped + 0.5, y = 2.0, z = 3.0 } end
        _G.GetPedCauseOfDeath = function() return 0 end
        _G.GetPedSourceOfDeath = function() return 0 end
        _G.GetPlayerPing = function() return 40 end
        _G.TriggerClientEvent = function() error('TriggerClientEvent direct interdit (core.net présent)') end
        _G.AddEventHandler = function() end
        _G.CancelEvent = function() end
        _G.NetworkGetEntityFromNetworkId = function() return 0 end
        _G.GetEntityType = function() return 0 end
        _G.IsPedAPlayer = function() return false end
        _G.NetworkGetEntityOwner = function() return 0 end
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
        api, life, hits, journal = registered, VavaHealth.life, VavaHealth.hits, VavaHealth.journal
        cfg, EVENTS, HOOKS = VavaHealth.config, VavaHealth.EVENTS, VavaHealth.HOOKS
        load(A)
        load(B)
        hookCalls, sent = {}, {}
    end)

    after_each(function()
        _G.exports = nil
        VavaHealth = nil
    end)

    describe('rien d\'appliqué', function()
        it('rend le montant « comme si », sans numéro, ni vie, ni mise à terre', function()
            local result, code = trial(packet())
            assert.is_nil(code)
            assert.same({ trial = true, amount = 12, base = 12, blocked = 0, absorbed = 0, resisted = 0, added = 0 },
                result)
            assert.equal(1.0, life.entry(A).health)
            assert.equal(1.0, life.entry(B).health)
            assert.is_false(life.entry(A).downed)
        end)

        it('aucun hook before ni after, aucun journal, aucun envoi ; contre-essai : hit les déclenche', function()
            for _ = 1, 3 do trial(packet()) end
            endTurn()
            assert.equal(0, #hookCalls)
            assert.equal(0, journal.pending())
            assert.equal(0, #sent)
            -- contre-essai : le même paquet sur un joueur passe par les deux hooks, le journal et l'envoi de la vie
            local result = api.hit(B, packet())
            assert.equal(12, result.applied)
            assert.equal(2, hookCount(HOOKS.HIT))   -- before puis after
            assert.equal(1, journal.pending())
            endTurn()
            assert.equal(1, #sent)
            assert.equal(EVENTS.SET, sent[1].event)
        end)

        it('ne prend aucun numéro de coup ; contre-essai : deux hit en prennent deux de suite', function()
            local first = api.hit(B, packet({ amount = 1 }))
            for _ = 1, 5 do trial(packet()) end
            local second = api.hit(B, packet({ amount = 1 }))
            assert.equal(first.id + 1, second.id)
        end)

        it('un essai d\'une source à 1 % de vie ne la met pas à terre ; contre-essai : hit la met à terre', function()
            life.entry(B).health = 0.01
            local result = registered.trial(packet({ source = B, amount = 200 }), copy(PLACE))
            assert.equal(200, result.amount)
            assert.is_false(life.entry(B).downed)
            assert.equal(0, hookCount(HOOKS.DOWNED))
            api.hit(B, packet({ amount = 200 }))
            assert.is_true(life.entry(B).downed)
            assert.equal(1, hookCount(HOOKS.DOWNED))
        end)
    end)

    describe('garde-fous', function()
        it('lieu : table aux seules clés x, y, z, finies et bornées', function()
            local bad = {
                false, 'x', { x = 0 / 0, y = 0, z = 0 }, { x = 1, y = 2, z = 3, w = 4 }, { x = 60000, y = 0, z = 0 },
                { x = 0, y = -50001, z = 0 }, { x = 0, y = 0, z = 6000 }, { x = math.huge, y = 0, z = 0 }, { 1, 2, 3 },
                { x = '1', y = 0, z = 0 },
            }
            for i, place in ipairs(bad) do
                local result, code = registered.trial(packet(), place)
                assert.is_nil(result, 'cas ' .. i)
                assert.equal('invalid_place', code, 'cas ' .. i)
            end
            local result, code = registered.trial(packet(), nil)
            assert.is_nil(result)
            assert.equal('invalid_place', code)
            -- bornes incluses
            assert.is_table(registered.trial(packet(), { x = 50000, y = -50000, z = 5000 }))
        end)

        it('paquet contrôlé comme celui de hit ; monde refusé ; source obligatoire et suivie', function()
            local cases = {
                { packet({ origin = 'vava_magic' }), 'unknown_field' },
                { packet({ kind = 'monde' }), 'invalid_kind' },
                { packet({ kind = 'glace' }), 'invalid_kind' },
                { packet({ amount = 0 }), 'invalid_amount' },
                { packet({ amount = 201 }), 'invalid_amount' },
                { packet({ tags = { melee = 'oui' } }), 'invalid_tags' },
                { packet({ launchedAt = 5 }), 'invalid_launch' },
                { packet({ source = 'a' }), 'invalid_source' },
                { packet({ source = 3 }), 'no_character' },
                { 'x', 'invalid_packet' },
            }
            for i, case in ipairs(cases) do
                local result, code = trial(case[1])
                assert.is_nil(result, 'cas ' .. i)
                assert.equal(case[2], code, 'cas ' .. i)
            end
            local p = packet()
            p.source = nil
            local result, code = trial(p)
            assert.is_nil(result)
            assert.equal('invalid_source', code)
        end)

        it('module arrêté : not_ready', function()
            VavaHealth.ready = false
            local result, code = trial(packet())
            assert.is_nil(result)
            assert.equal('not_ready', code)
        end)

        it('débit propre : 20 essais par seconde et par source, le 21e refusé, admis de nouveau 1 s après', function()
            for i = 1, 20 do assert.is_table(trial(packet()), 'essai ' .. i) end
            local result, code = trial(packet())
            assert.is_nil(result)
            assert.equal('too_many_hits', code)
            assert.is_nil((trial(packet())))
            assert.equal(1, logged("plus de 20 coups d'essai"))
            -- une autre source a son propre compte
            assert.is_table(registered.trial(packet({ source = B }), copy(PLACE)))
            now = now + 999
            assert.is_nil((trial(packet())))
            now = now + 1
            assert.is_table(trial(packet()))
        end)

        it('débits séparés : les essais n\'usent pas celui des vrais coups, ni l\'inverse', function()
            for _ = 1, 20 do trial(packet()) end
            assert.is_nil((trial(packet())))
            -- 20 vrais coups de A sur B : tous admis
            for i = 1, 20 do assert.is_table(api.hit(B, packet({ amount = 0.5 })), 'coup ' .. i) end
            -- contre-essai : le 21e vrai coup est refusé par le débit par paire
            assert.equal('too_many_hits', select(2, api.hit(B, packet({ amount = 0.5 }))))
            now = now + 1000
            for i = 1, 20 do assert.is_table(api.hit(B, packet({ amount = 0.5 })), 'coup ' .. i) end
            assert.is_table(trial(packet()))
        end)

        it('départ de la source : son compte d\'essais est oublié', function()
            for _ = 1, 20 do trial(packet()) end
            assert.is_nil((trial(packet())))
            hits.forget(A)
            assert.is_table(trial(packet()))
        end)

        it('borne de maxTrialsPerSecond contrôlée au démarrage', function()
            assert.is_true(hits.checkTrialConfig())
            for _, value in ipairs({ 0, 101, 1.5, '20' }) do
                cfg.chain.maxTrialsPerSecond = value
                local ok, reason = hits.checkTrialConfig()
                assert.is_false(ok, tostring(value))
                assert.matches('maxTrialsPerSecond', reason)
            end
            cfg.chain.maxTrialsPerSecond = 20
        end)
    end)

    describe('règles d\'un coup', function()
        it('source à terre : annulé source_downed ; lancé debout 1 s avant la chute : passe', function()
            local launchedAt = now
            now = now + 1000
            life.down(A, 'api')
            hookCalls = {}
            local result = trial(packet())
            assert.equal('source_downed', result.cancelled)
            assert.equal(0, result.amount)
            assert.is_nil(result.stage)
            result = trial(packet({ tags = { spell = true, ranged = true, launched = true }, launchedAt = launchedAt,
                kind = 'feu' }))
            assert.is_nil(result.cancelled)
            assert.equal(12, result.amount)
            assert.equal(0, #hookCalls)
        end)

        it('chain.pvp = false ne coupe pas un essai ; contre-essai : il coupe un vrai coup', function()
            cfg.chain.pvp = false
            local result = trial(packet())
            assert.is_nil(result.cancelled)
            assert.equal(12, result.amount)
            assert.equal('pvp_off', api.hit(B, packet()).cancelled)
            cfg.chain.pvp = true
        end)
    end)

    describe('modificateurs', function()
        it('un inscrit (trial = true) reçoit le contexte de l\'essai et peut changer le montant', function()
            local seen = {}
            addModifier('vava_test:armure', { stage = 'resistance', label = 'Armure', trial = true, apply = function(ctx)
                seen[#seen + 1] = ctx
                ctx.position.x = 0     -- ne change rien pour la suite
                return { blocked = 3 }
            end })
            local place = copy(PLACE)
            local result = registered.trial(packet(), place)
            assert.equal(9, result.amount)
            assert.equal(3, result.blocked)
            assert.equal(12, result.base)
            local ctx = seen[1]
            assert.is_true(ctx.trial)
            assert.equal(0, ctx.id)
            assert.equal(0, ctx.target)
            assert.equal(0, ctx.targetCharacter)
            assert.equal(100, ctx.health)
            assert.equal(A, ctx.source)
            assert.equal(CHAR[A], ctx.sourceCharacter)
            assert.equal('vava_combat', ctx.origin)
            assert.equal('tranchant', ctx.kind)
            assert.equal('taille_descendante', ctx.technique)
            assert.equal('resistance', ctx.stage)
            assert.same({ melee = true, parryable = true }, ctx.tags)
            -- lieu copié : celui de l'appelant n'a pas bougé
            assert.equal(PLACE.x, place.x)
            assert.equal(0, #hookCalls)
            -- appelé aussi pour les vrais coups
            api.hit(B, packet())
            assert.equal(2, #seen)
            assert.is_nil(seen[2].trial)
            assert.equal(B, seen[2].target)
        end)

        it('un inscrit qui annule : cancelled et stage ; en erreur : ignoré', function()
            addModifier('vava_test:esquive', { stage = 'esquive', label = 'Esquive', trial = true,
                apply = function() return { cancel = 'evite' } end })
            local result = trial(packet())
            assert.equal('evite', result.cancelled)
            assert.equal('esquive', result.stage)
            assert.equal(0, result.amount)
            -- remplacé par un modificateur en erreur : ignoré, le montant reste entier
            registries['vava_health:modifiers'].entries['vava_test:esquive'] = nil
            fire('core:registry:removed', { registry = 'vava_health:modifiers', key = 'vava_test:esquive',
                owner = 'vava_test' })
            addModifier('vava_test:panne', { stage = 'bouclier', label = 'Panne', trial = true,
                apply = function() error('panne voulue') end })
            result = trial(packet())
            assert.is_nil(result.cancelled)
            assert.equal(12, result.amount)
            assert.equal(1, logged("modificateur 'vava_test:panne' en erreur"))
        end)

        it('un non inscrit n\'est jamais appelé par un essai ; contre-essai : toujours par hit', function()
            local calls = 0
            addModifier('vava_test:bouclier', { stage = 'bouclier', label = 'Bouclier', apply = function()
                calls = calls + 1
                return { absorbed = 12 }
            end })
            addModifier('vava_test:refus', { stage = 'annulation', label = 'Refus', trial = false, apply = function()
                calls = calls + 1
                return { cancel = 'zone_protegee' }
            end })
            local result = trial(packet())
            assert.equal(12, result.amount)
            assert.equal(0, calls)
            assert.equal('zone_protegee', api.hit(B, packet()).cancelled)
            assert.equal(1, calls)
        end)

        it('modifiers() rend trial pour chaque entrée', function()
            addModifier('vava_test:armure', { stage = 'resistance', label = 'Armure', trial = true, apply = function() end })
            addModifier('vava_test:bouclier', { stage = 'bouclier', label = 'Bouclier', apply = function() end })
            local described = api.modifiers()
            assert.equal(2, #described)
            assert.equal('vava_test:bouclier', described[1].key)
            assert.is_false(described[1].trial)
            assert.is_true(described[2].trial)
            assert.equal(1, #VavaHealth.modifiers.trialList())
            assert.equal(2, #VavaHealth.modifiers.list())
        end)

        it('le schéma du registre connaît trial (booléen facultatif)', function()
            local fields = registries['vava_health:modifiers'].schema.fields
            assert.same({ type = 'boolean', optional = true }, fields.trial)
        end)
    end)
end)
