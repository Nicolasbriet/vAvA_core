--[[
    vava_codex/shared/pages.lua
    Rôle : logique pure des pages de lecture (1.5.0). Analyse d'un corps de page écrit en texte balisé léger
           (paragraphes, intertitres « ## », listes « - » et « 1. », notes « > », jetons entre doubles crochets :
           touche écrite, touche du registre, commande, lien de page ; italique *…*) en blocs déjà construits, que la
           page rend par éléments et
           textContent (jamais de HTML) ; validation d'un chapitre et d'une page (tables plates, le `data` de l'Atelier
           demain) ; construction de l'ensemble (refus avec code et ligne, ids, liens, tri, empreinte, poids réseau
           estimé) ; références citées (touches, commandes, pages). Aucune native, aucune API du core : testé hors jeu
           (tests/spec/codex_pages_spec.lua). Servi au seul serveur.
           Toutes les classes de caractères sont des ensembles d'octets écrits à la main : aucune classe liée à la
           locale (%a, %c, %s, %w…), aucun changement de casse.
    Dépendances : shared/constants.lua (READING, MAX_NAME, MAX_ACTION), shared/fingerprint.lua (empreinte des pages)
]]

local type, pairs, ipairs = type, pairs, ipairs
local mathType = math.type
local find, sub, match, gsub, gmatch, byte = string.find, string.sub, string.match, string.gsub, string.gmatch, string.byte
local concat, sort = table.concat, table.sort
local utf8len = utf8.len

local R = VavaCodex.READING
local MAX_NAME, MAX_ACTION = VavaCodex.MAX_NAME, VavaCodex.MAX_ACTION

local pages = {}
VavaCodex.pages = pages

-- Octets refusés dans une ligne de corps : contrôles 0 à 9 (tabulation comprise), 11 à 31, 127, et « < » partout.
-- Le saut de ligne (10) sépare les lignes ; « > » n'est permis qu'en premier caractère (note), vu à part.
local BAD_BODY_BYTE = '[\0-\9\11-\31\127<]'
-- Octets refusés dans un titre, un résumé, un nom de chapitre : tout contrôle, « < » et « > ».
local BAD_TEXT_BYTE = '[\0-\31\127<>]'
-- Octets refusés dans une touche écrite en toutes lettres et dans le libellé d'un lien.
local BAD_LITERAL_BYTE = '[%[%]|*]'

local SPACE, STAR, BRACKET, HASH = 32, 42, 91, 35

local PAGE_FIELDS = {
    id = true, chapter = true, order = true, title = true, summary = true, audience = true, permission = true,
    requires = true, body = true,
}
local CHAPTER_FIELDS = { id = true, label = true, order = true }
local AUDIENCES = { player = true, admin = true }

-- Outils ----------------------------------------------------------------------------------------------------------

--- Identifiant de page ou de chapitre : motif, longueur, jamais « vava… » (les chapitres de commandes portent le nom
--- d'un module : `openAt` les distingue ainsi).
---@param id any
---@return boolean
local function validId(id)
    return type(id) == 'string' and #id >= 1 and #id <= R.MAX_ID and find(id, R.ID_PATTERN) ~= nil
        and sub(id, 1, 4) ~= 'vava'
end
pages.validId = validId

--- Texte court (titre, résumé, nom de chapitre) : chaîne de `min` à `max` octets, UTF-8 valide, sans contrôle ni
--- « < » ni « > ».
---@param value any
---@param min integer
---@param max integer
---@return boolean
local function shortText(value, min, max)
    return type(value) == 'string' and #value >= min and #value <= max and utf8len(value) ~= nil
        and not find(value, BAD_TEXT_BYTE)
end

---@param value any
---@return boolean
local function validOrder(value)
    return mathType(value) == 'integer' and value >= 0 and value <= 999
end

--- Espaces multiples ramenées à une, espaces des bords retirées.
---@param text string
---@return string
local function squeeze(text)
    text = gsub(text, ' +', ' ')
    return match(text, '^ ?(.-) ?$')
end

--- Texte littéral d'un jeton (touche en toutes lettres, libellé de lien) : 1 à `max` octets, sans crochet, barre ni
--- astérisque, sans espace au bord.
---@param text string
---@param max integer
---@return boolean
local function literal(text, max)
    return #text >= 1 and #text <= max and not find(text, BAD_LITERAL_BYTE)
        and byte(text, 1) ~= SPACE and byte(text, #text) ~= SPACE
end

-- Jetons et segments ----------------------------------------------------------------------------------------------

--- Jeton écrit entre [[ et ]] (`inner` : ce qu'il y a entre les deux) : segment, ou nil s'il est mal formé.
---@param inner string
---@return table|nil
local function token(inner)
    local colon = find(inner, ':', 1, true)
    if not colon then
        if literal(inner, R.MAX_KBD) then return { 'kbd', inner } end
        return nil
    end
    local kind, rest = sub(inner, 1, colon - 1), sub(inner, colon + 1)
    if kind == 'touche' then
        if #rest <= MAX_NAME and find(rest, R.NAME_PATTERN) then return { 'key', rest } end
    elseif kind == 'commande' then
        local name, action = match(rest, '^([^ ]+) ([^ ]+)$')
        if not name then name, action = rest, '' end
        if #name <= MAX_NAME and find(name, R.NAME_PATTERN)
            and (action == '' or (#action <= MAX_ACTION and find(action, R.ACTION_PATTERN))) then
            return { 'cmd', name, action }
        end
    elseif kind == 'page' then
        local id, label = rest, ''
        local bar = find(rest, '|', 1, true)
        if bar then
            id, label = sub(rest, 1, bar - 1), sub(rest, bar + 1)
            if not literal(label, R.MAX_LINK_LABEL) then return nil end
        end
        if validId(id) then return { 'page', id, label } end
    end
    return nil
end

--- Découpe un texte (déjà joint, espaces ramenées) en segments : chaînes et jetons. `count` compte les jetons de la
--- page entière. Rend la liste, ou nil et un code.
---@param text string
---@param count { tokens: integer }
---@return table|nil segments
---@return string|nil code
local function segments(text, count)
    local out, n = {}, 0
    local function push(segment)
        if type(segment) == 'string' then
            if segment == '' then return true end
            if n > 0 and type(out[n]) == 'string' then
                out[n] = out[n] .. segment
                return true
            end
        else
            count.tokens = count.tokens + 1
            if count.tokens > R.MAX_TOKENS then return false end
        end
        n = n + 1
        out[n] = segment
        return true
    end
    local pos, length = 1, #text
    while pos <= length do
        local at = find(text, '[%[*]', pos)
        if not at then
            push(sub(text, pos))
            break
        end
        if byte(text, at) == STAR then
            -- *italique* : jusqu'au prochain astérisque, ni espace au bord, sans [[ ; sinon un astérisque ordinaire
            local close = find(text, '*', at + 1, true)
            local inner = close and sub(text, at + 1, close - 1)
            if inner and #inner >= 1 and #inner <= R.MAX_EM and byte(inner, 1) ~= SPACE
                and byte(inner, #inner) ~= SPACE and not find(inner, '[[', 1, true) then
                push(sub(text, pos, at - 1))
                if not push({ 'em', inner }) then return nil, 'too_many_tokens' end
                pos = close + 1
            else
                push(sub(text, pos, at))
                pos = at + 1
            end
        elseif byte(text, at + 1) == BRACKET then
            local close = find(text, ']]', at + 2, true)
            if not close then return nil, 'bad_token' end
            local segment = token(sub(text, at + 2, close - 1))
            if not segment then return nil, 'bad_token' end
            push(sub(text, pos, at - 1))
            if not push(segment) then return nil, 'too_many_tokens' end
            pos = close + 2
        else
            -- un crochet seul est du texte
            push(sub(text, pos, at))
            pos = at + 1
        end
    end
    return out
end

-- Analyse d'un corps ----------------------------------------------------------------------------------------------

--- Analyse un corps de page. Rend `blocks, meta` (`meta.lines` : ligne de départ de chaque bloc ; `meta.tokens` :
--- nombre de jetons), ou `nil, code, ligne` (ligne 0 : le corps entier). Blocs (listes pures) :
--- `{ 'h', texte }`, `{ 'p', segment… }`, `{ 'note', segment… }`, `{ 'ul', { segment… }, … }`, `{ 'ol', … }` ;
--- segment : chaîne, `{ 'kbd', touche }`, `{ 'key', nom }`, `{ 'cmd', nom, action|'' }`, `{ 'page', id, libellé|'' }`,
--- `{ 'em', texte }`.
---@param body any
---@return table|nil blocks
---@return table|string|nil meta_or_code
---@return integer|nil line
function pages.parse(body)
    if type(body) ~= 'string' or not utf8len(body) then return nil, 'bad_utf8', 0 end
    body = gsub(body, '\r', '')
    if #body > R.MAX_BODY then return nil, 'too_long', 0 end

    local blocks, lines = {}, {}
    local count = { tokens = 0 }
    -- bloc en cours : { kind = 'p'|'note'|'ul'|'ol', line, parts = { … } } ; liste : items = { { line, parts } }
    local current

    local function addBlock(block, line)
        if #blocks >= R.MAX_BLOCKS then return nil, 'too_many_blocks', line end
        blocks[#blocks + 1] = block
        lines[#lines + 1] = line
        return true
    end

    --- Texte d'un paragraphe, d'une note ou d'un élément : borné tel qu'écrit, puis découpé en segments.
    local function finish(parts, limit, line)
        local text = concat(parts, ' ')
        if #text > limit then return nil, 'too_long_block', line end
        local list, code = segments(squeeze(text), count)
        if not list then return nil, code, line end
        return list
    end

    local function close()
        local block = current
        current = nil
        if not block then return true end
        local out = { block.kind }
        if block.kind == 'ul' or block.kind == 'ol' then
            for i, item in ipairs(block.items) do
                local list, code, line = finish(item.parts, R.MAX_ITEM, item.line)
                if not list then return nil, code, line end
                out[i + 1] = list
            end
        else
            local list, code, line = finish(block.parts, R.MAX_PARAGRAPH, block.line)
            if not list then return nil, code, line end
            for i, segment in ipairs(list) do out[i + 1] = segment end
        end
        return addBlock(out, block.line)
    end

    local function addItem(kind, text, line)
        if not current or current.kind ~= kind then
            local ok, code, at = close()
            if not ok then return nil, code, at end
            current = { kind = kind, line = line, items = {} }
        end
        local items = current.items
        if #items >= R.MAX_ITEMS then return nil, 'too_many_items', line end
        items[#items + 1] = { line = line, parts = { text } }
        return true
    end

    local number = 0
    for raw in gmatch(body .. '\n', '([^\n]*)\n') do
        number = number + 1
        if find(raw, BAD_BODY_BYTE) or find(raw, '>', 2, true) then return nil, 'bad_char', number end
        local line = match(raw, '^(.-) *$')
        local ok, code, at = true, nil, nil
        local first = byte(line, 1)
        if line == '' then
            ok, code, at = close()
        elseif first == HASH then
            local text = match(line, '^## (.*)$')
            text = text and squeeze(text)
            if not text or text == '' or byte(text, 1) == HASH or find(text, '[[', 1, true) then
                return nil, 'bad_heading', number
            end
            if #text > R.MAX_HEADING then return nil, 'too_long_block', number end
            ok, code, at = close()
            if ok then ok, code, at = addBlock({ 'h', text }, number) end
        elseif first == 62 then   -- « > » : note ; « > » seul est ignoré
            local text = match(line, '^> ?(.*)$')
            if text ~= '' then
                if current and current.kind == 'note' then
                    current.parts[#current.parts + 1] = text
                else
                    ok, code, at = close()
                    current = { kind = 'note', line = number, parts = { text } }
                end
            end
        elseif match(line, '^%- ') then
            ok, code, at = addItem('ul', sub(line, 3), number)
        elseif match(line, '^[0-9][0-9]?%. ') then
            ok, code, at = addItem('ol', match(line, '^[0-9]+%. (.*)$'), number)
        elseif current and (current.kind == 'ul' or current.kind == 'ol') and match(line, '^  ') then
            -- suite de l'élément précédent
            local parts = current.items[#current.items].parts
            parts[#parts + 1] = line
        elseif current and current.kind == 'p' then
            current.parts[#current.parts + 1] = line
        else
            ok, code, at = close()
            current = { kind = 'p', line = number, parts = { line } }
        end
        if not ok then return nil, code, at end
    end
    local ok, code, at = close()
    if not ok then return nil, code, at end
    if #blocks == 0 then return nil, 'empty_body', 0 end
    return blocks, { lines = lines, tokens = count.tokens }
end

-- Références citées -----------------------------------------------------------------------------------------------

--- Touches, commandes et pages citées par des blocs, sans doublon, dans l'ordre de leur première apparition.
---@param blocks table
---@return { keys: string[], commands: { name: string, action: string }[], pages: string[] }
function pages.references(blocks)
    local keys, commands, links, seen = {}, {}, {}, {}
    local function visit(segment)
        if type(segment) ~= 'table' then return end
        local kind = segment[1]
        if kind == 'key' then
            local mark = 'k ' .. segment[2]
            if not seen[mark] then
                seen[mark] = true
                keys[#keys + 1] = segment[2]
            end
        elseif kind == 'cmd' then
            local mark = 'c ' .. segment[2] .. ' ' .. segment[3]
            if not seen[mark] then
                seen[mark] = true
                commands[#commands + 1] = { name = segment[2], action = segment[3] }
            end
        elseif kind == 'page' then
            local mark = 'p ' .. segment[2]
            if not seen[mark] then
                seen[mark] = true
                links[#links + 1] = segment[2]
            end
        end
    end
    for _, block in ipairs(type(blocks) == 'table' and blocks or {}) do
        local kind = block[1]
        for i = 2, #block do
            if kind == 'ul' or kind == 'ol' then
                for _, segment in ipairs(block[i]) do visit(segment) end
            else
                visit(block[i])
            end
        end
    end
    return { keys = keys, commands = commands, pages = links }
end

-- Poids réseau ----------------------------------------------------------------------------------------------------

--- Taille d'une valeur sérialisée en msgpack (règles du format, hors enveloppe du core) : ce que pèse une réponse.
---@param value any
---@return integer
local function wireSize(value)
    local kind = type(value)
    if kind == 'nil' or kind == 'boolean' then return 1 end
    if kind == 'number' then
        if mathType(value) == 'float' then return 9 end
        if value >= -32 and value <= 127 then return 1 end
        if value >= -32768 and value <= 65535 then return 3 end
        return 9
    end
    if kind == 'string' then
        local n = #value
        return n + (n < 32 and 1 or n < 256 and 2 or n < 65536 and 3 or 5)
    end
    if kind ~= 'table' then return 0 end
    local count = 0
    for _ in pairs(value) do count = count + 1 end
    local isList = count == #value
    local size = count < 16 and 1 or 3
    for key, item in pairs(value) do size = size + wireSize(item) + (isList and 0 or wireSize(key)) end
    return size
end
pages.wireSize = wireSize

-- Validation des définitions --------------------------------------------------------------------------------------

---@param def any
---@return boolean ok
---@return string|nil code
function pages.validateChapter(def)
    if type(def) ~= 'table' then return false, 'bad_id' end
    for key in pairs(def) do
        if not CHAPTER_FIELDS[key] then return false, 'unknown_field' end
    end
    if not validId(def.id) then return false, 'bad_id' end
    if not shortText(def.label, 1, R.MAX_LABEL) then return false, 'bad_label' end
    if not validOrder(def.order) then return false, 'bad_order' end
    return true
end

--- Champs d'une page (le corps est analysé à part, par `parse` : un corps qui n'est pas une chaîne y est refusé,
--- `bad_utf8`). `summary`, `permission` et `requires` absents valent '' ; les autres sont obligatoires.
---@param def any
---@return boolean ok
---@return string|nil code
function pages.validatePage(def)
    if type(def) ~= 'table' then return false, 'bad_id' end
    for key in pairs(def) do
        if not PAGE_FIELDS[key] then return false, 'unknown_field' end
    end
    if not validId(def.id) then return false, 'bad_id' end
    if type(def.chapter) ~= 'string' or not validId(def.chapter) then return false, 'bad_chapter' end
    if not validOrder(def.order) then return false, 'bad_order' end
    if not shortText(def.title, 1, R.MAX_TITLE) then return false, 'bad_title' end
    local summary = def.summary == nil and '' or def.summary
    if not shortText(summary, 0, R.MAX_SUMMARY) then return false, 'bad_summary' end
    if not AUDIENCES[def.audience] then return false, 'bad_audience' end
    local permission = def.permission == nil and '' or def.permission
    if type(permission) ~= 'string' then return false, 'bad_permission' end
    if permission ~= '' and (def.audience ~= 'admin' or #permission > R.MAX_PERMISSION
        or not find(permission, R.PERMISSION_PATTERN)) then
        return false, 'bad_permission'
    end
    local requires = def.requires == nil and '' or def.requires
    if type(requires) ~= 'string' then return false, 'bad_requires' end
    if requires ~= '' and (#requires > R.MAX_REQUIRES or not find(requires, R.REQUIRES_PATTERN)) then
        return false, 'bad_requires'
    end
    return true
end

-- Construction de l'ensemble --------------------------------------------------------------------------------------

--- Identifiant à écrire dans un refus (lisible même s'il est invalide).
---@param def any
---@return string
local function shownId(def)
    local id = type(def) == 'table' and def.id
    if type(id) == 'string' and #id <= 64 and utf8len(id) and not find(id, BAD_TEXT_BYTE) then return id end
    return '?'
end

--- Ligne du premier bloc d'une page qui cite `target`.
---@param page table
---@param target string
---@return integer
local function linkLine(page, target)
    for i, block in ipairs(page.blocks) do
        local refs = pages.references({ block })
        for _, id in ipairs(refs.pages) do
            if id == target then return page.lines[i] or 0 end
        end
    end
    return 0
end

--- Construit l'ensemble des pages depuis la graine `{ chapters = { … }, pages = { … } }`. Rend
--- `{ chapters, pages, byId }` (chapitres et pages gardés, triés : chapitres par rang puis id, pages par chapitre, rang,
--- id) et la liste des refus `{ { kind = 'chapter'|'page', id, code, line } }`. Une page refusée est écartée seule ;
--- un lien vers une page absente ou refusée, ou d'une page publique vers une page du Conseil, fait refuser la page qui
--- le porte, jusqu'à stabilité. Chaque page gardée porte `blocks`, `refs`, `hash` (empreinte du titre et des blocs),
--- `response` (`{ id, chapter, title, hash, body }`, la réponse du RPC) et `wire` (son poids estimé).
---@param seed any
---@return { chapters: table[], pages: table[], byId: table<string, table> } book
---@return { kind: string, id: string, code: string, line: integer }[] refused
function pages.build(seed)
    local book = { chapters = {}, pages = {}, byId = {} }
    local refused = {}
    local function refuse(kind, id, code, line)
        refused[#refused + 1] = { kind = kind, id = id, code = code, line = line or 0 }
    end
    if type(seed) ~= 'table' then return book, refused end

    -- chapitres
    local chapters, taken = {}, {}
    for _, def in ipairs(type(seed.chapters) == 'table' and seed.chapters or {}) do
        local ok, code = pages.validateChapter(def)
        if ok and taken[def.id] then ok, code = false, 'id_taken' end
        if ok then
            taken[def.id] = true
            chapters[#chapters + 1] = { id = def.id, label = def.label, order = def.order }
        else
            refuse('chapter', shownId(def), code)
        end
    end
    sort(chapters, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.id < b.id
    end)
    local rank = {}
    for i, chapter in ipairs(chapters) do
        if i > R.MAX_CHAPTERS then
            refuse('chapter', chapter.id, 'too_many_chapters')
        else
            book.chapters[i] = chapter
            rank[chapter.id] = i
        end
    end

    -- pages : champs, identifiant, chapitre, corps
    local list = {}
    for _, def in ipairs(type(seed.pages) == 'table' and seed.pages or {}) do
        local ok, code = pages.validatePage(def)
        local line = 0
        if ok and taken[def.id] then ok, code = false, 'id_taken' end
        if ok then taken[def.id] = true end
        if ok and not rank[def.chapter] then ok, code = false, 'bad_chapter' end
        local blocks, meta
        if ok then
            local parsed, second, third = pages.parse(def.body)
            if parsed then
                blocks, meta = parsed, second
            else
                ok, code, line = false, second, third
            end
        end
        if ok then
            list[#list + 1] = {
                id = def.id, chapter = def.chapter, order = def.order, title = def.title, summary = def.summary or '',
                audience = def.audience, permission = def.permission or '', requires = def.requires or '',
                blocks = blocks, lines = meta.lines, refs = pages.references(blocks),
            }
        else
            refuse('page', shownId(def), code, line)
        end
    end
    sort(list, function(a, b)
        if a.chapter ~= b.chapter then return rank[a.chapter] < rank[b.chapter] end
        if a.order ~= b.order then return a.order < b.order end
        return a.id < b.id
    end)

    -- nombre, poids
    local alive, kept = {}, {}
    local fingerprint = VavaCodex.fingerprint
    for i, page in ipairs(list) do
        if i > R.MAX_PAGES then
            refuse('page', page.id, 'too_many_pages')
        else
            page.hash = fingerprint and fingerprint({ title = page.title, body = page.blocks }) or ''
            page.response = { id = page.id, chapter = page.chapter, title = page.title, hash = page.hash, body = page.blocks }
            page.wire = wireSize(page.response)
            if page.wire > R.MAX_WIRE then
                refuse('page', page.id, 'too_large')
            else
                kept[#kept + 1] = page
                alive[page.id] = page
            end
        end
    end

    -- liens, jusqu'à stabilité : une page refusée peut en faire refuser une autre
    local changed = true
    while changed do
        changed = false
        for _, page in ipairs(kept) do
            if alive[page.id] then
                for _, target in ipairs(page.refs.pages) do
                    local other = alive[target]
                    if not other or (page.audience == 'player' and other.audience == 'admin') then
                        alive[page.id] = nil
                        refuse('page', page.id, 'bad_link', linkLine(page, target))
                        changed = true
                        break
                    end
                end
            end
        end
    end

    for _, page in ipairs(kept) do
        if alive[page.id] then
            page.lines = nil
            book.pages[#book.pages + 1] = page
            book.byId[page.id] = page
        end
    end
    return book, refused
end
