local helper = require('tests.helper')

-- server/reading.lua (pages de lecture, côté serveur) avec des doublures : droits du Conseil, ressources démarrées,
-- personnage chargé, journal du core, registre des commandes, RegisterCommand.
describe('vava_codex pages de lecture : serveur', function()
    local reading, logs, staff, rights, started, characters, registry, commands

    --- Graine de test : deux chapitres, une page publique, une page liée à un module, deux pages du Conseil (l'une à
    --- droit), une page fautive (ligne 3).
    local function seed()
        return {
            chapters = {
                { id = 'premiers_pas', label = 'Premiers pas', order = 10 },
                { id = 'royaume', label = 'Le royaume', order = 30 },
            },
            pages = {
                { id = 'bienvenue', chapter = 'premiers_pas', order = 10, title = 'Vivre à Eldoria', summary = 'Bienvenue.',
                    audience = 'player', permission = '', requires = '',
                    body = 'Le Codex : [[touche:codex]]. La besace : [[touche:vava_inventory]].\n\n- [[commande:date]]' },
                { id = 'magie', chapter = 'royaume', order = 10, title = 'La magie', summary = 'Elle se paie.',
                    audience = 'player', permission = '', requires = 'vava_magic',
                    body = 'Le grimoire : [[commande:grimoire]] ; [[commande:sigil offrir]] ; [[touche:vava_magic_roue]].' },
                { id = 'conseil_sieger', chapter = 'royaume', order = 30, title = 'Siéger au Conseil', summary = '',
                    audience = 'admin', permission = '', requires = '', body = 'Le Registre : [[touche:conseil]].' },
                { id = 'metiers_conseil', chapter = 'royaume', order = 40, title = 'Outils des métiers', summary = '',
                    audience = 'admin', permission = 'metiers', requires = '', body = '[[commande:recolte zones]]' },
                { id = 'faute', chapter = 'premiers_pas', order = 20, title = 'Fautive', summary = '',
                    audience = 'player', permission = '', requires = '', body = 'Un.\n\nDeux [[foo:bar]].' },
            },
        }
    end

    local function load(value)
        helper.reset()
        VavaCodex = nil
        helper.loadAll({
            'modules/vava_codex/shared/constants.lua',
            'modules/vava_codex/config.lua',
            'modules/vava_codex/shared/fingerprint.lua',
            'modules/vava_codex/shared/pages.lua',
        })
        logs = {}
        local function logger(level)
            return function(fmt, ...) logs[#logs + 1] = { level = level, text = string.format(fmt, ...) } end
        end
        VavaCodex.log = { info = logger('info'), warn = logger('warn'), error = logger('error'), debug = logger('debug') }
        VavaCodex.core = { log = VavaCodex.log, registry = { all = function() return registry end } }
        VavaCodex.bridge = {
            IsStaff = function(src) return staff[src] == true end,
            Can = function(src, permission, ace)
                assert.is_nil(ace)
                return rights[src] ~= nil and rights[src][permission] == true
            end,
            Started = function(resource) return started[resource] == true end,
        }
        VavaCodex.prefs = { get = function(src) return characters[src] and { favorites = {}, recent = {}, keepOpen = true } or nil end }
        commands = {}
        RegisterCommand = function(name, handler, restricted) commands[name] = { handler = handler, restricted = restricted } end
        VavaCodex.seed = value
        helper.load('modules/vava_codex/server/reading.lua')
        reading = VavaCodex.reading
        reading.load()
    end

    local function texts(level)
        local out = {}
        for _, entry in ipairs(logs) do
            if not level or entry.level == level then out[#out + 1] = entry.text end
        end
        return out
    end

    local function pageIds(index)
        local out = {}
        for i, page in ipairs(index.pages) do out[i] = page.id end
        return out
    end

    local function chapterIds(index)
        local out = {}
        for i, chapter in ipairs(index.chapters) do out[i] = chapter.id end
        return out
    end

    before_each(function()
        staff, rights, characters = {}, {}, { [1] = true, [2] = true, [3] = true }
        started = { vava_magic = true, vava_admin = true }
        registry = {
            codex = { kind = 'command', key = 'F1' },
            date = { kind = 'command' },
            conseil = { kind = 'command', key = 'F10' },
            recolte = { kind = 'command', actions = { { id = 'zones' } } },
            grimoire = { kind = 'command' },
            sigil = { kind = 'command', actions = { { id = 'renommer' } } },
            vava_magic_roue = { kind = 'key' },
        }
        load(seed())
    end)

    describe('chargement', function()
        it('écarte la page fautive, garde les autres, et l\'écrit en console', function()
            assert.same({
                'page « faute » refusée : jeton mal formé (voir le format : [[F1]], [[touche:…]], [[commande:…]], '
                    .. '[[page:…]]) (ligne 3)',
                'pages de lecture : 4 chargées, 1 refusées',
            }, texts())
            assert.equal('warn', logs[1].level)
            assert.equal('info', logs[2].level)
            assert.is_nil(VavaCodex.seed)
        end)

        it('écrit un chapitre refusé à part, sans le compter parmi les pages', function()
            local value = seed()
            value.chapters[3] = { id = 'vava_x', label = 'X', order = 50 }
            load(value)
            assert.equal('chapitre « vava_x » refusé : identifiant invalide (minuscules, chiffres, « _ », 32 au plus, '
                .. 'jamais « vava… »)', texts('warn')[1])
            assert.equal('pages de lecture : 4 chargées, 1 refusées', texts('info')[1])
        end)

        it('sans graine : aucune page, un avertissement', function()
            load(nil)
            assert.same({ 'warn' }, { logs[1].level })
            assert.equal(1, #logs)
            assert.same({ chapters = {}, pages = {} }, reading.index(1, false))
            assert.same({ false, 'unknown_page' }, { reading.page(1, 'bienvenue') })
        end)

        it('une erreur imprévue de la construction ne laisse aucune page, sans lever', function()
            VavaCodex.pages.build = function() error('boum') end
            VavaCodex.seed = seed()
            assert.has_no.errors(function() reading.load() end)
            assert.equal('error', logs[#logs].level)
            assert.truthy(logs[#logs].text:find('boum', 1, true))
            assert.same({ chapters = {}, pages = {} }, reading.index(1, true))
        end)
    end)

    describe('index d\'un joueur', function()
        it('ne montre au joueur que les pages publiques, sans sceau', function()
            local index = reading.index(1, false)
            assert.same({ 'bienvenue', 'magie' }, pageIds(index))
            assert.same({ { id = 'premiers_pas', label = 'Premiers pas' }, { id = 'royaume', label = 'Le royaume' } }, index.chapters)
            for _, page in ipairs(index.pages) do assert.is_nil(page.staff) end
            assert.same({ id = 'bienvenue', chapter = 'premiers_pas', title = 'Vivre à Eldoria', summary = 'Bienvenue.',
                hash = index.pages[1].hash }, index.pages[1])
            assert.equal(16, #index.pages[1].hash)
        end)

        it('montre au Conseil ses pages, avec un sceau, et la page à droit selon ce droit', function()
            staff[1] = true
            local gardien = reading.index(1, true)
            assert.same({ 'bienvenue', 'magie', 'conseil_sieger' }, pageIds(gardien))
            assert.is_true(gardien.pages[3].staff)
            rights[1] = { metiers = true }
            local senechal = reading.index(1, true)
            assert.same({ 'bienvenue', 'magie', 'conseil_sieger', 'metiers_conseil' }, pageIds(senechal))
            assert.is_true(senechal.pages[4].staff)
        end)

        it('cache la page d\'un module arrêté, et son chapitre s\'il n\'en reste aucune', function()
            started.vava_magic = nil
            local index = reading.index(1, false)
            assert.same({ 'bienvenue' }, pageIds(index))
            assert.same({ 'premiers_pas' }, chapterIds(index))
            staff[1] = true
            assert.same({ 'premiers_pas', 'royaume' }, chapterIds(reading.index(1, true)))
        end)

        it('garde la même empreinte d\'une ouverture à l\'autre, et en change avec le contenu', function()
            local first = VavaCodex.fingerprint(reading.index(1, false))
            assert.equal(first, VavaCodex.fingerprint(reading.index(1, false)))
            assert.equal(first, VavaCodex.fingerprint(reading.index(2, false)))
            local value = seed()
            value.pages[1].title = 'Vivre ici'
            load(value)
            assert.are_not.equal(first, VavaCodex.fingerprint(reading.index(1, false)))
            started.vava_magic = nil
            local stopped = VavaCodex.fingerprint(reading.index(1, false))
            started.vava_magic = true
            assert.are_not.equal(stopped, VavaCodex.fingerprint(reading.index(1, false)))
        end)

        it('n\'existe pas quand les pages sont fermées', function()
            VavaCodex.config.reading.enabled = false
            assert.is_nil(reading.index(1, true))
        end)
    end)

    describe('page demandée', function()
        it('rend la page visible en blocs', function()
            local ok, page = reading.page(1, 'bienvenue')
            assert.is_true(ok)
            -- chapitre et titre sont dans l'index : la réponse ne porte que l'id, l'empreinte et les blocs
            assert.same({ id = 'bienvenue', hash = page.hash, body = page.body }, page)
            assert.equal(reading.index(1, false).pages[1].hash, page.hash)
            assert.same({ 'p', 'Le Codex : ', { 'key', 'codex' }, '. La besace : ', { 'key', 'vava_inventory' }, '.' }, page.body[1])
            assert.same({ 'ul', { { 'cmd', 'date', '' } } }, page.body[2])
        end)

        it('répond le même code pour une page réservée, inconnue, refusée ou d\'un module arrêté', function()
            for _, id in ipairs({ 'conseil_sieger', 'metiers_conseil', 'inconnue', 'faute' }) do
                assert.same({ false, 'unknown_page' }, { reading.page(1, id) }, id)
            end
            started.vava_magic = nil
            assert.same({ false, 'unknown_page' }, { reading.page(1, 'magie') })
        end)

        it('ouvre au Conseil ses pages, droit compris', function()
            staff[1] = true
            assert.is_true((reading.page(1, 'conseil_sieger')))
            assert.same({ false, 'unknown_page' }, { reading.page(1, 'metiers_conseil') })
            rights[1] = { metiers = true }
            assert.is_true((reading.page(1, 'metiers_conseil')))
        end)

        it('cache une page à droit quand vava_admin n\'est pas démarré, sans ouvrir le repli ACE', function()
            staff[1], rights[1] = true, { metiers = true }
            started.vava_admin = nil
            assert.same({ 'bienvenue', 'magie', 'conseil_sieger' }, pageIds(reading.index(1, true)))
            assert.same({ false, 'unknown_page' }, { reading.page(1, 'metiers_conseil') })
            -- une page du Conseil sans droit reste ouverte au Conseil reconnu par l'ACE
            assert.is_true((reading.page(1, 'conseil_sieger')))
            started.vava_admin = true
            assert.is_true((reading.page(1, 'metiers_conseil')))
        end)

        it('ferme une page dont le droit a été retiré entre deux appels', function()
            staff[1], rights[1] = true, { metiers = true }
            assert.is_true((reading.page(1, 'metiers_conseil')))
            rights[1] = nil
            assert.same({ false, 'unknown_page' }, { reading.page(1, 'metiers_conseil') })
            staff[1] = nil
            assert.same({ false, 'unknown_page' }, { reading.page(1, 'conseil_sieger') })
        end)

        it('refuse sans personnage, puis quand les pages sont fermées', function()
            characters[1] = nil
            assert.same({ false, 'no_character' }, { reading.page(1, 'bienvenue') })
            VavaCodex.config.reading.enabled = false
            assert.same({ false, 'disabled' }, { reading.page(2, 'bienvenue') })
        end)
    end)

    describe('commande de console', function()
        it('est enregistrée, restreinte', function()
            reading.listen()
            assert.is_table(commands.vava_codex_pages)
            assert.is_true(commands.vava_codex_pages.restricted)
        end)

        it('n\'écrit rien pour un joueur', function()
            reading.listen()
            local before = #logs
            commands.vava_codex_pages.handler(3, {})
            commands.vava_codex_pages.handler('3', {})
            assert.equal(before, #logs)
        end)

        it('écrit une ligne par page, puis chaque touche ou commande citée absente du registre', function()
            reading.listen()
            local before = #logs
            commands.vava_codex_pages.handler(0, {})
            local lines = {}
            for i = before + 1, #logs do lines[#lines + 1] = logs[i].text end
            assert.equal(4 + 3, #lines)
            assert.truthy(lines[1]:find('^bienvenue %(premiers_pas%) : %d+ octets, public$'))
            assert.truthy(lines[2]:find('^magie %(royaume%) : %d+ octets, public, module vava_magic$'))
            assert.truthy(lines[3]:find('^conseil_sieger %(royaume%) : %d+ octets, Conseil$'))
            assert.truthy(lines[4]:find('^metiers_conseil %(royaume%) : %d+ octets, Conseil %(droit metiers%)$'))
            -- touche absente, entrée sans touche, sous-commande absente ; /grimoire, /recolte zones et les autres sont là
            assert.same({
                'page « bienvenue » : touche vava_inventory introuvable au registre (aucun module requis)',
                'page « magie » : touche vava_magic_roue introuvable au registre (vava_magic)',
                'page « magie » : commande /sigil offrir introuvable au registre (vava_magic)',
            }, { lines[5], lines[6], lines[7] })
        end)
    end)
end)
