local helper = require('tests.helper')

-- Accord entre la vie du serveur et le ped lu (modules/vava_health/shared/sync.lua, spec T-110 § 7.3 et § 11.1).
describe('vava_health lecture du ped', function()
    local sync

    before_each(function()
        helper.reset()
        VavaHealth = nil
        helper.loadAll({
            'modules/vava_health/shared/constants.lua',
            'modules/vava_health/config.lua',
            'modules/vava_health/shared/sync.lua',
        })
        sync = VavaHealth.sync
    end)

    it('ouvre une fenêtre d\'application de 1,5 s plus deux fois le ping, bornée', function()
        assert.equal(2660, sync.window(1000, 1500, 80, 1000))
        assert.equal(3500, sync.window(1000, 1500, 900, 1000))
        assert.equal(2500, sync.window(1000, 1500, 0, 1000))
        -- ping illisible : compté nul
        assert.equal(2500, sync.window(1000, 1500, nil, 1000))
        assert.equal(2500, sync.window(1000, 1500, -5, 1000))
    end)

    it('attend la fin de la fenêtre, quel que soit l\'écart', function()
        assert.equal('wait', sync.judge(0.1, 0.9, 1000, 1001, 0.02))
        assert.equal('wait', sync.judge(1.0, 0.2, 1000, 5000, 0.02))
    end)

    it('juge une lecture : d\'accord, perte native, client au-dessus', function()
        assert.equal('ok', sync.judge(0.785, 0.8, 2000, 1000, 0.02))
        local verdict, gap = sync.judge(0.6, 0.8, 2000, 1000, 0.02)
        assert.equal('loss', verdict)
        assert.is_near(0.2, gap, 1e-9)
        assert.equal('above', sync.judge(1.0, 0.5, 2000, 1000, 0.02))
        -- aux bornes de la tolérance : d'accord
        assert.equal('ok', sync.judge(0.78, 0.8, 2000, 1000, 0.02))
        assert.equal('ok', sync.judge(0.52, 0.5, 2000, 1000, 0.02))
        assert.equal('ok', sync.judge(0.5, 0.5, 2000, 2000, 0.02))
    end)

    it('lit d\'office une apparition non confirmée après le délai, si le ped existe', function()
        assert.equal('read', sync.spawnGate({ spawned = true }, 0, false, 20000))
        local entry = { spawned = false, spawnOrderedAt = 1000 }
        assert.equal('wait', sync.spawnGate(entry, 1000 + 19999, true, 20000))
        assert.equal('forced', sync.spawnGate(entry, 1000 + 20000, true, 20000))
        assert.equal('wait', sync.spawnGate(entry, 1000 + 60000, false, 20000))
        assert.equal('wait', sync.spawnGate({ spawned = false }, 1000000, true, 20000))
    end)
end)
