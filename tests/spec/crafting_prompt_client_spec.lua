local helper = require('tests.helper')

-- Invite et menu d'une station d'un type que le client ne connaît pas (T-144, relecture réseau R-6 de T-141) :
-- modules/vava_crafting/client/props.lua et client/interact.lua chargés sur la SEULE vue client (constantes et
-- config_client.lua, comme chez un joueur ; config.lua n'est pas lu), avec des doublures du core et des natives.
-- Règles documentées : README du module (« Réseau ») et docs/api.md, section vava_crafting :
--   le dessin d'une station (`def`) porte le nom de son type (`typeLabel`) et sa réserve de combustible (`capacity`,
--   absente sans combustible) ; l'invite les y lit, jamais dans la config du client ; le menu est demandé au serveur
--   (RPC open), qui décide ; l'animation d'un geste est celle que nomme le serveur dans sa réponse.
-- Le composteur est déclaré à l'artisanat par vava_farming, côté serveur seulement : son dessin est construit ici comme
-- le serveur le publie (server/catalog.lua, rebuildTypes et addStation ; shared/stationzone.lua, drawing).

local OPEN = 'vava_crafting:open'

--- Dessin publié par le serveur pour une station placée d'un type déclaré au registre.
---@param kind table   type tel que le déclare son module (config)
---@param station table
local function published(kind, station)
    local stationzone = VavaCrafting.stationzone
    local def = {
        id = station.id, label = station.label or kind.label, x = station.x, y = station.y, z = station.z,
        heading = station.heading or 0.0, quality = station.quality or 50, prop = station.prop,
        type = { id = kind.id, label = kind.label, skills = kind.skills, fuel = kind.fuel, anim = kind.anim, prop = kind.prop },
    }
    return { [stationzone.DEF] = stationzone.drawing(def), [stationzone.STATUS] = stationzone.status(0, false) }
end

describe('vava_crafting invite et menu vus du client (type inconnu de la config du client)', function()
    local composter, forge, onZone, threads, messages, focus, calls, scenarios, position

    --- Lance les threads en attente ; une boucle s'arrête à son premier Wait (la doublure lève 'stop').
    local function runThreads()
        while #threads > 0 do
            local list = threads
            threads = {}
            for _, fn in ipairs(list) do
                local ok, err = pcall(fn)
                if not ok then assert.truthy(tostring(err):find('stop', 1, true), tostring(err)) end
            end
        end
    end

    local function last(action)
        for i = #messages, 1, -1 do
            if messages[i].action == action then return messages[i].payload end
        end
        return nil
    end

    before_each(function()
        helper.reset()
        -- ce que publie le serveur : config complète de l'artisanat, composteur déclaré par vava_farming
        VavaCrafting, VavaFarming = nil, nil
        helper.loadAll({
            'modules/vava_crafting/shared/constants.lua',
            'modules/vava_crafting/config.lua',
            'modules/vava_crafting/shared/stationzone.lua',
            'modules/vava_farming/shared/constants.lua',
            'modules/vava_farming/config.lua',
        })
        local farm = VavaFarming.config.composter
        composter = { id = farm.station.id, state = published(farm.type, farm.station), station = farm.station }
        local crafting = VavaCrafting.config
        local forgeStation = crafting.stations[1]
        local forgeType = crafting.stationTypes[forgeStation.type]
        forgeType.id = forgeStation.type
        forge = { id = forgeStation.id, state = published(forgeType, forgeStation), station = forgeStation, capacity = forgeType.fuel.capacity }
        VavaFarming = nil

        -- puis la seule vue client
        helper.loadClientView('modules/vava_crafting', 'VavaCrafting')
        assert.is_nil(VavaCrafting.config.stations, 'vue client : config.lua ne doit pas être chargé')
        helper.loadAll({
            'modules/vava_crafting/shared/proximity.lua',
            'modules/vava_crafting/shared/stationzone.lua',
        })

        threads, messages, focus, calls, scenarios = {}, {}, {}, {}, {}
        position = { x = composter.station.x + 1.0, y = composter.station.y, z = composter.station.z }
        local entities = {}
        _G.CreateThread = function(fn) threads[#threads + 1] = fn end
        _G.Wait = function() error('stop', 0) end
        _G.AddEventHandler = function() end
        _G.PlayerPedId = function() return 1 end
        _G.GetEntityCoords = function() return position end
        _G.GetHashKey = function(model) return model end
        _G.IsModelValid = function() return true end
        _G.RequestModel = function() end
        _G.HasModelLoaded = function() return true end
        _G.SetModelAsNoLongerNeeded = function() end
        _G.CreateObjectNoOffset = function(model)
            entities[#entities + 1] = model
            return #entities
        end
        _G.SetEntityHeading = function() end
        _G.FreezeEntityPosition = function() end
        _G.PlaceObjectOnGroundProperly = function() end
        _G.DoesEntityExist = function(entity) return entities[entity] ~= nil end
        _G.DeleteObject = function(entity) entities[entity] = nil end
        _G.GetResourceState = function() return 'missing' end
        _G.SendNUIMessage = function(message) messages[#messages + 1] = message end
        _G.SetNuiFocus = function(hasFocus) focus[#focus + 1] = hasFocus end
        _G.RegisterNUICallback = function() end
        _G.TaskStartScenarioInPlace = function(_, scenario) scenarios[#scenarios + 1] = scenario end
        _G.ClearPedTasks = function() end
        local noop = function() end
        VavaCrafting.resource = 'vava_crafting'
        VavaCrafting.log = { warn = noop, error = noop }
        VavaCrafting.core = {
            zones = { watch = function(fn) onZone = fn; return true end },
            hooks = { after = noop },
            characters = { current = function() return true end, awaitingSelection = function() return false end },
            log = { warn = noop, error = noop },
            rpc = {
                call = function(name, ...)
                    calls[#calls + 1] = { name = name, args = table.pack(...) }
                    return true, true, { station = { id = ..., label = 'Composteur du champ', typeLabel = 'Composteur' }, recipes = {} }
                end,
                emit = noop,
            },
        }
        helper.loadAll({
            'modules/vava_crafting/client/nui.lua',
            'modules/vava_crafting/client/props.lua',
            'modules/vava_crafting/client/interact.lua',
        })
        VavaCrafting.props.start()
    end)

    after_each(function()
        VavaCrafting = nil
    end)

    it('le client ne connaît aucun type de station, ni le composteur', function()
        local cfg = VavaCrafting.config
        assert.is_nil(cfg.stationTypes)
        assert.is_table(cfg.anims)
    end)

    it('au composteur du champ : l\'invite « Composteur », sans combustible, et le modèle du type', function()
        onZone('enter', composter.id, composter.state)
        runThreads()
        local prompt = last('prompt')
        assert.is_table(prompt)
        assert.same({
            key = VavaCrafting.config.keys.interact, label = 'Composteur du champ', typeLabel = 'Composteur', busy = false,
        }, prompt)
        assert.equal(composter.id, (VavaCrafting.props.nearest()))
        assert.equal('prop_rub_binbag_01', VavaCrafting.props.station(composter.id).prop)
    end)

    it('à la forge : l\'invite montre la réserve de combustible reçue avec le dessin', function()
        position = { x = forge.station.x, y = forge.station.y + 1.0, z = forge.station.z }
        onZone('enter', forge.id, forge.state)
        runThreads()
        local prompt = last('prompt')
        assert.equal('Forge', prompt.typeLabel)
        assert.same({ stock = 0, capacity = forge.capacity }, prompt.fuel)
        -- combustible reçu par la zone : l'invite suit
        onZone('change', forge.id, { [VavaCrafting.stationzone.STATUS] = { fuel = 7, busy = false } }, nil)
        assert.same({ stock = 7, capacity = forge.capacity }, last('prompt').fuel)
    end)

    it('appui près du composteur : le menu est demandé au serveur et affiché avec le focus', function()
        onZone('enter', composter.id, composter.state)
        runThreads()
        VavaCrafting.interact.press()
        runThreads()
        assert.equal(1, #calls)
        assert.equal(OPEN, calls[1].name)
        assert.equal(composter.id, calls[1].args[1])
        assert.is_table(last('menu'))
        assert.equal(composter.id, VavaCrafting.interact.menuStation())
        assert.is_true(focus[#focus])
        -- l'invite se cache tant que le menu est ouvert
        assert.same({ hidden = true }, last('prompt'))
    end)

    it('geste au composteur : l\'animation est celle que nomme le serveur', function()
        onZone('enter', composter.id, composter.state)
        runThreads()
        VavaCrafting.interact.startWork(composter.id, 'craft', { token = 1, durationMs = 6000, anim = 'tan', label = 'Compost' })
        runThreads()
        assert.same({ VavaCrafting.config.anims.tan.scenario }, scenarios)
        -- sans animation nommée (réponse informe) : aucun geste joué, sans erreur
        VavaCrafting.interact.cancel()
        VavaCrafting.interact.startWork(composter.id, 'craft', { token = 2, durationMs = 6000, anim = { 'tan' } })
        runThreads()
        assert.equal(1, #scenarios)
    end)
end)
