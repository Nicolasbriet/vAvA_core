local helper = require('tests.helper')

-- Fenêtre de combat (vava_pause 1.0.0, T-145 § 7.1, décision 4 : 10 s) : logique pure de shared/combat.lua.
describe('vava_pause : fenêtre de combat', function()
    local combat, cfg

    before_each(function()
        helper.reset()
        VavaPause = nil
        helper.loadAll({
            'modules/vava_pause/shared/constants.lua',
            'modules/vava_pause/config.lua',
            'modules/vava_pause/shared/combat.lua',
        })
        combat, cfg = VavaPause.combat, VavaPause.config.combat
    end)

    it('10 s par défaut, faim et pertes natives ignorées', function()
        assert.equal(10000, cfg.windowMs)
        assert.same({ 'privation', 'monde' }, cfg.ignoredKinds)
    end)

    it('cible et source marquées', function()
        assert.same({ 3, 7 }, combat.marks({ target = 3, source = 7, kind = 'tranchant' }, cfg.ignoredKinds))
    end)

    it('source absente ou égale à la cible : la cible seule', function()
        assert.same({ 3 }, combat.marks({ target = 3, kind = 'feu' }, cfg.ignoredKinds))
        assert.same({ 3 }, combat.marks({ target = 3, source = 3, kind = 'feu' }, cfg.ignoredKinds))
    end)

    it('privation et monde ignorés', function()
        assert.same({}, combat.marks({ target = 3, kind = 'privation' }, cfg.ignoredKinds))
        assert.same({}, combat.marks({ target = 3, kind = 'monde', tags = { native = true } }, cfg.ignoredKinds))
    end)

    it('un coup annulé compte (une parade est un combat)', function()
        assert.same({ 3, 7 }, combat.marks({ target = 3, source = 7, kind = 'contondant', cancelled = 'parry', amount = 0 },
            cfg.ignoredKinds))
    end)

    it('charge informe : personne', function()
        assert.same({}, combat.marks(nil, cfg.ignoredKinds))
        assert.same({}, combat.marks({ target = 'x', source = 0, kind = 'feu' }, cfg.ignoredKinds))
    end)

    it('remaining : fenêtre posée, prolongée, close', function()
        local windows = {}
        combat.mark(windows, { 3, 7 }, 1000, cfg.windowMs)
        assert.equal(10000, combat.remaining(windows, 3, 1000))
        assert.equal(1, combat.remaining(windows, 7, 10999))
        assert.equal(0, combat.remaining(windows, 7, 11000))
        assert.equal(0, combat.remaining(windows, 9, 1000))
        combat.mark(windows, { 3 }, 5000, cfg.windowMs)
        assert.equal(10000, combat.remaining(windows, 3, 5000))
        -- une échéance plus proche ne raccourcit pas la fenêtre
        combat.mark(windows, { 3 }, 4000, 1000)
        assert.equal(10000, combat.remaining(windows, 3, 5000))
    end)
end)
