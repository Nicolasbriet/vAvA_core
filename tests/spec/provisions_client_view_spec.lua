local helper = require('tests.helper')

-- Vivres vus du client (T-141, lot 2 de T-132 ; relecture réseau R-2) : les fonctions de shared/ auxquelles le client
-- passe une table de sa config (client/interact.lua, client/main.lua, client/points.lua) sont essayées sur la SEULE
-- vue client (constantes et config_client.lua, comme chez un joueur ; config.lua n'est pas lu) :
--   pointzone.book(cfg.kinds), rules.promptVerb(cfg.kinds[…], messages.prompt), rules.successText(…, messages),
--   rules.refusalText(…, kind, messages), rules.noticeText(code, cfg.messages).
-- Chaque texte que le client peut montrer existe dans sa vue et tient dans une notification.

describe('vava_provisions vu du client (config_client.lua seul)', function()
    local rules, pointzone, cfg, points, MAX

    before_each(function()
        helper.reset()
        -- points d'eau tels que le serveur les publie : pris dans la config complète
        helper.loadAll({
            'modules/vava_provisions/shared/constants.lua',
            'modules/vava_provisions/config.lua',
            'modules/vava_provisions/shared/rules.lua',
            'modules/vava_provisions/shared/pointzone.lua',
        })
        local full = VavaProvisions.config
        points = {}
        for index, def in ipairs(full.points) do
            local ok, point = VavaProvisions.rules.validatePoint(def, full.kinds)
            assert.is_true(ok, 'point ' .. index)
            points[#points + 1] = { id = point.id, def = VavaProvisions.pointzone.drawing(point, full.kinds) }
        end
        -- puis la seule vue client
        helper.loadClientView('modules/vava_provisions', 'VavaProvisions')
        helper.loadAll({
            'modules/vava_provisions/shared/rules.lua',
            'modules/vava_provisions/shared/pointzone.lua',
        })
        rules, pointzone, cfg = VavaProvisions.rules, VavaProvisions.pointzone, VavaProvisions.config
        MAX = VavaProvisions.MAX_NOTIFICATION
    end)

    after_each(function()
        VavaProvisions = nil
    end)

    local function fits(text)
        assert.is_string(text)
        assert.is_true(#text > 0 and #text <= MAX, text)
    end

    it('la vue client est bien sans config.lua', function()
        assert.is_true(cfg.clientFile)
        assert.is_nil(cfg.points)
        assert.is_nil(cfg.items)
        assert.is_nil(cfg.interact.serverTolerance)
        assert.is_nil(cfg.streaming.subscribeSlack)
    end)

    it('carnet des points : chaque point publié se dessine avec le modèle de sa sorte', function()
        local book = pointzone.book(cfg.kinds)
        for _, p in ipairs(points) do
            assert.is_true(book:enter(p.id, { [pointzone.DEF] = p.def }), p.id)
            local drawn = book.points[p.id]
            assert.is_table(drawn, p.id)
            assert.equal(cfg.kinds[p.def.kind].model, drawn.model)
        end
        assert.equal(#points, book.count)
    end)

    it('invite : un verbe pour chaque sorte, et pour une sorte inconnue', function()
        for id, kind in pairs(cfg.kinds) do fits(rules.promptVerb(kind, cfg.messages.prompt), id) end
        fits(rules.promptVerb(nil, cfg.messages.prompt))
    end)

    it('réussites : chaque texte existe', function()
        fits(rules.successText({ action = 'fill', count = 1 }, cfg.messages))
        fits(rules.successText({ action = 'fill', count = 5 }, cfg.messages))
        fits(rules.successText({ action = 'drink', dry = false }, cfg.messages))
        fits(rules.successText({ action = 'drink', dry = true }, cfg.messages))
        fits(rules.successText({ action = 'drink', blocked = 'no_space' }, cfg.messages))
        fits(rules.successText({ action = 'drink', blocked = 'too_heavy' }, cfg.messages))
    end)

    it('refus : chaque code du serveur a son texte, un point à sec celui de sa sorte', function()
        for _, code in ipairs({ 'wait', 'too_far', 'not_thirsty', 'no_container', 'no_space', 'too_heavy', 'unavailable' }) do
            fits(rules.refusalText(code, nil, nil, cfg.messages))
        end
        for id, kind in pairs(cfg.kinds) do fits(rules.refusalText('dry', 125, kind, cfg.messages), id) end
        fits(rules.refusalText('dry', 125, nil, cfg.messages))
        fits(rules.refusalText('refused', 'Raison du hook.', nil, cfg.messages))
    end)

    it('avis : outre fendue, outre perdue', function()
        fits(rules.noticeText('torn', cfg.messages))
        fits(rules.noticeText('lost', cfg.messages))
        assert.is_nil(rules.noticeText('autre', cfg.messages))
    end)
end)
