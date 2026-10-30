local helper = require('tests.helper')

-- Arrivée côté serveur (modules/vava_arrival/server/store.lua, kit.lua, welcome.lua, admin.lua, T-022) avec des
-- doublures : base en mémoire qui respecte les conditions des requêtes (`WHERE kit = ?`, `welcomed_at IS NULL`) et
-- compte les lignes touchées, inventaire, personnage actif, envois, droits, journaux, horloge fixe ; CreateThread
-- exécuté aussitôt (tests/helper.lua). Règles documentées : README du module et docs/plan/specs/T-022.md § 7 et § 11.

describe('vava_arrival server', function()
    local store, welcome, admin, cfg, KIT, EVENTS, HOOKS
    local rows, queries, failures, before, after
    local active, accounts, names, allowed, known
    local exchanges, exchangeAnswers, sent, emitted, chats, adminLogs, journal, logs
    local now, timer

    local SOURCE, ACCOUNT, CHARACTER = 5, 50, 100
    local SPAWN = { source = SOURCE, characterId = CHARACTER }

    local function copy(value)
        if type(value) ~= 'table' then return value end
        local out = {}
        for key, item in pairs(value) do out[key] = copy(item) end
        return out
    end

    -- Base en mémoire : rows[character_id] = { account_id, kit, kit_at, welcomed_at, welcome_sends, created_at }.
    local handlers = {
        SELECT_ROW = function(p)
            local row = rows[p[1]]
            if not row then return nil end
            return { kit = row.kit, kit_at = row.kit_at, welcomed_at = row.welcomed_at, welcome_sends = row.welcome_sends }
        end,
        INSERT_ROW = function(p)
            if rows[p[1]] then return 0 end
            rows[p[1]] = { account_id = p[2], kit = 'due', welcome_sends = 0, created_at = p[3] }
            return 1
        end,
        TRANSITION = function(p)
            local row = rows[p[3]]
            if not row or row.kit ~= p[4] then return 0 end
            row.kit, row.kit_at = p[1], p[2]
            return 1
        end,
        COUNT_KITS = function(p)
            local count = 0
            for id, row in pairs(rows) do
                if row.account_id == p[1] and id ~= p[2] and (row.kit == 'claimed' or row.kit == 'given' or row.kit == 'uncertain')
                    and row.kit_at and row.kit_at >= p[3] then
                    count = count + 1
                end
            end
            return count
        end,
        COUNT_SEND = function(p)
            local row = rows[p[1]]
            if not row then return 0 end
            row.welcome_sends = row.welcome_sends + 1
            return 1
        end,
        ACK = function(p)
            local row = rows[p[2]]
            if not row or row.welcomed_at ~= nil then return 0 end
            row.welcomed_at = p[1]
            return 1
        end,
        REGIVE = function(p)
            local row = rows[p[1]]
            if row then
                row.kit, row.kit_at = 'given', p[6]
                return 2
            end
            rows[p[1]] = { account_id = p[2], kit = 'given', kit_at = p[3], welcomed_at = p[4], welcome_sends = 0, created_at = p[5] }
            return 1
        end,
        REPLAY = function(p)
            local row = rows[p[1]]
            if row then
                row.welcomed_at, row.welcome_sends = nil, 1
                return 2
            end
            rows[p[1]] = { account_id = p[2], kit = 'none', welcome_sends = 1, created_at = p[3] }
            return 1
        end,
    }

    local nameOf
    local function run(sql, params)
        local name = nameOf[sql]
        assert.is_string(name, 'requête inconnue : ' .. tostring(sql))
        queries[#queries + 1] = name
        if before[name] then
            local fn = before[name]
            before[name] = nil
            fn(params)
        end
        if failures[name] then return nil, failures[name] end
        local result = handlers[name](params)
        if after[name] then
            local fn = after[name]
            after[name] = nil
            fn(params)
        end
        return result
    end

    local function count(list, value)
        local n = 0
        for _, item in ipairs(list) do if item == value then n = n + 1 end end
        return n
    end

    local function kinds()
        local out = {}
        for i, entry in ipairs(journal) do out[i] = entry.kind end
        return out
    end

    before_each(function()
        helper.reset()
        VavaArrival = nil
        rows, queries, failures, before, after = {}, {}, {}, {}, {}
        active, accounts, names, allowed, known = { [SOURCE] = CHARACTER }, { [SOURCE] = ACCOUNT, [7] = 70, [8] = 80 },
            { [SOURCE] = 'Aldric Morn' }, { [8] = true }, {}
        exchanges, exchangeAnswers, sent, emitted, chats, adminLogs, journal = {}, {}, {}, {}, {}, {}, {}
        logs = { error = {}, warn = {}, info = {} }
        now, timer = 1761832800, 100000
        _G.GetGameTimer = function() return timer end

        helper.loadAll({
            'modules/vava_arrival/shared/constants.lua',
            'modules/vava_arrival/config.lua',
            'modules/vava_arrival/shared/rules.lua',
        })
        KIT, EVENTS, HOOKS = VavaArrival.KIT, VavaArrival.EVENTS, VavaArrival.HOOKS
        cfg = VavaArrival.config
        VavaArrival.resource = 'vava_arrival'
        VavaArrival.log = {
            error = function(fmt, ...) logs.error[#logs.error + 1] = fmt:format(...) end,
            warn = function(fmt, ...) logs.warn[#logs.warn + 1] = fmt:format(...) end,
            info = function(fmt, ...) logs.info[#logs.info + 1] = fmt:format(...) end,
            debug = function() end,
        }
        VavaArrival.bridge = {
            CONSOLE = 0, INVENTORY = 'vava_inventory',
            db = { single = run, scalar = run, update = run, insert = run },
            Now = function() return now end,
            ActiveCharacterId = function(src) return active[src] end,
            GetAccountId = function(src) return accounts[src] end,
            GetCharacterName = function(src) return names[src] end,
            ItemExists = function(name) return known[name] ~= false end,
            DeclareItem = function() return true end,
            Exchange = function(src, removals, additions)
                exchanges[#exchanges + 1] = { source = src, removals = copy(removals), additions = copy(additions) }
                local answer = table.remove(exchangeAnswers, 1) or { true }
                return table.unpack(answer)
            end,
            Send = function(target, event, ...)
                -- jamais à tous, jamais une liste, jamais un autre joueur que celui du personnage visé
                assert.equal('integer', math.type(target))
                assert.is_true(target > 0)
                assert.is_not_nil(active[target])
                sent[#sent + 1] = { target = target, event = event, args = table.pack(...) }
                return true
            end,
            Emit = function(name, payload) emitted[#emitted + 1] = { name = name, payload = copy(payload) } end,
            IsAllowed = function(src) return src == 0 or allowed[src] == true end,
            AdminLog = function(src, label, details) adminLogs[#adminLogs + 1] = { source = src, label = label, details = copy(details) } end,
            Chat = function(src, text) chats[#chats + 1] = { source = src, text = text } end,
        }
        VavaArrival.journal = { write = function(kind, entry) journal[#journal + 1] = { kind = kind, entry = copy(entry) } end }

        helper.loadAll({
            'modules/vava_arrival/server/store.lua',
            'modules/vava_arrival/server/kit.lua',
            'modules/vava_arrival/server/welcome.lua',
            'modules/vava_arrival/server/admin.lua',
        })
        store, welcome, admin = VavaArrival.store, VavaArrival.welcome, VavaArrival.admin
        nameOf = {}
        for name, sql in pairs(store.SQL) do nameOf[sql] = name end
    end)

    after_each(function()
        VavaArrival = nil
    end)

    local function arrive(playSeconds)
        return store.load(SOURCE, ACCOUNT, CHARACTER, playSeconds or 0, false)
    end

    describe('nouveau personnage', function()
        it('crée la ligne au chargement, donne la dotation une fois et envoie l\'accueil au seul joueur', function()
            local entry = arrive(0)
            assert.is_table(entry)
            assert.same({ 'SELECT_ROW', 'INSERT_ROW' }, queries)
            assert.equal('due', rows[CHARACTER].kit)

            queries = {}
            welcome.onSpawned(SPAWN)
            -- limite comptée, réservation, limite recomptée, échange, dotation écrite, envoi compté
            assert.same({ 'COUNT_KITS', 'TRANSITION', 'COUNT_KITS', 'TRANSITION', 'COUNT_SEND' }, queries)
            assert.equal(1, #exchanges)
            assert.same({ source = SOURCE, removals = {}, additions = cfg.kit.items }, exchanges[1])
            assert.equal('given', rows[CHARACTER].kit)
            assert.equal(now, rows[CHARACTER].kit_at)
            assert.same({ 'kit_given' }, kinds())
            assert.same({ items = cfg.kit.items }, journal[1].entry.details)
            assert.equal(1, #sent)
            assert.equal(SOURCE, sent[1].target)
            assert.equal(EVENTS.WELCOME, sent[1].event)
            assert.same({ n = 1, true }, sent[1].args)
            assert.equal(1, rows[CHARACTER].welcome_sends)
            assert.equal(1, #emitted)
            assert.equal(HOOKS.ARRIVED, emitted[1].name)
            assert.same({ source = SOURCE, characterId = CHARACTER, accountId = ACCOUNT, kit = 'given' }, emitted[1].payload)
            assert.is_false(entry.busy)
            assert.is_false(VavaArrival.kit.isClaiming(CHARACTER))
        end)

        it('ne fait rien à une seconde apparition (réanimation), accusée ou non', function()
            arrive(0)
            welcome.onSpawned(SPAWN)
            queries = {}
            welcome.onSpawned(SPAWN)
            assert.same({}, queries)
            assert.equal(1, #exchanges)
            assert.equal(1, #sent)
            assert.is_true(welcome.ack(SOURCE))
            queries = {}
            welcome.onSpawned(SPAWN)
            assert.same({}, queries)
            assert.equal(1, #exchanges)
            assert.equal(1, #sent)
            assert.equal(1, #emitted)
        end)

        it('ignore l\'apparition d\'un autre joueur pour ce personnage', function()
            arrive(0)
            welcome.onSpawned({ source = 9, characterId = CHARACTER })
            assert.equal(0, #exchanges)
            assert.equal(0, #sent)
        end)
    end)

    it('laisse un personnage ancien sans ligne et sans rien', function()
        assert.is_nil(arrive(120))
        assert.same({ 'SELECT_ROW' }, queries)
        assert.is_nil(rows[CHARACTER])
        welcome.onSpawned(SPAWN)
        assert.same({ 'SELECT_ROW' }, queries)
        assert.equal(0, #exchanges)
        assert.equal(0, #sent)
    end)

    it('passe une dotation réservée au chargement à « incertaine », sans jamais la redonner', function()
        rows[CHARACTER] = { account_id = ACCOUNT, kit = 'claimed', kit_at = now - 50, welcome_sends = 0 }
        local entry = arrive(30)
        assert.equal('uncertain', entry.kit)
        assert.equal('uncertain', rows[CHARACTER].kit)
        assert.equal(now - 50, rows[CHARACTER].kit_at)
        assert.same({ 'kit_uncertain' }, kinds())
        assert.same({ since = now - 50 }, journal[1].entry.details)
        assert.equal(1, #logs.error)
        for _ = 1, 10 do welcome.onSpawned(SPAWN) end
        assert.equal(0, #exchanges)
        assert.equal(1, #sent)
        assert.same({ n = 1, false }, sent[1].args)
    end)

    it('rend la dotation refusée (besace pleine) à « à donner », puis la donne à l\'apparition suivante sans second accueil', function()
        exchangeAnswers = { { false, 'no_space' } }
        arrive(0)
        welcome.onSpawned(SPAWN)
        assert.equal('due', rows[CHARACTER].kit)
        assert.is_nil(rows[CHARACTER].kit_at)
        assert.equal(1, #sent)
        assert.same({ n = 1, false }, sent[1].args)
        assert.equal('due', emitted[1].payload.kit)
        assert.same({}, kinds())
        assert.is_true(welcome.ack(SOURCE))

        welcome.onSpawned(SPAWN)
        assert.equal(2, #exchanges)
        assert.equal('given', rows[CHARACTER].kit)
        assert.equal(1, #sent)
        assert.same({ 'kit_given' }, kinds())
    end)

    it('reprend la dotation au retour de l\'inventaire, sans second accueil, pour les seuls personnages apparus', function()
        exchangeAnswers = { { false, 'inventory_unavailable' } }
        arrive(0)
        welcome.onSpawned(SPAWN)
        assert.equal('due', rows[CHARACTER].kit)
        assert.equal(1, #sent)
        -- un second joueur chargé, pas encore apparu
        active[6], accounts[6] = 101, 60
        store.load(6, 60, 101, 0, false)

        welcome.onInventoryReady()
        assert.equal(2, #exchanges)
        assert.equal(SOURCE, exchanges[2].source)
        assert.equal('given', rows[CHARACTER].kit)
        assert.equal('due', rows[101].kit)
        assert.equal(1, #sent)
    end)

    it('ne donne rien si le joueur a changé de personnage entre la réservation et l\'échange', function()
        arrive(0)
        after.TRANSITION = function() active[SOURCE] = 999 end
        welcome.onSpawned(SPAWN)
        assert.equal(0, #exchanges)
        assert.equal('due', rows[CHARACTER].kit)
        assert.equal(0, #sent)
        assert.same({}, kinds())
    end)

    describe('limite du compte', function()
        it('retient la dotation quand le compte en a eu trois en 30 jours', function()
            rows[1] = { account_id = ACCOUNT, kit = 'given', kit_at = now - 86400, welcome_sends = 1 }
            rows[2] = { account_id = ACCOUNT, kit = 'uncertain', kit_at = now - 10 * 86400, welcome_sends = 1 }
            rows[3] = { account_id = ACCOUNT, kit = 'claimed', kit_at = now - 29 * 86400, welcome_sends = 0 }
            rows[4] = { account_id = ACCOUNT, kit = 'given', kit_at = now - 31 * 86400, welcome_sends = 1 }
            rows[5] = { account_id = ACCOUNT, kit = 'withheld', kit_at = now - 86400, welcome_sends = 1 }
            arrive(0)
            welcome.onSpawned(SPAWN)
            assert.equal(0, #exchanges)
            assert.equal('withheld', rows[CHARACTER].kit)
            assert.same({ 'kit_withheld' }, kinds())
            assert.same({ count = 3, max = 3, days = 30 }, journal[1].entry.details)
            assert.equal(1, #sent)
            assert.same({ n = 1, false }, sent[1].args)
        end)

        it('donne la dotation sous la limite', function()
            rows[1] = { account_id = ACCOUNT, kit = 'given', kit_at = now - 86400, welcome_sends = 1 }
            rows[2] = { account_id = 999, kit = 'given', kit_at = now, welcome_sends = 1 }
            rows[3] = { account_id = 999, kit = 'given', kit_at = now, welcome_sends = 1 }
            arrive(0)
            welcome.onSpawned(SPAWN)
            assert.equal(1, #exchanges)
            assert.equal('given', rows[CHARACTER].kit)
        end)

        it('ne compte rien sans limite (max = 0)', function()
            cfg.kit.perAccount.max = 0
            arrive(0)
            welcome.onSpawned(SPAWN)
            assert.equal(0, count(queries, 'COUNT_KITS'))
            assert.equal(1, #exchanges)
        end)
    end)

    describe('personnage rechargé pendant la remise', function()
        it('ne lit pas « incertaine » une dotation dont la remise est en cours, et pose son issue sur la nouvelle entrée', function()
            local entry = arrive(0)
            local reloaded
            -- rechargé pendant l'écriture de la dotation donnée (après l'échange)
            after.TRANSITION = function()
                before.TRANSITION = function()
                    store.forget(SOURCE)
                    reloaded = arrive(30)
                end
            end
            welcome.onSpawned(SPAWN)
            assert.is_table(reloaded)
            assert.are_not.equal(entry, reloaded)
            assert.equal(1, #exchanges)
            assert.equal('given', rows[CHARACTER].kit)
            assert.equal('given', reloaded.kit)
            assert.equal(now, reloaded.kitAt)
            assert.same({ 'kit_given' }, kinds())
            assert.same({}, logs.error)
            assert.is_false(VavaArrival.kit.isClaiming(CHARACTER))
            -- la nouvelle entrée ne redonne rien
            welcome.onSpawned(SPAWN)
            assert.equal(1, #exchanges)
        end)

        it('refuse de redoter pendant une remise en cours d\'une entrée remplacée', function()
            arrive(0)
            after.TRANSITION = function()
                before.TRANSITION = function()
                    store.forget(SOURCE)
                    arrive(30)
                    admin.command(8, { 'redoter', tostring(SOURCE) })
                end
            end
            welcome.onSpawned(SPAWN)
            assert.equal(1, #exchanges)
            assert.equal(cfg.messages.admin.busy, chats[1].text)
            assert.same({}, adminLogs)
        end)

        it('abandonne la remise d\'une entrée remplacée pendant les attentes de la base, sans rien donner', function()
            local entry = arrive(0)
            local reloaded
            -- rechargé juste après la réservation, avant l'échange
            after.TRANSITION = function()
                store.forget(SOURCE)
                reloaded = arrive(30)
            end
            welcome.onSpawned(SPAWN)
            assert.is_table(reloaded)
            assert.are_not.equal(entry, reloaded)
            assert.equal(0, #exchanges)
            assert.equal('due', rows[CHARACTER].kit)
            assert.is_nil(rows[CHARACTER].kit_at)
            assert.equal('due', reloaded.kit)
            assert.same({}, kinds())
            assert.same({}, logs.error)
            assert.is_false(VavaArrival.kit.isClaiming(CHARACTER))
            -- la nouvelle entrée donne la dotation, une fois
            welcome.onSpawned(SPAWN)
            assert.equal(1, #exchanges)
            assert.equal('given', rows[CHARACTER].kit)
            assert.equal('given', reloaded.kit)
        end)

        it('abandonne la remise d\'un personnage déchargé pendant les attentes de la base', function()
            arrive(0)
            after.TRANSITION = function() store.forget(SOURCE) end
            welcome.onSpawned(SPAWN)
            assert.equal(0, #exchanges)
            assert.equal('due', rows[CHARACTER].kit)
            assert.is_false(VavaArrival.kit.isClaiming(CHARACTER))
        end)

        it('nettoie la remise en cours sur une erreur : la ligne restée réservée est relue « incertaine »', function()
            arrive(0)
            VavaArrival.bridge.Exchange = function() error('inventaire en panne') end
            welcome.onSpawned(SPAWN)
            assert.is_false(VavaArrival.kit.isClaiming(CHARACTER))
            assert.equal('claimed', rows[CHARACTER].kit)
            assert.equal(1, #logs.error)
            assert.matches('inventaire en panne', logs.error[1])
            store.forget(SOURCE)
            local entry = arrive(30)
            assert.equal('uncertain', entry.kit)
            assert.equal('uncertain', rows[CHARACTER].kit)
            assert.same({ 'kit_uncertain' }, kinds())
        end)
    end)

    describe('limite recomptée après la réservation', function()
        it('retient la dotation si le compte a atteint sa limite pendant les attentes de la base', function()
            rows[1] = { account_id = ACCOUNT, kit = 'given', kit_at = now - 86400, welcome_sends = 1 }
            rows[2] = { account_id = ACCOUNT, kit = 'given', kit_at = now - 2 * 86400, welcome_sends = 1 }
            local entry = arrive(0)
            -- une troisième dotation du compte écrite entre le premier compte et la réservation
            after.COUNT_KITS = function()
                rows[3] = { account_id = ACCOUNT, kit = 'claimed', kit_at = now, welcome_sends = 0 }
            end
            welcome.onSpawned(SPAWN)
            assert.equal(2, count(queries, 'COUNT_KITS'))
            assert.equal(0, #exchanges)
            assert.equal('withheld', rows[CHARACTER].kit)
            assert.equal(now, rows[CHARACTER].kit_at)
            assert.equal('withheld', entry.kit)
            assert.same({ 'kit_withheld' }, kinds())
            assert.same({ count = 3, max = 3, days = 30 }, journal[1].entry.details)
            assert.equal(1, #sent)
            assert.same({ n = 1, false }, sent[1].args)
            assert.is_false(VavaArrival.kit.isClaiming(CHARACTER))
        end)

        it('rend la réservation si le recomptage échoue', function()
            local entry = arrive(0)
            after.COUNT_KITS = function() failures.COUNT_KITS = 'boom' end
            welcome.onSpawned(SPAWN)
            assert.equal(0, #exchanges)
            assert.equal('due', rows[CHARACTER].kit)
            assert.equal('due', entry.kit)
            assert.same({}, kinds())
            assert.is_false(VavaArrival.kit.isClaiming(CHARACTER))
        end)
    end)

    it('ne donne rien si la réservation ne touche aucune ligne, et relit l\'entrée', function()
        local entry = arrive(0)
        before.TRANSITION = function() rows[CHARACTER].kit, rows[CHARACTER].kit_at = 'given', now - 5 end
        welcome.onSpawned(SPAWN)
        assert.equal(0, #exchanges)
        assert.equal('given', entry.kit)
        assert.equal(now - 5, entry.kitAt)
        assert.same({}, kinds())
    end)

    it('ne suit pas un personnage dont la ligne est illisible', function()
        failures.SELECT_ROW = 'boom'
        assert.is_nil(arrive(0))
        assert.is_nil(store.entry(CHARACTER))
        assert.is_nil(rows[CHARACTER])
        failures.SELECT_ROW = nil
        welcome.onSpawned(SPAWN)
        assert.equal(0, #exchanges)
        assert.equal(0, #sent)
    end)

    it('ne lance qu\'une arrivée pour deux apparitions coup sur coup', function()
        arrive(0)
        before.COUNT_KITS = function() welcome.onSpawned(SPAWN) end
        welcome.onSpawned(SPAWN)
        assert.equal(1, #exchanges)
        assert.equal(1, #sent)
        -- une arrivée : le compte avant la réservation et le recomptage après
        assert.equal(2, count(queries, 'COUNT_KITS'))
    end)

    it('ne réserve rien si un objet de la dotation est inconnu, et ne le répète qu\'une fois par 10 min', function()
        known.eau = false
        arrive(0)
        welcome.onSpawned(SPAWN)
        assert.equal(0, count(queries, 'TRANSITION'))
        assert.equal(0, count(queries, 'COUNT_KITS'))
        assert.equal('due', rows[CHARACTER].kit)
        assert.equal(1, #logs.error)
        assert.matches("'eau'", logs.error[1])
        assert.equal(1, #sent)

        now = now + 300
        store.forget(SOURCE)
        arrive(30)
        welcome.onSpawned(SPAWN)
        assert.equal(1, #logs.error)
        now = now + 301
        welcome.onSpawned(SPAWN)
        assert.equal(2, #logs.error)
        assert.equal(0, #exchanges)
    end)

    it('passe une dotation vide à « donnée » sans échange', function()
        cfg.kit.items = {}
        arrive(0)
        welcome.onSpawned(SPAWN)
        assert.equal(0, #exchanges)
        assert.equal(0, count(queries, 'COUNT_KITS'))
        assert.equal('given', rows[CHARACTER].kit)
        assert.equal(1, #sent)
        assert.same({ n = 1, false }, sent[1].args)
    end)

    describe('accusé de lecture', function()
        it('écrit l\'accusé une fois, puis refuse le suivant', function()
            arrive(0)
            welcome.onSpawned(SPAWN)
            queries = {}
            assert.same({ true }, { welcome.ack(SOURCE) })
            assert.same({ 'ACK' }, queries)
            assert.equal(now, rows[CHARACTER].welcomed_at)
            assert.same({ false, 'not_expected' }, { welcome.ack(SOURCE) })
            assert.same({ 'ACK' }, queries)
        end)

        it('refuse l\'accusé d\'un personnage qui n\'a pas reçu l\'accueil cette session', function()
            arrive(0)
            welcome.onSpawned(SPAWN)
            store.forget(SOURCE)
            arrive(30)
            assert.same({ false, 'not_expected' }, { welcome.ack(SOURCE) })
            active[6] = 101
            assert.same({ false, 'not_expected' }, { welcome.ack(6) })
            assert.same({ false, 'no_character' }, { welcome.ack(9) })
            assert.equal(0, count(queries, 'ACK'))
        end)

        it('garde l\'accueil attendu si l\'accusé n\'est pas écrit', function()
            local entry = arrive(0)
            welcome.onSpawned(SPAWN)
            failures.ACK = 'boom'
            assert.same({ false, 'db_error' }, { welcome.ack(SOURCE) })
            assert.is_true(entry.awaitingAck)
            assert.is_nil(entry.welcomedAt)
        end)
    end)

    it('envoie l\'accueil trois fois au plus sans accusé (une fois par session)', function()
        arrive(0)
        welcome.onSpawned(SPAWN)
        for _ = 1, 3 do
            store.forget(SOURCE)
            arrive(60)
            welcome.onSpawned(SPAWN)
        end
        assert.equal(3, #sent)
        assert.equal(3, rows[CHARACTER].welcome_sends)
        assert.equal(1, #emitted)
        assert.equal(1, #exchanges)
    end)

    describe('/accueil', function()
        local CONSOLE, STAFF = 0, 8

        it('ne fait rien sans droit, ni réponse ni journal', function()
            arrive(0)
            admin.command(7, { 'redoter', tostring(SOURCE) })
            assert.same({}, chats)
            assert.same({}, adminLogs)
            assert.same({}, journal)
            assert.equal(0, #exchanges)
        end)

        it('répond à la console et ne fait pas attendre la console', function()
            arrive(0)
            welcome.onSpawned(SPAWN)
            admin.command(CONSOLE, { 'etat', tostring(SOURCE) })
            admin.command(CONSOLE, { 'etat', tostring(SOURCE) })
            assert.equal(2, #chats)
            assert.equal(CONSOLE, chats[1].source)
            assert.matches('^Aldric Morn %(joueur 5, personnage n° 100%) : dotation donnée le ', chats[1].text)
            assert.matches('accueil envoyé 1 fois, pas encore vu%.$', chats[1].text)
        end)

        it('fait attendre un membre entre deux commandes', function()
            admin.command(STAFF, { 'etat', tostring(SOURCE) })
            timer = timer + 1000
            admin.command(STAFF, { 'etat', tostring(SOURCE) })
            assert.equal(2, #chats)
            assert.equal(cfg.messages.admin.wait, chats[2].text)
            timer = timer + 1000
            admin.command(STAFF, { 'x' })
            assert.equal(string.format(cfg.messages.admin.usage, 'accueil'), chats[3].text)
        end)

        it('répond qu\'un joueur sans personnage n\'a rien', function()
            admin.command(STAFF, { 'etat', '42' })
            assert.same({ { source = STAFF, text = 'Joueur 42 : aucun personnage en jeu.' } }, chats)
        end)

        it('lit l\'état sans rien écrire, en mémoire ou en base', function()
            rows[CHARACTER] = { account_id = ACCOUNT, kit = 'given', kit_at = now, welcomed_at = now, welcome_sends = 1 }
            admin.command(STAFF, { 'etat', tostring(SOURCE) })
            assert.same({ 'SELECT_ROW' }, queries)
            assert.equal(1, #chats)
            assert.matches('dotation donnée le .* ; accueil vu le ', chats[1].text)
            assert.same({}, journal)
            assert.same({}, adminLogs)
            timer = timer + 5000
            queries = {}
            rows[CHARACTER] = nil
            admin.command(STAFF, { 'etat', tostring(SOURCE) })
            assert.equal(string.format(cfg.messages.admin.unknown, 'Aldric Morn', SOURCE, CHARACTER), chats[2].text)
        end)

        it('redonne la dotation, l\'écrit et la journalise', function()
            arrive(0)
            welcome.onSpawned(SPAWN)
            queries = {}
            admin.command(STAFF, { 'redoter', tostring(SOURCE) })
            assert.equal(2, #exchanges)
            assert.same({ 'REGIVE' }, queries)
            assert.equal('given', rows[CHARACTER].kit)
            assert.same({ { source = STAFF, label = 'Dotation redonnée', details = { joueur = SOURCE, personnage = CHARACTER } } }, adminLogs)
            assert.equal('admin_regive', journal[#journal].kind)
            assert.equal(80, journal[#journal].entry.actorAccountId)
            assert.equal('Dotation redonnée à Aldric Morn.', chats[1].text)
            assert.equal(1, #sent)
        end)

        it('redonne à un personnage ancien sans lui préparer d\'accueil', function()
            arrive(120)
            admin.command(STAFF, { 'redoter', tostring(SOURCE) })
            assert.equal(1, #exchanges)
            assert.equal('given', rows[CHARACTER].kit)
            assert.equal(now, rows[CHARACTER].welcomed_at)
            store.forget(SOURCE)
            arrive(200)
            welcome.onSpawned(SPAWN)
            assert.equal(0, #sent)
        end)

        it('dit pourquoi la dotation n\'est pas redonnée', function()
            arrive(0)
            exchangeAnswers = { { false, 'no_space' } }
            admin.command(STAFF, { 'redoter', tostring(SOURCE) })
            assert.equal('Dotation non donnée à Aldric Morn : besace pleine.', chats[1].text)
            assert.same({}, adminLogs)
            assert.equal('due', rows[CHARACTER].kit)
        end)

        it('refuse de redoter pendant une dotation en cours', function()
            local entry = arrive(0)
            entry.busy = true
            admin.command(STAFF, { 'redoter', tostring(SOURCE) })
            assert.equal(cfg.messages.admin.busy, chats[1].text)
            assert.equal(0, #exchanges)
        end)

        it('rejoue l\'accueil d\'un personnage ancien : ligne « aucune », un envoi sans la dotation', function()
            arrive(120)
            admin.command(STAFF, { 'rejouer', tostring(SOURCE) })
            assert.equal('none', rows[CHARACTER].kit)
            assert.equal(1, rows[CHARACTER].welcome_sends)
            assert.equal(1, #sent)
            assert.same({ n = 1, false }, sent[1].args)
            assert.equal(0, #emitted)
            assert.equal('admin_replay', journal[1].kind)
            assert.same({ { source = STAFF, label = 'Accueil rejoué', details = { joueur = SOURCE, personnage = CHARACTER } } }, adminLogs)
            assert.equal('Accueil rejoué pour Aldric Morn.', chats[1].text)
            -- l'accusé de cet accueil est attendu
            assert.is_true(welcome.ack(SOURCE))
        end)

        it('rejoue l\'accueil d\'un personnage déjà accueilli', function()
            arrive(0)
            welcome.onSpawned(SPAWN)
            assert.is_true(welcome.ack(SOURCE))
            admin.command(STAFF, { 'rejouer', tostring(SOURCE) })
            assert.equal(2, #sent)
            assert.is_nil(rows[CHARACTER].welcomed_at)
            assert.equal(1, rows[CHARACTER].welcome_sends)
            assert.equal('given', rows[CHARACTER].kit)
        end)
    end)
end)
