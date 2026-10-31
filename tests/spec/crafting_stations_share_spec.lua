local helper = require('tests.helper')

-- Stations partagées avec les joueurs proches (modules/vava_crafting/server/stations.lua et client/props.lua, reprise
-- de T-017), avec des doublures du bridge, du core et des natives. Règles documentées : README du module (« Réseau ») :
--   une station placée par `addStation` dont le core refuse la zone n'est pas placée (son état est oublié) ; une
--   déclaration refusée n'est retentée par la boucle d'écriture qu'une fois par minute au plus, jamais à chaque
--   changement ; un état qui n'a pas pu partir est renvoyé au passage suivant ; côté client, une station reçue fait
--   aussitôt un passage (même quand la boucle tourne déjà) et le menu ouvert sur une station oubliée se ferme.

local FORGE_TYPE = { id = 'forge', label = 'Forge', prop = 'prop_tool_bench02', fuel = { item = 'charbon', capacity = 10, perCraft = 1 } }

describe('vava_crafting stations partagées (serveur)', function()
    local stations, calls, answers, errors, now, placed

    local function station(id)
        return { id = id, type = FORGE_TYPE, label = 'Forge du bourg', x = -255.0, y = -945.0, z = 31.2, heading = 90.0 }
    end

    local function answer(fn)
        local queued = answers[fn]
        if queued and #queued > 0 then return table.unpack(table.remove(queued, 1)) end
        return true
    end

    local function names()
        local list = {}
        for i, call in ipairs(calls) do list[i] = call.fn end
        return list
    end

    before_each(function()
        helper.reset()
        VavaCrafting = nil
        helper.loadAll({
            'modules/vava_crafting/shared/constants.lua',
            'modules/vava_crafting/config.lua',
            'modules/vava_crafting/shared/stationzone.lua',
        })
        calls, answers, errors, now, placed = {}, {}, {}, 1000, {}
        _G.GlobalState = {}
        _G.GetGameTimer = function() return now end
        local function record(fn)
            return function(...)
                calls[#calls + 1] = { fn = fn, args = table.pack(...) }
                return answer(fn)
            end
        end
        VavaCrafting.log = {
            error = function(fmt, ...) errors[#errors + 1] = fmt:format(...) end,
            warn = function(fmt, ...) errors[#errors + 1] = fmt:format(...) end,
        }
        VavaCrafting.bridge = {
            DefineZone = record('define'), MoveZone = record('move'), SetZone = record('set'),
            Integer = function(value, default) return math.tointeger(value) or default end,
            db = { query = function() return {} end, single = function() return nil end },
        }
        VavaCrafting.catalog = { stations = function() return placed end, itemLabel = function(item) return item end }
        helper.load('modules/vava_crafting/server/stations.lua')
        stations = VavaCrafting.stations
    end)

    after_each(function()
        _G.GlobalState = nil
    end)

    it('place une station adoptée : zone déclarée avec son dessin et son état', function()
        local def = station('forge_essai')
        placed[1] = def
        assert.is_true(stations.adopt(def))
        assert.same({ 'define' }, names())
        assert.equal(0, stations.fuel(def))
    end)

    it('refuse une station dont le core refuse la zone et oublie son état', function()
        local def = station('forge_essai')
        answers.define = { { false, 'full' } }
        local ok, code = stations.adopt(def)
        assert.is_false(ok)
        assert.equal('full', code)
        assert.is_true(stations.adopt(def))
        assert.same({ 'define', 'define' }, names())
    end)

    it('ne redéclare pas une station refusée à chaque changement, seulement une fois par minute', function()
        local def = station('forge_bourg')
        placed[1] = def
        assert.is_true(stations.load())
        answers.define = { { false, 'full' }, { false, 'full' } }
        assert.equal(0, stations.declareAll())
        calls = {}
        stations.addFuel(def, 3)
        stations.setBusy(def, 7)
        stations.retry()
        assert.same({}, names())
        now = now + 60000
        stations.retry()
        assert.same({ 'define' }, names())
        now = now + 30000
        stations.retry()
        assert.equal(1, #calls)
        now = now + 30000
        stations.retry()
        assert.same({ 'define', 'define' }, names())
        -- déclarée enfin : l'état entier part avec elle (combustible et occupation à jour)
        assert.same({ fuel = 3, busy = true }, calls[2].args[3].s)
    end)

    it('renvoie au passage suivant un état qui n’a pas pu partir, sans le répéter en console', function()
        local def = station('forge_bourg')
        placed[1] = def
        assert.is_true(stations.load())
        assert.equal(1, stations.declareAll())
        answers.set = { { false, 'unknown_zone' }, { false, 'unknown_zone' } }
        calls, errors = {}, {}
        stations.addFuel(def, 2)
        stations.retry()
        assert.same({ 'set', 'set' }, names())
        assert.equal(1, #errors)
        stations.retry()
        assert.same({ 'set', 'set', 'set' }, names())
        assert.same({ fuel = 2, busy = false }, calls[3].args[2].s)
        stations.retry()
        assert.equal(3, #calls)
    end)
end)

describe('vava_crafting stations vues du client', function()
    local props, stationzone, onZone, threads, created, forgotten, position

    local function stateOf(id, x)
        return {
            [stationzone.DEF] = { type = 'forge', typeLabel = 'Forge', label = 'Forge ' .. id, x = x, y = 0.0, z = 30.0, heading = 0.0, prop = 'prop_forge_' .. id },
            [stationzone.STATUS] = { fuel = 0, busy = false },
        }
    end

    local function runThreads()
        local list = threads
        threads = {}
        for _, fn in ipairs(list) do fn() end
    end

    local function hasModel(model)
        for _, entry in pairs(created) do
            if entry == model then return true end
        end
        return false
    end

    before_each(function()
        helper.reset()
        -- la seule vue client (T-132) : constantes et config_client.lua, comme chez un joueur ; config.lua n'est pas lu
        helper.loadClientView('modules/vava_crafting', 'VavaCrafting')
        assert.is_nil(VavaCrafting.config.stations, 'vue client : config.lua ne doit pas être chargé')
        helper.loadAll({
            'modules/vava_crafting/shared/proximity.lua',
            'modules/vava_crafting/shared/stationzone.lua',
        })
        stationzone = VavaCrafting.stationzone
        threads, created, forgotten, position = {}, {}, {}, { x = 0.0, y = 0.0, z = 30.0 }
        local entities = {}
        _G.CreateThread = function(fn) threads[#threads + 1] = fn end
        _G.AddEventHandler = function() end
        _G.PlayerPedId = function() return 1 end
        _G.GetEntityCoords = function() return position end
        _G.GetHashKey = function(model) return model end
        _G.IsModelValid = function() return true end
        _G.RequestModel = function() end
        _G.HasModelLoaded = function() return true end
        _G.SetModelAsNoLongerNeeded = function() end
        _G.CreateObjectNoOffset = function(model)
            local entity = #entities + 1
            entities[entity] = model
            created[entity] = model
            return entity
        end
        _G.SetEntityHeading = function() end
        _G.FreezeEntityPosition = function() end
        _G.PlaceObjectOnGroundProperly = function() end
        _G.DoesEntityExist = function(entity) return entities[entity] ~= nil end
        _G.DeleteObject = function(entity) entities[entity] = nil end
        local noop = function() end
        VavaCrafting.resource = 'vava_crafting'
        VavaCrafting.core = {
            zones = { watch = function(fn) onZone = fn; return true end },
            hooks = { after = noop },
            characters = { current = function() return true end, awaitingSelection = function() return false end },
            log = { warn = noop, error = noop },
        }
        helper.load('modules/vava_crafting/client/props.lua')
        props = VavaCrafting.props
        props.onForget(function(id) forgotten[#forgotten + 1] = id end)
        props.start()
    end)

    it('crée aussitôt le prop d’une station reçue quand la boucle tourne déjà pour une autre', function()
        -- une station lointaine connue : la boucle tourne (au ralenti)
        onZone('enter', 'forge_loin', stateOf('loin', 400.0))
        assert.equal(1, #threads)
        threads = {}
        -- le joueur arrive près d'une deuxième station : son prop est créé sans attendre la boucle
        position = { x = 1000.0, y = 0.0, z = 30.0 }
        onZone('enter', 'forge_pres', stateOf('pres', 1010.0))
        runThreads()
        assert.is_true(hasModel('prop_forge_pres'))
    end)

    it('prévient quand une station est oubliée (le menu ouvert sur elle se ferme)', function()
        onZone('enter', 'forge_pres', stateOf('pres', 5.0))
        onZone('change', 'forge_pres', { [stationzone.STATUS] = { fuel = 3, busy = false } }, nil)
        assert.same({}, forgotten)
        onZone('leave', 'forge_pres')
        assert.same({ 'forge_pres' }, forgotten)
    end)
end)
