local helper = require('tests.helper')

-- Taille d'une valeur une fois sérialisée en msgpack (règles du format) : ce que pèse une réponse RPC sur le réseau,
-- hors enveloppe du core.
local function msgpackSize(value)
    local kind = type(value)
    if kind == 'nil' or kind == 'boolean' then return 1 end
    if kind == 'number' then
        if math.type(value) == 'float' then return 9 end
        if value >= -32 and value <= 127 then return 1 end
        if value >= -32768 and value <= 65535 then return 3 end
        return 9
    end
    if kind == 'string' then
        local n = #value
        return n + (n < 32 and 1 or n < 256 and 2 or n < 65536 and 3 or 5)
    end
    local count, size = 0, 0
    for _ in pairs(value) do count = count + 1 end
    local isList = count == #value
    size = count < 16 and 1 or 3
    for key, item in pairs(value) do size = size + msgpackSize(item) + (isList and 0 or msgpackSize(key)) end
    return size
end

describe('vava_codex empreinte du contenu', function()
    local fingerprint, answerOpen

    before_each(function()
        helper.reset()
        VavaCodex = nil
        helper.loadAll({
            'modules/vava_codex/shared/constants.lua',
            'modules/vava_codex/config.lua',
            'modules/vava_codex/shared/fingerprint.lua',
        })
        fingerprint, answerOpen = VavaCodex.fingerprint, VavaCodex.answerOpen
    end)

    it('rend 16 chiffres hexadécimaux, au motif accepté par le RPC', function()
        for _, value in ipairs({ '', 'Codex', 0, -1, 1.5, true, false, {}, { a = { 1, 2, { b = 'c' } } } }) do
            local version = fingerprint(value)
            assert.equal(VavaCodex.VERSION_LENGTH, #version)
            assert.truthy(version:find(VavaCodex.VERSION_PATTERN))
        end
    end)

    it('suit FNV-1a 64 bits sur le codage canonique (valeurs de référence)', function()
        assert.equal('818753195c48e144', fingerprint(''))          -- FNV-1a de « s0: »
        assert.equal('37e0166994ef71cc', fingerprint('Codex'))     -- « s5:Codex »
        assert.equal('3ec51810f8a1ab41', fingerprint({ 'a', 'b' })) -- « T2{i1;s1:ai2;s1:b} »
    end)

    it('lit les longues chaînes par blocs sans changer le résultat (blocs de 8 octets, puis le reste)', function()
        -- références calculées hors Lua (BigInt) : 1 006 octets codés (125 blocs + 6), puis 365 en UTF-8 (45 + 5)
        assert.equal('46330131d62edf53', fingerprint(string.rep('abcdefghij', 100)))
        assert.equal('b5225d328897b74d', fingerprint(string.rep('Récolte · nœud ', 20)))
    end)

    it('ne dépend pas de l\'ordre dans lequel une table a été remplie', function()
        local first = { name = 'recolte', label = 'Récolte', scope = 'admin', runnable = true, args = { 'a', 'b' } }
        local second = {}
        for _, key in ipairs({ 'args', 'runnable', 'scope', 'label', 'name' }) do second[key] = first[key] end
        second.args = {}
        second.args[2], second.args[1] = 'b', 'a'
        assert.equal(fingerprint(first), fingerprint(second))
        -- clés de types mêlés : ordre total (booléens, nombres, chaînes)
        local mixed1, mixed2 = { [true] = 1, [false] = 2, [3] = 'x', [0.5] = 'y', z = 4 }, {}
        for _, key in ipairs({ 'z', 0.5, 3, false, true }) do mixed2[key] = mixed1[key] end
        assert.equal(fingerprint(mixed1), fingerprint(mixed2))
    end)

    it('distingue les types et les découpages', function()
        local pairsToCompare = {
            { '1', 1 }, { 1, 1.5 }, { true, 'true' }, { false, 0 },
            { { 'ab', 'c' }, { 'a', 'bc' } },
            { {}, { {} } },
            { { a = 1 }, { a = 1, b = false } },
            { { 1, 2 }, { 2, 1 } },
            { { [1] = 'a', [3] = 'c' }, { 'a', 'c' } },
            { { name = 'me' }, { name = 'mp' } },
        }
        for i, pair in ipairs(pairsToCompare) do
            assert.are_not.equal(fingerprint(pair[1]), fingerprint(pair[2]), 'paire ' .. i)
        end
    end)

    it('refuse sans lever d\'erreur ce qu\'il ne sait pas coder', function()
        local version, err = fingerprint(function() end)
        assert.is_nil(version)
        assert.equal('unsupported', err)
        assert.equal('unsupported', select(2, fingerprint({ [{}] = 1 })))
        local loop = {}
        loop.self = loop
        assert.equal('cycle', select(2, fingerprint(loop)))
        local deep = {}
        local cursor = deep
        for _ = 1, 20 do
            cursor.next = {}
            cursor = cursor.next
        end
        assert.equal('too_deep', select(2, fingerprint(deep)))
        -- une même table rangée à deux endroits n'est pas un cycle
        local shared = { 'x' }
        assert.truthy(fingerprint({ shared, shared }))
    end)

    describe('réponse à l\'ouverture', function()
        local content, prefs

        before_each(function()
            content = {
                entries = { { name = 'me', kind = 'command', label = 'Action', scope = 'player', runnable = true } },
                chapters = { { id = 'vava_chat', label = 'Chat' } },
                staff = false, undeclared = {},
            }
            prefs = { favorites = { 'me' }, recent = { { name = 'me', at = 1761800000 } }, keepOpen = true }
        end)

        it('envoie tout à une page qui n\'a rien', function()
            local answer = answerOpen(content, prefs, '', '')
            assert.equal(content, answer.content)
            assert.equal(prefs, answer.prefs)
            assert.equal(fingerprint(content), answer.version)
            assert.equal(fingerprint(prefs), answer.prefsVersion)
        end)

        it('n\'envoie que les deux versions quand rien n\'a changé (moins de 2 Ko)', function()
            local first = answerOpen(content, prefs, '', '')
            local again = answerOpen(content, prefs, first.version, first.prefsVersion)
            assert.is_nil(again.content)
            assert.is_nil(again.prefs)
            assert.same({ version = first.version, prefsVersion = first.prefsVersion }, again)
            assert.is_true(msgpackSize(again) < 2048)
            assert.is_true(msgpackSize(again) < 64)
        end)

        it('renvoie les seules préférences quand elles seules ont changé', function()
            local first = answerOpen(content, prefs, '', '')
            prefs.favorites[2] = 'mp'
            local again = answerOpen(content, prefs, first.version, first.prefsVersion)
            assert.is_nil(again.content)
            assert.equal(prefs, again.prefs)
            assert.are_not.equal(first.prefsVersion, again.prefsVersion)
        end)

        it('renvoie le contenu à une version ancienne ou inventée', function()
            local first = answerOpen(content, prefs, '', '')
            for _, known in ipairs({ '0000000000000000', 'ffffffffffffffff', '' }) do
                local answer = answerOpen(content, prefs, known, first.prefsVersion)
                assert.equal(content, answer.content)
                assert.is_nil(answer.prefs)
            end
        end)

        it('envoie tout, versions comprises, à un client qui n\'a que l\'une des deux', function()
            local first = answerOpen(content, prefs, '', '')
            local noContent = answerOpen(content, prefs, '', first.prefsVersion)
            assert.equal(content, noContent.content)
            assert.equal(first.version, noContent.version)
            assert.is_nil(noContent.prefs)
            local noPrefs = answerOpen(content, prefs, first.version, '')
            assert.is_nil(noPrefs.content)
            assert.equal(prefs, noPrefs.prefs)
            assert.equal(first.prefsVersion, noPrefs.prefsVersion)
        end)

        it('envoie toujours un contenu dont l\'empreinte n\'a pu être calculée', function()
            content.entries[1].odd = function() end
            local answer = answerOpen(content, prefs, '', '')
            assert.equal('', answer.version)
            assert.equal(content, answer.content)
        end)
    end)
end)

describe('vava_codex version du contenu d\'un joueur', function()
    local catalog, registry, staff, rights

    --- Copie des entrées dans un ordre de remplissage différent à chaque lecture (comme une copie du registre).
    local function shuffledCopy(source, flip)
        local keys = {}
        for key in pairs(source) do keys[#keys + 1] = key end
        table.sort(keys)
        if flip then
            for i = 1, #keys // 2 do keys[i], keys[#keys + 1 - i] = keys[#keys + 1 - i], keys[i] end
        end
        local out = {}
        for _, key in ipairs(keys) do
            local value = source[key]
            out[key] = type(value) == 'table' and shuffledCopy(value, flip) or value
        end
        return out
    end

    local reads = 0
    local function version(src)
        local entries, chapters, isStaff = catalog.visible(src)
        local content = { entries = entries, chapters = chapters, staff = isStaff, undeclared = isStaff and catalog.undeclared() or {} }
        return VavaCodex.fingerprint(content)
    end

    before_each(function()
        helper.reset()
        VavaCodex = nil
        helper.loadAll({
            'modules/vava_codex/shared/constants.lua',
            'modules/vava_codex/config.lua',
            'modules/vava_codex/shared/fingerprint.lua',
        })
        registry = {
            me = { kind = 'command', scope = 'player', module = 'vava_chat', chapter = 'Chat', label = 'Action',
                args = { { name = 'action', type = 'text', rest = true } } },
            conseil = { kind = 'command', scope = 'admin', module = 'vava_admin', chapter = 'Conseil', label = 'Registre', ui = true, key = 'F10' },
            recolte = { kind = 'command', scope = 'admin', permission = 'metiers', module = 'vava_gathering', chapter = 'Récolte',
                label = 'Récolte', actions = { { id = 'zones', label = 'Zones' }, { id = 'vitalite', label = 'Vitalité', permission = 'staff',
                    args = { { name = 'zone', type = 'list', list = 'zones' }, { name = 'vitalité', type = 'integer', min = 0, max = 100 } } } } },
            signaler = { kind = 'command', scope = 'player', module = 'vava_admin', chapter = 'Conseil', label = 'Signaler' },
            -- même chapitre que vava_admin : l'ordre des chapitres doit rester total
            cameras = { kind = 'command', scope = 'admin', module = 'vava_cameras', chapter = 'Conseil', label = 'Caméras' },
            vava_saveall = { kind = 'command', scope = 'console', module = 'vAvA_core', chapter = 'Core', label = 'Sauvegarder' },
        }
        staff, rights = {}, {}
        VavaCodex.core = { registry = {
            all = function()
                reads = reads + 1
                return shuffledCopy(registry, reads % 2 == 0)
            end,
            get = function(_, key) return registry[key] and shuffledCopy(registry[key], false) end,
        } }
        VavaCodex.bridge = {
            IsStaff = function(src) return staff[src] == true end,
            Can = function(src, permission) return rights[src] ~= nil and rights[src][permission] == true end,
            RegisteredCommands = function() return { { name = 'zonesvoix', resource = 'vava_voice' } } end,
        }
        helper.load('modules/vava_codex/server/catalog.lua')
        catalog = VavaCodex.catalog
    end)

    it('reste la même d\'une ouverture à l\'autre, quel que soit l\'ordre de lecture du registre', function()
        staff[1], rights[1] = true, { metiers = true }
        local first = version(1)
        for _ = 1, 4 do assert.equal(first, version(1)) end
    end)

    it('change quand un rang est donné puis retiré', function()
        local player = version(1)
        staff[1] = true
        local council = version(1)
        assert.are_not.equal(player, council)
        rights[1] = { metiers = true }
        local senechal = version(1)
        assert.are_not.equal(council, senechal)
        rights[1].staff = true   -- droit propre d'une sous-commande
        assert.are_not.equal(senechal, version(1))
        staff[1], rights[1] = nil, nil
        assert.equal(player, version(1))
    end)

    it('change quand un module s\'arrête ou redémarre avec d\'autres déclarations', function()
        staff[1], rights[1] = true, { metiers = true }
        local before = version(1)
        local saved = registry.recolte
        registry.recolte = nil
        local stopped = version(1)
        assert.are_not.equal(before, stopped)
        registry.recolte = saved
        assert.equal(before, version(1))
        registry.recolte.actions[1].label = 'État des zones'
        assert.are_not.equal(before, version(1))
    end)

    it('est la même pour deux joueurs qui voient la même chose', function()
        assert.equal(version(1), version(2))
        staff[2] = true
        assert.are_not.equal(version(1), version(2))
    end)

    it('ne bouge pas pour un joueur quand le droit d\'un autre change', function()
        local before = version(1)
        staff[2], rights[2] = true, { metiers = true, staff = true }
        assert.equal(before, version(1))
    end)
end)
