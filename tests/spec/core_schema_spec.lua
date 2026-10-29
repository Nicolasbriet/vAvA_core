local helper = require('tests.helper')

-- Chaque règle du tableau « Schémas » de docs/api.md a ici au moins un test positif (« accepte ») et un test
-- négatif (« refuse »). Les blocs suivent l'ordre du tableau, puis le paragraphe sur les entrées réseau.

local NAN, INF = 0 / 0, math.huge

describe('vAvA.lib.schema', function()
    local schema, net

    before_each(function()
        helper.reset()
        helper.loadAll({ 'shared/init.lua', 'config/shared.lua', 'shared/lib/schema.lua', 'config/server.lua' })
        schema = vAvA.lib.schema
        local bounds = vAvA.config.server.schema
        -- mêmes options que NET_SCHEMA dans server/core/rpc.lua
        net = {
            net = true,
            maxStringLength = bounds.maxStringLength,
            maxArrayLength = bounds.maxArrayLength,
            maxMapEntries = bounds.maxMapEntries,
        }
    end)

    local function contient(err, attendu)
        assert.is_string(err)
        assert.is_truthy(err:find(attendu, 1, true), ("message « %s » sans « %s »"):format(err, attendu))
    end

    local function valider(def, value, options)
        local compiled, err = schema.compile(def, options)
        assert(compiled, err)
        return schema.validate(compiled, value)
    end

    local function accepte(def, value, options)
        local ok, err = valider(def, value, options)
        assert.is_true(ok, err)
    end

    local function refuse(def, value, attendu, options)
        local ok, err = valider(def, value, options)
        assert.is_false(ok, 'valeur acceptée à tort')
        if attendu then contient(err, attendu) end
    end

    local function definitionRefusee(def, attendu, options)
        local compiled, err = schema.compile(def, options)
        assert.is_nil(compiled, 'définition acceptée à tort')
        if attendu then contient(err, attendu) end
    end

    describe('type', function()
        it('string : accepte une chaîne, refuse tout le reste', function()
            accepte({ type = 'string' }, 'abc')
            accepte({ type = 'string' }, '')
            refuse({ type = 'string' }, 12, 'chaîne attendue')
            refuse({ type = 'string' }, true, 'chaîne attendue')
            refuse({ type = 'string' }, {}, 'chaîne attendue')
        end)

        it('number : accepte entiers et flottants, refuse une chaîne numérique', function()
            accepte({ type = 'number' }, 3)
            accepte({ type = 'number' }, -2.75)
            accepte({ type = 'number' }, 1e300)
            refuse({ type = 'number' }, '3', 'nombre attendu')
            refuse({ type = 'number' }, false, 'nombre attendu')
        end)

        it('integer : accepte un entier et un flottant à équivalent entier (3.0)', function()
            accepte({ type = 'integer' }, 3)
            accepte({ type = 'integer' }, 3.0)
            accepte({ type = 'integer' }, -0.0)
            accepte({ type = 'integer' }, math.maxinteger)
            accepte({ type = 'integer' }, math.mininteger)
            -- -2^63 en flottant vaut exactement math.mininteger : il a un équivalent entier Lua
            accepte({ type = 'integer' }, -2.0 ^ 63)
        end)

        it('integer : refuse un flottant sans équivalent entier Lua (3.5, 1e300, 2^63)', function()
            refuse({ type = 'integer' }, 3.5, 'entier attendu')
            refuse({ type = 'integer' }, 1e300, 'entier attendu')
            refuse({ type = 'integer' }, 2.0 ^ 63, 'entier attendu')
            refuse({ type = 'integer' }, '3', 'nombre attendu')
        end)

        it('boolean : accepte true et false, refuse 1, 0 et « true »', function()
            accepte({ type = 'boolean' }, true)
            accepte({ type = 'boolean' }, false)
            refuse({ type = 'boolean' }, 1, 'booléen attendu')
            refuse({ type = 'boolean' }, 0, 'booléen attendu')
            refuse({ type = 'boolean' }, 'true', 'booléen attendu')
        end)

        it('table, array et map : refusent une valeur qui n’est pas une table', function()
            accepte({ type = 'table', fields = {} }, {})
            accepte({ type = 'array', items = { type = 'string' } }, {})
            accepte({ type = 'map', key = { type = 'string' }, value = { type = 'string' } }, {})
            refuse({ type = 'table', fields = {} }, 'x', 'table attendue')
            refuse({ type = 'array', items = { type = 'string' } }, 'x', 'liste attendue')
            refuse({ type = 'map', key = { type = 'string' }, value = { type = 'string' } }, 5, 'table attendue')
        end)

        it('table, array et map : refusent une table dotée d’une métatable (donnée non brute)', function()
            local avecMeta = setmetatable({}, {})
            refuse({ type = 'table', fields = {} }, avecMeta, 'donnée brute attendue')
            refuse({ type = 'array', items = { type = 'string' } }, avecMeta, 'donnée brute attendue')
            refuse({ type = 'map', key = { type = 'string' }, value = { type = 'string' } }, avecMeta,
                'donnée brute attendue')
            refuse({ type = 'string' }, avecMeta, 'donnée brute attendue')
        end)

        it('function : accepte une fonction locale ou une table appelable (fonction d’une autre ressource)', function()
            accepte({ type = 'function' }, function() end)
            accepte({ type = 'function' }, setmetatable({}, { __call = function() end }))
        end)

        it('function : refuse une table ordinaire et un nom de fonction', function()
            refuse({ type = 'function' }, {}, 'fonction attendue')
            refuse({ type = 'function' }, 'print', 'fonction attendue')
            refuse({ type = 'function' }, setmetatable({}, {}), 'fonction attendue')
        end)

        it('any : accepte toute valeur présente, refuse nil', function()
            accepte({ type = 'any' }, false)
            accepte({ type = 'any' }, 'x')
            accepte({ type = 'any' }, setmetatable({}, {}))
            refuse({ type = 'any' }, nil, 'valeur requise')
        end)

        it('refuse à la compilation un type inconnu ou une définition qui n’est pas une table', function()
            definitionRefusee({ type = 'float' }, "type inconnu 'float'")
            definitionRefusee({}, "type inconnu 'nil'")
            definitionRefusee('string', 'définition attendue (table)')
            definitionRefusee(nil, 'définition attendue (table)')
        end)
    end)

    describe('optional', function()
        it('accepte nil quand le champ est optionnel', function()
            accepte({ type = 'string', optional = true }, nil)
            accepte({ type = 'integer', optional = true, min = 1 }, nil)
        end)

        it('refuse nil quand le champ est requis (défaut)', function()
            refuse({ type = 'string' }, nil, 'valeur requise')
            refuse({ type = 'boolean', optional = false }, nil, 'valeur requise')
        end)

        it('n’assouplit ni le type ni les bornes d’une valeur présente', function()
            refuse({ type = 'string', optional = true }, 5, 'chaîne attendue')
            refuse({ type = 'integer', optional = true, min = 1 }, 0, 'valeur < 1')
            -- false n'est pas nil : il est validé comme un booléen
            accepte({ type = 'boolean', optional = true }, false)
            refuse({ type = 'boolean', optional = true }, 'false', 'booléen attendu')
        end)
    end)

    describe('min / max', function()
        it('string : borne la longueur, bornes incluses', function()
            local def = { type = 'string', min = 2, max = 4 }
            accepte(def, 'ab')
            accepte(def, 'abcd')
            refuse(def, 'a', 'longueur < 2')
            refuse(def, 'abcde', 'longueur > 4')
            refuse({ type = 'string', min = 1 }, '', 'longueur < 1')
        end)

        it('string : compte la longueur en octets (un « é » en vaut deux)', function()
            accepte({ type = 'string', max = 2 }, 'é')
            refuse({ type = 'string', max = 2 }, 'éé', 'longueur > 2')
        end)

        it('number : borne la valeur, bornes incluses', function()
            local def = { type = 'number', min = -1.5, max = 2.5 }
            accepte(def, -1.5)
            accepte(def, 2.5)
            accepte(def, 0)
            refuse(def, -1.6, 'valeur < -1.5')
            refuse(def, 2.6, 'valeur > 2.5')
        end)

        it('integer : borne la valeur, bornes incluses (exemple de docs/api.md : slot 1 à 40)', function()
            local def = { type = 'integer', min = 1, max = 40 }
            accepte(def, 1)
            accepte(def, 40)
            accepte(def, 40.0)
            refuse(def, 0, 'valeur < 1')
            refuse(def, 41, 'valeur > 40')
            refuse(def, 40.5, 'entier attendu')
        end)

        it('array : borne le nombre d’éléments, bornes incluses', function()
            local def = { type = 'array', items = { type = 'string' }, min = 1, max = 3 }
            accepte(def, { 'a' })
            accepte(def, { 'a', 'b', 'c' })
            refuse(def, {}, 'moins de 1 éléments')
            refuse(def, { 'a', 'b', 'c', 'd' }, 'plus de 3 éléments')
        end)

        it('map : borne le nombre d’entrées, bornes incluses', function()
            local def = { type = 'map', key = { type = 'string' }, value = { type = 'integer' }, min = 1, max = 2 }
            accepte(def, { a = 1 })
            accepte(def, { a = 1, b = 2 })
            refuse(def, {}, 'moins de 1 entrées')
            refuse(def, { a = 1, b = 2, c = 3 }, 'plus de 2 entrées')
        end)

        it('accepte min égal à max (longueur exacte)', function()
            accepte({ type = 'string', min = 3, max = 3 }, 'abc')
            refuse({ type = 'string', min = 3, max = 3 }, 'ab', 'longueur < 3')
        end)

        it('refuse à la compilation des bornes incohérentes ou non numériques', function()
            definitionRefusee({ type = 'integer', min = 5, max = 4 }, 'min > max')
            definitionRefusee({ type = 'string', min = '1' }, 'min doit être un nombre')
            definitionRefusee({ type = 'string', max = '10' }, 'max doit être un nombre')
        end)

        it('une borne de longueur ou de nombre d’éléments non entière ne fait jamais lever la validation', function()
            -- validate rend (false, err) et ne lève pas. Refuser une telle définition à la compilation serait une
            -- correction tout aussi valable : le test l'admet.
            local cas = {
                { { type = 'string', max = 2.5 }, 'abc' },
                { { type = 'string', min = 2.5 }, 'ab' },
                { { type = 'array', items = { type = 'integer' }, max = 1.5 }, { 1, 2 } },
                { { type = 'map', key = { type = 'string' }, value = { type = 'integer' }, min = 1.5 }, { a = 1 } },
            }
            for _, c in ipairs(cas) do
                local compiled = schema.compile(c[1])
                if compiled then
                    local ok, valid = pcall(schema.validate, compiled, c[2])
                    assert.is_true(ok, 'schema.validate a levé : ' .. tostring(valid))
                    assert.is_false(valid)
                end
            end
        end)
    end)

    describe('NaN et ±inf', function()
        it('number : refuse NaN, +inf et -inf même sans borne', function()
            refuse({ type = 'number' }, NAN, 'nombre non fini')
            refuse({ type = 'number' }, INF, 'nombre non fini')
            refuse({ type = 'number' }, -INF, 'nombre non fini')
        end)

        it('integer : refuse NaN, +inf et -inf', function()
            refuse({ type = 'integer' }, NAN, 'nombre non fini')
            refuse({ type = 'integer' }, INF, 'nombre non fini')
            refuse({ type = 'integer' }, -INF, 'nombre non fini')
        end)

        it('NaN ne passe pas entre des bornes (toute comparaison avec NaN est fausse)', function()
            refuse({ type = 'number', min = 0, max = 10 }, NAN, 'nombre non fini')
            refuse({ type = 'number', enum = { 1, 2 } }, NAN, 'nombre non fini')
        end)

        it('refuse NaN et ±inf en entrée réseau et au fond d’une structure', function()
            refuse({ type = 'number' }, NAN, 'nombre non fini', net)
            refuse({ type = 'table', fields = { x = { type = 'number' } } }, { x = INF }, 'x : nombre non fini')
            refuse({ type = 'array', items = { type = 'number' } }, { 1, -INF }, '[2] : nombre non fini', net)
            refuse({ type = 'map', key = { type = 'string' }, value = { type = 'number' } }, { a = NAN },
                '[a] : nombre non fini', net)
        end)

        it('refuse NaN dans une liste enum sans lever d’erreur (aucune fonction de l’API ne lève)', function()
            local ok, compiled, err = pcall(schema.compile, { type = 'number', enum = { 1, NAN } })
            assert.is_true(ok, 'schema.compile a levé : ' .. tostring(compiled))
            assert.is_nil(compiled)
            assert.is_string(err)
        end)
    end)

    describe('pattern', function()
        it('accepte une valeur conforme à un motif ancré', function()
            accepte({ type = 'string', pattern = '^%d+$' }, '123')
            accepte({ type = 'string', pattern = '^[%l_]+:[%l_]+$' }, 'vava_inventory:move')
        end)

        it('refuse une valeur non conforme à un motif ancré', function()
            local def = { type = 'string', pattern = '^%d+$' }
            refuse(def, '12a', 'format invalide')
            refuse(def, 'a12', 'format invalide')
            refuse(def, '', 'format invalide')
        end)

        it('un motif ancré refuse un saut de ligne final et un octet nul', function()
            local def = { type = 'string', pattern = '^%d+$' }
            refuse(def, '123\n', 'format invalide')
            refuse(def, '12\0' .. '3', 'format invalide')
        end)

        it('un motif non ancré ne demande que de contenir le motif (d’où l’obligation d’ancrer)', function()
            accepte({ type = 'string', pattern = '%d' }, 'abc1def')
            refuse({ type = 'string', pattern = '^%d$' }, 'abc1def', 'format invalide')
        end)

        it('contrôle la longueur en plus du motif', function()
            refuse({ type = 'string', pattern = '^%a+$', max = 3 }, 'abcd', 'longueur > 3')
        end)

        it('refuse à la compilation un motif invalide ou qui n’est pas une chaîne', function()
            definitionRefusee({ type = 'string', pattern = '[a-' }, 'motif invalide')
            definitionRefusee({ type = 'string', pattern = '%' }, 'motif invalide')
            definitionRefusee({ type = 'string', pattern = 123 }, 'motif invalide')
        end)
    end)

    describe('enum', function()
        it('string : accepte une valeur de la liste, refuse les autres (casse comprise)', function()
            local def = { type = 'string', enum = { 'm', 'f' } }
            accepte(def, 'm')
            accepte(def, 'f')
            refuse(def, 'x', 'valeur non autorisée')
            refuse(def, 'M', 'valeur non autorisée')
        end)

        it('integer : accepte 2 et 2.0, refuse une valeur hors liste', function()
            local def = { type = 'integer', enum = { 1, 2, 3 } }
            accepte(def, 2)
            accepte(def, 2.0)
            refuse(def, 4, 'valeur non autorisée')
        end)

        it('number : compare les flottants exactement', function()
            local def = { type = 'number', enum = { 0.5, 1 } }
            accepte(def, 0.5)
            accepte(def, 1.0)
            refuse(def, 0.25, 'valeur non autorisée')
        end)

        it('le type est vérifié avant la liste : « 1 » ne vaut pas 1', function()
            refuse({ type = 'integer', enum = { 1 } }, '1', 'nombre attendu')
            refuse({ type = 'string', enum = { '1' } }, 1, 'chaîne attendue')
        end)

        it('refuse à la compilation une liste vide, absente de forme ou sur un type non prévu', function()
            definitionRefusee({ type = 'string', enum = {} }, 'enum vide')
            definitionRefusee({ type = 'string', enum = 'm' }, 'enum réservé')
            definitionRefusee({ type = 'boolean', enum = { true } }, 'enum réservé')
            definitionRefusee({ type = 'table', fields = {}, enum = { 1 } }, 'enum réservé')
        end)
    end)

    describe('fields / strict', function()
        -- exemple de docs/api.md
        local function exemple()
            return { type = 'table', fields = {
                slot = { type = 'integer', min = 1, max = 40 },
                note = { type = 'string', max = 120, optional = true },
            } }
        end

        it('accepte une table conforme, champ optionnel présent ou absent', function()
            accepte(exemple(), { slot = 3 })
            accepte(exemple(), { slot = 3, note = 'pour Aldric' })
        end)

        it('refuse un champ requis absent ou invalide, en nommant le champ', function()
            refuse(exemple(), {}, 'slot : valeur requise')
            refuse(exemple(), { slot = 0 }, 'slot : valeur < 1')
            refuse(exemple(), { slot = 3, note = ('x'):rep(121) }, 'note : longueur > 120')
        end)

        it('strict (défaut) : refuse une clé inconnue', function()
            refuse(exemple(), { slot = 3, extra = true }, "clé non autorisée 'extra'")
        end)

        it('strict (défaut) : refuse une clé numérique ou une table-liste', function()
            refuse(exemple(), { slot = 3, [1] = 'x' }, "clé non autorisée '1'")
            refuse({ type = 'table', fields = {} }, { 'a' }, "clé non autorisée '1'")
        end)

        it('strict = false (entrée locale) : tolère les clés inconnues mais valide les champs déclarés', function()
            local def = { type = 'table', strict = false, fields = { slot = { type = 'integer' } } }
            accepte(def, { slot = 3, extra = true })
            refuse(def, { extra = true }, 'slot : valeur requise')
        end)

        it('refuse à la compilation une table sans fields ou un nom de champ non textuel', function()
            definitionRefusee({ type = 'table' }, 'fields attendu pour le type table')
            definitionRefusee({ type = 'table', fields = { { type = 'string' } } },
                'les noms de champs doivent être des chaînes')
            definitionRefusee({ type = 'table', fields = { slot = { type = 'entier' } } },
                "schéma.slot : type inconnu 'entier'")
        end)
    end)

    describe('items', function()
        local def = { type = 'array', items = { type = 'integer', min = 1 } }

        it('valide chaque élément', function()
            accepte(def, { 1, 2, 3 })
            refuse(def, { 1, 0, 3 }, '[2] : valeur < 1')
            refuse(def, { 1, 'deux' }, '[2] : nombre attendu')
        end)

        it('refuse une liste à trous', function()
            refuse(def, { [1] = 1, [3] = 3 }, 'liste attendue (trous)')
            refuse(def, { [2] = 2 }, 'liste attendue (trous)')
        end)

        it('refuse des clés qui ne sont pas des indices 1..n', function()
            refuse(def, { 1, 2, x = 3 }, 'clés non séquentielles')
            refuse(def, { [0] = 1 }, 'clés non séquentielles')
            refuse(def, { [-1] = 1 }, 'clés non séquentielles')
            refuse(def, { [1.5] = 1 }, 'clés non séquentielles')
        end)

        it('valide des listes de listes', function()
            local nested = { type = 'array', items = { type = 'array', items = { type = 'string' }, max = 2 } }
            accepte(nested, { { 'a', 'b' }, {} })
            refuse(nested, { { 'a' }, { 'a', 'b', 'c' } }, '[2] : plus de 2 éléments')
        end)

        it('refuse à la compilation une liste sans items', function()
            definitionRefusee({ type = 'array' }, 'schéma[] : définition attendue')
            definitionRefusee({ type = 'array', items = { type = 'nombre' } }, "type inconnu 'nombre'")
        end)
    end)

    describe('key / value', function()
        it('clés string : valide les clés puis les valeurs', function()
            local def = { type = 'map', key = { type = 'string', pattern = '^%l+$', max = 8 },
                value = { type = 'integer', min = 0 } }
            accepte(def, { pomme = 2, ble = 0 })
            refuse(def, { Pomme = 1 }, 'clé : format invalide')
            refuse(def, { pommeraie = 1 }, 'clé : longueur > 8')
            refuse(def, { [1] = 1 }, 'clé : chaîne attendue')
            refuse(def, { pomme = -1 }, '[pomme] : valeur < 0')
        end)

        it('clés integer : accepte des indices épars, refuse une clé hors bornes ou textuelle', function()
            local def = { type = 'map', key = { type = 'integer', min = 1 }, value = { type = 'boolean' } }
            accepte(def, { [1] = true, [42] = false })
            refuse(def, { [0] = true }, 'clé : valeur < 1')
            refuse(def, { [2.5] = true }, 'clé : entier attendu')
            refuse(def, { a = true }, 'clé : nombre attendu')
        end)

        it('refuse à la compilation une clé qui n’est ni string ni integer, ou un schéma manquant', function()
            local valeur = { type = 'string' }
            definitionRefusee({ type = 'map', key = { type = 'boolean' }, value = valeur },
                'les clés de map doivent être de type string ou integer')
            definitionRefusee({ type = 'map', key = { type = 'number' }, value = valeur },
                'les clés de map doivent être de type string ou integer')
            definitionRefusee({ type = 'map', value = valeur }, 'schéma<clé> : définition attendue')
            definitionRefusee({ type = 'map', key = { type = 'string' } }, 'schéma<valeur> : définition attendue')
        end)
    end)

    describe('entrée réseau et entrée locale', function()
        it('réseau : refuse any et function à la compilation, même imbriqués', function()
            definitionRefusee({ type = 'any' }, "le type 'any' est interdit pour une entrée réseau", net)
            definitionRefusee({ type = 'function' }, "le type 'function' est interdit pour une entrée réseau", net)
            definitionRefusee({ type = 'table', fields = { cb = { type = 'function' } } },
                "schéma.cb : le type 'function' est interdit", net)
            definitionRefusee({ type = 'array', items = { type = 'any' } }, "schéma[] : le type 'any' est interdit", net)
            definitionRefusee({ type = 'map', key = { type = 'string' }, value = { type = 'any' } },
                "schéma<valeur> : le type 'any' est interdit", net)
        end)

        it('locale : accepte any et function (callbacks d’entrées de registre)', function()
            accepte({ type = 'any' }, 42)
            accepte({ type = 'table', fields = { cb = { type = 'function' } } }, { cb = function() end })
        end)

        it('réseau : refuse strict = false à la compilation, même imbriqué', function()
            definitionRefusee({ type = 'table', strict = false, fields = {} },
                'strict = false est interdit pour une entrée réseau', net)
            definitionRefusee({ type = 'array', items = { type = 'table', strict = false, fields = {} } },
                'schéma[] : strict = false est interdit', net)
        end)

        it('réseau : une chaîne sans max reçoit la borne de config/server.lua (256)', function()
            assert.equal(256, net.maxStringLength)
            accepte({ type = 'string' }, ('x'):rep(256), net)
            refuse({ type = 'string' }, ('x'):rep(257), 'longueur > 256', net)
        end)

        it('réseau : une liste sans max reçoit la borne de config/server.lua (64)', function()
            assert.equal(64, net.maxArrayLength)
            local liste = {}
            for i = 1, 64 do liste[i] = i end
            accepte({ type = 'array', items = { type = 'integer' } }, liste, net)
            liste[65] = 65
            refuse({ type = 'array', items = { type = 'integer' } }, liste, 'plus de 64 éléments', net)
        end)

        it('réseau : une map sans max reçoit la borne de config/server.lua (64), ses clés aussi', function()
            assert.equal(64, net.maxMapEntries)
            local def = { type = 'map', key = { type = 'string' }, value = { type = 'boolean' } }
            local map = {}
            for i = 1, 64 do map['k' .. i] = true end
            accepte(def, map, net)
            map.k65 = true
            refuse(def, map, 'plus de 64 entrées', net)
            refuse(def, { [('k'):rep(257)] = true }, 'clé : longueur > 256', net)
        end)

        it('réseau : un max explicite est gardé tel quel, plus petit ou plus grand que la borne', function()
            refuse({ type = 'string', max = 8 }, ('x'):rep(9), 'longueur > 8', net)
            accepte({ type = 'string', max = 300 }, ('x'):rep(300), net)
        end)

        it('locale : aucune borne par défaut n’est injectée', function()
            accepte({ type = 'string' }, ('x'):rep(10000))
            local liste = {}
            for i = 1, 1000 do liste[i] = 'x' end
            accepte({ type = 'array', items = { type = 'string' } }, liste)
        end)
    end)

    describe('tables imbriquées et profondeur', function()
        local profond = { type = 'table', fields = {
            a = { type = 'table', fields = {
                b = { type = 'array', items = { type = 'table', fields = { n = { type = 'integer', max = 10 } } } },
            } },
        } }

        it('valide une structure imbriquée et nomme le chemin de l’erreur', function()
            accepte(profond, { a = { b = { { n = 1 }, { n = 10 } } } })
            refuse(profond, { a = { b = { { n = 1 }, { n = 11 } } } }, 'a : b : [2] : n : valeur > 10')
            refuse(profond, { a = { b = { { n = 1, x = 0 } } } }, "a : b : [1] : clé non autorisée 'x'")
        end)

        it('une valeur très profonde est refusée au niveau où le schéma s’arrête, sans débordement de pile', function()
            local valeur = {}
            local courant = valeur
            for _ = 1, 100000 do
                courant.a = {}
                courant = courant.a
            end
            local def = { type = 'table', fields = { a = { type = 'table', fields = { a = { type = 'integer' } } } } }
            refuse(def, valeur, 'a : a : nombre attendu')
        end)

        it('une valeur cyclique ne fait pas boucler la validation', function()
            local cyclique = {}
            cyclique.self = cyclique
            local def = { type = 'table', fields = { self = { type = 'table', fields = {} } } }
            refuse(def, cyclique, "self : clé non autorisée 'self'")
        end)

        it('une liste géante est refusée dès la borne dépassée', function()
            local geante = {}
            for i = 1, 100000 do geante[i] = i end
            refuse({ type = 'array', items = { type = 'integer' } }, geante, 'plus de 64 éléments', net)
        end)
    end)

    describe('compileList et validateList (arguments d’un RPC)', function()
        local function args(definitions)
            local compiled, err = schema.compileList(definitions, net, 'args')
            assert(compiled, err)
            return compiled
        end

        it('compileList : accepte une liste vide et nomme l’argument fautif', function()
            assert.same({}, schema.compileList({}, net, 'args'))
            local compiled, err = schema.compileList({ { type = 'string' }, { type = 'any' } }, net, 'args')
            assert.is_nil(compiled)
            contient(err, "args#2 : le type 'any' est interdit")
            compiled, err = schema.compileList({ { type = 'table', fields = { data = { type = 'any' } } } }, net, 'args')
            assert.is_nil(compiled)
            contient(err, 'args#1.data')
        end)

        it('compileList : refuse ce qui n’est pas une liste séquentielle', function()
            local compiled, err = schema.compileList(nil, net, 'args')
            assert.is_nil(compiled)
            contient(err, 'liste de schémas attendue')
            -- liste à trous : refusée quelle que soit la bordure (#) que Lua choisit
            compiled, err = schema.compileList({ [1] = { type = 'string' }, [3] = { type = 'string' } }, net, 'args')
            assert.is_nil(compiled)
            assert.is_string(err)
            compiled, err = schema.compileList({ slot = { type = 'integer' } }, net, 'args')
            assert.is_nil(compiled)
            contient(err, 'liste séquentielle attendue')
        end)

        it('validateList : accepte des valeurs conformes, arguments optionnels finaux omis', function()
            local list = args({ { type = 'integer', min = 1 }, { type = 'string', optional = true } })
            assert.is_true(schema.validateList(list, { 3, 'x' }, 2))
            assert.is_true(schema.validateList(list, { 3 }, 1))
            assert.is_true(schema.validateList(list, { 3, nil }, 2))
        end)

        it('validateList : refuse un argument requis manquant ou invalide, en donnant son rang', function()
            local list = args({ { type = 'integer' }, { type = 'string' } })
            local ok, err = schema.validateList(list, { 3 }, 1)
            assert.is_false(ok)
            contient(err, '#2 : valeur requise')
            ok, err = schema.validateList(list, { 3, 4 }, 2)
            assert.is_false(ok)
            contient(err, '#2 : chaîne attendue')
        end)

        it('validateList : refuse un nombre de valeurs absent, flottant, négatif ou trop grand', function()
            local list = args({ { type = 'integer', optional = true } })
            for _, count in ipairs({ -1, 2, 1.0, '1', NAN }) do
                local ok, err = schema.validateList(list, {}, count)
                assert.is_false(ok, 'nombre accepté : ' .. tostring(count))
                contient(err, 'nombre de valeurs invalide (0 à 1 attendu)')
            end
            local ok = schema.validateList(list, {}, nil)
            assert.is_false(ok)
        end)

        it('validateList : refuse une liste qui n’est pas une table brute', function()
            local list = args({ { type = 'integer', optional = true } })
            local ok, err = schema.validateList(list, 'x', 0)
            assert.is_false(ok)
            contient(err, 'liste de valeurs attendue')
            ok = schema.validateList(list, setmetatable({}, {}), 0)
            assert.is_false(ok)
        end)

        it('validateList : refuse une valeur au-delà du nombre annoncé', function()
            local list = args({ { type = 'integer', optional = true }, { type = 'integer', optional = true } })
            local ok, err = schema.validateList(list, { 1, 2 }, 1)
            assert.is_false(ok)
            contient(err, '#2 : valeur au-delà du nombre annoncé')
        end)

        it('validateList : refuse une valeur au-delà des schémas déclarés (contrat de schema.lua)', function()
            -- « Toute valeur au-delà de `count` ou des schémas déclarés est refusée. » (shared/lib/schema.lua)
            local list = args({ { type = 'integer' } })
            local ok = schema.validateList(list, { 1, 'en trop' }, 1)
            assert.is_false(ok, 'la 2e valeur, sans schéma, a été acceptée')
        end)
    end)

    describe('isCallable', function()
        it('reconnaît une fonction et une table à __call', function()
            assert.is_true(schema.isCallable(print))
            assert.is_true(schema.isCallable(setmetatable({}, { __call = function() end })))
        end)

        it('refuse une table ordinaire, une table à métatable sans __call et une chaîne', function()
            assert.is_false(schema.isCallable({}))
            assert.is_false(schema.isCallable(setmetatable({}, {})))
            assert.is_false(schema.isCallable('print'))
            assert.is_false(schema.isCallable(nil))
        end)
    end)
end)

-- 0.8.1 : définitions cycliques refusées à la compilation ; entiers arrivés en flottant normalisés à tout niveau.
describe('vAvA.lib.schema (0.8.1)', function()
    local schema

    before_each(function()
        helper.reset()
        helper.loadAll({ 'shared/init.lua', 'config/shared.lua', 'shared/lib/schema.lua', 'config/server.lua' })
        schema = vAvA.lib.schema
    end)

    describe('définitions cycliques', function()
        it('refuse une définition qui se contient elle-même, sans déborder la pile', function()
            local def = { type = 'array' }
            def.items = def
            local compiled, err = schema.compile(def)
            assert.is_nil(compiled)
            assert.matches('cyclique', err)
        end)

        it('refuse un cycle indirect (table → map → la même table)', function()
            local a = { type = 'table', fields = {} }
            local b = { type = 'map', key = { type = 'string' }, value = a }
            a.fields.child = b
            local compiled, err = schema.compile(a)
            assert.is_nil(compiled)
            assert.matches('cyclique', err)
            local list, listErr = schema.compileList({ { type = 'integer' }, b }, nil, 'args')
            assert.is_nil(list)
            assert.matches('cyclique', listErr)
        end)

        it('permet une même définition reprise à plusieurs endroits distincts, et repart d’un état propre', function()
            local id = { type = 'integer', min = 1 }
            assert.is_not_nil(schema.compile({ type = 'table', fields = { from = id, to = id, list = { type = 'array', items = id } } }))
            local def = { type = 'array' }
            def.items = def
            assert.is_nil(schema.compile(def))
            assert.is_not_nil(schema.compile({ type = 'array', items = id }))
            assert.is_not_nil(schema.compile(id))
        end)
    end)

    describe('normalize', function()
        it('convertit les entiers arrivés en flottant à tout niveau, en place, et laisse les nombres', function()
            local compiled = schema.compile({ type = 'table', fields = {
                n = { type = 'integer' },
                x = { type = 'number' },
                list = { type = 'array', items = { type = 'integer' } },
                map = { type = 'map', key = { type = 'string' }, value = { type = 'integer' } },
                deep = { type = 'table', fields = { k = { type = 'integer', optional = true } } },
            } })
            local value = { n = 3.0, x = 2.0, list = { 1.0, 2 }, map = { a = 5.0 }, deep = {} }
            assert.is_true(schema.validate(compiled, value))
            local out = schema.normalize(compiled, value)
            assert.equal(value, out)
            assert.equal('integer', math.type(value.n))
            assert.equal('float', math.type(value.x))
            assert.equal('integer', math.type(value.list[1]))
            assert.equal('integer', math.type(value.list[2]))
            assert.equal('integer', math.type(value.map.a))
            assert.is_nil(value.deep.k)
        end)

        it('normalise un scalaire, une liste d’arguments et une map à clés entières', function()
            assert.equal('integer', math.type(schema.normalize(schema.compile({ type = 'integer' }), 4.0)))
            assert.equal('float', math.type(schema.normalize(schema.compile({ type = 'number' }), 4.0)))
            local list = schema.compileList({ { type = 'integer' }, { type = 'string' }, { type = 'integer', optional = true } }, nil, 'args')
            local values = { 1.0, 'a' }
            schema.normalizeList(list, values, 2)
            assert.equal('integer', math.type(values[1]))
            assert.equal('a', values[2])
            assert.is_nil(values[3])
            local map = schema.compile({ type = 'map', key = { type = 'integer' }, value = { type = 'integer' } })
            local table = { [2] = 8.0 }
            assert.is_true(schema.validate(map, table))
            schema.normalize(map, table)
            assert.equal('integer', math.type(table[2]))
        end)
    end)
end)
