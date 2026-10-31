local helper = require('tests.helper')

-- Parcelles vues du client (modules/vava_farming/client/props.lua, 1.7.0, reprise de T-016), avec des natives et un
-- core simulés. Règle documentée : README du module (« Arrivée ») :
--   une parcelle reçue, changée ou quittée fait aussitôt un passage du client (props et invite à jour) sans attendre
--   la boucle lente : la marge d'abonnement de 20 m n'a à couvrir que le passage du core, même au galop.

describe('vava_farming parcelles côté client', function()
    local props, parcelzone, cfg, parcels, onZone, threads, created, deleted, nearest, position

    --- Parcelle telle que l'indexe server/catalog.lua, à partir d'une parcelle de la config.
    local function parcelOf(raw)
        local g = raw.granary
        return {
            id = raw.id, label = raw.label, x = raw.x, y = raw.y, z = raw.z, heading = raw.heading or 0.0,
            rows = raw.rows, cols = raw.cols, spacing = raw.spacing, count = raw.rows * raw.cols,
            granary = g and { x = g.x, y = g.y, z = g.z, heading = g.heading, label = g.label, prop = g.prop } or nil,
        }
    end

    --- Fait tourner les threads créés depuis le dernier appel (chargement des modèles), jamais la boucle.
    local function runThreads()
        local list = threads
        threads = {}
        for _, fn in ipairs(list) do fn() end
    end

    local function hasModel(list, model)
        for _, entry in pairs(list) do
            if entry == model then return true end
        end
        return false
    end

    before_each(function()
        helper.reset()
        VavaFarming = nil
        -- parcelles d'essai prises dans la config complète (le serveur les envoie), puis la seule vue client (T-132) :
        -- constantes et config_client.lua, comme chez un joueur ; config.lua n'est pas lu
        helper.loadAll({ 'modules/vava_farming/shared/constants.lua', 'modules/vava_farming/config.lua' })
        parcels = VavaFarming.config.parcels
        helper.loadClientView('modules/vava_farming', 'VavaFarming')
        helper.loadAll({
            'modules/vava_farming/shared/geometry.lua',
            'modules/vava_farming/shared/parcelzone.lua',
            'modules/vava_farming/shared/proximity.lua',
        })
        parcelzone, cfg = VavaFarming.parcelzone, VavaFarming.config
        assert.is_nil(cfg.parcels, 'vue client : config.lua ne doit pas être chargé')
        threads, created, deleted, nearest = {}, {}, {}, 'jamais appelé'
        local champ = parcels[1]
        position = { x = champ.x, y = champ.y, z = champ.z }
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
        _G.DeleteObject = function(entity)
            deleted[#deleted + 1] = entities[entity]
            entities[entity] = nil
        end
        local noop = function() end
        VavaFarming.resource = 'vava_farming'
        VavaFarming.core = {
            zones = { watch = function(fn) onZone = fn; return true end },
            hooks = { after = noop },
            characters = { current = function() return true end, awaitingSelection = function() return false end },
            log = { warn = noop, error = noop },
        }
        helper.load('modules/vava_farming/client/props.lua')
        props = VavaFarming.props
        props.onNearest(function(target) nearest = target end)
        props.start()
        -- la boucle est lancée (thread en attente) mais ne tourne jamais ici : seul le passage immédiat compte
        assert.equal(1, #threads)
        threads = {}
        created = {}
    end)

    local function enterChamp(stage)
        local champ = parcelOf(parcels[1])
        local values = {}
        for index = 1, champ.count do values[index] = parcelzone.slotValue(nil, 0, nil) end
        values[1] = parcelzone.slotValue('ble', stage, 'growing')
        onZone('enter', 'champ_communal', (parcelzone.state(champ, values)))
    end

    it('crée les props d’une parcelle reçue aussitôt, sans attendre la boucle', function()
        enterChamp(1)
        runThreads()
        assert.is_true(hasModel(created, cfg.crops.ble.stages[1]))
        assert.is_true(hasModel(created, parcels[1].granary.prop))
        assert.is_not_nil(props.parcel('champ_communal'))
    end)

    it('change le prop d’une plante et l’invite dès la différence reçue', function()
        local champ = parcelzone.readDefinition(parcelzone.definition(parcelOf(parcels[1])))
        local x, y, z = VavaFarming.geometry.slotPosition(champ, 1)
        position = { x = x, y = y, z = z }
        enterChamp(1)
        runThreads()
        assert.same({ 'slot', 1 }, { nearest.kind, nearest.index })
        nearest = nil
        onZone('change', 'champ_communal', { [parcelzone.slotKey(1)] = parcelzone.slotValue('ble', 2, 'growing') }, nil)
        runThreads()
        assert.is_true(hasModel(deleted, cfg.crops.ble.stages[1]))
        assert.is_true(hasModel(created, cfg.crops.ble.stages[2]))
        assert.same({ 'slot', 1 }, { nearest.kind, nearest.index })
        assert.equal(2, props.slot('champ_communal', 1).stage)
    end)

    it('retire les props d’une parcelle quittée aussitôt', function()
        enterChamp(1)
        runThreads()
        onZone('leave', 'champ_communal')
        assert.is_true(hasModel(deleted, cfg.crops.ble.stages[1]))
        assert.is_true(hasModel(deleted, parcels[1].granary.prop))
        assert.is_nil(props.parcel('champ_communal'))
    end)

    it('ne fait aucun passage hors du jeu (sélection du personnage)', function()
        props.setPlaying(false)
        enterChamp(1)
        runThreads()
        assert.same({}, created)
        assert.is_not_nil(props.parcel('champ_communal'))
    end)
end)
