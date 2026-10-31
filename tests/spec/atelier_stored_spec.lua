local helper = require('tests.helper')

-- Fiche gardée (T-101, shared/stored.lua) : JSON, normalisation par le formulaire en vigueur, montée de format, lieu,
-- poids, empreinte.
describe('vava_atelier stored', function()
    local stored, limits, form

    -- JSON réduit (objets, listes, chaînes simples, nombres, booléens) : le jeu utilise json.encode / json.decode.
    local function encode(value)
        local kind = type(value)
        if kind == 'string' then return '"' .. value:gsub('[%c"\\]', function(c) return ('\\u%04x'):format(c:byte()) end) .. '"' end
        if kind == 'number' then
            if math.type(value) == 'integer' then return tostring(value) end
            return ('%.14g'):format(value)
        end
        if kind == 'boolean' then return tostring(value) end
        local keys = {}
        for k in pairs(value) do keys[#keys + 1] = k end
        if #keys == #value and #keys > 0 then
            local parts = {}
            for i = 1, #value do parts[i] = encode(value[i]) end
            return '[' .. table.concat(parts, ',') .. ']'
        end
        table.sort(keys)
        local parts = {}
        for i, k in ipairs(keys) do parts[i] = encode(tostring(k)) .. ':' .. encode(value[k]) end
        return '{' .. table.concat(parts, ',') .. '}'
    end

    local function decode(text)
        local pos = 1
        local value
        local function ws() pos = text:find('[^ \n\r\t]', pos) or #text + 1 end
        function value()
            ws()
            local c = text:sub(pos, pos)
            if c == '{' then
                local out = {}
                pos = pos + 1
                ws()
                if text:sub(pos, pos) == '}' then pos = pos + 1 return out end
                while true do
                    local key = value()
                    ws(); assert(text:sub(pos, pos) == ':'); pos = pos + 1
                    out[key] = value()
                    ws()
                    local sep = text:sub(pos, pos); pos = pos + 1
                    if sep == '}' then return out end
                end
            elseif c == '[' then
                local out = {}
                pos = pos + 1
                ws()
                if text:sub(pos, pos) == ']' then pos = pos + 1 return out end
                while true do
                    out[#out + 1] = value()
                    ws()
                    local sep = text:sub(pos, pos); pos = pos + 1
                    if sep == ']' then return out end
                end
            elseif c == '"' then
                local stop = text:find('"', pos + 1, true)
                local raw = text:sub(pos + 1, stop - 1)
                pos = stop + 1
                return (raw:gsub('\\u(%x%x%x%x)', function(h) return string.char(tonumber(h, 16)) end))
            elseif text:sub(pos, pos + 3) == 'true' then pos = pos + 4 return true
            elseif text:sub(pos, pos + 4) == 'false' then pos = pos + 5 return false
            end
            local num = text:match('^-?[%d%.eE+-]+', pos)
            pos = pos + #num
            return tonumber(num)
        end
        local ok, result = pcall(value)
        if not ok then return nil end
        return result
    end

    local function board(over)
        local data = {
            titre = 'Panneau de la place', texte = 'Foire.', langue = 'commun', matiere = 'bois', quartier = 'marche',
            taille = 1.5, portee = 3, eclaire = false, duree = 604800, offrande = '', modele = 'prop_sign_road_01a',
        }
        for k, v in pairs(over or {}) do data[k] = v end
        return data
    end

    local function ctx(over)
        local out = { decode = decode, form = form, placement = 'oriented', limits = limits, format = 1 }
        for k, v in pairs(over or {}) do out[k] = v end
        return out
    end

    before_each(function()
        helper.reset()
        VavaAtelier, VavaExampleAtelier = nil, nil
        helper.loadAll({
            'modules/vava_atelier/shared/constants.lua',
            'modules/vava_atelier/config.lua',
            'modules/vava_atelier/shared/text.lua',
            'modules/vava_atelier/shared/formvalues.lua',
            'modules/vava_atelier/shared/fingerprint.lua',
            'modules/vava_atelier/shared/place.lua',
            'modules/vava_atelier/shared/stored.lua',
            'examples/vava_example_atelier/config.lua',
            'examples/vava_example_atelier/shared/forms.lua',
        })
        stored = VavaAtelier.stored
        limits = VavaAtelier.config.place
        form = VavaExampleAtelier.forms.panneau
    end)

    after_each(function()
        VavaExampleAtelier = nil
    end)

    it('data → JSON → data identique', function()
        local where = { x = -250.0, y = -930.0, z = 31.2, h = 90.0 }
        local dataJson, placeJson = stored.encode(encode, board(), where, 16384)
        local entry = stored.read({ data = dataJson, place = placeJson, format = 1, parent = nil }, ctx())
        assert.same(board(), entry.data)
        assert.same(where, entry.place)
        assert.same({}, entry.reset)
        assert.equal(stored.fingerprint(board(), where, nil), entry.fingerprint)
        -- un réel entier relu comme entier (« -250 ») reste un réel après l'arrondi : même empreinte
        local relu = stored.read({ data = dataJson, place = '{"h":90,"x":-250,"y":-930,"z":31.2}', format = 1 }, ctx())
        assert.equal(entry.fingerprint, relu.fingerprint)
    end)

    it('champ manquant → valeur de départ, signalé ; clé inconnue retirée', function()
        local raw = board({ intrus = 'x' })
        raw.taille = nil
        local data, reset = stored.normalize(form, raw)
        assert.equal(1.5, data.taille)
        assert.is_nil(data.intrus)
        assert.same({ 'taille' }, reset)
    end)

    it('3.0 → 3 pour un entier ; hors bornes → départ', function()
        local data, reset = stored.normalize(form, board({ portee = 3.0, taille = 99 }))
        assert.equal(3, data.portee)
        assert.equal('integer', math.type(data.portee))
        assert.equal(1.5, data.taille)
        assert.same({ 'taille' }, reset)
    end)

    it('format plus ancien : monté par upgrade, sinon normalisé', function()
        local old = encode({ titre = 'Vieux panneau', hauteur = 2 })
        local upgraded = stored.read({ data = old, format = 1 }, ctx({ format = 2, upgrade = function(data, from)
            assert.equal(1, from)
            return { titre = data.titre, taille = data.hauteur }
        end }))
        assert.equal(2, upgraded.data.taille)
        assert.equal('Vieux panneau', upgraded.data.titre)
        local plain = stored.read({ data = old, format = 1 }, ctx({ format = 2 }))
        assert.equal(1.5, plain.data.taille)
        assert.is_nil(plain.data.hauteur)
    end)

    it('format plus récent, ou upgrade qui échoue → illisible', function()
        local json = encode(board())
        local entry, err = stored.read({ data = json, format = 3 }, ctx({ format = 2 }))
        assert.is_nil(entry)
        assert.truthy(err:find('plus récent', 1, true))
        entry, err = stored.read({ data = json, format = 1 }, ctx({ format = 2, upgrade = function() return nil, 'non' end }))
        assert.is_nil(entry)
        assert.truthy(err:find('non', 1, true))
        assert.is_nil((stored.read({ data = '{pas du json', format = 1 }, ctx())))
        assert.is_nil((stored.read({ data = encode(board()), place = '{"x":1e9,"y":0,"z":0,"h":0}', format = 1 }, ctx())))
    end)

    it('poids : 16 384 octets acceptés, 16 385 refusés', function()
        assert.is_true(stored.fits(string.rep('a', 16000), string.rep('b', 384), 16384))
        assert.is_false(stored.fits(string.rep('a', 16000), string.rep('b', 385), 16384))
        local big = { titre = string.rep('x', 16373) }
        local json = encode(big)
        assert.equal(16385, #json)
        local ok, err = stored.encode(encode, big, nil, 16384)
        assert.is_nil(ok)
        assert.equal('too_large', err)
        local _, placeJson, bytes = stored.encode(encode, { titre = string.rep('x', 16372) }, nil, 16384)
        assert.equal('', placeJson)
        assert.equal(16384, bytes)
    end)

    it('empreinte stable quel que soit l\'ordre des clés, différente si le lieu ou le parent change', function()
        local a = { titre = 'A', taille = 1.5, portee = 3 }
        local b = {}
        for _, k in ipairs({ 'portee', 'taille', 'titre' }) do b[k] = a[k] end
        local where = { x = 1.0, y = 2.0, z = 3.0, h = 0.0 }
        assert.equal(stored.fingerprint(a, where, 'p'), stored.fingerprint(b, where, 'p'))
        assert.not_equal(stored.fingerprint(a, where, 'p'), stored.fingerprint(a, { x = 1.0, y = 2.0, z = 3.0, h = 1.0 }, 'p'))
        assert.not_equal(stored.fingerprint(a, where, 'p'), stored.fingerprint(a, where, 'q'))
        assert.not_equal(stored.fingerprint(a, where, 'p'), stored.fingerprint(a, nil, 'p'))
        assert.not_equal(stored.fingerprint(a, where, 'p'), stored.fingerprint(a, where, nil))
    end)

    it('fiche passée au module : data + id, version, parent, place ; jamais status', function()
        local def = stored.def({ data = { titre = 'A' }, parent = 'p', place = { x = 1 } }, 'a', 3)
        assert.same({ titre = 'A', id = 'a', version = 3, parent = 'p', place = { x = 1 } }, def)
        assert.same({ titre = 'A', id = 'a' }, stored.def({ data = { titre = 'A' } }, 'a', nil))
    end)

    it('lecture d\'un module : clés réservées séparées, lieu contrôlé', function()
        local raw = board({ id = 'x', place = { x = 1, y = 2, z = 3, h = -90 }, parent = 'panneau_a', status = 'live' })
        local entry = stored.fromModule(raw, form, 'oriented', limits)
        assert.same(board(), entry.data)
        assert.equal(270.0, entry.place.h)
        assert.equal('panneau_a', entry.parent)
        local refused = stored.fromModule(board({ place = { x = 1 } }), form, 'oriented', limits)
        assert.is_nil(refused)
        local ignored = stored.fromModule(board({ place = { x = 1 } }), form, nil, limits)
        assert.is_nil(ignored.place)
    end)
end)
