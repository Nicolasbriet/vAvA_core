local helper = require('tests.helper')

-- Barre de tension vue du client (modules/vava_gathering/client/fishing.lua, relecture réseau R-2 de T-141), sur la
-- seule vue client (constantes et config_client.lua : la pêche est dans config.lua, servi au seul serveur) :
--   la part à tenir vient de la touche envoyée par le serveur, bornée à [0, 1] ; absente ou invalide, le repli
--   FISHING_HOLD_RATIO des constantes ; seul un raté est cru par le serveur (ligne tenue : il tire encore la prise).

describe('vava_gathering pêche côté client', function()
    local fishing, sent, reeled

    before_each(function()
        helper.reset()
        helper.loadClientView('modules/vava_gathering', 'VavaGathering')
        sent, reeled = {}, {}
        VavaGathering.core = {}
        VavaGathering.nui = { send = function(name, data) sent[#sent + 1] = { name = name, data = data } end }
        VavaGathering.interact = {
            bite = function() return true end,
            reel = function(token, held) reeled[#reeled + 1] = { token = token, held = held } end,
        }
        helper.load('modules/vava_gathering/client/fishing.lua')
        fishing = VavaGathering.fishing
    end)

    after_each(function()
        VavaGathering = nil
    end)

    --- Tenue déclarée pour une barre reçue avec `holdRatio` et finie à la part `ratio`.
    local function heldWith(holdRatio, ratio)
        fishing.onBite({ token = 7, tension = { durationMs = 6000, holdRatio = holdRatio } })
        fishing.done({ token = 7, ratio = ratio })
        return reeled[#reeled].held
    end

    it('la vue client ne porte plus la pêche (config.lua seul)', function()
        assert.is_nil(VavaGathering.config.fishing)
        assert.equal(0.6, VavaGathering.FISHING_HOLD_RATIO)
    end)

    it('part à tenir reçue avec la touche', function()
        assert.is_true(heldWith(0.3, 0.35))
        assert.is_false(heldWith(0.8, 0.75))
        assert.is_true(heldWith(0, 0))
        assert.is_true(heldWith(1, 1))
        assert.equal('tension', sent[1].name)
        assert.equal(VavaGathering.config.keys.interact, sent[1].data.key)
    end)

    it('part absente, hors de [0, 1], NaN ou texte : repli des constantes', function()
        for _, bad in ipairs({ false, -0.1, 1.5, 0 / 0, math.huge, '0.1' }) do
            local value = bad
            if bad == false then value = nil end
            assert.is_false(heldWith(value, 0.59), tostring(bad))
            assert.is_true(heldWith(value, 0.6), tostring(bad))
        end
    end)

    it('une barre sans réglages ni jeton valide est ignorée', function()
        fishing.onBite({ token = 7 })
        fishing.onBite('x')
        assert.equal(0, #sent)
        fishing.done({ token = 7, ratio = 1 })
        assert.equal(0, #reeled)
    end)
end)
