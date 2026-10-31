local helper = require('tests.helper')

-- Configs partagées (T-132, docs/plan/specs/T-132.md § 2.4 et § 3.4) : un joueur ne télécharge que ce que son client
-- lit. `config.lua` (réglages du seul serveur) est en tête des server_scripts ; `config_client.lua` (réglages lus par
-- le client) est partagé, ouvre la table, et config.lua la complète sans réécrire une de ses clés ; la logique de
-- shared/ n'est partagée que si un fichier client s'en sert. Fichiers lus depuis VAVA_ROOT (ou le dossier courant).
--
-- T0 forme du manifeste · T1 aucune valeur écrite deux fois · T2 le client ne lit que sa part · T3 logique au bon
-- endroit. Limites de T2 (lecture statique) : un index dynamique (`cfg.x[k]`) arrête la chaîne, un alias passé en
-- paramètre ou posé sur plusieurs lignes n'est pas suivi ; une clé absente des deux vues (facultative) est ignorée.

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
    vava_farming = 'T-141', vava_crafting = 'T-141', vava_gathering = 'T-141', vava_skills = 'T-141',
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

--- Lectures de config d'un fichier client : liste de { line, chain = { 'texts', 'refused' } }.
local function configReads(code, global)
    local reads = {}
    local lines = {}
    for l in (code .. '\n'):gmatch('([^\n]*)\n') do lines[#lines + 1] = l end
    -- alias : `local x = <global>.config[.a.b]` puis `local y = x.c` (expression qui finit la ligne), jusqu'au point fixe
    local aliases = {}   -- nom → chemin de base (liste)
    local base = escape(global) .. '%.config'
    local changed = true
    while changed do
        changed = false
        for _, l in ipairs(lines) do
            local name, rest = l:match('^%s*local%s+([A-Za-z_][A-Za-z0-9_]*)%s*=%s*' .. base .. '([A-Za-z0-9_.]*)%s*$')
            local from
            if not name then
                local src
                name, src, rest = l:match('^%s*local%s+([A-Za-z_][A-Za-z0-9_]*)%s*=%s*([A-Za-z_][A-Za-z0-9_]*)'
                    .. '(%.[A-Za-z0-9_.]+)%s*$')
                from = src and aliases[src]
                if not from then name = nil end
            else
                from = {}
            end
            if name and not aliases[name] and (rest == '' or rest:match('^%.[A-Za-z_]')) then
                local chain = {}
                for _, k in ipairs(from) do chain[#chain + 1] = k end
                for k in rest:gmatch('[A-Za-z0-9_]+') do chain[#chain + 1] = k end
                aliases[name] = chain
                changed = true
            end
        end
    end
    -- chaîne `<tête>.k1.k2…` : arrêt à `[`, `(`, `:` ou tout autre signe ; la tête n'est pas précédée d'un nom, d'un
    -- point ou de deux-points (`self.cfg.x` n'est pas l'alias `cfg`)
    local function scan(lineNo, l, head, prefix)
        local pos = 1
        while true do
            local s, e, tail = l:find(head .. '([A-Za-z0-9_.]*)', pos)
            if not s then break end
            pos = e + 1
            local before = s > 1 and l:sub(s - 1, s - 1) or ''
            if not before:match('[A-Za-z0-9_.:]') and (tail == '' or tail:sub(1, 1) == '.') then
                local chain = {}
                for _, k in ipairs(prefix) do chain[#chain + 1] = k end
                for k in tail:gmatch('[A-Za-z0-9_]+') do chain[#chain + 1] = k end
                if #chain > 0 then reads[#reads + 1] = { line = lineNo, chain = chain } end
            end
        end
    end
    for lineNo, l in ipairs(lines) do
        scan(lineNo, l, base, {})
        for name, chain in pairs(aliases) do scan(lineNo, l, '%f[A-Za-z0-9_]' .. escape(name), chain) end
    end
    return reads
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
                    local code = strip(src, true)
                    for _, r in ipairs(configReads(code, mod.global)) do
                        local f, c, path = full, clientView, 'config'
                        for _, key in ipairs(r.chain) do
                            if type(f) ~= 'table' then break end
                            f = f[key]
                            if type(c) == 'table' then c = c[key] else c = nil end
                            path = path .. '.' .. key
                            if f == nil then break end
                            if c == nil then
                                error(('%s:%d lit config.%s (%s), que seul config.lua définit'):format(file, r.line,
                                    table.concat(r.chain, '.'), path))
                            end
                        end
                    end
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
