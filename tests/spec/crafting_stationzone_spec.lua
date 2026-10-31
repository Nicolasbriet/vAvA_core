local helper = require('tests.helper')

-- Stations partagées par les abonnements de zone du core (modules/vava_crafting/shared/stationzone.lua, T-017).
-- Valeurs documentées : README du module (« Réseau ») et docs/api.md, section vava_crafting :
--   une zone du core par station, rayon 2 m, marge = portée des props (80 m) + 20 m = 100 m ;
--   état { def = { type, typeLabel, capacity?, label, x, y, z, heading, prop }, s = { fuel, busy } } : le nom du type et
--   sa réserve de combustible partent avec le dessin, le client ne connaît pas les types (T-144) ;
--   le client ignore ce qui est mal formé (jamais d'erreur) et ne connaît que les stations des zones qu'il suit.

describe('vava_crafting stationzone', function()
    local stationzone, cfg

    before_each(function()
        helper.reset()
        helper.loadAll({
            'modules/vava_crafting/shared/constants.lua',
            'modules/vava_crafting/config.lua',
            'modules/vava_crafting/shared/stationzone.lua',
        })
        stationzone = VavaCrafting.stationzone
        cfg = VavaCrafting.config
    end)

    --- Définition serveur d'une station de la config, comme la construit server/catalog.lua.
    local function definition(station)
        local kind = cfg.stationTypes[station.type]
        return {
            id = station.id, type = { id = station.type, label = kind.label, fuel = kind.fuel, prop = kind.prop }, label = station.label or kind.label,
            x = station.x, y = station.y, z = station.z, heading = station.heading or 0.0, quality = station.quality,
            prop = station.prop,
        }
    end

    local FORGE = {
        type = 'forge', typeLabel = 'Forge', capacity = 20, label = 'Forge du bourg', x = -255.0, y = -945.0, z = 31.2, heading = 90.0,
        prop = 'prop_tool_bench02',
    }

    describe('serveur', function()
        it('zone d\'une station : centre de la station, rayon 2 m, marge 100 m (80 + 20) avec la config livrée', function()
            local streaming = cfg.streaming
            local area = stationzone.area({ x = 1.5, y = -2.5, z = 30.0 }, streaming.zoneRadius, streaming.radius + streaming.subscribeSlack)
            assert.same({ x = 1.5, y = -2.5, z = 30.0, radius = 2.0, margin = 100.0 }, area)
        end)

        it('dessin : identifiant et nom du type, réserve de combustible, modèle de la station sinon du type, cap 0 par défaut, rien d\'autre', function()
            local def = definition(cfg.stations[1])
            local drawing = stationzone.drawing(def)
            assert.same(FORGE, drawing)
            assert.is_nil(drawing.quality)
            assert.is_nil(drawing.owner)
            def.prop, def.heading = 'prop_anvil', nil
            drawing = stationzone.drawing(def)
            assert.equal('prop_anvil', drawing.prop)
            assert.equal(0.0, drawing.heading)
            -- type sans combustible : pas de réserve
            def.type = { id = 'etabli', label = 'Établi', prop = 'prop_tool_bench02_ld' }
            drawing = stationzone.drawing(def)
            assert.equal('Établi', drawing.typeLabel)
            assert.is_nil(drawing.capacity)
        end)

        it('état publié et comparaison avant envoi (nil n\'est égal à rien)', function()
            assert.same({ fuel = 3, busy = true }, stationzone.status(3, true))
            assert.same({ fuel = 0, busy = false }, stationzone.status(0, nil))
            assert.is_true(stationzone.sameStatus({ fuel = 3, busy = false }, stationzone.status(3, false)))
            assert.is_false(stationzone.sameStatus({ fuel = 3, busy = false }, { fuel = 2, busy = false }))
            assert.is_false(stationzone.sameStatus({ fuel = 3, busy = false }, { fuel = 3, busy = true }))
            assert.is_false(stationzone.sameStatus(nil, { fuel = 0, busy = false }))
            assert.is_false(stationzone.sameStatus({ fuel = 0, busy = false }, nil))
        end)

        it('chaque station livrée est lue telle quelle par le client, avec un identifiant et un nom dans les bornes', function()
            for _, station in ipairs(cfg.stations) do
                assert.is_true(#station.id <= VavaCrafting.STATION_ID_MAX, station.id)
                local drawing = stationzone.drawing(definition(station))
                local read = stationzone.readDrawing(station.id, drawing)
                assert.is_not_nil(read, station.id)
                assert.equal(station.id, read.id)
                assert.is_true(stationzone.sameDrawing(drawing, read), station.id)
            end
        end)
    end)

    describe('lecture côté client', function()
        it('dessin bien formé : copié avec l\'identifiant de la zone ; cap absent → 0, modèle et réserve absents permis', function()
            local read = stationzone.readDrawing('forge_bourg', FORGE)
            assert.same({
                id = 'forge_bourg', type = 'forge', typeLabel = 'Forge', capacity = 20, label = 'Forge du bourg',
                x = -255.0, y = -945.0, z = 31.2, heading = 90.0, prop = 'prop_tool_bench02',
            }, read)
            read = stationzone.readDrawing('composteur', { type = 'composteur', typeLabel = 'Composteur', label = 'Composteur', x = 1, y = 2, z = 3 })
            assert.equal(0.0, read.heading)
            assert.is_nil(read.prop)
            assert.is_nil(read.capacity)
            assert.equal('Composteur', read.typeLabel)
        end)

        it('dessin mal formé : ignoré, sans erreur', function()
            local function with(key, value)
                local copy = {}
                for k, v in pairs(FORGE) do copy[k] = v end
                copy[key] = value
                return copy
            end
            assert.is_nil(stationzone.readDrawing('Forge', FORGE))
            assert.is_nil(stationzone.readDrawing(12, FORGE))
            assert.is_nil(stationzone.readDrawing('forge_bourg', 'forge'))
            assert.is_nil(stationzone.readDrawing('forge_bourg', nil))
            assert.is_nil(stationzone.readDrawing('forge_bourg', with('type', 'Forge')))
            assert.is_nil(stationzone.readDrawing('forge_bourg', with('type', string.rep('a', 33))))
            assert.is_nil(stationzone.readDrawing('forge_bourg', with('label', '')))
            assert.is_nil(stationzone.readDrawing('forge_bourg', with('label', string.rep('a', 129))))
            assert.is_not_nil(stationzone.readDrawing('forge_bourg', with('label', string.rep('a', 128))))
            assert.is_nil(stationzone.readDrawing('forge_bourg', with('x', 0 / 0)))
            assert.is_nil(stationzone.readDrawing('forge_bourg', with('y', math.huge)))
            assert.is_nil(stationzone.readDrawing('forge_bourg', with('z', '31')))
            assert.is_nil(stationzone.readDrawing('forge_bourg', with('heading', 'nord')))
            assert.is_nil(stationzone.readDrawing('forge_bourg', with('heading', -math.huge)))
            assert.is_nil(stationzone.readDrawing('forge_bourg', with('prop', string.rep('p', 65))))
            assert.is_nil(stationzone.readDrawing('forge_bourg', with('prop', 42)))
            -- nom du type exigé et borné ; réserve entière de 1 à FUEL_CAPACITY_MAX, ou absente (T-144)
            assert.is_nil(stationzone.readDrawing('forge_bourg', with('typeLabel', nil)))
            assert.is_nil(stationzone.readDrawing('forge_bourg', with('typeLabel', '')))
            assert.is_nil(stationzone.readDrawing('forge_bourg', with('typeLabel', 7)))
            assert.is_nil(stationzone.readDrawing('forge_bourg', with('typeLabel', string.rep('a', 129))))
            assert.is_not_nil(stationzone.readDrawing('forge_bourg', with('typeLabel', string.rep('a', 128))))
            assert.is_nil(stationzone.readDrawing('forge_bourg', with('capacity', 0)))
            assert.is_nil(stationzone.readDrawing('forge_bourg', with('capacity', -5)))
            assert.is_nil(stationzone.readDrawing('forge_bourg', with('capacity', 2.5)))
            assert.is_nil(stationzone.readDrawing('forge_bourg', with('capacity', 0 / 0)))
            assert.is_nil(stationzone.readDrawing('forge_bourg', with('capacity', math.huge)))
            assert.is_nil(stationzone.readDrawing('forge_bourg', with('capacity', '20')))
            assert.is_nil(stationzone.readDrawing('forge_bourg', with('capacity', VavaCrafting.FUEL_CAPACITY_MAX + 1)))
            assert.is_not_nil(stationzone.readDrawing('forge_bourg', with('capacity', VavaCrafting.FUEL_CAPACITY_MAX)))
            assert.is_not_nil(stationzone.readDrawing('forge_bourg', with('capacity', 1)))
            assert.equal(20, stationzone.readDrawing('forge_bourg', with('capacity', 20.0)).capacity)
            assert.is_nil(stationzone.readDrawing('forge_bourg', with('capacity', nil)).capacity)
        end)

        it('types livrés : nom et réserve dans les bornes que relit le client', function()
            for id, kind in pairs(cfg.stationTypes) do
                assert.is_true(#kind.label >= 1 and #kind.label <= stationzone.LABEL_MAX, id)
                if kind.fuel then
                    assert.equal('integer', math.type(kind.fuel.capacity), id)
                    assert.is_true(kind.fuel.capacity >= 1 and kind.fuel.capacity <= VavaCrafting.FUEL_CAPACITY_MAX, id)
                end
            end
        end)

        it('état : vide et libre si absent ou mal formé ; combustible négatif ou non fini ramené à 0', function()
            assert.same({ fuel = 0, busy = false }, stationzone.readStatus(nil))
            assert.same({ fuel = 0, busy = false }, stationzone.readStatus('plein'))
            assert.same({ fuel = 7, busy = true }, stationzone.readStatus({ fuel = 7, busy = true }))
            assert.same({ fuel = 0, busy = false }, stationzone.readStatus({ fuel = -1, busy = 'oui' }))
            assert.same({ fuel = 0, busy = false }, stationzone.readStatus({ fuel = 0 / 0 }))
            assert.same({ fuel = 0, busy = false }, stationzone.readStatus({ fuel = math.huge }))
        end)
    end)

    describe('carnet du client', function()
        local book

        before_each(function()
            book = stationzone.book()
        end)

        local function state(drawing, status)
            return { def = drawing, s = status }
        end

        it('entrée : la station est placée ; son état est lu (vide et libre sans `s`)', function()
            local placed, statusChanged = book:enter('forge_bourg', state(FORGE, { fuel = 0, busy = false }))
            assert.is_true(placed)
            assert.is_false(statusChanged)
            assert.equal(1, book:size())
            assert.equal('Forge du bourg', book:station('forge_bourg').label)
            assert.same({ fuel = 0, busy = false }, book:status('forge_bourg'))
            placed, statusChanged = book:enter('etabli_bourg', { def = { type = 'etabli', typeLabel = 'Établi', label = 'Établi', x = 0, y = 0, z = 0 } })
            assert.is_true(placed)
            assert.is_false(statusChanged)
            assert.same({ fuel = 0, busy = false }, book:status('etabli_bourg'))
        end)

        it('entrée d\'une station occupée : état changé', function()
            local placed, statusChanged = book:enter('forge_bourg', state(FORGE, { fuel = 5, busy = true }))
            assert.is_true(placed)
            assert.is_true(statusChanged)
            assert.same({ fuel = 5, busy = true }, book:status('forge_bourg'))
        end)

        it('état entier reçu de nouveau, identique : rien n\'a bougé (le prop est gardé)', function()
            book:enter('forge_bourg', state(FORGE, { fuel = 5, busy = false }))
            local kept = book:station('forge_bourg')
            local placed, statusChanged = book:enter('forge_bourg', state(FORGE, { fuel = 5, busy = false }))
            assert.is_false(placed)
            assert.is_false(statusChanged)
            assert.equal(kept, book:station('forge_bourg'))
            assert.equal(1, book:size())
        end)

        it('état entier reçu de nouveau, station déplacée ou d\'un autre modèle : placée de nouveau', function()
            book:enter('forge_bourg', state(FORGE))
            local moved = {}
            for k, v in pairs(FORGE) do moved[k] = v end
            moved.x = -250.0
            assert.same({ true, false, false }, { book:enter('forge_bourg', state(moved)) })
            assert.equal(-250.0, book:station('forge_bourg').x)
            moved.prop = 'prop_anvil'
            assert.same({ true, false, false }, { book:enter('forge_bourg', state(moved)) })
            moved.heading = 180.0
            assert.same({ true, false, false }, { book:enter('forge_bourg', state(moved)) })
            assert.equal(1, book:size())
        end)

        it('nom, nom du type ou réserve changés : textes mis à jour sur place, la station n\'est pas replacée (R-1)', function()
            book:enter('forge_bourg', state(FORGE))
            local kept = book:station('forge_bourg')
            local list = book:list()
            local renamed = {}
            for k, v in pairs(FORGE) do renamed[k] = v end
            renamed.label = 'Forge neuve'
            assert.same({ false, false, true }, { book:enter('forge_bourg', state(renamed)) })
            renamed.typeLabel = 'Grande forge'
            assert.same({ false, false, true }, { book:change('forge_bourg', { def = renamed }, {}) })
            renamed.capacity = 40
            assert.same({ false, false, true }, { book:enter('forge_bourg', state(renamed)) })
            renamed.capacity = nil
            assert.same({ false, false, true }, { book:enter('forge_bourg', state(renamed)) })
            -- même station (liste et groupes la gardent), textes à jour
            assert.equal(kept, book:station('forge_bourg'))
            assert.equal(list, book:list())
            assert.equal('Forge neuve', kept.label)
            assert.equal('Grande forge', kept.typeLabel)
            assert.is_nil(kept.capacity)
            -- identique : rien
            assert.same({ false, false, false }, { book:enter('forge_bourg', state(renamed)) })
            -- textes et lieu changés ensemble : placée de nouveau
            renamed.label, renamed.x = 'Forge du port', 10.0
            assert.same({ true, false, false }, { book:enter('forge_bourg', state(renamed)) })
            assert.equal('Forge du port', book:station('forge_bourg').label)
            assert.are_not.equal(kept, book:station('forge_bourg'))
        end)

        it('samePlace et sameText partagent le dessin : sameDrawing exige les deux', function()
            local other = {}
            for k, v in pairs(FORGE) do other[k] = v end
            other.label = 'Autre'
            assert.is_true(stationzone.samePlace(FORGE, other))
            assert.is_false(stationzone.sameText(FORGE, other))
            assert.is_false(stationzone.sameDrawing(FORGE, other))
            other.label, other.z = FORGE.label, 0.0
            assert.is_false(stationzone.samePlace(FORGE, other))
            assert.is_true(stationzone.sameText(FORGE, other))
            assert.is_false(stationzone.sameDrawing(FORGE, other))
        end)

        it('état entier mal formé : la station est oubliée', function()
            book:enter('forge_bourg', state(FORGE, { fuel = 2, busy = true }))
            local placed = book:enter('forge_bourg', { def = { type = 'forge' } })
            assert.is_true(placed)
            assert.is_nil(book:station('forge_bourg'))
            assert.same({ fuel = 0, busy = false }, book:status('forge_bourg'))
            assert.equal(0, book:size())
            assert.same({ false, false, false }, { book:enter('inconnue', 'rien') })
        end)

        it('changement de l\'état : seul l\'état change ; un état identique ne compte pas', function()
            book:enter('forge_bourg', state(FORGE, { fuel = 5, busy = false }))
            assert.same({ false, true, false }, { book:change('forge_bourg', { s = { fuel = 5, busy = true } }, {}) })
            assert.same({ fuel = 5, busy = true }, book:status('forge_bourg'))
            assert.same({ false, false, false }, { book:change('forge_bourg', { s = { fuel = 5, busy = true } }, {}) })
            assert.same({ false, true, false }, { book:change('forge_bourg', { s = { fuel = 4, busy = false } }, {}) })
        end)

        it('changement du dessin : placée de nouveau ; dessin mal formé ou retiré : oubliée', function()
            book:enter('forge_bourg', state(FORGE))
            local moved = {}
            for k, v in pairs(FORGE) do moved[k] = v end
            moved.prop = 'prop_anvil'
            assert.same({ true, false, false }, { book:change('forge_bourg', { def = moved }, {}) })
            assert.equal('prop_anvil', book:station('forge_bourg').prop)
            assert.same({ true, false, false }, { book:change('forge_bourg', { def = { label = 'x' } }, {}) })
            assert.is_nil(book:station('forge_bourg'))
            book:enter('forge_bourg', state(FORGE))
            assert.same({ true, false, false }, { book:change('forge_bourg', {}, { 'def' }) })
            assert.is_nil(book:station('forge_bourg'))
        end)

        it('état retiré : vide et libre', function()
            book:enter('forge_bourg', state(FORGE, { fuel = 3, busy = true }))
            assert.same({ false, true, false }, { book:change('forge_bourg', {}, { 's' }) })
            assert.same({ fuel = 0, busy = false }, book:status('forge_bourg'))
        end)

        it('changement d\'une station inconnue : ignoré (le core envoie toujours l\'état entier d\'abord)', function()
            assert.same({ false, false, false }, { book:change('forge_bourg', { s = { fuel = 1, busy = true } }, {}) })
            assert.is_nil(book:station('forge_bourg'))
            assert.equal(0, book:size())
        end)

        it('sortie : oubliée avec son état ; sortie d\'une station inconnue : rien', function()
            book:enter('forge_bourg', state(FORGE, { fuel = 3, busy = true }))
            assert.same({ true, false, false }, { book:leave('forge_bourg') })
            assert.is_nil(book:station('forge_bourg'))
            assert.same({ fuel = 0, busy = false }, book:status('forge_bourg'))
            assert.same({ false, false, false }, { book:leave('forge_bourg') })
            assert.equal(0, book:size())
        end)

        it('liste triée par identifiant, gardée tant qu\'aucune station ne bouge, refaite après', function()
            local function at(x) return { type = 'etabli', typeLabel = 'Établi', label = 'É', x = x, y = 0, z = 0 } end
            book:enter('b', state(at(2)))
            book:enter('a', state(at(1)))
            book:enter('c', state(at(3)))
            local list = book:list()
            assert.same({ 'a', 'b', 'c' }, { list[1].id, list[2].id, list[3].id })
            book:change('b', { s = { fuel = 0, busy = true } }, {})
            assert.equal(list, book:list())
            book:leave('b')
            local after = book:list()
            assert.are_not.equal(list, after)
            assert.same({ 'a', 'c' }, { after[1].id, after[2].id })
            book:clear()
            assert.equal(0, book:size())
            assert.same({}, book:list())
        end)

        it('identifiant non chaîne : rien, sans erreur', function()
            assert.is_nil(book:station(12))
            assert.same({ fuel = 0, busy = false }, book:status(nil))
        end)
    end)
end)
