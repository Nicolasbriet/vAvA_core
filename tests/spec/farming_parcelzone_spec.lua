local helper = require('tests.helper')

-- Parcelles en zones du core (vava_farming 1.7.0, T-016) : règles pures de modules/vava_farming/shared/parcelzone.lua
-- (lieu de la zone, définition, valeurs publiées, différences par lots, lecture côté client), puis
-- modules/vava_farming/server/zones.lua branché sur le vrai service des zones du core (server/core/zones.lua) : l'état
-- entier ne part qu'à l'arrivée d'un joueur proche, un emplacement changé ne fait partir que lui (environ 40 o, contre
-- 470 o pour tout le champ communal dans GlobalState avant), les changements en masse d'une parcelle (gel, croissance)
-- partent en un seul envoi par parcelle, un joueur loin ne reçoit rien.

local FARMING = {
    'modules/vava_farming/shared/constants.lua',
    'modules/vava_farming/config.lua',
    'modules/vava_farming/shared/geometry.lua',
    'modules/vava_farming/shared/parcelzone.lua',
}

--- Parcelle telle que l'indexe server/catalog.lua, à partir d'une parcelle de la config.
local function parcelOf(raw)
    local def = {
        id = raw.id, label = raw.label or raw.id, x = raw.x, y = raw.y, z = raw.z, heading = raw.heading or 0.0,
        rows = raw.rows, cols = raw.cols, spacing = raw.spacing or 1.5, count = raw.rows * raw.cols,
    }
    if raw.granary then
        local g = raw.granary
        def.granary = { x = g.x, y = g.y, z = g.z, heading = g.heading, label = g.label or 'Grenier commun', prop = g.prop }
    end
    return def
end

--- Valeurs publiées d'une parcelle : toutes libres, sauf celles données (n° → { crop, stage, state }).
local function valuesOf(parcelzone, count, planted)
    local values = {}
    for index = 1, count do
        local p = planted and planted[index]
        values[index] = p and parcelzone.slotValue(p[1], p[2], p[3]) or parcelzone.slotValue(nil, 0, nil)
    end
    return values
end

local function keysOf(t)
    local list = {}
    for key in pairs(t) do list[#list + 1] = key end
    table.sort(list)
    return list
end

describe('vava_farming parcelzone', function()
    local parcelzone, cfg, champ, jardin

    before_each(function()
        helper.reset()
        helper.loadAll(FARMING)
        parcelzone, cfg = VavaFarming.parcelzone, VavaFarming.config
        champ, jardin = parcelOf(cfg.parcels[1]), parcelOf(cfg.parcels[2])
    end)

    it('clés des emplacements : s1 à s64, rien d\'autre', function()
        assert.equal('s1', parcelzone.slotKey(1))
        assert.equal('s64', parcelzone.slotKey(64))
        for index = 1, VavaFarming.MAX_SLOTS do assert.equal(index, parcelzone.slotIndex(parcelzone.slotKey(index))) end
        for _, key in ipairs({ 's0', 's65', 's01', 's', 'def', 'S1', 's1 ', 's-1', 's1.5', 's1000', 1, nil }) do
            assert.is_nil(parcelzone.slotIndex(key), tostring(key))
        end
    end)

    it('valeur d\'un emplacement libre : chaînes vides, jamais nil', function()
        assert.same({ crop = '', stage = 0, state = '' }, parcelzone.slotValue(nil, nil, nil))
        assert.same({ crop = 'ble', stage = 2, state = 'growing' }, parcelzone.slotValue('ble', 2, 'growing'))
        assert.equal('ble:2:growing', parcelzone.signature(parcelzone.slotValue('ble', 2, 'growing')))
        assert.are_not.equal(parcelzone.signature(parcelzone.slotValue('ble', 2, 'growing')),
            parcelzone.signature(parcelzone.slotValue('ble', 2, 'ripe')))
    end)

    it('lieu : centre de la parcelle, rayon qui couvre emplacements et grenier, marge des props + battement', function()
        local margin = cfg.streaming.radius + cfg.streaming.subscribeSlack
        assert.equal(100, margin)
        local area = parcelzone.area(champ, margin, VavaFarming.ZONE_MIN_RADIUS)
        assert.same({ -230.0, -890.0, 31.2, 100 }, { area.x, area.y, area.z, area.margin })
        -- grenier à (−222, −885) : √(8² + 5²), plus loin que le coin de la grille (√(2,4² + 1,6²))
        assert.near(math.sqrt(89), area.radius, 1e-9)
        -- jardin 2 × 3 à 1,6 m, sans grenier : demi-diagonale de la grille
        assert.near(math.sqrt(1.6 ^ 2 + 0.8 ^ 2), parcelzone.area(jardin, margin, 1.0).radius, 1e-9)
        -- un seul emplacement : rayon minimal (le core refuse un rayon nul)
        local single = parcelOf({ id = 'seul', x = 0.0, y = 0.0, z = 0.0, rows = 1, cols = 1 })
        assert.equal(1.0, parcelzone.area(single, margin, 1.0).radius)
        -- chaque emplacement et le grenier sont dans le rayon
        for index = 1, champ.count do
            local x, y = VavaFarming.geometry.slotPosition(champ, index)
            assert.is_true(math.sqrt((x - area.x) ^ 2 + (y - area.y) ^ 2) <= area.radius + 1e-9)
        end
    end)

    it('état entier : définition (sans propriétaire) et un s<n°> par emplacement, signatures rendues', function()
        local private = parcelOf(cfg.parcels[2])
        private.owner = { kind = 'character', id = 1 }
        local state, signatures = parcelzone.state(private, valuesOf(parcelzone, private.count, { [2] = { 'ble', 1, 'growing' } }))
        assert.same({ 'def', 's1', 's2', 's3', 's4', 's5', 's6' }, keysOf(state))
        assert.is_nil(state.def.owner)
        assert.same({ label = 'Jardin privé', x = -240.0, y = -905.0, z = 31.2, heading = 30.0, rows = 2, cols = 3, spacing = 1.6 },
            state.def)
        assert.same({ crop = 'ble', stage = 1, state = 'growing' }, state.s2)
        assert.equal('ble:1:growing', signatures[2])
        assert.equal(':0:', signatures[1])
        local withGranary = parcelzone.state(champ, valuesOf(parcelzone, champ.count))
        assert.same({ label = 'Grenier commun', x = -222.0, y = -885.0, z = 31.2, heading = 0.0, prop = 'prop_crate_11e' },
            withGranary.def.granary)
    end)

    it('différences : rien de connu → tout ; rien de changé → rien ; un emplacement → lui seul', function()
        local values = valuesOf(parcelzone, 12, { [3] = { 'ble', 1, 'growing' } })
        local batches, signatures = parcelzone.diff(nil, values, 64)
        assert.equal(1, #batches)
        assert.equal(12, #keysOf(batches[1]))
        batches = parcelzone.diff(signatures, values, 64)
        assert.same({}, batches)
        values[3] = parcelzone.slotValue('ble', 2, 'growing')
        local next
        batches, next = parcelzone.diff(signatures, values, 64)
        assert.same({ { s3 = { crop = 'ble', stage = 2, state = 'growing' } } }, batches)
        assert.equal('ble:2:growing', next[3])
        -- la table publiée d'avant n'est jamais modifiée (gardée si l'envoi échoue)
        assert.equal('ble:1:growing', signatures[3])
    end)

    it('changements en masse : un seul lot par parcelle, découpé seulement au-delà de la limite du core', function()
        local before = valuesOf(parcelzone, 12, {})
        for index = 1, 12 do before[index] = parcelzone.slotValue('ble', 1, 'growing') end
        local _, published = parcelzone.diff(nil, before, 64)
        -- une nuit de gel : 7 plantes sur 12 meurent
        local after = {}
        for index = 1, 12 do
            after[index] = index <= 7 and parcelzone.slotValue('ble', 1, 'dead') or before[index]
        end
        local batches = parcelzone.diff(published, after, VavaFarming.ZONE_MAX_CHANGES)
        assert.equal(1, #batches)
        assert.same({ 's1', 's2', 's3', 's4', 's5', 's6', 's7' }, keysOf(batches[1]))
        -- 64 emplacements tous changés : un seul appel (limite du core : 64 clés)
        local full = valuesOf(parcelzone, 64, {})
        assert.equal(1, #parcelzone.diff(nil, full, VavaFarming.ZONE_MAX_CHANGES))
        -- limite plus petite : lots de 5, 5 et 2
        batches = parcelzone.diff(nil, after, 5)
        assert.same({ 5, 5, 2 }, { #keysOf(batches[1]), #keysOf(batches[2]), #keysOf(batches[3]) })
    end)

    it('lecture de la définition : aller-retour fidèle, refus de ce qui est illisible', function()
        local state = parcelzone.state(champ, valuesOf(parcelzone, champ.count))
        local def = parcelzone.readDefinition(state.def)
        assert.same(state.def, def)
        assert.equal(parcelzone.definitionKey(def), parcelzone.definitionKey(parcelzone.readDefinition(state.def)))
        local moved = parcelzone.readDefinition(parcelzone.definition(parcelOf({ id = 'x', label = 'Champ communal',
            x = -229.0, y = -890.0, z = 31.2, rows = 3, cols = 4, spacing = 1.6, granary = cfg.parcels[1].granary })))
        assert.are_not.equal(parcelzone.definitionKey(def), parcelzone.definitionKey(moved))

        local function with(changes)
            local copy = {}
            for key, value in pairs(state.def) do copy[key] = value end
            for key, value in pairs(changes) do copy[key] = value end
            return copy
        end
        for name, bad in pairs({
            nan = with({ x = 0 / 0 }), inf = with({ y = math.huge }), noRows = with({ rows = 0 }), floatRows = with({ rows = 1.5 }),
            tooMany = with({ rows = 8, cols = 9 }), spacing = with({ spacing = 0 }), heading = with({ heading = 'nord' }),
        }) do
            assert.is_nil(parcelzone.readDefinition(bad), name)
        end
        assert.is_nil(parcelzone.readDefinition('def'))
        assert.is_nil(parcelzone.readDefinition(nil))
        -- grenier sans position : ignoré ; nom trop long : vide
        local odd = parcelzone.readDefinition(with({ granary = { x = 1.0, y = 2.0 }, label = string.rep('a', 129) }))
        assert.is_nil(odd.granary)
        assert.equal('', odd.label)
        -- entiers venus en flottants (JSON, msgpack) : acceptés
        assert.equal(3, parcelzone.readDefinition(with({ rows = 3.0 })).rows)
    end)

    it('lecture des emplacements : libre = nil, état sans culture effacé, clés étrangères ignorées', function()
        assert.same({ crop = nil, stage = 0, state = nil }, parcelzone.readSlot({ crop = '', stage = 0, state = '' }))
        assert.same({ crop = 'ble', stage = 2, state = 'ripe' }, parcelzone.readSlot({ crop = 'ble', stage = 2.7, state = 'ripe' }))
        assert.same({ crop = nil, stage = 0, state = nil }, parcelzone.readSlot({ crop = '', stage = -3, state = 'dead' }))
        assert.same({ crop = 'ble', stage = 0, state = nil }, parcelzone.readSlot({ crop = 'ble', stage = 0 / 0, state = 4 }))
        assert.is_nil(parcelzone.readSlot('ble'))
        local slots = parcelzone.readSlots({
            def = {}, s1 = { crop = 'ble', stage = 1, state = 'growing' }, s6 = { crop = 'chou', stage = 1, state = 'growing' },
            s7 = { crop = 'lin', stage = 1, state = 'growing' }, s01 = { crop = 'lin' }, autre = 1,
        }, 6)
        assert.same({ 1, 6 }, keysOf(slots))
    end)
end)

describe('vava_farming zones (service du core réel)', function()
    local farming, parcelzone, cfg, coreZones, net, sent, now, peds, positions, characters, global, globalWrites
    local champ, jardin
    local OWNER = 'vava_farming'
    local STATE, DIFF, LEAVE = 'vAvA:zone:state', 'vAvA:zone:diff', 'vAvA:zone:leave'

    before_each(function()
        helper.reset()
        now = 0
        sent, peds, positions, characters = {}, {}, {}, {}
        _G.GetGameTimer = function() return now end
        _G.DoesPlayerExist = function(src) return src >= 1 and src <= 8 end
        _G.GetPlayerPed = function(src) return peds[src] or 0 end
        _G.DoesEntityExist = function(ped) return ped ~= 0 end
        _G.GetEntityCoords = function(ped) return positions[ped] end
        _G.GetPlayerRoutingBucket = function() return 0 end
        _G.TriggerClientEvent = function(event, target, ...)
            sent[#sent + 1] = { event = event, target = target, args = table.pack(...) }
        end
        _G.TriggerLatentClientEvent = function(event, target, _, ...)
            sent[#sent + 1] = { event = event, target = target, latent = true, args = table.pack(...) }
        end
        _G.msgpack, _G.TriggerClientEventInternal, _G.TriggerLatentClientEventInternal = nil, nil, nil
        -- GlobalState : écritures comptées
        global, globalWrites = { ['vava_farming:parcel:champ_communal'] = { slots = {} } }, {}
        _G.GlobalState = setmetatable({}, {
            __index = function(_, key) return global[key] end,
            __newindex = function(_, key, value)
                globalWrites[#globalWrites + 1] = key
                global[key] = value
            end,
        })
        local realPrint = _G.print
        _G.print = function() end
        helper.loadAll({
            'shared/init.lua', 'config/shared.lua', 'shared/lib/string.lua', 'shared/core/logger.lua', 'config/server.lua',
            'server/core/netsize.lua', 'server/core/netstats.lua', 'server/core/net.lua',
        })
        vAvA.rpc = { register = function() return true end }
        helper.loadAll({ 'server/core/zonegrid.lua', 'server/core/zonestate.lua', 'server/core/zones.lua' })
        _G.print = realPrint
        net, coreZones = vAvA.net, vAvA.zones
        vAvA.characters = { forEachActive = function(fn) for _, c in ipairs(characters) do fn(c) end end }
        vAvA.sync = { isCurrent = function() return true end }
        coreZones.registerRpc()
        coreZones.start()

        helper.loadAll(FARMING)
        local errors = {}
        VavaFarming.log = { error = function(...) errors[#errors + 1] = string.format(...) end }
        VavaFarming.errors = errors
        -- surface core.zones d'un module, comme server/core/api.lua la donne à vava_farming
        VavaFarming.core = { zones = {
            define = function(id, area, state) return coreZones.define(OWNER, id, area, state) end,
            move = function(id, area) return coreZones.move(OWNER, id, area) end,
            set = function(id, changes, removed) return coreZones.set(OWNER, id, changes, removed) end,
            replace = function(id, state) return coreZones.replace(OWNER, id, state) end,
            remove = function(id) return coreZones.remove(OWNER, id) end,
        } }
        helper.load('modules/vava_farming/server/zones.lua')
        farming, parcelzone, cfg = VavaFarming.zones, VavaFarming.parcelzone, VavaFarming.config
        champ, jardin = parcelOf(cfg.parcels[1]), parcelOf(cfg.parcels[2])
    end)

    after_each(function()
        _G.GlobalState = nil
    end)

    local function place(src, x, y)
        local ped = 100 + src
        peds[src], positions[ped] = ped, { x = x, y = y, z = 31.0 }
        characters[#characters + 1] = { source = src, spawned = true }
    end

    local function runPass()
        now = now + 1000
        for i = #helper.timers, 1, -1 do
            local timer = helper.timers[i]
            if timer.ms == vAvA.config.server.zones.passMs and not timer.done then
                timer.done = true
                timer.fn()
                return
            end
        end
        error('aucun passage programmé')
    end

    local function endTurn()
        for _, timer in ipairs(helper.timers) do
            if timer.ms == 0 and not timer.done then
                timer.done = true
                timer.fn()
            end
        end
    end

    local function of(event, target)
        local list = {}
        for _, entry in ipairs(sent) do
            if entry.event == event and (target == nil or entry.target == target) then list[#list + 1] = entry end
        end
        return list
    end

    --- Taille msgpack d'un message (valeurs seules, sans le nom de l'évènement).
    local function bytes(entry)
        return vAvA.netsize.args(1 << 20, table.unpack(entry.args, 1, entry.args.n))
    end

    it('l\'ancien state bag est effacé une fois, rien n\'est écrit pour une clé absente', function()
        farming.clearLegacy({ champ, jardin })
        assert.same({ 'vava_farming:parcel:champ_communal' }, globalWrites)
        assert.is_nil(global['vava_farming:parcel:champ_communal'])
        farming.clearLegacy({ champ, jardin })
        assert.equal(1, #globalWrites)
    end)

    it('état entier au seul joueur proche, à son arrivée ; un joueur loin ne reçoit rien', function()
        place(1, -232.0, -820.0)     -- 70 m du champ (rayon 9,4 + 100), 85 m du jardin (rayon 1,8 + 100)
        place(2, -230.0, -400.0)     -- 490 m : loin
        assert.is_true(farming.share(champ, valuesOf(parcelzone, champ.count, { [1] = { 'ble', 1, 'growing' } })))
        assert.is_true(farming.share(jardin, valuesOf(parcelzone, jardin.count)))
        runPass()
        local states = of(STATE, 1)
        assert.equal(2, #states)
        assert.equal(0, #of(STATE, 2))
        assert.equal(0, #sent - #of(STATE, 1))
        local champState = states[1].args[2] == 'vava_farming:champ_communal' and states[1] or states[2]
        assert.same({ crop = 'ble', stage = 1, state = 'growing' }, champState.args[4].s1)
        assert.equal('Champ communal', champState.args[4].def.label)
        -- état entier du champ communal : du même ordre que l'ancienne publication (470 o), mais au seul joueur proche
        local size = bytes(champState)
        assert.is_true(size > 400 and size < 800, 'état entier : ' .. size .. ' o')
        -- rien n'est écrit dans GlobalState
        assert.same({}, globalWrites)
    end)

    it('un emplacement change : sa seule différence (environ 40 o) aux seuls abonnés, rien si rien ne change', function()
        place(1, -230.0, -850.0)
        place(2, -230.0, -400.0)
        local values = valuesOf(parcelzone, champ.count)
        farming.share(champ, values)
        runPass()
        sent = {}
        values[3] = parcelzone.slotValue('ble', 1, 'growing')
        assert.is_true(farming.publish(champ, values))
        endTurn()
        local diffs = of(DIFF)
        assert.equal(1, #diffs)
        assert.equal(1, diffs[1].target)
        assert.same({ s3 = { crop = 'ble', stage = 1, state = 'growing' } }, diffs[1].args[3])
        local size = bytes(diffs[1])
        assert.is_true(size <= 48, 'différence : ' .. size .. ' o')
        -- rien de changé : rien ne part
        sent = {}
        assert.is_true(farming.publish(champ, values))
        endTurn()
        assert.same({}, sent)
    end)

    it('nuit de gel sur deux parcelles : un seul envoi par parcelle, toutes ses plantes ensemble', function()
        place(1, -235.0, -897.0)     -- entre le champ et le jardin : abonné aux deux
        local champValues, jardinValues = {}, {}
        for index = 1, champ.count do champValues[index] = parcelzone.slotValue('ble', 2, 'growing') end
        for index = 1, jardin.count do jardinValues[index] = parcelzone.slotValue('lin', 1, 'growing') end
        farming.share(champ, champValues)
        farming.share(jardin, jardinValues)
        runPass()
        sent = {}
        -- le gel prend 7 plantes du champ et 3 du jardin (slots.frost publie chaque parcelle touchée une fois)
        for index = 1, 7 do champValues[index] = parcelzone.slotValue('ble', 2, 'dead') end
        for index = 1, 3 do jardinValues[index] = parcelzone.slotValue('lin', 1, 'dead') end
        farming.publish(champ, champValues)
        farming.publish(jardin, jardinValues)
        endTurn()
        local diffs = of(DIFF, 1)
        assert.equal(2, #diffs)
        local counts = {}
        for _, diff in ipairs(diffs) do counts[#counts + 1] = #keysOf(diff.args[3]) end
        table.sort(counts)
        assert.same({ 3, 7 }, counts)
        -- deux publications de la même parcelle dans le même tour (geste puis croissance) : un seul envoi
        sent = {}
        champValues[8] = parcelzone.slotValue('ble', 3, 'ripe')
        farming.publish(champ, champValues)
        champValues[9] = parcelzone.slotValue('ble', 3, 'ripe')
        farming.publish(champ, champValues)
        endTurn()
        assert.equal(1, #of(DIFF, 1))
        assert.same({ 's8', 's9' }, keysOf(of(DIFF, 1)[1].args[3]))
    end)

    it('parcelle déplacée en jeu : état entier aux abonnés, joueurs du nouveau lieu servis sans reconnexion', function()
        place(1, -230.0, -850.0)
        place(2, 500.0, 500.0)
        local values = valuesOf(parcelzone, champ.count)
        farming.share(champ, values)
        runPass()
        sent = {}
        local moved = parcelOf({ id = 'champ_communal', label = 'Champ du Val', x = 480.0, y = 520.0, z = 31.2,
            rows = 2, cols = 2, spacing = 2.0 })
        assert.is_true(farming.share(moved, valuesOf(parcelzone, moved.count)))
        -- l'abonné d'avant reçoit le nouvel état entier aussitôt (puis la sortie au passage suivant)
        local replaced = of(STATE, 1)
        assert.equal(1, #replaced)
        assert.equal('Champ du Val', replaced[1].args[4].def.label)
        assert.is_nil(replaced[1].args[4].s5)
        runPass()
        assert.equal(1, #of(LEAVE, 1))
        assert.equal(1, #of(STATE, 2))
    end)

    it('parcelle retirée : ses abonnés l\'oublient ; zone inconnue du core : redéclarée au prochain passage', function()
        place(1, -230.0, -850.0)
        local values = valuesOf(parcelzone, champ.count)
        farming.share(champ, values)
        runPass()
        assert.is_true(farming.drop('champ_communal'))
        assert.equal(1, #of(LEAVE, 1))
        assert.is_true(farming.drop('champ_communal'))
        -- retirée en dehors du module (le core l'a oubliée) : la publication suivante la redéclare entière
        farming.share(champ, values)
        coreZones.remove(OWNER, 'champ_communal')
        values[1] = parcelzone.slotValue('carotte', 1, 'growing')
        assert.is_false(farming.publish(champ, values))
        assert.equal(1, #VavaFarming.errors)
        assert.is_true(farming.publish(champ, values))
        assert.same({ 'champ_communal' }, coreZones.list(OWNER))
        sent = {}
        runPass()
        assert.equal(1, #of(STATE, 1))
        assert.same({ crop = 'carotte', stage = 1, state = 'growing' }, of(STATE, 1)[1].args[4].s1)
    end)

    it('erreur répétée : écrite en console une fois par minute', function()
        VavaFarming.core.zones.define = function() return false, 'full' end
        local values = valuesOf(parcelzone, champ.count)
        assert.is_false(farming.share(champ, values))
        assert.is_false(farming.publish(champ, values))
        assert.equal(1, #VavaFarming.errors)
        now = now + 60000
        assert.is_false(farming.publish(champ, values))
        assert.equal(2, #VavaFarming.errors)
    end)
end)
