local helper = require('tests.helper')

-- RPC du core (server/core/rpc.lua), au regard de la section « core.rpc » de docs/api.md : enregistrement, chaîne de
-- contrôle d'une requête (RPC connu, limite, schéma, handler isolé), réponses au seul appelant, entiers arrivés en
-- flottant convertis à tout niveau (0.8.1), appels serveur → client (returns obligatoire, 0.9.0), réponse retenue
-- quand le joueur est parti pendant le handler (0.9.0).
-- Les net events sont capturés par une doublure de RegisterNetEvent ; `source` est posé avant chaque requête.
describe('vAvA.rpc', function()
    local rpc, EVENTS, now, netHandlers, sent, realPrint, printed
    -- réaction d'un faux client à une demande serveur → client (rpc.lua garde TriggerClientEvent en local : la
    -- doublure posée avant le chargement délègue ici)
    local onClientRequest

    before_each(function()
        helper.reset()
        now = 0
        _G.GetGameTimer = function() return now end
        realPrint = _G.print
        printed = {}
        _G.print = function(line) printed[#printed + 1] = tostring(line) end
        netHandlers, sent = {}, {}
        _G.RegisterNetEvent = function(name, fn) netHandlers[name] = fn end
        onClientRequest = nil
        _G.TriggerClientEvent = function(event, src, ...)
            sent[#sent + 1] = { event = event, src = src, n = select('#', ...), args = { ... } }
            if event == EVENTS.CLIENT_REQUEST and onClientRequest then onClientRequest(src, ...) end
        end
        -- envoi latent (net.lua en estimation, faute de msgpack.pack_args hors jeu) : noté avec son débit
        _G.TriggerLatentClientEvent = function(event, src, rate, ...)
            sent[#sent + 1] = { event = event, src = src, rate = rate, latent = true, n = select('#', ...), args = { ... } }
            if event == EVENTS.CLIENT_REQUEST and onClientRequest then onClientRequest(src, ...) end
        end
        _G.DoesPlayerExist = function(src) return src == 1 or src == 2 end
        helper.loadAll({
            'shared/init.lua',
            'config/shared.lua',
            'shared/lib/table.lua',
            'shared/lib/string.lua',
            'shared/lib/schema.lua',
            'shared/lib/pending.lua',
            'shared/core/logger.lua',
            'shared/core/hooks.lua',
            'config/server.lua',
            'server/core/ratelimit.lua',
            'server/core/netsize.lua',
            'server/core/netstats.lua',
            'server/core/net.lua',
            'server/core/rpc.lua',
        })
        rpc, EVENTS = vAvA.rpc, vAvA.EVENTS
        assert.is_true(rpc.init())
        rpc.start()
    end)

    after_each(function()
        _G.print = realPrint
    end)

    --- Requête d'un client : (id, nom, nombre d'arguments, arguments).
    local function request(src, id, name, args, count)
        _G.source = src
        netHandlers[EVENTS.RPC_REQUEST](id, name, count or #args, args)
    end

    --- Dernière réponse envoyée à un joueur : { src, id, ok, ... }.
    local function lastReply()
        for i = #sent, 1, -1 do
            if sent[i].event == EVENTS.RPC_RESPONSE then return sent[i] end
        end
        return nil
    end

    local function register(name, args, handler, rateLimit)
        return rpc.register('vava_test', name, { args = args, rateLimit = rateLimit }, handler or function() return true end)
    end

    describe('register', function()
        it('accepte un nom préfixé par la ressource et des arguments décrits', function()
            assert.is_true(register('vava_test:ping', {}))
        end)

        it('refuse un nom sans le préfixe de la ressource ou qui n’est pas un identifiant', function()
            local ok, err = rpc.register('vava_test', 'autre:ping', { args = {} }, function() end)
            assert.is_false(ok)
            assert.matches('nom de RPC invalide', err)
            ok = rpc.register('vava_test', 'vava_test:p ing', { args = {} }, function() end)
            assert.is_false(ok)
        end)

        it('refuse un RPC déjà enregistré, en nommant son propriétaire', function()
            assert.is_true(register('vava_test:ping', {}))
            local ok, err = rpc.register('vava_autre', 'vava_test:ping', { args = {} }, function() end)
            assert.is_false(ok)
            assert.matches('vava_test', err)
        end)

        it('exige des options, une liste d’arguments et un handler appelable', function()
            local ok, err = rpc.register('vava_test', 'vava_test:ping', nil, function() end)
            assert.is_false(ok)
            assert.matches('options', err)
            ok, err = rpc.register('vava_test', 'vava_test:ping', {}, function() end)
            assert.is_false(ok)
            assert.matches('args', err)
            ok, err = rpc.register('vava_test', 'vava_test:ping', { args = {} }, 'handler')
            assert.is_false(ok)
            assert.matches('handler', err)
        end)

        it('compile les arguments comme une entrée réseau (any, function et strict = false refusés)', function()
            local ok, err = register('vava_test:ping', { { type = 'any' } })
            assert.is_false(ok)
            assert.matches('interdit', err)
            ok = register('vava_test:ping', { { type = 'table', fields = {}, strict = false } })
            assert.is_false(ok)
        end)

        it('borne le nombre d’arguments à rpc.maxArgs et valide la règle de limite', function()
            local many = {}
            for i = 1, vAvA.config.server.rpc.maxArgs + 1 do many[i] = { type = 'integer' } end
            local ok, err = register('vava_test:ping', many)
            assert.is_false(ok)
            assert.matches('maximum', err)
            ok, err = register('vava_test:ping', {}, nil, { capacity = 0, refillPerSecond = 1 })
            assert.is_false(ok)
            assert.matches('rateLimit', err)
        end)
    end)

    describe('requête entrante', function()
        it('ignore une requête mal formée (identifiant ou nom invalides) sans répondre', function()
            assert.is_true(register('vava_test:ping', {}))
            request(1, -1, 'vava_test:ping', {})
            request(1, 1.5, 'vava_test:ping', {})
            request(1, 1, 12, {})
            assert.is_nil(lastReply())
        end)

        it('répond unknown_rpc à un RPC inconnu', function()
            request(1, 7, 'vava_test:absent', {})
            local reply = lastReply()
            assert.equal(1, reply.src)
            assert.same({ 7, false, 'unknown_rpc' }, { reply.args[1], reply.args[2], reply.args[3] })
        end)

        it('répond invalid_args quand le schéma refuse, sans appeler le handler', function()
            local called = false
            assert.is_true(register('vava_test:ping', { { type = 'integer', min = 1, max = 10 } }, function() called = true return true end))
            request(1, 3, 'vava_test:ping', { 11 })
            assert.same({ 3, false, 'invalid_args' }, { lastReply().args[1], lastReply().args[2], lastReply().args[3] })
            request(1, 4, 'vava_test:ping', { 5, 6 })   -- une valeur de trop
            assert.equal('invalid_args', lastReply().args[3])
            request(1, 5, 'vava_test:ping', {}, 0)      -- argument requis manquant
            assert.equal('invalid_args', lastReply().args[3])
            assert.is_false(called)
        end)

        it('appelle le handler avec la source et les arguments, et renvoie ses valeurs au seul appelant', function()
            local got
            assert.is_true(register('vava_test:ping', { { type = 'string', max = 8 }, { type = 'integer', optional = true } }, function(src, word, n)
                got = { src = src, word = word, n = n }
                return true, word .. '!', nil, 3
            end))
            request(2, 9, 'vava_test:ping', { 'salut' }, 1)
            assert.same({ src = 2, word = 'salut' }, got)
            local reply = lastReply()
            assert.equal(2, reply.src)
            assert.equal(9, reply.args[1])
            assert.is_true(reply.args[2])
            assert.equal(4, reply.args[3])                       -- nombre de valeurs, nil compris
            assert.same({ true, 'salut!', nil, 3 }, reply.args[4])
            assert.equal(1, #sent)
        end)

        it('traite un emit (id 0) sans répondre', function()
            local calls = 0
            assert.is_true(register('vava_test:ping', {}, function() calls = calls + 1 end))
            request(1, 0, 'vava_test:ping', {})
            assert.equal(1, calls)
            assert.equal(0, #sent)
        end)

        it('répond server_error quand le handler lève une erreur, sans en donner le détail', function()
            assert.is_true(register('vava_test:ping', {}, function() error('secret interne') end))
            request(1, 2, 'vava_test:ping', {})
            local reply = lastReply()
            assert.is_false(reply.args[2])
            assert.equal('server_error', reply.args[3])
            assert.equal(3, reply.n)
        end)

        it('convertit en entiers les flottants à valeur entière, à tout niveau', function()
            local got
            assert.is_true(register('vava_test:ping', {
                { type = 'integer' },
                { type = 'table', fields = {
                    n = { type = 'integer' },
                    x = { type = 'number' },
                    list = { type = 'array', items = { type = 'integer' } },
                    map = { type = 'map', key = { type = 'string' }, value = { type = 'integer' } },
                } },
            }, function(_, first, second)
                got = { first = first, second = second }
                return true
            end))
            request(1, 1, 'vava_test:ping', { 3.0, { n = 4.0, x = 2.0, list = { 1.0, 2.0 }, map = { a = 5.0 } } })
            assert.is_true(lastReply().args[2])
            assert.equal('integer', math.type(got.first))
            assert.equal('integer', math.type(got.second.n))
            assert.equal('float', math.type(got.second.x))
            assert.equal('integer', math.type(got.second.list[1]))
            assert.equal('integer', math.type(got.second.list[2]))
            assert.equal('integer', math.type(got.second.map.a))
        end)

        it('refuse toujours un flottant sans équivalent entier', function()
            assert.is_true(register('vava_test:ping', { { type = 'integer' } }))
            request(1, 1, 'vava_test:ping', { 3.5 })
            assert.equal('invalid_args', lastReply().args[3])
            request(1, 2, 'vava_test:ping', { 2 ^ 63 })
            assert.equal('invalid_args', lastReply().args[3])
        end)

        it('répond rate_limited au-delà de la limite du RPC, puis accepte de nouveau après la recharge', function()
            assert.is_true(register('vava_test:ping', {}, nil, { capacity = 2, refillPerSecond = 1 }))
            request(1, 1, 'vava_test:ping', {})
            request(1, 2, 'vava_test:ping', {})
            request(1, 3, 'vava_test:ping', {})
            assert.same({ 3, false, 'rate_limited' }, { lastReply().args[1], lastReply().args[2], lastReply().args[3] })
            request(2, 4, 'vava_test:ping', {})             -- un autre joueur a sa propre limite
            assert.is_true(lastReply().args[2])
            now = 1000
            request(1, 5, 'vava_test:ping', {})
            assert.is_true(lastReply().args[2])
        end)

        it('ne répond pas si le joueur est parti pendant un handler lent, même si son numéro est redonné (0.9.0)', function()
            -- le handler « attend la base » : le joueur part, un nouveau venu reçoit le même numéro et fait un appel
            -- portant le même petit identifiant ; la réponse du premier ne doit jamais lui parvenir
            assert.is_true(register('vava_test:quick', {}, function() return true, 'pour le nouveau' end))
            assert.is_true(register('vava_test:slow', {}, function(src)
                rpc.purgePlayer(src)
                request(src, 5, 'vava_test:quick', {})
                return true, 'liste du premier joueur'
            end))
            request(1, 5, 'vava_test:slow', {})
            local replies = {}
            for i = 1, #sent do
                if sent[i].event == EVENTS.RPC_RESPONSE then replies[#replies + 1] = sent[i] end
            end
            assert.equal(1, #replies)
            assert.same({ true, 'pour le nouveau' }, replies[1].args[4])
        end)

        it('ne répond pas non plus server_error à un joueur parti pendant le handler', function()
            assert.is_true(register('vava_test:slow', {}, function(src)
                rpc.purgePlayer(src)
                error('base injoignable')
            end))
            request(1, 6, 'vava_test:slow', {})
            assert.is_nil(lastReply())
        end)

        it('ignore un déclenchement local (sans source réseau)', function()
            local calls = 0
            assert.is_true(register('vava_test:ping', {}, function() calls = calls + 1 end))
            _G.source = 0
            netHandlers[EVENTS.RPC_REQUEST](1, 'vava_test:ping', 0, {})
            _G.source = nil
            netHandlers[EVENTS.RPC_REQUEST](1, 'vava_test:ping', 0, {})
            assert.equal(0, calls)
        end)
    end)

    describe('unregister et purge', function()
        it('retire un RPC à son propriétaire seulement', function()
            assert.is_true(register('vava_test:ping', {}))
            local ok, err = rpc.unregister('vava_autre', 'vava_test:ping')
            assert.is_false(ok)
            assert.matches('autre ressource', err)
            assert.is_true(rpc.unregister('vava_test', 'vava_test:ping'))
            ok, err = rpc.unregister('vava_test', 'vava_test:ping')
            assert.is_false(ok)
            assert.matches('inconnu', err)
            request(1, 1, 'vava_test:ping', {})
            assert.equal('unknown_rpc', lastReply().args[3])
        end)

        it('purgeOwner retire tous les RPC d’une ressource et laisse ceux des autres', function()
            assert.is_true(register('vava_test:a', {}))
            assert.is_true(register('vava_test:b', {}))
            assert.is_true(rpc.register('vava_autre', 'vava_autre:c', { args = {} }, function() return true end))
            rpc.purgeOwner('vava_test')
            request(1, 1, 'vava_test:a', {})
            assert.equal('unknown_rpc', lastReply().args[3])
            request(1, 2, 'vava_autre:c', {})
            assert.is_true(lastReply().args[2])
        end)
    end)

    describe('callClient', function()
        it('refuse une cible absente, un nom invalide, des options hors bornes', function()
            local ok, code = rpc.callClient('vava_test', nil, 99, 'vava_test:show')
            assert.is_false(ok)
            assert.equal('invalid_target', code)
            ok, code = rpc.callClient('vava_test', nil, 0, 'vava_test:show')
            assert.equal('invalid_target', code)
            ok, code = rpc.callClient('vava_test', nil, 1, 'pas un nom valide')
            assert.equal('invalid_name', code)
            ok, code = rpc.callClient('vava_test', { timeout = 1 }, 1, 'vava_test:show')
            assert.equal('invalid_options', code)
            ok, code = rpc.callClient('vava_test', { returns = { { type = 'any' } } }, 1, 'vava_test:show')
            assert.equal('invalid_options', code)
            assert.equal(0, #sent)
        end)

        it('envoie la demande au seul joueur visé et rend ses valeurs validées par returns, entiers convertis', function()
            -- le client répond pendant l'envoi : la promesse est résolue avant l'attente (pas de planificateur ici)
            onClientRequest = function(src, id)
                _G.source = src
                netHandlers[EVENTS.CLIENT_RESPONSE](id, true, 2, { 7.0, 'vu' })
            end
            local ok, n, word = rpc.callClient('vava_test', { returns = { { type = 'integer' }, { type = 'string' } } }, 2, 'vava_test:show', 'bonjour', 1)
            assert.is_true(ok)
            assert.equal(7, n)
            assert.equal('integer', math.type(n))
            assert.equal('vu', word)
            assert.equal(1, #sent)
            assert.equal(EVENTS.CLIENT_REQUEST, sent[1].event)
            assert.equal(2, sent[1].src)
            assert.equal('vava_test:show', sent[1].args[2])
            assert.equal(2, sent[1].args[3])
            assert.same({ 'bonjour', 1 }, sent[1].args[4])
        end)

        it('refuse une réponse qui ne respecte pas returns, ou venant d’un autre joueur', function()
            local answerFrom, answerValues = 2, { 'pas un entier' }
            onClientRequest = function(src, id)
                _G.source = answerFrom
                netHandlers[EVENTS.CLIENT_RESPONSE](id, true, #answerValues, answerValues)
                -- une réponse usurpée est ignorée : la vraie suit, pour ne pas bloquer le test
                if answerFrom ~= src then
                    _G.source = src
                    netHandlers[EVENTS.CLIENT_RESPONSE](id, true, 1, { 1 })
                end
            end
            local ok, code = rpc.callClient('vava_test', { returns = { { type = 'integer' } } }, 2, 'vava_test:show')
            assert.is_false(ok)
            assert.equal('invalid_response', code)
            answerFrom, answerValues = 1, { 99 }
            local ok2, value = rpc.callClient('vava_test', { returns = { { type = 'integer' } } }, 2, 'vava_test:show')
            assert.is_true(ok2)
            assert.equal(1, value)
        end)

        -- 0.9.0 : returns obligatoire, comme args pour un RPC (audit T-010)
        it('refuse des options sans returns, avant tout envoi', function()
            local ok, code = rpc.callClient('vava_test', {}, 2, 'vava_test:show')
            assert.is_false(ok)
            assert.equal('invalid_options', code)
            ok, code = rpc.callClient('vava_test', { timeout = 1000 }, 2, 'vava_test:show')
            assert.equal('invalid_options', code)
            ok, code = rpc.callClient('vava_test', { returns = 'integer' }, 2, 'vava_test:show')
            assert.equal('invalid_options', code)
            ok, code = rpc.callClient('vava_test', { returns = { type = 'integer' } }, 2, 'vava_test:show')
            assert.equal('invalid_options', code)
            local many = {}
            for i = 1, vAvA.config.server.rpc.maxReturns + 1 do many[i] = { type = 'integer' } end
            ok, code = rpc.callClient('vava_test', { returns = many }, 2, 'vava_test:show')
            assert.equal('invalid_options', code)
            assert.equal(0, #sent)
        end)

        it('returns = {} : accepte un simple acquittement, refuse toute valeur renvoyée', function()
            local answer = {}
            onClientRequest = function(src, id)
                _G.source = src
                netHandlers[EVENTS.CLIENT_RESPONSE](id, true, #answer, answer)
            end
            local ok, extra = rpc.callClient('vava_test', { returns = {} }, 2, 'vava_test:show')
            assert.is_true(ok)
            assert.is_nil(extra)
            answer = { { libre = string.rep('x', 100) } }
            local code
            ok, code = rpc.callClient('vava_test', { returns = {} }, 2, 'vava_test:show')
            assert.is_false(ok)
            assert.equal('invalid_response', code)
        end)

        it('sans options (callClient court), aucune valeur n’est acceptée du client', function()
            local count, values = 0, {}
            onClientRequest = function(src, id)
                _G.source = src
                netHandlers[EVENTS.CLIENT_RESPONSE](id, true, count, values)
            end
            local ok = rpc.callClient('vava_test', nil, 2, 'vava_test:show', 'ordre')
            assert.is_true(ok)
            -- une valeur, même nil, est refusée : le module n'a rien décrit
            count, values = 1, { 'forgée' }
            local code
            ok, code = rpc.callClient('vava_test', nil, 2, 'vava_test:show')
            assert.is_false(ok)
            assert.equal('invalid_response', code)
            count, values = 1, {}
            ok, code = rpc.callClient('vava_test', nil, 2, 'vava_test:show')
            assert.is_false(ok)
            assert.equal('invalid_response', code)
        end)
    end)

    -- 0.10.0 : envois par core.net (mesurés, comptés, latents au-delà du seuil)
    describe('réponses et appels par core.net', function()
        local netCfg

        before_each(function()
            netCfg = vAvA.config.server.net
        end)

        local function events(name)
            local found = {}
            for i = 1, #sent do
                if sent[i].event == name then found[#found + 1] = sent[i] end
            end
            return found
        end

        it('réponse de 20 Ko : préavis (id, octets, débit) puis réponse latente, dans cet ordre', function()
            assert.is_true(register('vava_test:gros', {}, function() return true, string.rep('x', 20480) end))
            request(1, 4, 'vava_test:gros', {})
            assert.equal(2, #sent)
            assert.equal(EVENTS.RPC_LATENT, sent[1].event)
            assert.is_nil(sent[1].latent)
            assert.equal(4, sent[1].args[1])
            assert.is_true(sent[1].args[2] > 20480)
            assert.equal(netCfg.latent.bytesPerSecond, sent[1].args[3])
            assert.equal(EVENTS.RPC_RESPONSE, sent[2].event)
            assert.is_true(sent[2].latent)
            assert.equal(netCfg.latent.bytesPerSecond, sent[2].rate)
            assert.same({ 4, true, 2 }, { sent[2].args[1], sent[2].args[2], sent[2].args[3] })
            -- délai jusqu'à l'arrivée : le transfert de ce seul message (environ 20 Ko à 64 Ko/s)
            assert.equal(math.ceil(sent[1].args[2] * 1000 / netCfg.latent.bytesPerSecond), sent[1].args[4])
        end)

        -- relecture réseau de T-013 : un second latent attend le premier, le préavis le dit
        it('préavis : le délai annoncé compte les latents déjà en route vers le joueur', function()
            assert.is_true(register('vava_test:gros', {}, function() return true, string.rep('x', 100000) end))
            request(1, 1, 'vava_test:gros', {})
            request(1, 2, 'vava_test:gros', {})
            local notices = events(EVENTS.RPC_LATENT)
            assert.equal(2, #notices)
            local first, second = notices[1].args[4], notices[2].args[4]
            assert.is_true(first > 1500 and first < 1600, 'premier : ' .. first)
            assert.is_true(second >= 2 * first - 1 and second <= 2 * first, 'second : ' .. second)
        end)

        it('callClient derrière un latent en route : attente du serveur allongée des deux transferts', function()
            assert.is_true(register('vava_test:gros', {}, function() return true, string.rep('x', 100000) end))
            request(2, 1, 'vava_test:gros', {})   -- environ 1,5 s de latent vers le joueur 2
            local timeout = vAvA.config.server.rpc.defaultTimeoutMs
            local shared = vAvA.config.shared.rpc
            local extended
            onClientRequest = function(src, id)
                extended = helper.timers[#helper.timers].ms
                _G.source = src
                netHandlers[EVENTS.CLIENT_RESPONSE](id, true, 0, {})
            end
            assert.is_true(rpc.callClient('vava_test', nil, 2, 'vava_test:show', string.rep('x', 20000)))
            local waited = extended - timeout - shared.latentMarginMs
            -- 100 Ko puis 20 Ko à 64 Ko/s : environ 1 527 + 306 ms
            assert.is_true(waited > 1800 and waited < 1900, 'attente : ' .. waited)
        end)

        it('le préavis reste borné à rpc.maxLatentExtendMs', function()
            local shared = vAvA.config.shared.rpc
            shared.maxLatentExtendMs = 1000
            local extended
            onClientRequest = function(src, id)
                extended = helper.timers[#helper.timers].ms
                _G.source = src
                netHandlers[EVENTS.CLIENT_RESPONSE](id, true, 0, {})
            end
            assert.is_true(rpc.callClient('vava_test', nil, 2, 'vava_test:show', string.rep('x', 100000)))
            assert.equal(vAvA.config.server.rpc.defaultTimeoutMs + 1000, extended)
        end)

        it('latent = never : la même réponse part en fiable, sans préavis', function()
            assert.is_true(rpc.register('vava_test', 'vava_test:etat', { args = {}, latent = 'never' }, function()
                return true, string.rep('x', 20480)
            end))
            request(1, 4, 'vava_test:etat', {})
            assert.equal(1, #sent)
            assert.equal(EVENTS.RPC_RESPONSE, sent[1].event)
            assert.is_nil(sent[1].latent)
        end)

        it('register refuse une autre valeur de latent', function()
            for _, value in ipairs({ 'oui', 'always', true, 1 }) do
                local ok, err = rpc.register('vava_test', 'vava_test:x', { args = {}, latent = value }, function() end)
                assert.is_false(ok)
                assert.matches('latent', err)
            end
            assert.is_true(rpc.register('vava_test', 'vava_test:x', { args = {}, latent = 'auto' }, function() end))
        end)

        it('réponse au-delà de maxBytes : (id, false, too_large), erreur en console avec le nom du RPC', function()
            assert.is_true(register('vava_test:enorme', {}, function() return true, string.rep('x', netCfg.maxBytes) end))
            request(1, 5, 'vava_test:enorme', {})
            assert.equal(1, #sent)
            assert.same({ 5, false, 'too_large' }, { sent[1].args[1], sent[1].args[2], sent[1].args[3] })
            local named = false
            for _, line in ipairs(printed) do
                if line:find('rpc vava_test:enorme', 1, true) then named = true end
            end
            assert.is_true(named)
        end)

        it('joueur saturé de réponses latentes : (id, false, saturated)', function()
            assert.is_true(register('vava_test:gros', {}, function() return true, string.rep('x', 200000) end))
            request(1, 1, 'vava_test:gros', {})
            request(1, 2, 'vava_test:gros', {})
            request(1, 3, 'vava_test:gros', {})
            local replies = events(EVENTS.RPC_RESPONSE)
            assert.equal(3, #replies)
            assert.is_true(replies[2].args[2])
            assert.same({ 3, false, 'saturated' }, { replies[3].args[1], replies[3].args[2], replies[3].args[3] })
            assert.is_nil(replies[3].latent)
            assert.equal(2, #events(EVENTS.RPC_LATENT))
        end)

        it('compte un RPC inconnu sous « rpc <inconnu> », quel que soit le nom envoyé', function()
            for i = 1, 100 do
                now = i * 100   -- limite globale du joueur rechargée
                request(1, i, 'vava_test:absent' .. i, {})
            end
            assert.equal(100, #events(EVENTS.RPC_RESPONSE))
            local stats = vAvA.net.stats({ limit = 50 })
            assert.equal(1, #stats.events)
            assert.same({ vAvA.resourceName, 'rpc <inconnu>', 100 },
                { stats.events[1].resource, stats.events[1].label, stats.events[1].messages })
        end)

        it('compte les réponses sous la ressource et le nom du RPC enregistré', function()
            assert.is_true(register('vava_test:ping', {}))
            request(1, 1, 'vava_test:ping', {})
            local event = vAvA.net.stats().events[1]
            assert.same({ 'vava_test', 'rpc vava_test:ping', 1 }, { event.resource, event.label, event.messages })
        end)

        it('callClient au-delà du seuil : demande latente, attente du serveur allongée du temps de transfert', function()
            local timeout = vAvA.config.server.rpc.defaultTimeoutMs
            local shared = vAvA.config.shared.rpc
            local seen
            onClientRequest = function(src, id)
                seen = {}
                for _, timer in ipairs(helper.timers) do seen[#seen + 1] = timer.ms end
                -- l'échéance d'origine est dépassée : elle ne résout plus rien, la réponse du client passe encore
                helper.timers[1].fn()
                _G.source = src
                netHandlers[EVENTS.CLIENT_RESPONSE](id, true, 0, {})
            end
            local ok = rpc.callClient('vava_test', nil, 2, 'vava_test:show', string.rep('x', 20000))
            assert.is_true(ok)
            assert.is_true(events(EVENTS.CLIENT_REQUEST)[1].latent)
            assert.equal(2, #seen)
            assert.equal(timeout, seen[1])
            -- délai d'origine + transfert (environ 20 Ko à 64 Ko/s : 306 ms) + marge
            local transfer = seen[2] - timeout - shared.latentMarginMs
            assert.is_true(transfer >= 305 and transfer <= 310, 'transfert : ' .. transfer)
        end)

        it('callClient trop gros : too_large tout de suite, rien n’est envoyé', function()
            local ok, code = rpc.callClient('vava_test', nil, 2, 'vava_test:show', string.rep('x', netCfg.maxBytes))
            assert.is_false(ok)
            assert.equal('too_large', code)
            assert.equal(0, #sent)
        end)
    end)
end)
