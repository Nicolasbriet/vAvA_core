-- Fichiers web communs (T-012) : vava_ui tient seul les polices, textures et ornements des interfaces ; chaque page
-- basculée les prend par nui://vava_ui/, ne livre plus ses copies ni ses données simulées (web/dev/devmock.js).
-- Fichiers lus depuis VAVA_ROOT (ou le dossier courant), comme examples_guard_spec.lua.

local ROOT = (os.getenv('VAVA_ROOT') or '.') .. '/'

-- Pages basculées sur vava_ui, avec le nom de leur feuille. Une page s'ajoute ici le jour de sa bascule (T-012,
-- étapes 4 à 17) ; à la fin de T-012, les 15 interfaces y sont.
local PAGES = {
    { module = 'vava_hud', sheet = 'style.css' },
}

local COMMON = {
    'web/fonts/cinzel.woff2', 'web/fonts/eb_garamond.woff2', 'web/fonts/eb_garamond_italic.woff2',
    'web/fonts/cinzel_decorative_400.woff2', 'web/fonts/cinzel_decorative_700.woff2',
    'web/img/grain.png', 'web/img/paper.png', 'web/img/frame.svg', 'web/img/divider.svg', 'web/img/diamond.svg',
}

local function read(path)
    local file = io.open(ROOT .. path, 'rb')
    if not file then return nil end
    local text = file:read('a')
    file:close()
    return text
end

local function exists(path)
    local file = io.open(ROOT .. path, 'rb')
    if file then file:close() end
    return file ~= nil
end

local function find(text, needle)
    return text:find(needle, 1, true)
end

--- Vrai si le manifeste déclare `name` en dépendance (`dependency 'x'` ou dans `dependencies { … }`).
local function declaresDependency(manifest, name)
    for value in manifest:gmatch('dependency%s*%(?%s*[\'"]([%w_]+)[\'"]') do
        if value == name then return true end
    end
    for block in manifest:gmatch('dependencies%s*(%b{})') do
        if block:find('[\'"]' .. name .. '[\'"]') then return true end
    end
    return false
end

local function withoutComments(css)
    return (css:gsub('/%*.-%*/', ''))
end

describe('vava_ui', function()
    local manifest = assert(read('modules/vava_ui/fxmanifest.lua'))
    local sheet = withoutComments(assert(read('modules/vava_ui/web/css/vava_ui.css')))
    local offline = assert(read('modules/vava_ui/web/dev/horsjeu.js'))

    it('ne livre ni ses outils hors jeu ni aucun script', function()
        assert.is_nil(find(manifest, 'web/dev'))
        assert.is_nil(manifest:find('_scripts?%s*[{(\'"]'))
        for _, pattern in ipairs({ "'web/css/vava_ui.css'", "'web/fonts/*.woff2'", "'web/img/*.webp'", "'web/img/*.svg'" }) do
            assert.truthy(find(manifest, pattern), pattern)
        end
    end)

    it('déclare cinq polices, chacune présente', function()
        local count = 0
        for block in sheet:gmatch('@font%-face%s*(%b{})') do
            count = count + 1
            local file = block:match('url%("%.%./fonts/([%w_]+%.woff2)"%)')
            assert.is_not_nil(file, block)
            assert.is_true(exists('modules/vava_ui/web/fonts/' .. file), file)
        end
        assert.equal(5, count)
    end)

    it('tient ses jetons d\'image et ceux de horsjeu.js identiques, chaque fichier présent', function()
        local tokens, count = {}, 0
        for name, path in sheet:gmatch('(%-%-ui%-[%w-]+):%s*url%("nui://vava_ui/([^"]+)"%)') do
            assert.is_true(exists('modules/vava_ui/' .. path), path)
            tokens[name] = path
            count = count + 1
        end
        assert.is_true(count >= 5)
        local seen = 0
        for name, path in offline:gmatch('\'(%-%-ui%-[%w-]+)\':%s*\'([^\']+)\'') do
            assert.equal(tokens[name], path, name)
            seen = seen + 1
        end
        assert.equal(count, seen)
    end)

    it('ne contient que @font-face et :root (aucune règle d\'élément ni de classe)', function()
        local rules = 0
        for selector in sheet:gmatch('([^{}]*)%b{}') do
            selector = selector:match('^%s*(.-)%s*$')
            assert.is_true(selector == ':root' or selector == '@font-face', selector)
            rules = rules + 1
        end
        assert.equal(6, rules)
    end)
end)

for _, page in ipairs(PAGES) do
    local base = 'modules/' .. page.module .. '/'
    describe(page.module .. ' (page basculée sur vava_ui)', function()
        local manifest = assert(read(base .. 'fxmanifest.lua'))
        local html = assert(read(base .. 'web/index.html'))
        local css = assert(read(base .. 'web/css/' .. page.sheet))

        it('déclare vava_ui en dépendance et ne livre ni polices ni données simulées', function()
            assert.is_true(declaresDependency(manifest, 'vava_ui'))
            assert.is_nil(find(manifest, 'web/fonts'))
            assert.is_nil(find(manifest, 'web/dev'))
        end)

        it('lie la feuille commune avant la sienne, et ne charge les données simulées que hors jeu', function()
            local common = find(html, 'href="nui://vava_ui/web/css/vava_ui.css"')
            local own = find(html, 'href="css/')
            assert.is_not_nil(common)
            assert.is_not_nil(own)
            assert.is_true(common < own)
            local line = html:match('<script>(typeof GetParentResourceName === \'function\' ||[^\n]*)</script>')
            assert.is_not_nil(line)
            assert.truthy(find(line, '../../vava_ui/web/dev/horsjeu.js'))
            assert.truthy(find(line, 'dev/devmock.js'))
            assert.is_nil(find(html, 'src="js/devmock.js"'))
        end)

        it('a ses données simulées dans web/dev/ et plus aucune copie commune', function()
            assert.is_false(exists(base .. 'web/js/devmock.js'))
            assert.is_true(exists(base .. 'web/dev/devmock.js'))
            for _, file in ipairs(COMMON) do
                assert.is_false(exists(base .. file), file)
            end
        end)

        it('prend polices et images dans vava_ui, toujours avec un repli', function()
            assert.is_nil(find(css, '@font-face'))
            for _, name in ipairs({ 'grain.png', 'paper.png', 'frame.svg', 'divider.svg', 'diamond.svg' }) do
                assert.is_nil(find(css, name), name)
            end
            local uses = 0
            for token in css:gmatch('var%((%-%-ui%-[%w-]+)') do
                uses = uses + 1
                assert.truthy(css:find('var%(' .. token:gsub('%-', '%%-') .. ',%s*none%)'), token)
            end
            for _ in css:gmatch('var%(%-%-ui%-[%w-]+%)') do
                error('jeton --ui- employé sans repli')
            end
            assert.is_true(uses > 0)
        end)
    end)
end
