-- Écran de chargement vava_loading (T-020) : ce qu'il livre (manifeste, polices, poids), page sans ressource externe ni
-- innerHTML, textes et réglages de la page dans leur format fixé, réglages et fonctions pures du client Lua.
-- Fichiers lus depuis VAVA_ROOT (ou le dossier courant), comme ui_shared_spec.lua dont les fonctions sont reprises.

local ROOT = (os.getenv('VAVA_ROOT') or '.') .. '/'
local BASE = 'modules/vava_loading/'

-- Motifs livrés, dans l'ordre du manifeste (web/dev/ n'est jamais livré : aucun joker de dossier).
local FILES = { 'web/index.html', 'web/css/style.css', 'web/js/*.js', 'web/fonts/*.woff2' }
local MUSIC_PATTERN = 'web/audio/*.ogg'

-- Fichiers livrés, comptés dans le poids (toute page ou police ajoutée s'écrit ici).
local DELIVERED = {
    'web/index.html', 'web/css/style.css',
    'web/js/config.js', 'web/js/strings.js', 'web/js/text.js', 'web/js/progress.js', 'web/js/quality.js',
    'web/js/scene.js', 'web/js/app.js',
}
local SCRIPTS = { 'config.js', 'strings.js', 'text.js', 'progress.js', 'quality.js', 'scene.js', 'app.js' }

-- Copies identiques des polices de vava_ui ; la quatrième est la seule propre à l'écran (décision 3 de la spec).
local COPIES = { 'cinzel.woff2', 'eb_garamond.woff2', 'eb_garamond_italic.woff2' }
local DECORATIVE = { ['cinzel_decorative_900.woff2'] = 'own', ['cinzel_decorative_700.woff2'] = 'copy' }

local MAX_BYTES, MAX_BYTES_MUSIC = 300 * 1024, 700 * 1024

-- Ligne hors jeu de la spec (§ 9), seule mention des données simulées.
local OFFLINE_LINE = [[<script>location.protocol === 'file:' && document.write('<script src="dev/devmock.js"><\/script>');</script>]]

local function read(path)
    local file = io.open(ROOT .. path, 'rb')
    if not file then return nil end
    local text = file:read('a')
    file:close()
    return text
end

local function size(path)
    local file = io.open(ROOT .. path, 'rb')
    if not file then return nil end
    local bytes = file:seek('end')
    file:close()
    return bytes
end

local function find(text, needle)
    return text:find(needle, 1, true)
end

local function count(text, needle)
    local n, from = 0, 1
    while true do
        local start, stop = text:find(needle, from, true)
        if not start then return n end
        n, from = n + 1, stop + 1
    end
end

--- Manifeste sans ses commentaires Lua (blocs `--[[ … ]]`, puis lignes `-- …`).
local function manifestCode(manifest)
    return (manifest:gsub('%-%-%[(=*)%[.-%]%1%]', ''):gsub('%-%-[^\n]*', ''))
end

--- Motifs livrés par un manifeste : entrées des blocs `files { … }` et des lignes `file '…'`, dans l'ordre.
local function deliveredPatterns(manifest)
    local code, patterns = manifestCode(manifest), {}
    for block in code:gmatch('%f[%w_]files%s*(%b{})') do
        for pattern in block:gmatch('[\'"]([^\'"]+)[\'"]') do patterns[#patterns + 1] = pattern end
    end
    for pattern in code:gmatch('%f[%w_]file%s*%(?%s*[\'"]([^\'"]+)[\'"]') do patterns[#patterns + 1] = pattern end
    return patterns
end

--- Nil si le motif ne peut rien livrer de web/dev/ ; sinon la raison.
local function unsafePattern(pattern)
    if find(pattern, '**') then return '** : ' .. pattern end
    local folders = pattern:match('^(.*)/[^/]*$') or ''
    if folders:find('[%*%?%[]') then return 'joker dans un dossier : ' .. pattern end
    if pattern == 'web/dev' or pattern:sub(1, 8) == 'web/dev/' then return 'web/dev/ livré : ' .. pattern end
    return nil
end

local function withoutCssComments(css)
    return (css:gsub('/%*.-%*/', ''))
end

--- Lignes d'un tableau JS écrit au format fixé : `nom: [`, une chaîne entre apostrophes simples par ligne, `]`.
--- Renvoie les chaînes (apostrophes et barres obliques échappées rendues), ou nil et la raison.
local function stringList(js, name)
    local items, inside = {}, false
    for line in (js:gsub('\r', '') .. '\n'):gmatch('([^\n]*)\n') do
        if not inside then
            if line:match('^%s*' .. name .. '%s*:%s*%[%s*$') then inside = true end
        elseif line:match('^%s*%]%s*,?%s*$') then
            return items
        elseif not (line:match('^%s*$') or line:match('^%s*//')) then
            local value = line:match("^%s*'(.*)'%s*,?%s*$")
            if not value then return nil, name .. ' : ligne hors format : ' .. line end
            items[#items + 1] = (value:gsub('\\(.)', '%1'))
        end
    end
    return nil, name .. ' : tableau introuvable ou non fermé'
end

--- Touches d'un conseil (`[[F1]]`) : liste des touches, ou nil et la raison (crochets non fermés).
local function keysOf(text)
    local keys, from = {}, 1
    while true do
        local open = text:find('[[', from, true)
        if not open then return keys end
        local close = text:find(']]', open + 2, true)
        if not close then return nil, 'crochets non fermés : ' .. text end
        keys[#keys + 1] = text:sub(open + 2, close - 1)
        from = close + 2
    end
end

--- Charge des fichiers Lua du module dans un environnement à part (lecture des globales standard seulement) ; renvoie
--- l'environnement, où ne restent que les globales écrites.
local function loadInEnv(paths, seed)
    local env = setmetatable(seed or {}, { __index = _G })
    for _, path in ipairs(paths) do
        local chunk = assert(loadfile(ROOT .. path, 't', env))
        chunk()
    end
    return setmetatable(env, nil)
end

describe('vava_loading : manifeste', function()
    local manifest = assert(read(BASE .. 'fxmanifest.lua'))
    local code = manifestCode(manifest)
    local pageConfig = assert(read(BASE .. 'web/js/config.js'))
    local musicBlock = pageConfig:match('music%s*:%s*(%b{})') or ''
    local musicFile = musicBlock:match('file%s*:%s*[\'"]([^\'"]*)[\'"]')

    it('déclare la page de chargement, fermée à la main, avec la souris', function()
        assert.truthy(code:find("%f[%w_]loadscreen%s+'web/index%.html'"))
        assert.truthy(code:find("%f[%w_]loadscreen_manual_shutdown%s+'yes'"))
        assert.truthy(code:find("%f[%w_]loadscreen_cursor%s+'yes'"))
    end)

    it('livre exactement ses motifs, sans web/dev, sans page NUI ni script serveur', function()
        assert.is_not_nil(musicFile, 'music.file introuvable dans web/js/config.js')
        local expected = { table.unpack(FILES) }
        if musicFile ~= '' then expected[#expected + 1] = MUSIC_PATTERN end
        assert.same(expected, deliveredPatterns(manifest))
        for _, pattern in ipairs(deliveredPatterns(manifest)) do
            assert.is_nil(unsafePattern(pattern))
        end
        assert.is_nil(find(code, 'web/dev'))   -- le commentaire du manifeste le nomme, le code jamais
        assert.is_nil(code:find('%f[%w_]ui_page%f[^%w_]'))
        assert.is_nil(code:find('server_script'))
        assert.is_nil(code:find('shared_script'))
    end)
end)

describe('vava_loading : polices', function()
    local css = withoutCssComments(assert(read(BASE .. 'web/css/style.css')))

    it('déclare quatre polices présentes, dont trois copies identiques de celles de vava_ui', function()
        local files, seen = {}, {}
        for block in css:gmatch('@font%-face%s*(%b{})') do
            local file = block:match('url%(%s*[\'"]?%.%./fonts/([%w_]+%.woff2)[\'"]?%s*%)')
            assert.is_not_nil(file, block)
            assert.is_not_nil(size(BASE .. 'web/fonts/' .. file), file)
            files[#files + 1] = file
            seen[file] = true
        end
        assert.equal(4, #files)
        for _, file in ipairs(COPIES) do
            assert.is_true(seen[file] == true, file)
            local own, shared = read(BASE .. 'web/fonts/' .. file), read('modules/vava_ui/web/fonts/' .. file)
            assert.is_true(own ~= nil and own == shared, file .. ' : copie différente de vava_ui')
        end
        local decorative = 0
        for file, kind in pairs(DECORATIVE) do
            if seen[file] then
                decorative = decorative + 1
                if kind == 'copy' then
                    local own = read(BASE .. 'web/fonts/' .. file)
                    assert.is_true(own == read('modules/vava_ui/web/fonts/' .. file), file)
                end
            end
        end
        assert.equal(1, decorative)
    end)
end)

describe('vava_loading : poids', function()
    it('livre au plus 300 Ko sans musique (700 Ko avec)', function()
        local css = withoutCssComments(assert(read(BASE .. 'web/css/style.css')))
        local paths = { table.unpack(DELIVERED) }
        for file in css:gmatch('url%(%s*[\'"]?%.%./fonts/([%w_]+%.woff2)[\'"]?%s*%)') do
            paths[#paths + 1] = 'web/fonts/' .. file
        end
        local pageConfig = assert(read(BASE .. 'web/js/config.js'))
        local musicFile = (pageConfig:match('music%s*:%s*(%b{})') or ''):match('file%s*:%s*[\'"]([^\'"]*)[\'"]')
        if musicFile and musicFile ~= '' then paths[#paths + 1] = 'web/audio/' .. musicFile end
        local total = 0
        for _, path in ipairs(paths) do
            local bytes = size(BASE .. path)
            assert.is_not_nil(bytes, path)
            total = total + bytes
        end
        local limit = (musicFile and musicFile ~= '') and MAX_BYTES_MUSIC or MAX_BYTES
        assert.is_true(total <= limit, ('%d octets livrés (> %d)'):format(total, limit))
    end)
end)

describe('vava_loading : page', function()
    local html = assert(read(BASE .. 'web/index.html'))

    it('ne charge que les scripts comptés, dans l\'ordre de la spec, et aucune adresse externe', function()
        local loaded = {}
        for src in html:gmatch('<script[^>]-src%s*=%s*"js/([%w_]+%.js)"') do loaded[#loaded + 1] = src end
        assert.same(SCRIPTS, loaded)
        -- espaces de noms SVG permis (comme l'audit), puis plus aucune adresse
        local clean = html:gsub('xmlns:?%a*%s*=%s*["\']http://www%.w3%.org/[^"\']*["\']', '')
            :gsub('["\']http://www%.w3%.org/2000/svg["\']', '')
        assert.is_nil(clean:find('https?://'))
        assert.is_nil(clean:find('wss?://'))
        assert.is_nil(clean:find('src%s*=%s*["\']?//'))
        assert.is_nil(clean:find('href%s*=%s*["\']?//'))
        assert.is_nil(clean:find('url%(%s*["\']?//'))
    end)

    it('ne charge les données simulées que hors jeu, par la seule ligne file:', function()
        assert.equal(1, count(html, 'devmock'))
        assert.equal(1, count(html, OFFLINE_LINE))
        assert.is_nil(find(html, 'essais'))
    end)

    it('n\'emploie jamais innerHTML', function()
        assert.is_nil(find(html, 'innerHTML'))
        for _, file in ipairs(SCRIPTS) do
            local js = assert(read(BASE .. 'web/js/' .. file), file)
            assert.is_nil(find(js, 'innerHTML'), file)
            assert.is_nil(find(js, 'outerHTML'), file)
            assert.is_nil(find(js, 'insertAdjacentHTML'), file)
        end
    end)
end)

describe('vava_loading : textes (strings.js)', function()
    local js = assert(read(BASE .. 'web/js/strings.js'))

    it('ne contient aucun HTML', function()
        assert.is_nil(find(js, '<'))
    end)

    it('a six étapes', function()
        local stages = js:match('stages%s*:%s*(%b[])')
        assert.is_not_nil(stages)
        local n = 0
        for _ in stages:gmatch('%f[%w_]text%s*:') do n = n + 1 end
        assert.equal(6, n)
    end)

    it('a de 6 à 40 extraits de 240 octets au plus', function()
        local quotes, err = stringList(js, 'quotes')
        assert.is_not_nil(quotes, err)
        assert.is_true(#quotes >= 6 and #quotes <= 40, #quotes .. ' extraits')
        for _, quote in ipairs(quotes) do
            assert.is_true(#quote > 0 and #quote <= 240, quote)
        end
    end)

    it('a de 6 à 20 conseils de 240 octets au plus, au plus trois touches fermées de 12 octets au plus', function()
        local tips, err = stringList(js, 'tips')
        assert.is_not_nil(tips, err)
        assert.is_true(#tips >= 6 and #tips <= 20, #tips .. ' conseils')
        for _, tip in ipairs(tips) do
            assert.is_true(#tip > 0 and #tip <= 240, tip)
            local keys, reason = keysOf(tip)
            assert.is_not_nil(keys, reason)
            assert.is_true(#keys <= 3, tip)
            for _, key in ipairs(keys) do
                assert.is_true(#key > 0 and #key <= 12, key)
            end
        end
    end)

    it('lit le format fixé et repère les touches mal écrites', function()
        local sample = "x = {\n  tips: [\n    'Un \\'mot\\' [[F1]] et [[I]]',\n    // note\n    'b',\n  ],\n}\n"
        assert.same({ "Un 'mot' [[F1]] et [[I]]", 'b' }, (stringList(sample, 'tips')))
        assert.is_nil((stringList("tips: [\n  \"double\",\n]\n", 'tips')))
        assert.is_nil((stringList("tips: [\n  'a',\n", 'tips')))
        assert.same({ 'F1', 'I' }, keysOf('[[F1]] puis [[I]]'))
        assert.is_nil((keysOf('[[F1 sans fin')))
    end)
end)

describe('vava_loading : réglages de la page (config.js)', function()
    local js = assert(read(BASE .. 'web/js/config.js'))

    it('a le journal de calibrage coupé', function()
        local block = js:match('debug%s*:%s*(%b{})')
        assert.is_not_nil(block)
        assert.truthy(block:find('journal%s*:%s*false'))
    end)

    it('a six seuils entiers croissants de 0 à 99', function()
        local list = js:match('stages%s*:%s*%[([^%]]*)%]')
        assert.is_not_nil(list)
        local values = {}
        for value in list:gmatch('[^,%s]+') do values[#values + 1] = value end
        assert.equal(6, #values)
        local previous = -1
        for i, text in ipairs(values) do
            assert.truthy(text:match('^%d+$'), text)
            local value = tonumber(text)
            if i == 1 then assert.equal(0, value) end
            assert.is_true(value > previous and value <= 99, text)
            previous = value
        end
    end)
end)

describe('vava_loading : client Lua', function()
    local env = loadInEnv({ BASE .. 'shared/constants.lua', BASE .. 'config.lua' })
    local loading = env.VavaLoading
    local cfg = loading.config

    it('ne crée que sa table VavaLoading', function()
        local names = {}
        for name in pairs(env) do names[#names + 1] = name end
        assert.same({ 'VavaLoading' }, names)
    end)

    it('a des réglages dans leurs bornes', function()
        assert.equal('integer', math.type(cfg.handoffMs))
        assert.is_true(cfg.handoffMs >= loading.HANDOFF_MIN_MS and cfg.handoffMs <= loading.HANDOFF_MAX_MS)
        assert.equal(300, loading.HANDOFF_MIN_MS)
        assert.equal(5000, loading.HANDOFF_MAX_MS)
        -- au-delà du délai des RPC du core (10 s) : la liste des personnages peut attendre jusque-là
        assert.is_true(type(cfg.selectionFallbackMs) == 'number' and cfg.selectionFallbackMs > 10000)
        assert.is_true(type(cfg.noCorePollMs) == 'number' and cfg.noCorePollMs > 0)
        for _, value in ipairs({ cfg.coreVersion, cfg.selection.resource, cfg.selection.shownHook,
            cfg.selection.isShownExport }) do
            assert.is_true(type(value) == 'string' and value ~= '', tostring(value))
        end
        assert.truthy(cfg.coreVersion:match('^%d+%.%d+%.%d+$'))
        -- le hook attendu appartient à la ressource de sélection (le core refuse un hook hors de son espace de noms)
        assert.equal(cfg.selection.resource .. ':', cfg.selection.shownHook:sub(1, #cfg.selection.resource + 1))
        for _, name in pairs(loading.MESSAGES) do
            assert.truthy(name:match('^vava_loading:%a+$'), name)
        end
    end)

    it('laisse au filet du core le temps de celui de vava_loading et de l\'éclair', function()
        local core = loadInEnv({ 'config/shared.lua' }, { vAvA = { config = {} } })
        local screen = core.vAvA.config.shared.spawn.loadingScreen
        assert.equal('vava_loading', screen.resource)
        assert.is_true(screen.maxHoldMs > cfg.selectionFallbackMs + loading.HANDOFF_MAX_MS)
    end)

    it('borne une durée en entier, avec un repli pour ce qui n\'est pas un nombre fini', function()
        local clamp = loading.clamp
        assert.equal(1800, clamp(1800, 300, 5000, 1))
        assert.equal(300, clamp(10, 300, 5000, 1))
        assert.equal(5000, clamp(1e9, 300, 5000, 1))
        assert.equal(1234, clamp(1234.9, 300, 5000, 1))
        assert.equal('integer', math.type(clamp(1234.9, 300, 5000, 1)))
        assert.equal(1, clamp(0 / 0, 300, 5000, 1))
        assert.equal(1, clamp(math.huge, 300, 5000, 1))
        assert.equal(1, clamp(-math.huge, 300, 5000, 1))
        assert.equal(1, clamp('1800', 300, 5000, 1))
        assert.equal(1, clamp(nil, 300, 5000, 1))
    end)

    it('compare des versions MAJEUR.MINEUR.CORRECTIF', function()
        local atLeast = loading.versionAtLeast
        assert.is_true(atLeast('0.13.0', '0.13.0'))
        assert.is_true(atLeast('0.13.1', '0.13.0'))
        assert.is_true(atLeast('1.0.0', '0.13.0'))
        assert.is_true(atLeast('0.20.0', '0.13.0'))
        assert.is_false(atLeast('0.12.9', '0.13.0'))
        assert.is_false(atLeast('0.9.0', '0.13.0'))
        assert.is_false(atLeast(nil, '0.13.0'))
        assert.is_false(atLeast('0.13', '0.13.0'))
        assert.is_false(atLeast('0.13.0-beta', '0.13.0'))
        assert.is_false(atLeast('0.13.0', nil))
    end)
end)
