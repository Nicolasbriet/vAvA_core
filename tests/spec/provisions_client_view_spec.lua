local helper = require('tests.helper')

-- Vivres vus du client (T-141, lot 2 de T-132 ; relecture réseau R-2 ; T-143, lot 4) : les fonctions de shared/ dont
-- le client se sert avec sa config (client/interact.lua, client/main.lua, client/points.lua) sont essayées sur la SEULE
-- vue client (constantes et config_client.lua, comme chez un joueur ; config.lua n'est pas lu) :
--   pointzone.book(cfg.kinds), et shared/texts.lua, qui lit les textes de `messages` : texts.promptVerb(cfg.kinds[…]),
--   texts.successText(…), texts.refusalText(…, kind), texts.noticeText(code), texts.cutText(…).
-- Chaque texte que le client peut montrer existe dans sa vue et tient dans une notification ; les textes du Conseil
-- (messages.admin, messages.journal) n'y sont pas, ni la logique du seul serveur (shared/rules.lua).

describe('vava_provisions vu du client (config_client.lua seul)', function()
    local texts, pointzone, cfg, points, MAX

    before_each(function()
        helper.reset()
        -- points d'eau tels que le serveur les publie : pris dans la config complète
        helper.loadAll({
            'modules/vava_provisions/shared/constants.lua',
            'modules/vava_provisions/config.lua',
            'modules/vava_provisions/shared/texts.lua',
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
            'modules/vava_provisions/shared/texts.lua',
            'modules/vava_provisions/shared/pointzone.lua',
        })
        texts, pointzone, cfg = VavaProvisions.texts, VavaProvisions.pointzone, VavaProvisions.config
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
        -- textes du Conseil et logique du seul serveur (T-143)
        assert.is_nil(cfg.messages.admin)
        assert.is_nil(cfg.messages.journal)
        assert.is_nil(VavaProvisions.rules)
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
        for id, kind in pairs(cfg.kinds) do fits(texts.promptVerb(kind), id) end
        fits(texts.promptVerb(nil))
    end)

    it('réussites : chaque texte existe', function()
        fits(texts.successText({ action = 'fill', count = 1 }))
        fits(texts.successText({ action = 'fill', count = 5 }))
        fits(texts.successText({ action = 'drink', dry = false }))
        fits(texts.successText({ action = 'drink', dry = true }))
        fits(texts.successText({ action = 'drink', blocked = 'no_space' }))
        fits(texts.successText({ action = 'drink', blocked = 'too_heavy' }))
    end)

    it('refus : chaque code du serveur a son texte, un point à sec celui de sa sorte', function()
        for _, code in ipairs({ 'wait', 'too_far', 'not_thirsty', 'no_container', 'no_space', 'too_heavy', 'unavailable' }) do
            fits(texts.refusalText(code, nil, nil))
        end
        for id, kind in pairs(cfg.kinds) do fits(texts.refusalText('dry', 125, kind), id) end
        fits(texts.refusalText('dry', 125, nil))
        fits(texts.refusalText('refused', 'Raison du hook.', nil))
    end)

    it('avis : outre fendue, outre perdue', function()
        fits(texts.noticeText('torn'))
        fits(texts.noticeText('lost'))
        assert.is_nil(texts.noticeText('autre'))
    end)

    it('réponse de /eau reçue sans vava_chat : coupée à MAX_REPLY sans briser un caractère', function()
        local reply = texts.cutText(string.rep('é', VavaProvisions.MAX_REPLY), VavaProvisions.MAX_REPLY)
        assert.is_true(#reply <= VavaProvisions.MAX_REPLY)
        assert.is_not_nil(utf8.len(reply))
        assert.is_nil(texts.cutText({}, VavaProvisions.MAX_REPLY))
    end)
end)
