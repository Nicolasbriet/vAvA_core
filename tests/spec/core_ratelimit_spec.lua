local helper = require('tests.helper')

-- Limitation de débit du core (server/core/ratelimit.lua) : règles bornées par config/server.lua, seau à jetons
-- rechargé à l'accès (aucune boucle), isolement par joueur et par clé, purge, hook core:ratelimit:exceeded limité en
-- fréquence. GetGameTimer et print sont remplacés AVANT le chargement (gardés en local par les fichiers du core).
describe('vAvA.ratelimit', function()
    local ratelimit, hooks, now, logs, realPrint

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
            'config/server.lua',
            'server/core/ratelimit.lua',
        })
        ratelimit, hooks = vAvA.ratelimit, vAvA.hooks
    end)

    after_each(function()
        _G.print = realPrint
    end)

    local function rule(capacity, refillPerSecond)
        local normalized, err = ratelimit.normalizeRule({ capacity = capacity, refillPerSecond = refillPerSecond })
        assert.is_not_nil(normalized, err)
        return normalized
    end

    describe('normalizeRule', function()
        it('convertit une règle valide : capacité entière et recharge par milliseconde', function()
            local normalized = rule(5, 2)
            assert.equal(5, normalized.capacity)
            assert.is_near(0.002, normalized.refillPerMs, 1e-12)
        end)

        it('refuse ce qui n’est pas une table', function()
            for _, value in ipairs({ 'règle', 12, true }) do
                local normalized, err = ratelimit.normalizeRule(value)
                assert.is_nil(normalized)
                assert.is_string(err)
            end
            assert.is_nil(ratelimit.normalizeRule(nil))
        end)

        it('borne la capacité aux entiers de bounds.minCapacity à bounds.maxCapacity', function()
            local bounds = vAvA.config.server.rateLimit.bounds
            assert.is_not_nil(rule(bounds.minCapacity, 1))
            assert.is_not_nil(rule(bounds.maxCapacity, 1))
            for _, capacity in ipairs({ bounds.minCapacity - 1, bounds.maxCapacity + 1, 2.5, '3' }) do
                local normalized, err = ratelimit.normalizeRule({ capacity = capacity, refillPerSecond = 1 })
                assert.is_nil(normalized, tostring(capacity))
                assert.matches('capacity', err)
            end
        end)

        it('borne la recharge et refuse NaN', function()
            local bounds = vAvA.config.server.rateLimit.bounds
            assert.is_not_nil(rule(3, bounds.minRefillPerSecond))
            assert.is_not_nil(rule(3, bounds.maxRefillPerSecond))
            for _, refill in ipairs({ bounds.minRefillPerSecond / 2, bounds.maxRefillPerSecond + 1, 0 / 0, '1' }) do
                local normalized, err = ratelimit.normalizeRule({ capacity = 3, refillPerSecond = refill })
                assert.is_nil(normalized)
                assert.matches('refillPerSecond', err)
            end
        end)

        it('accepte la configuration livrée (global et rpcDefault)', function()
            assert.is_not_nil(ratelimit.normalizeRule(vAvA.config.server.rateLimit.global))
            assert.is_not_nil(ratelimit.normalizeRule(vAvA.config.server.rateLimit.rpcDefault))
        end)
    end)

    describe('consume', function()
        it('accorde une rafale de capacity jetons puis refuse', function()
            local r = rule(3, 1)
            assert.is_true(ratelimit.consume(1, 'a:b', r))
            assert.is_true(ratelimit.consume(1, 'a:b', r))
            assert.is_true(ratelimit.consume(1, 'a:b', r))
            assert.is_false(ratelimit.consume(1, 'a:b', r))
        end)

        it('rend les jetons au rythme de refillPerSecond, calculé au moment de l’accès', function()
            local r = rule(2, 1)
            assert.is_true(ratelimit.consume(1, 'a:b', r))
            assert.is_true(ratelimit.consume(1, 'a:b', r))
            now = 500
            assert.is_false(ratelimit.consume(1, 'a:b', r))   -- un demi-jeton seulement
            now = 1000
            assert.is_true(ratelimit.consume(1, 'a:b', r))    -- un jeton entier rendu
            assert.is_false(ratelimit.consume(1, 'a:b', r))
        end)

        it('ne dépasse jamais la capacité après une longue pause', function()
            local r = rule(2, 10)
            assert.is_true(ratelimit.consume(1, 'a:b', r))
            now = 60000
            assert.is_true(ratelimit.consume(1, 'a:b', r))
            assert.is_true(ratelimit.consume(1, 'a:b', r))
            assert.is_false(ratelimit.consume(1, 'a:b', r))
        end)

        it('tient un seau par joueur et par clé', function()
            local r = rule(1, 1)
            assert.is_true(ratelimit.consume(1, 'a:b', r))
            assert.is_false(ratelimit.consume(1, 'a:b', r))
            assert.is_true(ratelimit.consume(2, 'a:b', r))
            assert.is_true(ratelimit.consume(1, 'a:c', r))
        end)

        it('ne tient pas compte d’une horloge qui recule', function()
            local r = rule(1, 1)
            now = 5000
            assert.is_true(ratelimit.consume(1, 'a:b', r))
            now = 0
            assert.is_false(ratelimit.consume(1, 'a:b', r))
        end)
    end)

    describe('dépassement', function()
        it('journalise et émet core:ratelimit:exceeded une fois par intervalle, avec le nombre de refus tus', function()
            local received = {}
            hooks.subscribe('test', 'after', 'core:ratelimit:exceeded', function(payload)
                received[#received + 1] = payload
            end)
            local r = rule(1, 0.01)
            assert.is_true(ratelimit.consume(7, 'a:b', r))
            for _ = 1, 4 do assert.is_false(ratelimit.consume(7, 'a:b', r)) end
            assert.equal(1, #received)
            assert.equal(7, received[1].source)
            assert.equal('a:b', received[1].key)
            assert.equal(0, received[1].suppressed)
            local warnings = 0
            for _, line in ipairs(logs) do
                if line:find('limite dépassée sur a:b', 1, true) then warnings = warnings + 1 end
            end
            assert.equal(1, warnings)
            -- intervalle passé : un second signalement, qui compte les trois refus tus
            now = vAvA.config.shared.log.throttleMs
            assert.is_false(ratelimit.consume(7, 'a:b', r))
            assert.equal(2, #received)
            assert.equal(3, received[2].suppressed)
        end)
    end)

    describe('purge', function()
        it('purgePlayer rend sa pleine rafale au joueur, et à lui seul', function()
            local r = rule(1, 0.01)
            assert.is_true(ratelimit.consume(1, 'a:b', r))
            assert.is_true(ratelimit.consume(2, 'a:b', r))
            ratelimit.purgePlayer(1)
            assert.is_true(ratelimit.consume(1, 'a:b', r))
            assert.is_false(ratelimit.consume(2, 'a:b', r))
        end)

        it('purgeKey oublie la clé chez tous les joueurs, sans toucher aux autres clés', function()
            local r = rule(1, 0.01)
            assert.is_true(ratelimit.consume(1, 'a:b', r))
            assert.is_true(ratelimit.consume(2, 'a:b', r))
            assert.is_true(ratelimit.consume(1, 'a:c', r))
            ratelimit.purgeKey('a:b')
            assert.is_true(ratelimit.consume(1, 'a:b', r))
            assert.is_true(ratelimit.consume(2, 'a:b', r))
            assert.is_false(ratelimit.consume(1, 'a:c', r))
        end)
    end)
end)
