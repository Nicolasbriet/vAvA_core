local helper = require('tests.helper')

-- Moteur de hooks du core (shared/core/hooks.lua) et sa surface d'API par ressource (api.buildHooks dans
-- shared/core/api.lua), au regard de la section « core.hooks » de docs/api.md.
-- GetGameTimer et print sont remplacés AVANT le chargement : logger.lua et hooks.lua les gardent en local.
-- Ils sont posés dans _G : une affectation nue irait dans l'environnement isolé du fichier de spec (busted).
describe('vAvA.hooks', function()
    local hooks, logs, now, realPrint

    before_each(function()
        helper.reset()
        now = 0
        _G.GetGameTimer = function() return now end
        logs = {}
        realPrint = _G.print
        _G.print = function(line) logs[#logs + 1] = tostring(line) end
        helper.loadAll({
            'shared/init.lua',
            'config/shared.lua',
            'shared/lib/table.lua',
            'shared/lib/string.lua',
            'shared/lib/schema.lua',
            'shared/core/logger.lua',
            'shared/core/hooks.lua',
            'shared/core/api.lua',
        })
        hooks = vAvA.hooks
    end)

    after_each(function()
        _G.print = realPrint
    end)

    local function journalContient(texte)
        for _, line in ipairs(logs) do
            if line:find(texte, 1, true) then return true end
        end
        return false
    end

    local function compterJournal(texte)
        local count = 0
        for _, line in ipairs(logs) do
            if line:find(texte, 1, true) then count = count + 1 end
        end
        return count
    end

    -- handler qui note son passage dans `calls` et renvoie les valeurs données
    local function noter(calls, label, ...)
        local results = table.pack(...)
        return function()
            calls[#calls + 1] = label
            return table.unpack(results, 1, results.n)
        end
    end

    describe('inscription', function()
        it('rend un identifiant entier distinct à chaque inscription', function()
            local id1 = hooks.subscribe('vava_a', 'before', 'vava_a:x', function() end)
            local id2 = hooks.subscribe('vava_a', 'after', 'vava_a:x', function() end)
            assert.equal('integer', math.type(id1))
            assert.equal('integer', math.type(id2))
            assert.are_not.equal(id1, id2)
        end)

        it('refuse une phase autre que before ou after', function()
            local id, err = hooks.subscribe('vava_a', 'during', 'vava_a:x', function() end)
            assert.is_nil(id)
            assert.equal('phase invalide (before ou after)', err)
        end)

        it('refuse un nom de hook qui n’est pas un identifiant', function()
            for _, name in ipairs({ 'vava a:x', '', ('a'):rep(65), 'vava_a:é', 42 }) do
                local id, err = hooks.subscribe('vava_a', 'before', name, function() end)
                assert.is_nil(id, 'nom accepté : ' .. tostring(name))
                assert.is_truthy(err:find('nom de hook invalide', 1, true))
            end
            assert.is_nil((hooks.subscribe('vava_a', 'before', nil, function() end)))
        end)

        it('refuse un handler non appelable, accepte une table à __call', function()
            for _, handler in ipairs({ 'fn', {}, 12 }) do
                local id, err = hooks.subscribe('vava_a', 'before', 'vava_a:x', handler)
                assert.is_nil(id)
                assert.equal('handler non appelable', err)
            end
            local callable = setmetatable({}, { __call = function() end })
            assert.is_not_nil(hooks.subscribe('vava_a', 'before', 'vava_a:x', callable))
        end)

        it('accepte une priorité entière de 0 à 1000, bornes incluses', function()
            assert.is_not_nil(hooks.subscribe('vava_a', 'before', 'vava_a:x', function() end, 0))
            assert.is_not_nil(hooks.subscribe('vava_a', 'before', 'vava_a:x', function() end, 1000))
        end)

        it('refuse une priorité hors bornes ou non entière', function()
            for _, priority in ipairs({ -1, 1001, 1.5, '10', 0 / 0 }) do
                local id, err = hooks.subscribe('vava_a', 'before', 'vava_a:x', function() end, priority)
                assert.is_nil(id, 'priorité acceptée : ' .. tostring(priority))
                assert.equal('priorité invalide (entier de 0 à 1000)', err)
            end
        end)
    end)

    describe('ordre d’exécution', function()
        it('suit la priorité croissante, puis l’ordre d’inscription', function()
            local calls = {}
            hooks.subscribe('vava_a', 'before', 'vava_a:x', noter(calls, 'c'), 200)
            hooks.subscribe('vava_a', 'before', 'vava_a:x', noter(calls, 'a'), 50)
            hooks.subscribe('vava_b', 'before', 'vava_a:x', noter(calls, 'b1'))
            hooks.subscribe('vava_a', 'before', 'vava_a:x', noter(calls, 'b2'))
            hooks.subscribe('vava_b', 'before', 'vava_a:x', noter(calls, 'z'), 0)
            assert.is_true(hooks.runBefore('vava_a:x', {}))
            assert.same({ 'z', 'a', 'b1', 'b2', 'c' }, calls)
        end)

        it('place la priorité par défaut à 100', function()
            local calls = {}
            hooks.subscribe('vava_a', 'after', 'vava_a:x', noter(calls, '101'), 101)
            hooks.subscribe('vava_a', 'after', 'vava_a:x', noter(calls, 'défaut'))
            hooks.subscribe('vava_a', 'after', 'vava_a:x', noter(calls, '99'), 99)
            hooks.subscribe('vava_a', 'after', 'vava_a:x', noter(calls, '100'), 100)
            hooks.runAfter('vava_a:x', {})
            assert.same({ '99', 'défaut', '100', '101' }, calls)
        end)

        it('sépare les chaînes before et after d’un même hook', function()
            local calls = {}
            hooks.subscribe('vava_a', 'before', 'vava_a:x', noter(calls, 'before'))
            hooks.subscribe('vava_a', 'after', 'vava_a:x', noter(calls, 'after'))
            hooks.runBefore('vava_a:x', {})
            assert.same({ 'before' }, calls)
            hooks.runAfter('vava_a:x', {})
            assert.same({ 'before', 'after' }, calls)
        end)
    end)

    describe('runBefore', function()
        it('laisse passer quand aucun handler n’est inscrit', function()
            assert.is_true(hooks.runBefore('vava_a:personne', {}))
        end)

        it('transmet le payload à chaque handler', function()
            local payload, received = { slot = 3 }, {}
            hooks.subscribe('vava_a', 'before', 'vava_a:x', function(p) received[#received + 1] = p end)
            hooks.subscribe('vava_a', 'before', 'vava_a:x', function(p) received[#received + 1] = p end)
            hooks.runBefore('vava_a:x', payload)
            assert.equal(payload, received[1])
            assert.equal(payload, received[2])
        end)

        it('false, raison annule l’action et arrête la chaîne', function()
            local calls = {}
            hooks.subscribe('vava_a', 'before', 'vava_a:x', noter(calls, 'refus', false, 'inventaire plein'), 10)
            hooks.subscribe('vava_a', 'before', 'vava_a:x', noter(calls, 'suivant'), 20)
            local allowed, reason = hooks.runBefore('vava_a:x', {})
            assert.is_false(allowed)
            assert.equal('inventaire plein', reason)
            assert.same({ 'refus' }, calls)
        end)

        it('false sans raison textuelle annule avec « cancelled »', function()
            hooks.subscribe('vava_a', 'before', 'vava_a:x', function() return false end)
            assert.same({ false, 'cancelled' }, { hooks.runBefore('vava_a:x', {}) })
            hooks.subscribe('vava_a', 'before', 'vava_a:y', function() return false, 42 end)
            assert.same({ false, 'cancelled' }, { hooks.runBefore('vava_a:y', {}) })
        end)

        it('toute autre valeur de retour laisse l’action continuer', function()
            local calls = {}
            hooks.subscribe('vava_a', 'before', 'vava_a:x', noter(calls, 'nil'), 1)
            hooks.subscribe('vava_a', 'before', 'vava_a:x', noter(calls, 'true', true), 2)
            hooks.subscribe('vava_a', 'before', 'vava_a:x', noter(calls, 'zéro', 0), 3)
            hooks.subscribe('vava_a', 'before', 'vava_a:x', noter(calls, 'nil raison', nil, 'raison'), 4)
            hooks.subscribe('vava_a', 'before', 'vava_a:x', noter(calls, 'texte', 'false'), 5)
            assert.is_true(hooks.runBefore('vava_a:x', {}))
            assert.same({ 'nil', 'true', 'zéro', 'nil raison', 'texte' }, calls)
        end)

        it('un handler en erreur annule (hook_error), arrête la chaîne et est journalisé', function()
            local calls = {}
            hooks.subscribe('vava_a', 'before', 'vava_a:x', function() error('boum') end, 10)
            hooks.subscribe('vava_a', 'before', 'vava_a:x', noter(calls, 'suivant'), 20)
            local allowed, reason = hooks.runBefore('vava_a:x', {})
            assert.is_false(allowed)
            assert.equal('hook_error', reason)
            assert.same({}, calls)
            assert.is_true(journalContient("handler before de 'vava_a:x' (ressource vava_a) en erreur"))
            assert.is_true(journalContient('boum'))
        end)

        it('appelle une table à __call (fonction venant d’une autre ressource)', function()
            local received
            local callable = setmetatable({}, { __call = function(_, payload) received = payload end })
            hooks.subscribe('vava_b', 'before', 'vava_a:x', callable)
            local payload = {}
            assert.is_true(hooks.runBefore('vava_a:x', payload))
            assert.equal(payload, received)
        end)
    end)

    describe('runAfter', function()
        it('exécute tous les handlers malgré une erreur, et journalise l’erreur', function()
            local calls = {}
            hooks.subscribe('vava_a', 'after', 'vava_a:x', noter(calls, 'premier'), 10)
            hooks.subscribe('vava_b', 'after', 'vava_a:x', function() error('boum') end, 20)
            hooks.subscribe('vava_a', 'after', 'vava_a:x', noter(calls, 'dernier'), 30)
            hooks.runAfter('vava_a:x', {})
            assert.same({ 'premier', 'dernier' }, calls)
            assert.is_true(journalContient("handler after de 'vava_a:x' (ressource vava_b) en erreur"))
        end)

        it('ignore la valeur de retour : false n’arrête pas la chaîne', function()
            local calls = {}
            hooks.subscribe('vava_a', 'after', 'vava_a:x', noter(calls, 'refus', false, 'non'), 10)
            hooks.subscribe('vava_a', 'after', 'vava_a:x', noter(calls, 'suivant'), 20)
            hooks.runAfter('vava_a:x', {})
            assert.same({ 'refus', 'suivant' }, calls)
        end)

        it('ne fait rien quand aucun handler n’est inscrit', function()
            assert.has_no.errors(function() hooks.runAfter('vava_a:personne', {}) end)
        end)
    end)

    describe('désinscription', function()
        it('seul le propriétaire retire son handler', function()
            local calls = {}
            local id = hooks.subscribe('vava_a', 'after', 'vava_a:x', noter(calls, 'a'))
            local ok, err = hooks.unsubscribe('vava_b', id)
            assert.is_false(ok)
            assert.equal('ce hook appartient à une autre ressource', err)
            hooks.runAfter('vava_a:x', {})
            assert.same({ 'a' }, calls)
            assert.is_true(hooks.unsubscribe('vava_a', id))
            hooks.runAfter('vava_a:x', {})
            assert.same({ 'a' }, calls)
        end)

        it('échoue pour un identifiant inconnu ou déjà retiré', function()
            local id = hooks.subscribe('vava_a', 'after', 'vava_a:x', function() end)
            assert.is_true(hooks.unsubscribe('vava_a', id))
            assert.same({ false, 'hook inconnu' }, { hooks.unsubscribe('vava_a', id) })
            assert.same({ false, 'hook inconnu' }, { hooks.unsubscribe('vava_a', 9999) })
        end)

        it('un handler retiré pendant un déclenchement n’est plus appelé', function()
            local calls, idB = {}, nil
            hooks.subscribe('vava_a', 'before', 'vava_a:x', function()
                calls[#calls + 1] = 'a'
                hooks.unsubscribe('vava_b', idB)
            end, 10)
            idB = hooks.subscribe('vava_b', 'before', 'vava_a:x', noter(calls, 'b'), 20)
            assert.is_true(hooks.runBefore('vava_a:x', {}))
            assert.same({ 'a' }, calls)
        end)

        it('un handler ajouté pendant un déclenchement n’est appelé qu’au suivant', function()
            local calls, added = {}, false
            hooks.subscribe('vava_a', 'after', 'vava_a:x', function()
                calls[#calls + 1] = 'a'
                if not added then
                    added = true
                    hooks.subscribe('vava_b', 'after', 'vava_a:x', noter(calls, 'nouveau'), 500)
                end
            end, 10)
            hooks.runAfter('vava_a:x', {})
            assert.same({ 'a' }, calls)
            hooks.runAfter('vava_a:x', {})
            assert.same({ 'a', 'a', 'nouveau' }, calls)
        end)

        it('purgeOwner retire tous les handlers d’une ressource, tous noms et phases, et rend leur nombre', function()
            local calls = {}
            hooks.subscribe('vava_a', 'before', 'vava_a:x', noter(calls, 'a1'))
            hooks.subscribe('vava_a', 'after', 'vava_a:x', noter(calls, 'a2'))
            hooks.subscribe('vava_a', 'after', 'core:player:joined', noter(calls, 'a3'))
            hooks.subscribe('vava_b', 'after', 'core:player:joined', noter(calls, 'b'))
            assert.equal(3, hooks.purgeOwner('vava_a'))
            hooks.runBefore('vava_a:x', {})
            hooks.runAfter('vava_a:x', {})
            hooks.runAfter('core:player:joined', {})
            assert.same({ 'b' }, calls)
            assert.equal(0, hooks.purgeOwner('vava_a'))
            assert.equal(0, hooks.purgeOwner('vava_inconnu'))
        end)
    end)

    describe('handlers lents', function()
        it('signale un handler plus lent que hooks.slowHandlerMs (25 ms), pas un handler à 25 ms', function()
            assert.equal(25, vAvA.config.shared.hooks.slowHandlerMs)
            hooks.subscribe('vava_a', 'after', 'vava_a:pile', function() now = now + 25 end)
            hooks.runAfter('vava_a:pile', {})
            assert.is_false(journalContient('handler lent'))
            hooks.subscribe('vava_a', 'after', 'vava_a:lent', function() now = now + 26 end)
            hooks.runAfter('vava_a:lent', {})
            assert.is_true(journalContient("handler lent sur 'vava_a:lent' (after, priorité 100, ressource vava_a) : 26 ms"))
        end)

        it('limite la fréquence des signalements d’un même handler', function()
            hooks.subscribe('vava_a', 'before', 'vava_a:lent', function() now = now + 30 end)
            hooks.runBefore('vava_a:lent', {})
            hooks.runBefore('vava_a:lent', {})
            assert.equal(1, compterJournal('handler lent'))
            now = now + vAvA.config.shared.log.throttleMs
            hooks.runBefore('vava_a:lent', {})
            assert.equal(2, compterJournal('handler lent'))
            assert.is_true(journalContient('[1 message(s) similaire(s) ignoré(s)]'))
        end)
    end)

    describe('surface d’API d’une ressource (core.hooks)', function()
        local function surface(owner)
            return vAvA.api.buildHooks(owner, function(fn) return fn end)
        end

        it('s’abonne à n’importe quel hook, y compris ceux du core', function()
            local a, calls = surface('vava_a'), {}
            assert.is_not_nil(a.after('core:player:joined', noter(calls, 'a')))
            assert.is_not_nil(a.before('vava_b:move', noter(calls, 'b')))
            hooks.runAfter('core:player:joined', {})
            hooks.runBefore('vava_b:move', {})
            assert.same({ 'a', 'b' }, calls)
        end)

        it('déclenche les hooks de son espace de noms et rend le résultat de la chaîne', function()
            local a = surface('vava_a')
            a.before('vava_a:move', function() return false, 'trop loin' end)
            assert.same({ false, 'trop loin' }, { a.runBefore('vava_a:move', {}) })
            assert.is_true(a.runBefore('vava_a:libre', {}))
            assert.is_true(a.runAfter('vava_a:move', {}))
        end)

        it('refuse de déclencher un hook hors de son espace de noms, core: compris', function()
            local a = surface('vava_a')
            local ok, err = a.runBefore('vava_b:move', {})
            assert.is_false(ok)
            assert.equal("hook 'vava_b:move' hors de l'espace de noms 'vava_a:*'", err)
            ok = a.runAfter('core:player:joined', {})
            assert.is_false(ok)
        end)

        it('l’espace de noms inclut le deux-points : vava_a ne déclenche pas vava_ab:x', function()
            local a, calls = surface('vava_a'), {}
            hooks.subscribe('vava_ab', 'after', 'vava_ab:x', noter(calls, 'ab'))
            assert.is_false((a.runAfter('vava_ab:x', {})))
            assert.is_false((a.runBefore('vava_a', {})))
            assert.same({}, calls)
        end)

        it('refuse sans erreur un nom de hook qui n’est pas une chaîne', function()
            local a = surface('vava_a')
            local ok, err = a.runBefore(nil, {})
            assert.is_false(ok)
            assert.is_string(err)
            assert.is_nil((a.before(nil, function() end)))
        end)

        it('off ne retire que ses propres hooks', function()
            local a, b = surface('vava_a'), surface('vava_b')
            local id = a.after('vava_a:x', function() end)
            assert.same({ false, 'ce hook appartient à une autre ressource' }, { b.off(id) })
            assert.is_true(a.off(id))
        end)
    end)
end)
