local helper = require('tests.helper')

-- Zones de récolte reçues par le client (modules/vava_gathering/client/props.lua, 1.8.0), vue du client seule (T-132)
-- avec des doublures des natives. Relecture réseau R-2 de T-102 : une récolte (charges, bande) chez tous les abonnés
-- d'une zone ne fait qu'un passage de la boucle des props, sans regrouper de nouveau ses points (0,2 ms pour 120 points) ;
-- seuls l'entrée, la sortie, un lieu ou la `def` changés les regroupent ; le blip n'est corrigé que si `def` change.
describe('vava_gathering props : regroupement des points d’une zone', function()
    local props, onZone, groups, defs, passes

    before_each(function()
        helper.reset()
        helper.loadClientView('modules/vava_gathering', 'VavaGathering')
        helper.loadAll({
            'modules/vava_gathering/shared/geometry.lua',
            'modules/vava_gathering/shared/proximity.lua',
            'modules/vava_gathering/shared/zonestate.lua',
        })
        groups, defs, passes = 0, 0, 0
        local group = VavaGathering.proximity.group
        VavaGathering.proximity.group = function(...)
            groups = groups + 1
            return group(...)
        end
        VavaGathering.resource = 'vava_gathering'
        VavaGathering.core = {
            log = { warn = function() end, error = function() end },
            zones = { watch = function(fn)
                onZone = fn
                return true
            end },
            hooks = { after = function() return 1 end },
            characters = { current = function() return nil end, awaitingSelection = function() return true end },
        }
        _G.CreateThread = function() end
        _G.AddEventHandler = function() end
        _G.PlayerPedId = function() return 1 end
        _G.GetEntityCoords = function()
            passes = passes + 1
            return { x = 5000.0, y = 5000.0, z = 0.0 }
        end
        _G.DoesEntityExist = function() return false end
        _G.DeleteObject = function() end
        helper.load('modules/vava_gathering/client/props.lua')
        props = VavaGathering.props
        props.onDef(function() defs = defs + 1 end)
        props.start()
        props.setPlaying(true)
    end)

    after_each(function()
        VavaGathering = nil
        for _, name in ipairs({ 'AddEventHandler', 'PlayerPedId', 'GetEntityCoords', 'DoesEntityExist', 'DeleteObject' }) do
            _G[name] = nil
        end
    end)

    local function state()
        local out = { zone = { band = 'normal', scarred = false }, def = { 'Bois', 'foret', 0, 0, 3000, 6000 } }
        for i = 1, 120 do
            out[string.format('p:p%03d', i)] = { 'chene', i * 300, 0, 3000, 0 }
            out[string.format('n:p%03d', i)] = 3
        end
        return out
    end

    it('une récolte (charges et bande) : un passage, aucun regroupement, aucun blip corrigé', function()
        onZone('enter', 'bois', state())
        assert.equal(1, groups)
        assert.equal(1, defs)
        local before = passes
        onZone('change', 'bois', { ['n:p001'] = 2, zone = { band = 'reduced', scarred = false } }, {})
        assert.equal(1, groups)
        assert.equal(1, defs)
        assert.equal(before + 1, passes)
        assert.equal(2, props.charges(props.node('p001')))
    end)

    it('un point déplacé ou retiré : regroupé ; `def` changée : regroupé et blip corrigé', function()
        onZone('enter', 'bois', state())
        onZone('change', 'bois', { ['p:p001'] = { 'chene', 400, 0, 3000, 0 } }, {})
        assert.equal(2, groups)
        assert.equal(1, defs)
        assert.equal(4.0, props.node('p001').x)
        onZone('change', 'bois', {}, { 'p:p002', 'n:p002' })
        assert.equal(3, groups)
        assert.is_nil(props.node('p002'))
        onZone('change', 'bois', { def = { 'Bois Neuf', 'foret', 0, 0, 3000, 6000 } }, {})
        assert.equal(4, groups)
        assert.equal(2, defs)
    end)

    it('essai : une charge d’essai prise ne regroupe rien, un point d’essai ajouté si', function()
        props.trial({ zone = 'bois', mode = 'full', def = { 'Bois', 'foret', 0, 0, 3000, 6000 },
            nodes = { p001 = { 'chene', 300, 0, 3000, 0, 3 } } })
        assert.equal(1, groups)
        assert.is_true(props.isTrial('bois'))
        props.trial({ zone = 'bois', mode = 'patch', nodes = { p001 = 2 } })
        assert.equal(1, groups)
        assert.equal(2, props.charges(props.node('p001')))
        props.trial({ zone = 'bois', mode = 'patch', nodes = { p002 = { 'pin', 600, 0, 3000, 0, 4 } } })
        assert.equal(2, groups)
    end)
end)
