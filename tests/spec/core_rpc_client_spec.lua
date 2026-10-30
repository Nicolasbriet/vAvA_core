local helper = require('tests.helper')

-- Côté client du RPC (client/core/rpc.lua, core 0.10.0) : préavis d'une réponse latente (id, octets, débit, délai).
-- L'attente de l'appel est repoussée du délai annoncé par le serveur (latents déjà en route compris), au moins du
-- transfert du message seul, plus la marge, au plus rpc.maxLatentExtendMs. Le serveur est une doublure : il reçoit la
-- demande (TriggerServerEvent) et y répond aussitôt, comme le jeu le ferait plus tard.
describe('vAvA.rpc (client)', function()
    local rpc, EVENTS, netHandlers, cfg, onRequest

    before_each(function()
        helper.reset()
        _G.GetGameTimer = function() return 0 end
        netHandlers = {}
        _G.RegisterNetEvent = function(name, fn) netHandlers[name] = fn end
        _G.TriggerServerEvent = function(_, id) if onRequest then onRequest(id) end end
        helper.loadAll({
            'shared/init.lua',
            'config/shared.lua',
            'shared/lib/table.lua',
            'shared/lib/string.lua',
            'shared/lib/schema.lua',
            'shared/lib/pending.lua',
            'shared/core/logger.lua',
            'client/core/rpc.lua',
        })
        rpc, EVENTS, cfg = vAvA.rpc, vAvA.EVENTS, vAvA.config.shared.rpc
        rpc.start()
    end)

    --- Appel dont le serveur annonce une réponse latente, puis répond ; rend le délai de la minuterie posée par le préavis.
    local function extensionFor(...)
        local notice = table.pack(...)
        local extended
        onRequest = function(id)
            local before = #helper.timers
            netHandlers[EVENTS.RPC_LATENT](id, table.unpack(notice, 1, notice.n))
            if #helper.timers > before then extended = helper.timers[#helper.timers].ms end
            netHandlers[EVENTS.RPC_RESPONSE](id, true, 1, { 'ok' })
        end
        -- délai d'origine le plus court permis : toute extension utile le dépasse
        local ok, value = rpc.call({ timeout = cfg.minTimeoutMs }, 'vava_test:gros')
        assert.is_true(ok)
        assert.equal('ok', value)
        return extended
    end

    it('sans délai annoncé : transfert du message seul plus la marge', function()
        assert.equal(math.ceil(20000 * 1000 / 65536) + cfg.latentMarginMs, extensionFor(20000, 65536))
    end)

    it('délai annoncé plus long (latents déjà en route) : c’est lui qui compte', function()
        assert.equal(5000 + cfg.latentMarginMs, extensionFor(20000, 65536, 5000))
    end)

    it('délai annoncé plus court que le transfert : le transfert compte', function()
        assert.equal(math.ceil(20000 * 1000 / 65536) + cfg.latentMarginMs, extensionFor(20000, 65536, 10))
    end)

    it('borné à rpc.maxLatentExtendMs ; plus court que le délai d’origine : rien ne change', function()
        cfg.maxLatentExtendMs = 12000
        assert.equal(12000, extensionFor(20000, 65536, 60000))
        cfg.maxLatentExtendMs = cfg.minTimeoutMs - 50
        assert.is_nil(extensionFor(20000, 65536, 60000))
    end)

    it('préavis mal formé : ignoré', function()
        assert.is_nil(extensionFor(20000, 0))
        assert.is_nil(extensionFor('20000', 65536))
        assert.is_nil(extensionFor(-1, 65536))
        assert.is_nil(extensionFor(20000, 65536.5))
    end)
end)
