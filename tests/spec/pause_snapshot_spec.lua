local helper = require('tests.helper')

-- Instantané d'ouverture de la bannière (vava_pause 1.0.0, T-145 § 6.1 et § 10.4) : logique pure de
-- shared/snapshot.lua ; poids de la page livrée (§ 9.12).
describe('vava_pause : instantané d\'ouverture', function()
    local snapshot, cfg

    local function view(id, label, level, rank, rankLabel)
        return { id = id, label = label, level = level, rank = { name = rank or 'novice', label = rankLabel or 'Novice' },
            xp = 0, mentor = nil, apprentices = {} }
    end

    before_each(function()
        helper.reset()
        VavaPause = nil
        helper.loadAll({
            'modules/vava_pause/shared/constants.lua',
            'modules/vava_pause/config.lua',
            'modules/vava_pause/shared/snapshot.lua',
        })
        snapshot, cfg = VavaPause.snapshot, VavaPause.config
    end)

    describe('savoir-faire', function()
        it('compactés et triés : niveau décroissant, puis libellé', function()
            local out = snapshot.skills({
                view('peche', 'Pêche', 12), view('forge', 'Forge', 45, 'compagnon', 'Compagnon'),
                view('alchimie', 'Alchimie', 12), view('cuisine', 'Cuisine', 80.0, 'maitre', 'Maître'),
            }, 32)
            assert.same({
                { id = 'cuisine', label = 'Cuisine', level = 80, rank = 'maitre', rankLabel = 'Maître' },
                { id = 'forge', label = 'Forge', level = 45, rank = 'compagnon', rankLabel = 'Compagnon' },
                { id = 'alchimie', label = 'Alchimie', level = 12, rank = 'novice', rankLabel = 'Novice' },
                { id = 'peche', label = 'Pêche', level = 12, rank = 'novice', rankLabel = 'Novice' },
            }, out)
            assert.equal('integer', math.type(out[1].level))
        end)

        it('plafond', function()
            local views = {}
            for i = 1, 40 do views[i] = view('s' .. i, 'Art ' .. i, i) end
            local out = snapshot.skills(views, cfg.snapshot.maxSkills)
            assert.equal(32, #out)
            assert.equal(40, out[1].level)
        end)

        it('vue malformée écartée', function()
            local out = snapshot.skills({
                view('ok', 'Bon', 10), 'texte', { id = 'sans_rang', label = 'X', level = 3 },
                view('a b', 'Espace', 1), view('nan', 'NaN', 0 / 0), view('trop', 'Trop', 101), view('html', '<b>', 5),
            }, 32)
            assert.equal(1, #out)
            assert.equal('ok', out[1].id)
            assert.same({}, snapshot.skills(nil, 32))
        end)
    end)

    describe('confrérie', function()
        local CHARGES = { 'croix', 'lion' }
        local function guild(overrides)
            local g = { label = 'Tisserands de la Rive', short = 'Rive', grade = 'Compagnon', cloth = '#1f4a3a',
                clothDark = '#123026', field = '#b08a3e', charge = 'lion' }
            for key, value in pairs(overrides or {}) do g[key] = value end
            return g
        end

        it('valide : copie', function()
            assert.same(guild(), snapshot.guild(guild(), CHARGES, 'croix'))
        end)

        it('aucune : nil sans raison', function()
            assert.same({}, { snapshot.guild(nil, CHARGES, 'croix') })
        end)

        it('champ inconnu, couleur courte, chevrons, contrôle, trop long : nil', function()
            assert.is_nil(snapshot.guild(guild({ couleur = 'x' }), CHARGES, 'croix'))
            assert.is_nil(snapshot.guild(guild({ field = '#fff' }), CHARGES, 'croix'))
            assert.is_nil(snapshot.guild(guild({ cloth = 'red' }), CHARGES, 'croix'))
            assert.is_nil(snapshot.guild(guild({ label = '<b>Rive</b>' }), CHARGES, 'croix'))
            assert.is_nil(snapshot.guild(guild({ short = 'Ri\nve' }), CHARGES, 'croix'))
            assert.is_nil(snapshot.guild(guild({ short = string.rep('a', 17) }), CHARGES, 'croix'))
            assert.is_nil(snapshot.guild(guild({ grade = string.rep('a', 33) }), CHARGES, 'croix'))
            assert.is_nil(snapshot.guild('Rive', CHARGES, 'croix'))
        end)

        it('meuble inconnu : meuble par défaut', function()
            assert.equal('croix', snapshot.guild(guild({ charge = 'dragon' }), CHARGES, 'croix').charge)
            assert.equal('croix', snapshot.guild(guild({ charge = 'a b' }), CHARGES, 'croix').charge)
        end)

        it('le meuble par défaut est celui de la bannière royale et il est connu', function()
            assert.equal(cfg.royal.charge, cfg.guild.charges[1])
        end)
    end)

    describe('touches', function()
        local function entry(overrides)
            local e = { kind = 'key', scope = 'player', module = 'vava_codex', chapter = 'Codex', label = 'Ouvrir le Codex',
                key = 'F1' }
            for key, value in pairs(overrides or {}) do e[key] = value end
            return e
        end

        it('sorte, portée, cachées : seules les touches du joueur', function()
            local out = snapshot.keys({
                codex = entry(),
                metiers = entry({ kind = 'command' }),
                vava_admin_noclip = entry({ scope = 'admin', module = 'vava_admin' }),
                cachee = entry({ hidden = true }),
            }, cfg.snapshot.keyScopes, 48)
            assert.same({ { name = 'codex', label = 'Ouvrir le Codex', chapter = 'Codex', module = 'vava_codex', key = 'F1' } }, out)
        end)

        it('hold et keyDisplay gardés', function()
            local out = snapshot.keys({ vava_gathering_interact = entry({ hold = true, keyDisplay = 'E (maintenir)' }) },
                { 'player' }, 48)
            assert.is_true(out[1].hold)
            assert.equal('E (maintenir)', out[1].keyDisplay)
        end)

        it('bornes : libellé trop long ou chevrons écartés', function()
            local out = snapshot.keys({
                a = entry({ label = string.rep('x', 81) }), b = entry({ chapter = '<i>' }), c = entry({ key = '' }),
            }, { 'player' }, 48)
            assert.same({}, out)
        end)

        it('tri par chapitre, puis libellé ; plafond', function()
            local entries = {
                z = entry({ chapter = 'Voix', label = 'Portée' }),
                b = entry({ chapter = 'Codex', label = 'Ouvrir' }),
                a = entry({ chapter = 'Codex', label = 'Fermer' }),
            }
            local out = snapshot.keys(entries, { 'player' }, 48)
            assert.same({ 'a', 'b', 'z' }, { out[1].name, out[2].name, out[3].name })
            for i = 1, 60 do entries['k' .. i] = entry({ label = 'T' .. i }) end
            assert.equal(48, #snapshot.keys(entries, { 'player' }, cfg.snapshot.maxKeys))
        end)
    end)

    describe('demande au Conseil', function()
        it('revalidée', function()
            local raw = { id = 12, kind = 'question', state = 'sent', age = 180 }
            assert.same(raw, snapshot.request(raw, VavaPause.KINDS))
            assert.is_nil(snapshot.request({ id = 12, kind = 'plainte', state = 'sent', age = 0 }, VavaPause.KINDS))
            assert.is_nil(snapshot.request({ id = 12, kind = 'bug', state = 'lost', age = 0 }, VavaPause.KINDS))
            assert.is_nil(snapshot.request({ id = 1.5, kind = 'bug', state = 'sent', age = 0 }, VavaPause.KINDS))
            assert.is_nil(snapshot.request(nil, VavaPause.KINDS))
        end)
    end)
end)

-- Page livrée (fichiers de `files` du manifeste, hors web/dev) : 100 Ko au plus (§ 9.12).
describe('vava_pause : poids de la page', function()
    local LIMIT = 100 * 1024
    local ROOT = (os.getenv('VAVA_ROOT') or '.') .. '/'

    it('web livré ≤ 100 Ko', function()
        local list = io.popen('git ls-files -- "modules/vava_pause/web"')
        if not list then return pending('git indisponible') end
        local total, count = 0, 0
        for path in list:lines() do
            if not path:find('/web/dev/', 1, true) then
                local file = io.open(ROOT .. path, 'rb')
                if file then
                    total = total + file:seek('end')
                    count = count + 1
                    file:close()
                end
            end
        end
        list:close()
        assert.is_true(count > 0, 'page de vava_pause introuvable (git ls-files modules/vava_pause/web)')
        assert.is_true(total <= LIMIT, ('page de vava_pause : %d octets (≤ %d)'):format(total, LIMIT))
    end)
end)
