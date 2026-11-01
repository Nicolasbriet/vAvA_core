local helper = require('tests.helper')

-- Paquet du Conseil côté serveur (T-157, modules/vava_atelier/server/delivery.lua réel, avec server/access.lua réel ;
-- doublures : métadonnées du manifeste, fichiers de la ressource, Bridge, core). Règles documentées : spec T-157 § 3.2,
-- § 6.1, § 7.1 et § 7.2, README de vava_atelier (« Code livré au seul Conseil ») :
--   construction au démarrage dans l'ordre de vava_conseil_lua puis vava_conseil_web, `\r\n` ramené, fichiers Lua
--   compilés sans être exécutés, empreinte, morceaux de 64 Ko ; un paquet qui ne se construit pas laisse le module
--   démarrer et le RPC répond `unavailable` ; RPC `code` : personnage, Registre, droit relu à CHAQUE appel, description
--   ou morceau d'empreinte courante, budget de 3 paquets par heure glissante et par joueur, ligne de console une fois par
--   (joueur, empreinte), oubli au départ.

local ROOT = (os.getenv('VAVA_ROOT') or '.') .. '/'
local DIR = 'modules/vava_atelier/'
local HOUR_MS = 3600000

local function readFile(path)
    local file = io.open(ROOT .. path, 'rb')
    if not file then return nil end
    local text = file:read('a')
    file:close()
    return text
end

--- Métadonnées d'un fxmanifest.lua, lues en l'exécutant dans un environnement qui range chaque directive, dans l'ordre
--- (forme simple ou table de chaînes), comme le lecteur de FXServer pour les directives sans « s » final.
local function manifestMeta(path)
    local meta = {}
    local env = setmetatable({}, { __index = function(_, key)
        return function(value)
            meta[key] = meta[key] or {}
            if type(value) == 'table' then
                for _, v in ipairs(value) do table.insert(meta[key], v) end
            else
                table.insert(meta[key], value)
            end
        end
    end })
    local chunk = assert(loadfile(ROOT .. path, 't', env))
    chunk()
    return meta
end

--- Taille exacte du paquet de ces fichiers (format du § 5.1), calculée ici sans codepack.
local function packSize(names, files)
    local size = #'VAVAPAQ1\n'
    for _, name in ipairs(names) do
        local code = files[name]
        size = size + 2 + #name + 1 + #tostring(#code) + 1 + #code + 1
    end
    return size
end

describe('vava_atelier paquet du Conseil (serveur)', function()
    local delivery, meta, disk, logs, now, chars, can, adminReady

    local function start(meta_, disk_)
        meta, disk = meta_, disk_
        helper.reset()
        VavaAtelier = nil
        helper.loadAll({
            DIR .. 'shared/constants.lua',
            DIR .. 'shared/bounds.lua',
            DIR .. 'config.lua',
            DIR .. 'shared/digest.lua',
            DIR .. 'shared/codepack.lua',
        })
        logs = { info = {}, warn = {}, error = {} }
        local function logger(level)
            return function(fmt, ...) table.insert(logs[level], fmt:format(...)) end
        end
        VavaAtelier.log = { info = logger('info'), warn = logger('warn'), error = logger('error') }
        VavaAtelier.core = { log = VavaAtelier.log, hooks = { runAfter = function() end } }
        VavaAtelier.resource = 'vava_atelier'
        now, chars, can, adminReady = 1000, { [7] = { accountId = 12 } }, { [7] = true }, true
        VavaAtelier.bridge = {
            Character = function(source) return chars[source] end,
            AdminReady = function() return adminReady end,
            AccountId = function(source) return chars[source] and chars[source].accountId end,
            Can = function(source, right)
                assert.equal('metiers', right)
                return can[source] == true
            end,
        }
        VavaAtelier.editors = {}
        _G.GetGameTimer = function() return now end
        _G.GetNumResourceMetadata = function(resource, key)
            assert.equal('vava_atelier', resource)
            return meta[key] and #meta[key] or 0
        end
        _G.GetResourceMetadata = function(resource, key, index)
            assert.equal('vava_atelier', resource)
            return meta[key] and meta[key][index + 1] or nil
        end
        _G.LoadResourceFile = function(resource, path)
            assert.equal('vava_atelier', resource)
            return disk(path)
        end
        helper.load(DIR .. 'server/access.lua')
        helper.load(DIR .. 'server/delivery.lua')
        delivery = VavaAtelier.delivery
    end

    after_each(function()
        VavaAtelier = nil
        _G.GetNumResourceMetadata, _G.GetResourceMetadata, _G.LoadResourceFile = nil, nil, nil
    end)

    --- Le manifeste et les fichiers réels du module.
    local function loadReal()
        start(manifestMeta(DIR .. 'fxmanifest.lua'), function(path) return readFile(DIR .. path) end)
    end

    --- Paquet écrit ici : fichiers `files` (nom → code), listes `lua` et `web`.
    local function loadSynthetic(lua, web, files)
        start({ vava_conseil_lua = lua, vava_conseil_web = web }, function(path) return files[path] end)
    end

    local function fetchAll(source, fp, parts)
        local out = {}
        for k = 1, parts do
            local ok, chunk = delivery.rpc(source, fp, k)
            assert.is_true(ok, tostring(chunk))
            out[k] = chunk
        end
        return table.concat(out)
    end

    describe('construction', function()
        it('paquet réel : 24 fichiers dans l\'ordre du manifeste, compilés, 4 morceaux, ligne de console', function()
            loadReal()
            assert.is_true(delivery.build())
            local lua, web = meta.vava_conseil_lua, meta.vava_conseil_web
            assert.equal(9, #lua)
            assert.equal(15, #web)
            local names, files = {}, {}
            for _, list in ipairs({ lua, web }) do
                for _, name in ipairs(list) do
                    names[#names + 1] = name
                    files[name] = readFile(DIR .. name):gsub('\r\n', '\n')
                end
            end
            local status = delivery.status()
            assert.is_true(status.ready)
            assert.equal(24, status.pieces)
            assert.equal(packSize(names, files), status.bytes)
            assert.equal(4, status.parts)
            assert.equal(1, #logs.info)
            assert.truthy(logs.info[1]:find('^paquet du Conseil : 24 fichiers, %d+ %d%d%d octets, 4 morceaux, '
                .. 'empreinte [0-9a-f]+$'), logs.info[1])
            -- morceaux concaténés : le paquet, dans l'ordre des deux listes, tous les L d'abord
            local ok, info = delivery.rpc(7, '', 0)
            assert.is_true(ok)
            local text = fetchAll(7, info.fp, info.parts)
            assert.equal(info.fp, VavaAtelier.digest(text))
            local pieces = assert(VavaAtelier.codepack.decode(text))
            for i, name in ipairs(names) do
                assert.equal(name, pieces[i].name)
                assert.equal(i <= 9 and 'L' or (name:match('%.css$') and 'C' or 'J'), pieces[i].kind)
                assert.equal(files[name], pieces[i].code)
            end
        end)

        it('`\\r\\n` ramené à `\\n`, genres par extension, ordre des listes gardé', function()
            loadSynthetic({ 'client/b.lua', 'client/a.lua' }, { 'web/js/z.js', 'web/css/s.css' }, {
                ['client/a.lua'] = 'return 1\r\n', ['client/b.lua'] = 'local x = 1\r\nreturn x\r\n',
                ['web/js/z.js'] = 'z();\r\n', ['web/css/s.css'] = '.a{}\r\n',
            })
            assert.is_true(delivery.build())
            local ok, info = delivery.rpc(7, '', 0)
            assert.is_true(ok)
            local pieces = assert(VavaAtelier.codepack.decode(fetchAll(7, info.fp, info.parts)))
            assert.same({
                { kind = 'L', name = 'client/b.lua', code = 'local x = 1\nreturn x\n' },
                { kind = 'L', name = 'client/a.lua', code = 'return 1\n' },
                { kind = 'J', name = 'web/js/z.js', code = 'z();\n' },
                { kind = 'C', name = 'web/css/s.css', code = '.a{}\n' },
            }, pieces)
        end)

        it('compile sans exécuter : un fichier qui lèverait une erreur au chargement passe la construction', function()
            loadSynthetic({ 'client/a.lua' }, { 'web/js/a.js' },
                { ['client/a.lua'] = 'error("jamais sur le serveur")\n', ['web/js/a.js'] = '' })
            assert.is_true(delivery.build())
            assert.same({}, logs.error)
        end)

        local BROKEN = {
            { 'fichier absent', { 'client/a.lua', 'client/absent.lua' }, { 'web/js/a.js' }, 'fichier absent : client/absent.lua' },
            { 'octet nul', { 'client/nul.lua' }, { 'web/js/a.js' }, 'octet nul dans client/nul.lua' },
            { 'erreur de syntaxe (nom et ligne)', { 'client/a.lua', 'client/syntaxe.lua' }, { 'web/js/a.js' },
                'vava_atelier/client/syntaxe.lua:2:' },
            { 'doublon', { 'client/a.lua', 'client/a.lua' }, { 'web/js/a.js' }, 'listé deux fois : client/a.lua' },
            { 'liste Lua vide', {}, { 'web/js/a.js' }, 'vava_conseil_lua vide' },
            { 'liste de la page vide', { 'client/a.lua' }, {}, 'vava_conseil_web vide' },
            { 'chemin refusé', { 'client/A.lua' }, { 'web/js/a.js' }, 'chemin refusé' },
            { 'extension hors de sa liste', { 'client/a.lua' }, { 'web/js/a.lua' }, 'chemin refusé' },
            { 'config.lua jamais (extension .lua hors de la page, et fichier du serveur)', { 'client/a.lua' },
                { 'config.lua' }, 'chemin refusé' },
            { 'trop gros', { 'client/a.lua', 'client/gros.lua' }, { 'web/js/a.js' }, 'too_large' },
        }
        local FILES = {
            ['client/a.lua'] = 'return 1\n', ['web/js/a.js'] = 'a();\n', ['client/nul.lua'] = 'return "\0"\n',
            ['client/syntaxe.lua'] = 'local a = 1\nlocal = 2\n', ['client/gros.lua'] = '--' .. string.rep('x', 530000),
            ['client/A.lua'] = 'return 1\n', ['web/js/a.lua'] = 'return 1\n', ['config.lua'] = 'return 1\n',
        }
        for _, case in ipairs(BROKEN) do
            it('non construit : ' .. case[1] .. ' → unavailable, erreur en console', function()
                loadSynthetic(case[2], case[3], FILES)
                local ok, err = delivery.build()
                assert.is_false(ok)
                assert.truthy(tostring(err):find(case[4], 1, true), tostring(err))
                assert.equal(1, #logs.error)
                assert.truthy(logs.error[1]:find('paquet du Conseil non construit', 1, true))
                assert.same({ false, 'unavailable' }, { delivery.rpc(7, '', 0) })
                assert.same({ false, 'unavailable' }, { delivery.rpc(7, '0123456789abcdef', 1) })
                -- hors du Conseil : le droit passe avant (rien n'est dit de l'état du paquet)
                can[7] = false
                assert.same({ false, 'not_allowed' }, { delivery.rpc(7, '', 0) })
            end)
        end
    end)

    describe('RPC code', function()
        local info

        before_each(function()
            loadReal()
            assert.is_true(delivery.build())
            local ok
            ok, info = delivery.rpc(7, '', 0)
            assert.is_true(ok)
        end)

        it('description : empreinte, morceaux, taille ; même réponse avec une empreinte périmée', function()
            local status = delivery.status()
            assert.same({ fp = status.fp, parts = 4, bytes = status.bytes }, info)
            assert.same({ true, info }, { delivery.rpc(7, 'ffffffffffffffff', 0) })
        end)

        it('morceaux de 64 Ko au plus dont la suite a l\'empreinte annoncée', function()
            local parts = {}
            for k = 1, info.parts do
                local ok, chunk = delivery.rpc(7, info.fp, k)
                assert.is_true(ok)
                assert.is_true(#chunk <= 65536 and #chunk > 0)
                parts[k] = chunk
            end
            local text = table.concat(parts)
            assert.equal(info.bytes, #text)
            assert.equal(info.fp, VavaAtelier.digest(text))
        end)

        it('hors du Conseil : not_allowed, aucun morceau, une ligne de refus', function()
            can[7] = false
            assert.same({ false, 'not_allowed' }, { delivery.rpc(7, '', 0) })
            assert.same({ false, 'not_allowed' }, { delivery.rpc(7, info.fp, 1) })
            assert.equal(1, #logs.warn)
            assert.truthy(logs.warn[1]:find('vava_atelier:code refusé (droit)', 1, true))
        end)

        it('sans personnage : no_character ; Registre absent : not_ready', function()
            chars[7] = nil
            assert.same({ false, 'no_character' }, { delivery.rpc(7, info.fp, 1) })
            chars[7] = { accountId = 12 }
            adminReady = false
            assert.same({ false, 'not_ready' }, { delivery.rpc(7, info.fp, 1) })
        end)

        it('empreinte qui n\'est plus celle du serveur : stale ; morceau au-delà : bad_request', function()
            assert.same({ false, 'stale' }, { delivery.rpc(7, '0123456789abcdef', 1) })
            assert.same({ false, 'stale' }, { delivery.rpc(7, '', 1) })
            assert.same({ false, 'bad_request' }, { delivery.rpc(7, info.fp, 5) })
        end)

        it('droit retiré entre deux morceaux : le suivant est refusé', function()
            assert.is_true((delivery.rpc(7, info.fp, 1)))
            assert.is_true((delivery.rpc(7, info.fp, 2)))
            can[7] = false
            assert.same({ false, 'not_allowed' }, { delivery.rpc(7, info.fp, 3) })
        end)

        it('budget : 3 paquets par heure glissante, le 4e refusé (rate_limited), rendu après l\'heure', function()
            for _ = 1, 3 do fetchAll(7, info.fp, info.parts) end
            assert.same({ false, 'rate_limited' }, { delivery.rpc(7, info.fp, 1) })
            -- la description reste permise ; un autre membre a son propre budget
            assert.is_true((delivery.rpc(7, '', 0)))
            chars[8], can[8] = { accountId = 13 }, true
            fetchAll(8, info.fp, info.parts)
            now = now + HOUR_MS - 1
            assert.same({ false, 'rate_limited' }, { delivery.rpc(7, info.fp, 1) })
            now = now + 1
            fetchAll(7, info.fp, info.parts)
        end)

        it('ligne de console une fois par (joueur, empreinte) ; départ : budget oublié', function()
            for _ = 1, 3 do fetchAll(7, info.fp, info.parts) end
            assert.equal(2, #logs.info)   -- construction, puis un seul envoi
            assert.truthy(logs.info[2]:find('^paquet du Conseil envoyé : joueur 7, compte 12, %d+ %d%d%d octets$'),
                logs.info[2])
            delivery.forget(7)
            fetchAll(7, info.fp, info.parts)
            assert.equal(3, #logs.info)
        end)
    end)

    describe('réglages (setup)', function()
        before_each(function() loadReal() end)

        it('config livrée : acceptée', function()
            assert.same({ true }, { delivery.checkSettings(VavaAtelier.config) })
        end)

        it('attentes, textes et budget hors bornes : refusés avec la raison', function()
            local cfg = VavaAtelier.config
            cfg.delivery.pageWaitMs = 999
            assert.matches('delivery.pageWaitMs', select(2, delivery.checkSettings(cfg)), 1, true)
            cfg.delivery.pageWaitMs, cfg.delivery.bootWaitMs = 5000, 30001
            assert.matches('delivery.bootWaitMs', select(2, delivery.checkSettings(cfg)), 1, true)
            cfg.delivery.bootWaitMs = 1.5
            assert.is_false((delivery.checkSettings(cfg)))
            cfg.delivery.bootWaitMs = 5000
            cfg.texts.loading = string.rep('a', 161)
            assert.matches('texts.loading', select(2, delivery.checkSettings(cfg)), 1, true)
            cfg.texts.loading = 'x'
            cfg.texts.loadFailed = ''
            assert.matches('texts.loadFailed', select(2, delivery.checkSettings(cfg)), 1, true)
            cfg.texts.loadFailed = 'x'
            for _, bad in ipairs({ 0, 21, 2.5 }) do
                cfg.delivery.hourlyPackages = bad
                assert.matches('delivery.hourlyPackages', select(2, delivery.checkSettings(cfg)), 1, true)
            end
            cfg.delivery.hourlyPackages = 20
            assert.is_true((delivery.checkSettings(cfg)))
            -- config.lua de 1.3.0 gardé : ni budget ni débit du RPC
            local code = cfg.rateLimits.code
            cfg.rateLimits.code = nil
            assert.matches('rateLimits.code', select(2, delivery.checkSettings(cfg)), 1, true)
            cfg.rateLimits.code, cfg.delivery.hourlyPackages = code, nil
            assert.matches('delivery.hourlyPackages', select(2, delivery.checkSettings(cfg)), 1, true)
        end)
    end)

    describe('page et amorce', function()
        it('l\'ordre de vava_conseil_web est celui des feuilles et scripts de web/dev/index.html', function()
            local html = assert(readFile(DIR .. 'web/dev/index.html'))
            local order = {}
            for tag in html:gmatch('<[^>]+>') do
                local href = tag:match('^<link[^>]-href="%.%./(css/[^"]+)"')
                local src = tag:match('^<script[^>]-src="%.%./(js/[^"]+)"')
                if href or src then order[#order + 1] = 'web/' .. (href or src) end
            end
            assert.same(manifestMeta(DIR .. 'fxmanifest.lua').vava_conseil_web, order)
        end)

        it('les bornes de web/boot.js valent celles de CODEPACK', function()
            helper.reset()
            VavaAtelier = nil
            helper.load(DIR .. 'shared/constants.lua')
            local boot = assert(readFile(DIR .. 'web/boot.js'))
            for _, key in ipairs({ 'MAX_PIECES', 'MAX_BYTES', 'MAX_NAME', 'MAX_DEPTH' }) do
                local value = boot:match(key .. '%s*[=:]%s*(%d+)')
                assert.equal(VavaAtelier.CODEPACK[key], tonumber(value), key)
            end
        end)
    end)
end)

-- Démarrage par server/main.lua réel (doublures des autres fichiers du serveur) : un paquet qui ne se construit pas
-- laisse le module démarrer et le RPC `code` déclaré ; une config du chargeur hors bornes refuse le setup.
describe('vava_atelier paquet du Conseil (setup du module)', function()
    local setup, registered, files

    before_each(function()
        helper.reset()
        VavaAtelier = nil
        helper.loadAll({
            DIR .. 'shared/constants.lua', DIR .. 'shared/bounds.lua', DIR .. 'config.lua', DIR .. 'shared/rights.lua',
            DIR .. 'shared/digest.lua', DIR .. 'shared/codepack.lua',
        })
        local quiet = function() end
        VavaAtelier.log = { info = quiet, warn = quiet, error = quiet }
        registered, setup = {}, nil
        VavaAtelier.core = {
            log = VavaAtelier.log,
            hooks = { after = function() return 1 end, runAfter = quiet },
            rpc = { register = function(name, options, handler)
                registered[name] = { options = options, handler = handler }
                return true
            end },
            modules = { register = function(def) setup = def.setup return true end },
        }
        VavaAtelier.resource = 'vava_atelier'
        VavaAtelier.bridge = { Character = function() return { accountId = 1 } end, AdminReady = function() return true end,
            Can = function() return true end }
        local ok = function() return true end
        VavaAtelier.editors = { define = ok }
        VavaAtelier.commands = { declare = ok }
        VavaAtelier.archives = { register = quiet, forget = quiet }
        VavaAtelier.journal = { purge = quiet }
        VavaAtelier.sync = { repair = ok }
        VavaAtelier.history = { purge = quiet }
        VavaAtelier.home, VavaAtelier.entries, VavaAtelier.check, VavaAtelier.cycle = {}, {}, {}, {}
        VavaAtelier.trials, VavaAtelier.placement = {}, {}
        files = { ['client/a.lua'] = 'return 1\n', ['web/js/a.js'] = 'a();\n' }
        local meta = { vava_conseil_lua = { 'client/a.lua' }, vava_conseil_web = { 'web/js/a.js' }, version = { '1.4.0' } }
        _G.GetNumResourceMetadata = function(_, key) return meta[key] and #meta[key] or 0 end
        _G.GetResourceMetadata = function(_, key, index) return meta[key] and meta[key][index + 1] end
        _G.LoadResourceFile = function(_, path) return files[path] end
        helper.load(DIR .. 'server/access.lua')
        helper.load(DIR .. 'server/delivery.lua')
        helper.load(DIR .. 'server/main.lua')
        assert.is_function(setup)
    end)

    after_each(function()
        VavaAtelier = nil
        _G.GetNumResourceMetadata, _G.GetResourceMetadata, _G.LoadResourceFile = nil, nil, nil
    end)

    it('paquet construit : RPC code déclaré au schéma borné et au débit de config.lua', function()
        assert.is_true((setup()))
        local code = registered['vava_atelier:code']
        assert.is_table(code)
        assert.same(VavaAtelier.config.rateLimits.code, code.options.rateLimit)
        assert.same({ capacity = 12, refillPerSecond = 0.2 }, code.options.rateLimit)
        assert.same({ type = 'string', min = 0, max = 16, pattern = '^[0-9a-f]*$' }, code.options.args[1])
        assert.same({ type = 'integer', min = 0, max = 8 }, code.options.args[2])
        assert.is_nil(code.options.latent)
        assert.is_true((code.handler(1, '', 0)))
    end)

    it('paquet impossible à construire : le module démarre quand même, code répond unavailable', function()
        files['client/a.lua'] = nil
        assert.is_true((setup()))
        assert.same({ false, 'unavailable' }, { registered['vava_atelier:code'].handler(1, '', 0) })
        assert.is_table(registered['vava_atelier:home'])
    end)

    it('config du chargeur hors bornes : le setup refuse, avec la raison', function()
        VavaAtelier.config.delivery.pageWaitMs = 40000
        local ok, err = setup()
        assert.is_false(ok)
        assert.matches('delivery.pageWaitMs', err, 1, true)
    end)
end)
