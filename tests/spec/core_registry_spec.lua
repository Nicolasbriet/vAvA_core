local helper = require('tests.helper')

-- Registres du core (server/core/registry.lua), au regard de la section « core.registry » de docs/api.md : nom
-- préfixé par le propriétaire, entrées validées par le schéma puis par le validateur (en erreur = refus), droits de
-- retrait, purge d'un propriétaire, hooks core:registry:added / removed / dropped.
describe('vAvA.registry', function()
    local registry, hooks, events, realPrint

    local ITEM = { type = 'table', fields = {
        label = { type = 'string', max = 32 },
        weight = { type = 'integer', min = 0, optional = true },
    } }

    before_each(function()
        helper.reset()
        realPrint = _G.print
        _G.print = function() end
        helper.loadAll({
            'shared/init.lua',
            'config/shared.lua',
            'shared/lib/table.lua',
            'shared/lib/string.lua',
            'shared/lib/schema.lua',
            'shared/core/logger.lua',
            'shared/core/hooks.lua',
            'server/core/registry.lua',
        })
        registry, hooks = vAvA.registry, vAvA.hooks
        events = {}
        for _, name in ipairs({ 'core:registry:added', 'core:registry:removed', 'core:registry:dropped' }) do
            local id, err = hooks.subscribe('test', 'after', name, function(payload)
                events[#events + 1] = { hook = name, payload = payload }
            end)
            assert.is_not_nil(id, err)
        end
    end)

    after_each(function()
        _G.print = realPrint
    end)

    local function define(options)
        return registry.define('vava_inv', 'vava_inv:items', options or { schema = ITEM })
    end

    describe('define', function()
        it('accepte un nom préfixé par le propriétaire', function()
            assert.is_true(define())
            assert.is_true(registry.exists('vava_inv:items'))
            assert.is_false(registry.exists('vava_inv:autre'))
        end)

        it('refuse un nom sans le préfixe du propriétaire, ou qui n’est pas un identifiant', function()
            local ok, err = registry.define('vava_inv', 'autre:items', { schema = ITEM })
            assert.is_false(ok)
            assert.matches('nom de registre invalide', err)
            ok, err = registry.define('vava_inv', 'vava_inv:des items', { schema = ITEM })
            assert.is_false(ok)
            assert.matches('nom de registre invalide', err)
            assert.is_false(registry.exists('autre:items'))
        end)

        it('refuse un registre déjà défini', function()
            assert.is_true(define())
            local ok, err = define()
            assert.is_false(ok)
            assert.matches('déjà défini', err)
        end)

        it('refuse des options absentes, un schéma invalide, un validateur non appelable, un maxEntries non entier positif', function()
            local ok, err = registry.define('vava_inv', 'vava_inv:items')
            assert.is_false(ok)
            assert.matches('options requises', err)
            ok, err = define({ schema = { type = 'mystère' } })
            assert.is_false(ok)
            assert.matches('type inconnu', err)
            ok, err = define({ schema = ITEM, validator = 'oui' })
            assert.is_false(ok)
            assert.matches('validator', err)
            for _, max in ipairs({ 0, -1, 2.5, 'dix' }) do
                ok, err = define({ schema = ITEM, maxEntries = max })
                assert.is_false(ok)
                assert.matches('maxEntries', err)
            end
            assert.is_false(registry.exists('vava_inv:items'))
        end)
    end)

    describe('add', function()
        it('ajoute une entrée valide, lisible par get, has et all, et émet core:registry:added', function()
            assert.is_true(define())
            assert.is_true(registry.add('vava_food', 'vava_inv:items', 'pain', { label = 'Miche', weight = 400 }))
            assert.is_true(registry.has('vava_inv:items', 'pain'))
            assert.equal('Miche', registry.get('vava_inv:items', 'pain').label)
            assert.same({ pain = { label = 'Miche', weight = 400 } }, registry.all('vava_inv:items'))
            assert.equal(1, #events)
            assert.equal('core:registry:added', events[1].hook)
            assert.same({ registry = 'vava_inv:items', key = 'pain', owner = 'vava_food' }, events[1].payload)
        end)

        it('refuse un registre inconnu, une clé invalide, une clé déjà prise', function()
            local ok, err = registry.add('vava_food', 'vava_inv:absent', 'pain', { label = 'Miche' })
            assert.is_false(ok)
            assert.matches('inexistant', err)
            assert.is_true(define())
            ok, err = registry.add('vava_food', 'vava_inv:items', 'pain frais', { label = 'Miche' })
            assert.is_false(ok)
            assert.matches('clé invalide', err)
            assert.is_true(registry.add('vava_food', 'vava_inv:items', 'pain', { label = 'Miche' }))
            ok, err = registry.add('vava_autre', 'vava_inv:items', 'pain', { label = 'Autre miche' })
            assert.is_false(ok)
            assert.matches('déjà enregistrée', err)
            assert.matches('vava_food', err)
            assert.equal('Miche', registry.get('vava_inv:items', 'pain').label)
        end)

        it('refuse une entrée hors schéma, avec la raison', function()
            assert.is_true(define())
            local ok, err = registry.add('vava_food', 'vava_inv:items', 'pain', { label = 12 })
            assert.is_false(ok)
            assert.matches('invalide', err)
            assert.matches('chaîne attendue', err)
            ok, err = registry.add('vava_food', 'vava_inv:items', 'pain', { label = 'Miche', couleur = 'dorée' })
            assert.is_false(ok)
            assert.matches('clé non autorisée', err)
            assert.is_false(registry.has('vava_inv:items', 'pain'))
            assert.equal(0, #events)
        end)

        it('applique le validateur : refus avec sa raison, et une erreur vaut refus', function()
            local seen = {}
            assert.is_true(define({ schema = ITEM, validator = function(key, data)
                seen[#seen + 1] = key
                if key == 'bombe' then error('boum') end
                if data.weight and data.weight > 1000 then return false, 'trop lourd' end
                return true
            end }))
            assert.is_true(registry.add('vava_food', 'vava_inv:items', 'pain', { label = 'Miche', weight = 400 }))
            local ok, err = registry.add('vava_food', 'vava_inv:items', 'enclume', { label = 'Enclume', weight = 9000 })
            assert.is_false(ok)
            assert.equal('trop lourd', err)
            ok, err = registry.add('vava_food', 'vava_inv:items', 'bombe', { label = 'Bombe' })
            assert.is_false(ok)
            assert.equal('validator_error', err)
            assert.same({ 'pain', 'enclume', 'bombe' }, seen)
            assert.is_false(registry.has('vava_inv:items', 'bombe'))
        end)

        it('refuse au-delà de maxEntries', function()
            assert.is_true(define({ schema = ITEM, maxEntries = 2 }))
            assert.is_true(registry.add('vava_food', 'vava_inv:items', 'pain', { label = 'Miche' }))
            assert.is_true(registry.add('vava_food', 'vava_inv:items', 'pomme', { label = 'Pomme' }))
            local ok, err = registry.add('vava_food', 'vava_inv:items', 'eau', { label = 'Eau' })
            assert.is_false(ok)
            assert.matches('plein', err)
            -- une place libérée se reprend
            assert.is_true(registry.remove('vava_food', 'vava_inv:items', 'pomme'))
            assert.is_true(registry.add('vava_food', 'vava_inv:items', 'eau', { label = 'Eau' }))
        end)
    end)

    describe('remove', function()
        before_each(function()
            assert.is_true(define())
            assert.is_true(registry.add('vava_food', 'vava_inv:items', 'pain', { label = 'Miche' }))
            events = {}
        end)

        it('est permis à l’auteur de l’entrée et émet core:registry:removed', function()
            assert.is_true(registry.remove('vava_food', 'vava_inv:items', 'pain'))
            assert.is_false(registry.has('vava_inv:items', 'pain'))
            assert.is_nil(registry.get('vava_inv:items', 'pain'))
            assert.equal(1, #events)
            assert.same({ registry = 'vava_inv:items', key = 'pain', owner = 'vava_food', reason = 'removed' }, events[1].payload)
        end)

        it('est permis au propriétaire du registre', function()
            assert.is_true(registry.remove('vava_inv', 'vava_inv:items', 'pain'))
            assert.is_false(registry.has('vava_inv:items', 'pain'))
        end)

        it('est refusé à tout autre, et sur une clé absente ou un registre inconnu', function()
            local ok, err = registry.remove('vava_tiers', 'vava_inv:items', 'pain')
            assert.is_false(ok)
            assert.matches('auteur', err)
            assert.is_true(registry.has('vava_inv:items', 'pain'))
            ok, err = registry.remove('vava_food', 'vava_inv:items', 'pomme')
            assert.is_false(ok)
            assert.matches('absente', err)
            ok, err = registry.remove('vava_food', 'vava_inv:absent', 'pain')
            assert.is_false(ok)
            assert.matches('inexistant', err)
            assert.equal(0, #events)
        end)
    end)

    describe('lecture', function()
        it('rend nil ou faux pour un registre inconnu, sans erreur', function()
            assert.is_nil(registry.get('vava_inv:absent', 'pain'))
            assert.is_false(registry.has('vava_inv:absent', 'pain'))
            assert.is_nil(registry.all('vava_inv:absent'))
        end)

        it('all rend une nouvelle table à chaque appel', function()
            assert.is_true(define())
            assert.is_true(registry.add('vava_food', 'vava_inv:items', 'pain', { label = 'Miche' }))
            local first = registry.all('vava_inv:items')
            first.pomme = { label = 'Pomme' }
            assert.is_nil(registry.all('vava_inv:items').pomme)
        end)
    end)

    describe('purgeOwner', function()
        before_each(function()
            assert.is_true(define())
            assert.is_true(registry.define('vava_food', 'vava_food:recettes', { schema = { type = 'string' } }))
            assert.is_true(registry.add('vava_food', 'vava_inv:items', 'pain', { label = 'Miche' }))
            assert.is_true(registry.add('vava_inv', 'vava_inv:items', 'sac', { label = 'Sac' }))
            assert.is_true(registry.add('vava_inv', 'vava_food:recettes', 'soupe', 'soupe'))
            events = {}
        end)

        it('supprime les registres du propriétaire et ses entrées ailleurs, puis émet dropped et removed', function()
            registry.purgeOwner('vava_food')
            assert.is_false(registry.exists('vava_food:recettes'))
            assert.is_true(registry.exists('vava_inv:items'))
            assert.is_false(registry.has('vava_inv:items', 'pain'))
            assert.is_true(registry.has('vava_inv:items', 'sac'))
            assert.equal(2, #events)
            assert.equal('core:registry:dropped', events[1].hook)
            assert.same({ registry = 'vava_food:recettes', owner = 'vava_food' }, events[1].payload)
            assert.equal('core:registry:removed', events[2].hook)
            assert.same({ registry = 'vava_inv:items', key = 'pain', owner = 'vava_food', reason = 'owner_stopped' }, events[2].payload)
        end)

        it('ne touche à rien pour un propriétaire sans enregistrement', function()
            registry.purgeOwner('vava_tiers')
            assert.is_true(registry.exists('vava_food:recettes'))
            assert.equal(2, #(function() local n = {} for k in pairs(registry.all('vava_inv:items')) do n[#n + 1] = k end return n end)())
            assert.equal(0, #events)
        end)

        it('laisse une place libre après la purge (compteur de taille à jour)', function()
            registry.purgeOwner('vava_food')
            assert.is_true(registry.add('vava_tiers', 'vava_inv:items', 'pain', { label = 'Autre miche' }))
            assert.equal('Autre miche', registry.get('vava_inv:items', 'pain').label)
        end)
    end)
end)
