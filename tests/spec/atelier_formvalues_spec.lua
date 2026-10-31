local helper = require('tests.helper')

-- Valeurs d'une fiche de l'Atelier (T-100) : paquet reçu de l'interface → data du module (bornes, pas, choix, jeux de
-- caractères, longueurs), data du module → paquet (valeurs reprises par défaut), défauts d'une entrée nouvelle.
describe('vava_atelier formvalues', function()
    local fv, form

    --- Codes d'erreur rangés « champ:code » pour comparer en une fois.
    local function codes(errors)
        local out = {}
        for i, e in ipairs(errors or {}) do out[i] = (e.field or e.key or '?') .. ':' .. e.code end
        return out
    end

    before_each(function()
        helper.reset()
        VavaAtelier = nil
        helper.loadAll({
            'modules/vava_atelier/shared/constants.lua',
            'modules/vava_atelier/shared/bounds.lua',
            'modules/vava_atelier/shared/text.lua',
            'modules/vava_atelier/shared/formvalues.lua',
        })
        fv = VavaAtelier.formvalues
        form = {
            titleField = 'nom',
            fields = {
                { id = 'nom', widget = 'text', charset = 'name', min = 3, max = 40, label = 'Nom', help = 'Aide.' },
                { id = 'texte', widget = 'text', charset = 'free', multiline = true, max = 300, optional = true, label = 'Texte', help = 'Aide.' },
                { id = 'code', widget = 'text', charset = 'id', max = 20, optional = true, label = 'Code', help = 'Aide.' },
                { id = 'part', widget = 'slider', min = 0, max = 1, step = 0.1, default = 0.5, label = 'Part', help = 'Aide.' },
                { id = 'pas', widget = 'slider', integer = true, min = 1, max = 10, step = 1, default = 3, label = 'Pas', help = 'Aide.' },
                { id = 'matiere', widget = 'segmented', label = 'Matière', help = 'Aide.',
                    options = { { value = 'bois', label = 'Bois' }, { value = 'pierre', label = 'Pierre' } } },
                { id = 'langue', widget = 'select', default = 'commun', label = 'Langue', help = 'Aide.',
                    options = { { value = 'commun', label = 'Commune' }, { value = 'runes', label = 'Runes' } } },
                { id = 'quartier', widget = 'select', source = 'quartiers', label = 'Quartier', help = 'Aide.' },
                { id = 'eclaire', widget = 'toggle', default = false, label = 'Éclairé', help = 'Aide.' },
                { id = 'duree', widget = 'duration', min = 3600, max = 2592000, units = { 'h', 'j' }, default = 604800, label = 'Durée', help = 'Aide.' },
                { id = 'offrande', widget = 'item', optional = true, label = 'Objet', help = 'Aide.' },
                { id = 'outil', widget = 'item', label = 'Outil', help = 'Aide.' },
                { id = 'modele', widget = 'model', label = 'Modèle', help = 'Aide.',
                    choices = { { value = 'prop_a', label = 'A', provisional = true }, { value = 'prop_b', label = 'B' } } },
                { id = 'libre', widget = 'model', free = true, optional = true, label = 'Libre', help = 'Aide.',
                    choices = { { value = 'prop_a', label = 'A' } } },
            },
        }
    end)

    local function goodPacket()
        return {
            n = { part = 0.5, pas = 3, duree = 7200 },
            s = { nom = 'Forêt de Brume', texte = 'Deux\nlignes', code = 'foret_1', matiere = 'bois', langue = 'runes',
                quartier = 'port', offrande = '', outil = 'hache', modele = 'prop_b', libre = 'prop_zz' },
            b = { eclaire = true },
        }
    end

    describe('toData', function()
        it('rend la data d\'un paquet juste', function()
            local data, errors = fv.toData(form, goodPacket())
            assert.is_nil(errors)
            assert.same({
                nom = 'Forêt de Brume', texte = 'Deux\nlignes', code = 'foret_1', part = 0.5, pas = 3, matiere = 'bois',
                langue = 'runes', quartier = 'port', eclaire = true, duree = 7200, offrande = '', outil = 'hache',
                modele = 'prop_b', libre = 'prop_zz',
            }, data)
            assert.equal('integer', math.type(data.pas))
            assert.equal('integer', math.type(data.duree))
        end)

        it('refuse une clé inconnue, sans champ', function()
            local packet = goodPacket()
            packet.s.intrus = 'x'
            local data, errors = fv.toData(form, packet)
            assert.is_nil(data)
            assert.same({ 'intrus:unknown_field' }, codes(errors))
            assert.is_nil(errors[1].field)
        end)

        it('refuse une valeur rangée dans la mauvaise carte', function()
            local packet = goodPacket()
            packet.n.part, packet.s.part = nil, '0.5'
            local _, errors = fv.toData(form, packet)
            assert.same({ 'part:type' }, codes(errors))
        end)

        it('refuse un champ requis absent ; un facultatif absent vaut ""', function()
            local packet = goodPacket()
            packet.s.nom, packet.s.texte, packet.s.offrande = nil, nil, nil
            local _, errors = fv.toData(form, packet)
            assert.same({ 'nom:required' }, codes(errors))
            packet.s.nom = 'Nom juste'
            local data = fv.toData(form, packet)
            assert.equal('', data.texte)
            assert.equal('', data.offrande)
        end)

        it('borne un curseur et le tient sur ses pas', function()
            local function partError(value)
                local packet = goodPacket()
                packet.n.part = value
                local data, errors = fv.toData(form, packet)
                return data and data.part, errors and errors[1].code
            end
            assert.same({ nil, 'range' }, { partError(-0.1) })
            assert.same({ nil, 'range' }, { partError(1.2) })
            assert.same({ nil, 'step' }, { partError(0.35) })
            local value = partError(0.30000000000000004)
            assert.equal(0.3, value)
            assert.equal(1, (partError(1)))
            assert.same({ nil, 'number' }, { partError(0 / 0) })
            assert.same({ nil, 'number' }, { partError(math.huge) })
            local packet = goodPacket()
            packet.n.pas = 2.5
            local _, errors = fv.toData(form, packet)
            assert.same({ 'pas:step' }, codes(errors))
            assert.same({ 1 }, errors[1].args)
        end)

        it('refuse un choix inconnu et un interrupteur absent', function()
            local packet = goodPacket()
            packet.s.matiere, packet.s.langue = 'verre', 'elfique'
            packet.b.eclaire = nil
            local _, errors = fv.toData(form, packet)
            assert.same({ 'matiere:choice', 'langue:choice', 'eclaire:required' }, codes(errors))
        end)

        it('texte name : accents et apostrophe acceptés, balises, contrôles et espaces doublés refusés', function()
            local function nom(value)
                local packet = goodPacket()
                packet.s.nom = value
                local data, errors = fv.toData(form, packet)
                return data and data.nom, errors and errors[1].code
            end
            assert.equal('Forêt de Brume', nom('Forêt de Brume'))
            assert.equal('L\'Ancre-Rouge', nom('L\'Ancre-Rouge'))
            assert.equal('Bords retirés', nom('   Bords retirés  '))
            assert.same({ nil, 'charset' }, { nom('<b>Essai</b>') })
            assert.same({ nil, 'control' }, { nom('Nom\tcaché') })
            assert.same({ nil, 'spaces' }, { nom('Deux  espaces') })
            assert.same({ nil, 'charset' }, { nom('\xC3 invalide') })
            assert.same({ nil, 'required' }, { nom('   ') })
            assert.same({ nil, 'type' }, { nom(12) })
        end)

        it('texte : longueur comptée en caractères', function()
            local function nom(value)
                local packet = goodPacket()
                packet.s.nom = value
                local data, errors = fv.toData(form, packet)
                return data and data.nom, errors and errors[1].code, errors and errors[1].args
            end
            assert.equal('Été', nom('Été'))                         -- 3 caractères, 5 octets
            assert.same({ nil, 'length', { 3, 40 } }, { nom('Éa') })
            assert.equal(string.rep('é', 40), nom(string.rep('é', 40)))   -- 80 octets, 40 caractères
            assert.same({ nil, 'length', { 3, 40 } }, { nom(string.rep('é', 41)) })
        end)

        it('texte multiline : 8 lignes au plus, retours unifiés, < et > refusés', function()
            local function texte(value)
                local packet = goodPacket()
                packet.s.texte = value
                local data, errors = fv.toData(form, packet)
                return data and data.texte, errors and errors[1].code
            end
            assert.equal('a\nb', texte('a\r\nb'))
            assert.equal(string.rep('l\n', 7) .. 'l', texte(string.rep('l\n', 7) .. 'l'))
            assert.same({ nil, 'lines' }, { texte(string.rep('l\n', 8) .. 'l') })
            assert.same({ nil, 'charset' }, { texte('a < b') })
            assert.same({ nil, 'control' }, { texte('a\tb') })
        end)

        it('texte id : minuscules, chiffres et _', function()
            local packet = goodPacket()
            packet.s.code = 'Forêt'
            local _, errors = fv.toData(form, packet)
            assert.same({ 'code:charset' }, codes(errors))
        end)

        it('durée en secondes entières, dans ses bornes', function()
            local packet = goodPacket()
            packet.n.duree = 3600.5
            local _, errors = fv.toData(form, packet)
            assert.same({ 'duree:integer' }, codes(errors))
            packet.n.duree = 60
            _, errors = fv.toData(form, packet)
            assert.same({ 'duree:range' }, codes(errors))
            packet.n.duree = 7200.0
            local data = fv.toData(form, packet)
            assert.equal(7200, data.duree)
            assert.equal('integer', math.type(data.duree))
        end)

        it('objet : vide seulement si facultatif, nom au motif du registre', function()
            local packet = goodPacket()
            packet.s.outil = ''
            local _, errors = fv.toData(form, packet)
            assert.same({ 'outil:required' }, codes(errors))
            packet.s.outil = 'hache de fer'
            _, errors = fv.toData(form, packet)
            assert.same({ 'outil:item' }, codes(errors))
            packet.s.outil = 'vava:hache.fer-1'
            assert.is_not_nil(fv.toData(form, packet))
        end)

        it('modèle : parmi les choix, ou libre si permis', function()
            local packet = goodPacket()
            packet.s.modele = 'prop_inconnu'
            local _, errors = fv.toData(form, packet)
            assert.same({ 'modele:model' }, codes(errors))
            packet.s.modele = 'prop_a'
            packet.s.libre = 'prop_zz-2'
            assert.is_not_nil(fv.toData(form, packet))
            packet.s.libre = 'prop zz'
            _, errors = fv.toData(form, packet)
            assert.same({ 'libre:model' }, codes(errors))
        end)

        it('range les erreurs dans l\'ordre du formulaire', function()
            local packet = goodPacket()
            packet.s.modele, packet.s.nom, packet.n.part = 'x x', '<b>', 9
            packet.s.zz = 'x'
            local _, errors = fv.toData(form, packet)
            assert.same({ 'zz:unknown_field', 'nom:charset', 'part:range', 'modele:model' }, codes(errors))
        end)

        it('refuse un paquet mal formé sans lever d\'erreur', function()
            local _, errors = fv.toData(form, 'n')
            assert.is_true(#errors > 0)
            _, errors = fv.toData(form, { n = 'x' })
            assert.equal('type', errors[1].code)
        end)
    end)

    describe('toPacket', function()
        it('toPacket puis toData rendent la même data', function()
            local data = fv.toData(form, goodPacket())
            local packet, warnings = fv.toPacket(form, data)
            assert.same({}, warnings)
            assert.same(data, fv.toData(form, packet))
            assert.equal(0.5, packet.n.part)
            assert.is_true(packet.b.eclaire)
            assert.equal('Forêt de Brume', packet.s.nom)
        end)

        it('reprend par défaut une valeur du module hors bornes ou absente, avec un avertissement', function()
            local data = fv.toData(form, goodPacket())
            data.part, data.duree, data.matiere, data.eclaire = 4, nil, 'verre', 'oui'
            local packet, warnings = fv.toPacket(form, data)
            assert.same({ 'part', 'matiere', 'eclaire', 'duree' }, warnings)
            assert.equal(0.5, packet.n.part)
            assert.equal(604800, packet.n.duree)
            assert.equal('bois', packet.s.matiere)
            assert.is_false(packet.b.eclaire)
        end)

        it('garde vide un champ facultatif absent, sans avertissement', function()
            local data = fv.toData(form, goodPacket())
            data.texte, data.offrande = nil, nil
            local packet, warnings = fv.toPacket(form, data)
            assert.same({}, warnings)
            assert.equal('', packet.s.texte)
            assert.equal('', packet.s.offrande)
        end)

        it('omet une carte vide', function()
            local small = { titleField = 'nom', fields = { form.fields[1] } }
            local packet = fv.toPacket(small, { nom = 'Abc' })
            assert.same({ s = { nom = 'Abc' } }, packet)
        end)
    end)

    it('defaults : valeurs d\'une entrée nouvelle', function()
        assert.same({
            nom = '', texte = '', code = '', part = 0.5, pas = 3, matiere = 'bois', langue = 'commun', quartier = '',
            eclaire = false, duree = 604800, offrande = '', outil = '', modele = 'prop_a', libre = '',
        }, fv.defaults(form))
    end)
end)
