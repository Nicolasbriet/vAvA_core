local helper = require('tests.helper')

-- Configs partagées (T-132, docs/plan/specs/T-132.md § 2.4 et § 3.4) : un joueur ne télécharge que ce que son client
-- lit. `config.lua` (réglages du seul serveur) est en tête des server_scripts ; `config_client.lua` (réglages lus par
-- le client) est partagé, ouvre la table, et config.lua la complète sans réécrire une de ses clés ; la logique de
-- shared/ n'est partagée que si un fichier client s'en sert. Fichiers lus depuis VAVA_ROOT (ou le dossier courant).
--
-- T0 forme du manifeste · T1 aucune valeur écrite deux fois · T2 le client ne lit que sa part · T3 logique au bon
-- endroit. T2 (lecture statique) suit les alias `local a, b <const> = <Global>.config.x, cfg.y` (sur une ligne) et
-- ferme par défaut : toute table de config utilisée autrement que par `.clé` — indexée par une variable, passée à une
-- fonction, parcourue, rangée ailleurs, alias non suivi (`local c = cfg or {}`) — doit être ENTIÈRE dans la vue client
-- (relecture réseau R-1 et R-2). Une clé absente des deux vues (facultative) est ignorée.

local ROOT = (os.getenv('VAVA_ROOT') or '.') .. '/'

-- Les 30 ressources de modules/ et examples/ qui ont du Lua (toutes sauf vava_ui), avec leur table de module.
local MODULES = {
    { dir = 'modules/vava_admin', global = 'VavaAdmin' },
    { dir = 'modules/vava_appearance', global = 'VavaAppearance' },
    { dir = 'modules/vava_arrival', global = 'VavaArrival' },
    { dir = 'modules/vava_atelier', global = 'VavaAtelier' },
    { dir = 'modules/vava_cameras', global = 'VavaCameras' },
    { dir = 'modules/vava_chancellerie', global = 'VavaBridge' },
    { dir = 'modules/vava_characters_ui', global = 'VavaCharactersUi' },
    { dir = 'modules/vava_chat', global = 'VavaChat' },
    { dir = 'modules/vava_codex', global = 'VavaCodex' },
    { dir = 'modules/vava_combat', global = 'VavaCombat' },
    { dir = 'modules/vava_crafting', global = 'VavaCrafting' },
    { dir = 'modules/vava_farming', global = 'VavaFarming' },
    { dir = 'modules/vava_gathering', global = 'VavaGathering' },
    { dir = 'modules/vava_health', global = 'VavaHealth' },
    { dir = 'modules/vava_hud', global = 'VavaHud' },
    { dir = 'modules/vava_inventory', global = 'VavaInventory' },
    { dir = 'modules/vava_loading', global = 'VavaLoading' },
    { dir = 'modules/vava_magic', global = 'VavaMagic' },
    { dir = 'modules/vava_needs', global = 'VavaNeeds' },
    { dir = 'modules/vava_provisions', global = 'VavaProvisions' },
    { dir = 'modules/vava_skills', global = 'VavaSkills' },
    { dir = 'modules/vava_time', global = 'VavaTime' },
    { dir = 'modules/vava_voice', global = 'VavaVoice' },
    { dir = 'modules/vava_world', global = 'VavaWorld' },
    { dir = 'examples/vava_anim_test', global = 'VavaAnimTest' },
    { dir = 'examples/vava_dev_characters', global = 'VavaDevCharacters' },
    { dir = 'examples/vava_example', global = 'VavaExample' },
    { dir = 'examples/vava_example_atelier', global = 'VavaExampleAtelier' },
    { dir = 'examples/vava_example_combat', global = 'VavaExampleCombat' },
    { dir = 'examples/vava_example_items', global = 'VavaExampleItems' },
}
-- Ressources sans Lua : aucun script, rien à découper.
local WITHOUT_LUA = { ['modules/vava_ui'] = true }

-- Modules pas encore basculés (lots 2 à 4 de T-132), sautés par T0 à T3 ; chaque lot retire les siens, avec leurs
-- exceptions transitoires de scripts/audit-exceptions.txt.
local PENDING = {
    vava_provisions = 'T-141',
    vava_inventory = 'T-142', vava_combat = 'T-142', vava_health = 'T-142', vava_time = 'T-142', vava_codex = 'T-142',
    vava_admin = 'T-142', vava_voice = 'T-142', vava_chat = 'T-142', vava_cameras = 'T-142',
    vava_appearance = 'T-142', vava_needs = 'T-142', vava_world = 'T-142', vava_hud = 'T-142', vava_loading = 'T-142',
    vava_characters_ui = 'T-142', vava_anim_test = 'T-142', vava_dev_characters = 'T-142',
    vava_example_combat = 'T-142',
    vava_magic = 'T-143',
}

local SCRIPT_LISTS = {
    shared_script = 'shared', shared_scripts = 'shared',
    client_script = 'client', client_scripts = 'client',
    server_script = 'server', server_scripts = 'server',
}

local function read(path)
    local file = io.open(ROOT .. path, 'rb')
    if not file then return nil end
    local text = file:read('a')
    file:close()
    return (text:gsub('\r\n', '\n'))
end

local function exists(path)
    local file = io.open(ROOT .. path, 'rb')
    if file then file:close() end
    return file ~= nil
end

local function blanks(text)
    return (text:gsub('[^\n]', ' '))
end

--- Code Lua sans ses commentaires (remplacés par des espaces, lignes gardées) ; `dropStrings` vide aussi le contenu
--- des chaînes (guillemets gardés).
---@param src string
---@param dropStrings boolean|nil
---@return string code
local function strip(src, dropStrings)
    local out = {}
    local i, n = 1, #src
    local function push(text) out[#out + 1] = text end
    while i <= n do
        local c = src:sub(i, i)
        if c == '-' and src:sub(i + 1, i + 1) == '-' then
            local eq = src:match('^%[(=*)%[', i + 2)
            if eq then
                local close = ']' .. eq .. ']'
                local stop = src:find(close, i + 2 + #eq + 2, true)
                local last = stop and stop + #close - 1 or n
                push(blanks(src:sub(i, last)))
                i = last + 1
            else
                local stop = src:find('\n', i, true) or (n + 1)
                push(blanks(src:sub(i, stop - 1)))
                i = stop
            end
        elseif c == '[' and src:match('^%[=*%[', i) then
            local eq = src:match('^%[(=*)%[', i)
            local open = 2 + #eq
            local close = ']' .. eq .. ']'
            local stop = src:find(close, i + open, true)
            local last = stop and stop + #close - 1 or n
            if dropStrings then push(src:sub(i, i + open - 1) .. blanks(src:sub(i + open, last - #close)) .. close)
            else push(src:sub(i, last)) end
            i = last + 1
        elseif c == '"' or c == "'" then
            local j = i + 1
            while j <= n do
                local d = src:sub(j, j)
                if d == '\\' then j = j + 2
                elseif d == c or d == '\n' then break
                else j = j + 1 end
            end
            if dropStrings then push(c .. string.rep(' ', j - i - 1) .. c) else push(src:sub(i, j)) end
            i = j + 1
        else
            local stop = src:find('[%-%[\'"]', i) or (n + 1)
            if stop == i then stop = i + 1 end
            push(src:sub(i, stop - 1))
            i = stop
        end
    end
    return table.concat(out)
end

--- Chaînes des listes de scripts d'un manifeste : { shared = {…}, client = {…}, server = {…}, wild = {…} } (entrées
--- `@ressource/…` sautées ; `wild` : chaînes à joker, refusées dans une liste de scripts).
---@param manifest string
local function parseManifest(manifest)
    local code = strip(manifest)
    local lists = { shared = {}, client = {}, server = {}, wild = {} }
    local i, n = 1, #code
    local function readString(at)
        local q = code:sub(at, at)
        if q == '"' or q == "'" then
            local stop = at + 1
            while stop <= #code and code:sub(stop, stop) ~= q do
                stop = stop + (code:sub(stop, stop) == '\\' and 2 or 1)
            end
            return code:sub(at + 1, stop - 1), stop + 1
        end
        local eq = code:match('^%[(=*)%[', at)
        if eq then
            local close = ']' .. eq .. ']'
            local stop = code:find(close, at, true)
            return code:sub(at + #eq + 2, stop - 1), stop + #close
        end
    end
    local function add(side, value)
        value = value:gsub('\\', '/'):gsub('^%./', '')
        if value:sub(1, 1) == '@' then return end
        if value:find('[%*%?%[]') then lists.wild[#lists.wild + 1] = value end
        local list = lists[side]
        list[#list + 1] = value
    end
    while i <= n do
        local s = code:find('[A-Za-z_\'"%[]', i)
        if not s then break end
        local c0 = code:sub(s, s)
        local word, e
        if c0 == '"' or c0 == "'" or (c0 == '[' and code:match('^%[=*%[', s)) then
            local _, after = readString(s)      -- chaîne hors d'une liste suivie : sautée
            i = after
        elseif c0 == '[' then
            i = s + 1
        else
            s, e, word = code:find('^([A-Za-z_][A-Za-z0-9_]*)', s)
            i = e + 1
        end
        local side = word and SCRIPT_LISTS[word]
        if side and (s == 1 or not code:sub(s - 1, s - 1):match('[A-Za-z0-9_.:]')) then
            local at = code:find('[^%s%(]', i)
            if at then
                local c = code:sub(at, at)
                if c == '{' then
                    local depth, j = 1, at + 1
                    while j <= n and depth > 0 do
                        local d = code:sub(j, j)
                        if d == '{' then depth = depth + 1; j = j + 1
                        elseif d == '}' then depth = depth - 1; j = j + 1
                        elseif d == '"' or d == "'" or (d == '[' and code:match('^%[=*%[', j)) then
                            local value, after = readString(j)
                            add(side, value)
                            j = after
                        else j = j + 1 end
                    end
                    i = j
                elseif c == '"' or c == "'" or (c == '[' and code:match('^%[=*%[', at)) then
                    local value, after = readString(at)
                    add(side, value)
                    i = after
                end
            end
        end
    end
    return lists
end

local function indexOf(list, value)
    for i, v in ipairs(list) do if v == value then return i end end
    return nil
end

local function deepCopy(value)
    if type(value) ~= 'table' then return value end
    local copy = {}
    for k, v in pairs(value) do copy[k] = deepCopy(v) end
    return copy
end

local function run(path)
    local chunk, err = loadfile(ROOT .. path)
    if not chunk then error(err, 2) end
    chunk()
end

--- Charge les constantes, puis config_client.lua (s'il existe) et rend la vue client (copie), puis config.lua (s'il
--- existe) sous garde : toute écriture d'une clé déjà posée par config_client.lua est relevée. Rend la vue client,
--- la vue complète, les réécritures et vrai si config.lua a remplacé la table.
local function loadViews(mod)
    helper.reset()
    _G[mod.global] = nil
    if exists(mod.dir .. '/shared/constants.lua') then run(mod.dir .. '/shared/constants.lua') end
    local hasClient, hasServer = exists(mod.dir .. '/config_client.lua'), exists(mod.dir .. '/config.lua')
    if hasClient then run(mod.dir .. '/config_client.lua') end
    local root = _G[mod.global]
    local opened = root and root.config
    local clientView = deepCopy(opened)
    local rewrites, guarded = {}, {}
    -- garde : chaque table posée par config_client.lua est vidée dans une ombre, lue et complétée par métatable
    local function guard(t, path)
        local shadow = {}
        for k, v in pairs(t) do shadow[k] = v end
        for k in pairs(shadow) do rawset(t, k, nil) end
        guarded[#guarded + 1] = { t = t, shadow = shadow }
        setmetatable(t, {
            __index = shadow,
            __newindex = function(_, k, v)
                if shadow[k] ~= nil then rewrites[#rewrites + 1] = path .. '.' .. tostring(k) end
                shadow[k] = v
            end,
            __pairs = function() return next, shadow, nil end,
        })
        for k, v in pairs(shadow) do
            if type(v) == 'table' then guard(v, path .. '.' .. tostring(k)) end
        end
    end
    if type(opened) == 'table' and hasServer then guard(opened, 'config') end
    if hasServer then run(mod.dir .. '/config.lua') end
    for i = #guarded, 1, -1 do
        local g = guarded[i]
        setmetatable(g.t, nil)
        for k, v in pairs(g.shadow) do rawset(g.t, k, v) end
    end
    root = _G[mod.global]
    local full = root and root.config
    local replaced = opened ~= nil and not rawequal(opened, full)
    _G[mod.global] = nil
    return clientView, full, rewrites, replaced
end

--- Chemins des feuilles et des tables de `view` : « a.b.c » → valeur.
local function paths(view, prefix, out)
    out = out or {}
    for k, v in pairs(view) do
        local path = prefix .. '.' .. tostring(k)
        out[#out + 1] = { path = path, value = v }
        if type(v) == 'table' then paths(v, path, out) end
    end
    return out
end

local function at(view, path)
    local value = view
    for key in path:gmatch('[^.]+') do
        if type(value) ~= 'table' then return nil end
        local num = tonumber(key)
        value = value[key] ~= nil and value[key] or (num and value[num])
    end
    return value
end

--- Fichiers servis au client par le manifeste : client_scripts, et shared/*.lua de shared_scripts (hors constantes et
--- config_client.lua).
local function clientFiles(lists)
    local files = {}
    for _, f in ipairs(lists.client) do
        if f:match('%.lua$') and f ~= 'config_client.lua' then files[#files + 1] = f end
    end
    for _, f in ipairs(lists.shared) do
        if f:match('^shared/.+%.lua$') and f ~= 'shared/constants.lua' then files[#files + 1] = f end
    end
    return files
end

local function escape(text)
    return (text:gsub('[%^%$%(%)%%%.%[%]%*%+%-%?]', '%%%0'))
end

--- Coupe une liste d'expressions aux virgules de premier niveau (hors parenthèses, accolades, crochets).
local function splitTop(text)
    local parts, depth, start = {}, 0, 1
    for i = 1, #text do
        local c = text:sub(i, i)
        if c == '(' or c == '{' or c == '[' then depth = depth + 1
        elseif c == ')' or c == '}' or c == ']' then depth = depth - 1
        elseif c == ',' and depth == 0 then
            parts[#parts + 1] = text:sub(start, i - 1)
            start = i + 1
        end
    end
    parts[#parts + 1] = text:sub(start)
    return parts
end

local function trim(text)
    return (text:gsub('^%s+', ''):gsub('%s+$', ''))
end

--- Références à la config d'un fichier client (code sans commentaires ni contenu de chaînes) : liste de
--- { line, chain = { 'texts', 'refused' }, pure } — `pure` : l'expression entière d'un alias suivi
--- (`local texts = cfg.texts`), dont la table n'a pas à être entière côté client.
local function configReads(code, global)
    local reads = {}
    local lines = {}
    for l in (code .. '\n'):gmatch('([^\n]*)\n') do lines[#lines + 1] = l end
    local base = escape(global) .. '%.config'
    -- alias : `local a, b <const> = <global>.config[.x], cfg.y[.z], cfg` (une ligne), jusqu'au point fixe
    local aliases = {}   -- nom → chemin de base (liste)
    local pure = {}      -- ligne → { [expression] = true }
    local function aliasOf(expr)
        local rest = expr:match('^' .. base .. '([A-Za-z0-9_.]*)$')
        local from = {}
        if not rest then
            local head
            head, rest = expr:match('^([A-Za-z_][A-Za-z0-9_]*)([A-Za-z0-9_.]*)$')
            from = head and aliases[head]
            if not from then return nil end
        end
        if rest ~= '' and not rest:match('^%.[A-Za-z_]') then return nil end
        local chain = {}
        for _, k in ipairs(from) do chain[#chain + 1] = k end
        for k in rest:gmatch('[A-Za-z0-9_]+') do chain[#chain + 1] = k end
        return chain
    end
    local changed = true
    while changed do
        changed = false
        for lineNo, l in ipairs(lines) do
            local names, exprs = l:match('^%s*local%s+([A-Za-z0-9_,%s<>]+)=%s*([^=].*)$')
            if names and not names:match('^function') then
                local nameList, exprList = {}, splitTop(exprs)
                for n in names:gmatch('[^,]+') do
                    nameList[#nameList + 1] = n:match('^%s*([A-Za-z_][A-Za-z0-9_]*)%s*<?%a*>?%s*$')
                end
                for i, name in ipairs(nameList) do
                    local expr = exprList[i] and trim(exprList[i])
                    local chain = expr and aliasOf(expr)
                    if chain then
                        pure[lineNo] = pure[lineNo] or {}
                        pure[lineNo][expr] = true
                        if name and not aliases[name] then
                            aliases[name] = chain
                            changed = true
                        end
                    end
                end
            end
        end
    end
    -- référence `<tête>.k1.k2…` (tête : <global>.config ou un alias, pas précédée d'un nom, d'un point ni de deux-points ;
    -- `self.cfg.x` n'est pas l'alias `cfg`) ; la chaîne s'arrête à `[`, `(`, `:` ou tout autre signe
    local function scan(lineNo, l, head, prefix)
        -- les noms déclarés (`local a, b = …`, avant le `=`) ne sont pas des lectures
        local declared = l:match('^(%s*local%s+[A-Za-z0-9_,%s<>]+)=[^=]')
        local pos = declared and #declared + 1 or 1
        while true do
            local s, e, tail = l:find(head .. '([A-Za-z0-9_.]*)', pos)
            if not s then break end
            pos = e + 1
            local before = s > 1 and l:sub(s - 1, s - 1) or ''
            if not before:match('[A-Za-z0-9_.:]') and (tail == '' or tail:sub(1, 1) == '.') then
                tail = tail:gsub('%.$', '')
                local chain = {}
                for _, k in ipairs(prefix) do chain[#chain + 1] = k end
                for k in tail:gmatch('[A-Za-z0-9_]+') do chain[#chain + 1] = k end
                local text = trim(l:sub(s, e))
                reads[#reads + 1] = { line = lineNo, chain = chain, pure = pure[lineNo] and pure[lineNo][text] or false }
            end
        end
    end
    for lineNo, l in ipairs(lines) do
        scan(lineNo, l, base, {})
        for name, chain in pairs(aliases) do scan(lineNo, l, '%f[A-Za-z0-9_]' .. escape(name), chain) end
    end
    return reads
end

local function deepEqual(a, b)
    if type(a) ~= 'table' or type(b) ~= 'table' then return a == b end
    for k, v in pairs(a) do if not deepEqual(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

--- T2 pour un fichier : nil, ou le premier manquement. `full` : vue complète ; `client` : vue client.
local function checkReads(file, code, global, full, client)
    for _, r in ipairs(configReads(code, global)) do
        local f, c, path = full, client, 'config'
        local broken = false
        for _, key in ipairs(r.chain) do
            if type(f) ~= 'table' then broken = true break end
            f = f[key]
            if type(c) == 'table' then c = c[key] else c = nil end
            path = path .. '.' .. key
            if f == nil then broken = true break end
            if c == nil then
                return ('%s:%d lit config.%s (%s), que seul config.lua définit'):format(file, r.line,
                    table.concat(r.chain, '.'), path)
            end
        end
        if not broken and type(f) == 'table' and not r.pure and not deepEqual(f, c) then
            return ('%s:%d utilise la table %s entière (indexée par une variable, passée, parcourue ou alias non '
                .. 'suivi) : elle doit être entière dans config_client.lua'):format(file, r.line, path)
        end
    end
    return nil
end

--- Champs exportés par un fichier : `^Global.champ =` ou `^function Global.champ`.
local function exports(code, global)
    local fields = {}
    local g = escape(global)
    for l in (code .. '\n'):gmatch('([^\n]*)\n') do
        local field = l:match('^' .. g .. '%.([A-Za-z_][A-Za-z0-9_]*)%s*=') or l:match('^function%s+' .. g
            .. '%.([A-Za-z_][A-Za-z0-9_]*)')
        if field then fields[field] = true end
    end
    return fields
end

local function cites(code, global, field)
    return code:find(escape(global) .. '%.' .. field .. '%f[^A-Za-z0-9_]') ~= nil
end

describe('configs partagées (T-132)', function()
    -- relectures S-3 et R-5 : les exceptions transitoires de l'audit et PENDING désignent les mêmes ressources, et une
    -- exception qui ne couvre plus rien (manifeste déjà basculé) est signalée
    it('exceptions « T-132 » de scripts/audit-exceptions.txt = PENDING, aucune morte', function()
        local text = read('scripts/audit-exceptions.txt')
        assert(text, 'scripts/audit-exceptions.txt introuvable')
        local excepted = {}
        for line in (text .. '\n'):gmatch('([^\n]*)\n') do
            local path, extract, reason = line:match('^([^\t#][^\t]*)\t([^\t]*)\t(.*)$')
            if path and reason:match('^T%-132') then
                local name = path:match('^[a-z]+/([^/]+)/fxmanifest%.lua$')
                assert(name, 'exception T-132 hors d\'un manifeste : ' .. path)
                assert.is_nil(excepted[name], 'deux exceptions T-132 pour ' .. name)
                excepted[name] = true
                local manifest = read(path)
                assert(manifest, 'exception T-132 morte : ' .. path .. ' introuvable')
                assert(manifest:find(extract, 1, true), 'exception T-132 morte : extrait absent de ' .. path)
                local lists = parseManifest(manifest)
                assert(indexOf(lists.shared, 'config.lua') or indexOf(lists.client, 'config.lua'),
                    'exception T-132 morte : ' .. path .. ' ne sert plus config.lua (retirer l\'exception et PENDING)')
            end
        end
        for name in pairs(PENDING) do
            assert(excepted[name], name .. ' est dans PENDING sans exception T-132 dans scripts/audit-exceptions.txt')
        end
        for name in pairs(excepted) do
            assert(PENDING[name], name .. ' a une exception T-132 sans être dans PENDING')
        end
    end)

    it('la liste des ressources est complète (git ls-files)', function()
        local pipe = io.popen and io.popen('git -C "' .. ROOT .. '" ls-files -- "modules/*/fxmanifest.lua" '
            .. '"examples/*/fxmanifest.lua" 2>&1')
        local listed = pipe and pipe:read('a') or ''
        if pipe then pipe:close() end
        if not listed:find('fxmanifest.lua', 1, true) then
            pending('git ls-files indisponible')
            return
        end
        local known = {}
        for _, mod in ipairs(MODULES) do known[mod.dir] = true end
        for dir in listed:gmatch('([^\n]+)/fxmanifest%.lua') do
            assert(known[dir] or WITHOUT_LUA[dir], dir .. ' manque à MODULES de config_split_spec.lua')
        end
    end)

    for _, mod in ipairs(MODULES) do
        local name = mod.dir:match('[^/]+$')

        if PENDING[name] then
            it(name .. ' : pas encore basculé', function() pending(PENDING[name] .. ' (lot de T-132)') end)
        else describe(name, function()
            local manifest = read(mod.dir .. '/fxmanifest.lua')
            local lists = manifest and parseManifest(manifest) or { shared = {}, client = {}, server = {}, wild = {} }
            local hasClient, hasServer = exists(mod.dir .. '/config_client.lua'), exists(mod.dir .. '/config.lua')

            it('T0 : listes de scripts explicites, config_client.lua partagé, config.lua en tête des server_scripts',
                function()
                    assert(manifest, mod.dir .. '/fxmanifest.lua introuvable')
                    assert.same({}, lists.wild, 'liste explicite attendue (aucun joker dans les scripts)')
                    if hasClient then
                        local side = #lists.server > 0 and 'shared' or 'client'
                        assert(indexOf(lists[side], 'config_client.lua'), 'config_client.lua attendu en ' .. side
                            .. '_scripts')
                        assert.is_nil(indexOf(lists.server, 'config_client.lua'), 'config_client.lua servi au seul serveur')
                    end
                    if hasServer then
                        assert.is_nil(indexOf(lists.shared, 'config.lua'), 'config.lua servi aux joueurs (shared_scripts)')
                        assert.is_nil(indexOf(lists.client, 'config.lua'), 'config.lua servi aux joueurs (client_scripts)')
                        local i = indexOf(lists.server, 'config.lua')
                        assert(i, 'config.lua attendu en server_scripts')
                        for j = 1, i - 1 do
                            assert.equal('shared/constants.lua', lists.server[j],
                                'config.lua attendu en tête des server_scripts (seules les constantes avant lui)')
                        end
                    end
                    if hasClient and hasServer then
                        local clientView = loadViews(mod)
                        assert.is_true(clientView.clientFile, 'config_client.lua doit poser clientFile = true (R7)')
                        local found = false
                        for _, f in ipairs(lists.server) do
                            if f:match('^server/') and (read(mod.dir .. '/' .. f) or ''):find('clientFile', 1, true) then
                                found = true
                            end
                        end
                        assert(found, 'aucun fichier de server/ ne vérifie clientFile (R7)')
                    end
                end)

            it('T1 : aucune valeur écrite deux fois (config.lua complète config_client.lua)', function()
                if not (hasClient and hasServer) then return end
                local clientView, full, rewrites, replaced = loadViews(mod)
                assert.is_false(replaced, 'config.lua remplace la table ouverte par config_client.lua')
                table.sort(rewrites)
                for _, path in ipairs(rewrites) do
                    error(('config.lua réécrit %s, déjà dans config_client.lua'):format(path))
                end
                for _, entry in ipairs(paths(clientView, 'config')) do
                    local value = at(full, entry.path:sub(#'config.' + 1))
                    if type(entry.value) == 'table' then
                        assert.equal('table', type(value), entry.path .. ' : table attendue')
                    else
                        assert.equal(entry.value, value, entry.path)
                    end
                end
            end)

            it('T2 : le client ne lit que sa part de la config', function()
                local clientView, full = loadViews(mod)
                clientView = clientView or {}
                full = full or {}
                for _, file in ipairs(clientFiles(lists)) do
                    local src = read(mod.dir .. '/' .. file)
                    assert(src, mod.dir .. '/' .. file .. ' introuvable')
                    local failure = checkReads(file, strip(src, true), mod.global, full, clientView)
                    if failure then error(failure) end
                end
            end)

            it('T3 : logique de shared/ partagée seulement si un fichier client s\'en sert', function()
                local client = {}
                for _, file in ipairs(clientFiles(lists)) do
                    client[file] = strip(read(mod.dir .. '/' .. file) or '', true)
                end
                for _, file in ipairs(lists.shared) do
                    if file:match('^shared/.+%.lua$') and file ~= 'shared/constants.lua' then
                        local used = false
                        for field in pairs(exports(client[file], mod.global)) do
                            for other, code in pairs(client) do
                                if other ~= file and cites(code, mod.global, field) then used = true end
                            end
                        end
                        assert(used, file .. ' n\'est lu par aucun fichier client : le servir au seul serveur')
                    end
                end
                for _, file in ipairs(lists.server) do
                    if file:match('^shared/.+%.lua$') then
                        local code = strip(read(mod.dir .. '/' .. file) or '', true)
                        for field in pairs(exports(code, mod.global)) do
                            for other, clientCode in pairs(client) do
                                if cites(clientCode, mod.global, field) then
                                    error(('%s servi au seul serveur mais lu par %s (%s.%s)'):format(file, other,
                                        mod.global, field))
                                end
                            end
                        end
                    end
                end
            end)
        end) end
    end
end)

-- Lecture statique de T2 sur des sources écrites ici (relecture réseau R-1 et R-2) : chaque forme d'alias suivie, et
-- toute autre façon de tenir une table de config fermée par défaut (essais de mutation gardés).
describe('configs partagées : T2 sur des sources d\'essai', function()
    local full = {
        kit = { items = { 1 } },
        texts = { title = 'T', refused = { busy = 'B' } },
        welcome = { delayMs = 1 },
    }
    local client = { texts = { refused = { busy = 'B' } }, welcome = { delayMs = 1 } }
    local function check(src) return checkReads('client/x.lua', strip(src, true), 'VavaX', full, client) end

    it('lectures de la part client : rien à redire', function()
        assert.is_nil(check('local cfg = VavaX.config\nlocal texts = cfg.texts\nprint(texts.refused[code], cfg.welcome.delayMs)'))
        assert.is_nil(check('for k in pairs(VavaX.config.texts.refused) do end'))   -- refused entier côté client
        assert.is_nil(check('show(VavaX.config.welcome)'))                           -- welcome entier côté client
        assert.is_nil(check('local cfg = VavaX.config\nprint(self.cfg.kit, other.cfg.kit)'))
        assert.is_nil(check('local cfg = VavaX.config\n-- cfg.kit.items\nprint(\'cfg.kit\')'))
    end)

    it('alias en affectation multiple suivi', function()
        local failure = check('local cfg, screen = VavaX.config, VavaX.screen\nlocal n = #cfg.kit.items')
        assert.matches('client/x.lua:2 lit config.kit.items', failure, 1, true)
        -- l'alias lui-même lit config.kit, absent de la vue client
        failure = check('local a, b = 1, VavaX.config.kit\nprint(b.items)')
        assert.matches('client/x.lua:1 lit config.kit', failure, 1, true)
    end)

    it('alias <const> suivi', function()
        assert.matches('client/x.lua:2 lit config.kit', check('local cfg <const> = VavaX.config\nreturn cfg.kit'), 1, true)
    end)

    it('alias d\'alias et copie d\'alias suivis', function()
        local failure = check('local cfg = VavaX.config\nlocal c2 = cfg\nlocal t = c2.texts\nprint(t.title)')
        assert.matches('client/x.lua:4 lit config.texts.title', failure, 1, true)
    end)

    it('fermé par défaut : alias non suivi, table passée, index dynamique, affectation', function()
        assert.matches('utilise la table config entière', check('local cfg = VavaX.config or {}'), 1, true)
        assert.matches('utilise la table config.texts entière', check('local t = VavaX.config.texts or {}'), 1, true)
        assert.matches('utilise la table config.texts entière', check('show(VavaX.config.texts)'), 1, true)
        assert.matches('utilise la table config.texts entière',
            check('local t = VavaX.config.texts\nprint(t[key])'), 1, true)
        assert.matches('utilise la table config entière', check('cfg = VavaX.config'), 1, true)
        assert.matches('utilise la table config entière', check('local cfg\ncfg = VavaX.config'), 1, true)
    end)
end)
