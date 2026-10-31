--[[
    vava_atelier/server/journal.lua
    Rôle : journal du Conseil (table vava_atelier_journal, sql/0001_journal.sql). Écriture d'une ligne contrôlée
           (atelier et type déclarés, action connue, textes bornés, droit effectif de l'atelier ou console), sans
           faire attendre l'appelant ; débit borné par ressource appelante ; recopie au journal du Registre et hook
           vava_atelier:journal une fois la ligne écrite. Lecture paginée par curseur, filtrée par les droits détenus
           (colonne `required_right` écrite au moment du changement ; aucun filtre pour qui les détient tous) et, au
           besoin, par atelier ; purge au démarrage. T-101 : acteur imposé pour une écriture interne (fin d'essai après
           le départ du membre : nom gardé au début de l'essai, sans recopie au Registre), atelier déjà retiré du
           registre donné par l'appelant, lignes d'un atelier entier (sans fiche).
    Dépendances : shared/constants.lua, config.lua, shared/text.lua, shared/journaltext.lua, shared/rights.lua,
                  bridge/server.lua, server/core.lua, server/editors.lua
]]

local type, ipairs, tostring, tonumber = type, ipairs, tostring, tonumber
local find, rep = string.find, string.rep
local concat = table.concat
local mathType, min = math.type, math.min
local CreateThread, GetGameTimer = CreateThread, GetGameTimer
local time = os.time

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local texts = cfg.texts
local Bridge = VavaAtelier.bridge
local editors = VavaAtelier.editors
local text, jt, rights = VavaAtelier.text, VavaAtelier.journaltext, VavaAtelier.rights
local OUT = VavaAtelier.OUT
local HOOK_JOURNAL = VavaAtelier.HOOKS.JOURNAL
local CONSOLE = 0
-- détail d'une recopie au Registre : 120 caractères au plus (bornes de vava_admin)
local MIRROR_VALUE = 120

local ACTIONS = {}
for _, action in ipairs(VavaAtelier.ACTIONS) do ACTIONS[action] = true end

local INSERT_SQL = 'INSERT INTO `vava_atelier_journal` (`editor`, `kind`, `def_id`, `action`, `title`, `summary`, '
    .. '`version`, '
    .. '`required_right`, `actor_account_id`, `actor_label`) '
    .. "VALUES (?, ?, NULLIF(?, ''), ?, ?, NULLIF(?, ''), NULLIF(?, 0), ?, NULLIF(?, 0), ?)"
local PURGE_SQL = 'DELETE FROM `vava_atelier_journal` WHERE `created_at` < DATE_SUB(NOW(), INTERVAL ? DAY)'
local SELECT_HEAD = 'SELECT `id`, `editor`, `kind`, `def_id`, `action`, `title`, `summary`, `version`, `actor_label`, '
    .. 'UNIX_TIMESTAMP(`created_at`) AS `at` FROM `vava_atelier_journal`'
-- colonne `version` : INT UNSIGNED
local MAX_VERSION = 4294967295

local journal = {}
VavaAtelier.journal = journal

-- écritures par ressource appelante : { start, count, warned }
local flood = {}
-- requêtes de lecture, construites une fois par forme : nombre de droits, curseur, atelier
local selects = {}

--- Requête de lecture : autant de `?` que de droits à filtrer (jamais une valeur dans le texte ; 0 : tous les droits
--- permis sont détenus, aucun filtre, lecture à rebours sur la clé primaire), curseur et atelier facultatifs,
--- `LIMIT ?`.
---@param rights integer
---@param cursor boolean
---@param editor boolean
---@return string
local function selectSql(rights, cursor, editor)
    local key = rights .. (cursor and 'c' or '') .. (editor and 'e' or '')
    local sql = selects[key]
    if not sql then
        local where = {}
        if rights > 0 then where[#where + 1] = '`required_right` IN (' .. rep('?', rights, ', ') .. ')' end
        if cursor then where[#where + 1] = '`id` < ?' end
        if editor then where[#where + 1] = '`editor` = ?' end
        sql = SELECT_HEAD .. (#where > 0 and ' WHERE ' .. concat(where, ' AND ') or '')
            .. ' ORDER BY `id` DESC LIMIT ?'
        selects[key] = sql
    end
    return sql
end

--- Débit d'écriture d'une ressource : `journal.flood.lines` par `windowMs`.
---@param owner string
---@return boolean
local function withinFlood(owner)
    local now, limits = GetGameTimer(), cfg.journal.flood
    local state = flood[owner]
    if not state or now - state.start >= limits.windowMs then
        state = { start = now, count = 0, warned = false }
        flood[owner] = state
    end
    if state.count >= limits.lines then
        if not state.warned then
            state.warned = true
            VavaAtelier.log.warn('journal : %s écrit plus de %d lignes en %d ms, lignes refusées', owner, limits.lines,
                limits.windowMs)
        end
        return false
    end
    state.count = state.count + 1
    return true
end

---@param value any
---@param minBytes integer
---@param maxBytes integer
---@return boolean
local function isText(value, minBytes, maxBytes)
    return type(value) == 'string' and #value >= minBytes and #value <= maxBytes and text.isUtf8(value)
        and not text.hasControl(value)
end

---@class vAvA.AtelierJournalEntry
---@field editor string
---@field kind string
---@field id? string
---@field action string
---@field title string
---@field summary? string
---@field version? integer

--- Écrit une ligne au journal. `owner` : ressource appelante (export) dont l'atelier doit porter le nom ; nil pour un
--- appel interne. `source` : membre qui a le droit effectif de l'atelier, ou 0 (console : sans recopie au Registre).
--- L'écriture en base part dans son propre fil : l'appelant n'attend pas (le numéro de la ligne est dans le hook).
--- Appel interne seulement : `actor` impose l'auteur ({ accountId?, label }, sans contrôle de droit ni recopie au
--- Registre) ; `known` donne l'atelier quand il vient de quitter le registre.
---@param source integer
---@param entry vAvA.AtelierJournalEntry
---@param owner? string
---@param actor? { accountId: integer|nil, label: string }
---@param known? vAvA.AtelierEditor
---@return boolean ok
---@return string|nil code  invalid_args | unknown_editor | not_owner | not_allowed | flood
function journal.write(source, entry, owner, actor, known)
    if mathType(source) ~= 'integer' or source < 0 or type(entry) ~= 'table' then return false, 'invalid_args' end
    local editor = type(entry.editor) == 'string' and editors.get(entry.editor) or nil
    if not editor and known and known.id == entry.editor then editor = known end
    if not editor then return false, 'unknown_editor' end
    if owner and editor.owner ~= owner then return false, 'not_owner' end
    local kind = type(entry.kind) == 'string' and editors.kind(editor, entry.kind) or nil
    if not kind or not ACTIONS[entry.action] or not isText(entry.title, 1, OUT.title) then
        return false, 'invalid_args'
    end
    if entry.summary ~= nil and not isText(entry.summary, 0, OUT.summary) then return false, 'invalid_args' end
    if entry.id ~= nil and (type(entry.id) ~= 'string' or #entry.id > VavaAtelier.MAX_ENTRY
        or not find(entry.id, VavaAtelier.ENTRY_PATTERN)) then
        return false, 'invalid_args'
    end
    if entry.version ~= nil and (mathType(entry.version) ~= 'integer' or entry.version < 1
        or entry.version > MAX_VERSION) then
        return false, 'invalid_args'
    end

    local accountId, label = nil, texts.console
    if actor then
        if type(actor.label) ~= 'string' or actor.label == '' then return false, 'invalid_args' end
        accountId, label, source = actor.accountId, text.truncate(actor.label, OUT.actor), CONSOLE
    elseif source ~= CONSOLE then
        if not Bridge.Can(source, editor.right) then return false, 'not_allowed' end
        accountId, label = Bridge.AccountId(source), Bridge.ActorLabel(source)
        if not accountId or not label then return false, 'not_allowed' end
    end
    -- débit : par ressource appelante pour un export ; pour une écriture interne, par membre (ou console) : un
    -- module bavard ou un membre pressé n'épuise jamais la part des autres
    local floodKey = owner or ('#' .. tostring(accountId or 'console'))
    if not withinFlood(floodKey) then return false, 'flood' end

    local summary = entry.summary ~= '' and entry.summary or nil
    local row = {
        editor = editor.id, kind = entry.kind, defId = entry.id, action = entry.action, title = entry.title,
        summary = summary, version = entry.version, right = editor.right, accountId = accountId, actor = label,
    }
    -- recopie au Registre préparée ici (libellé de l'atelier lu au moment de l'appel), envoyée après l'écriture
    local mirror = nil
    if source ~= CONSOLE and cfg.journal.mirror then
        mirror = { atelier = editor.label, objet = row.title }
        if row.version then mirror.version = row.version end
        if row.summary then mirror.resume = text.truncate(row.summary, MIRROR_VALUE) end
    end
    CreateThread(function()
        -- aucune valeur nil dans la liste (elle traverse un export) : '' et 0 deviennent NULL par NULLIF
        local id, err = core.db.insert(INSERT_SQL, {
            row.editor, row.kind, row.defId or '', row.action, row.title, row.summary or '', row.version or 0,
            row.right, row.accountId or 0, row.actor,
        })
        if not id then
            VavaAtelier.log.error('journal non écrit (%s, %s) : %s', row.editor, row.action, tostring(err))
            return
        end
        -- le Registre ne garde que ce qui est réellement écrit ici
        if mirror then Bridge.MirrorLog(source, texts.mirror[row.action], mirror) end
        core.hooks.runAfter(HOOK_JOURNAL, {
            id = id, editor = row.editor, kind = row.kind, defId = row.defId, action = row.action, title = row.title,
            summary = row.summary, version = row.version, actor = { accountId = row.accountId, label = row.actor },
        })
    end)
    return true
end

--- Lignes du journal lisibles avec ces droits, des plus récentes aux plus anciennes : au plus `limit`, avant la ligne
--- `before` (0 : les plus récentes), d'un seul atelier si `editorId` n'est pas vide (les lignes n'ont alors pas de
--- champ `editor` : la page le tient de son filtre). Qui détient tous les droits permis lit sans filtre de droit.
---@param held string[]  droits détenus (au moins un)
---@param before integer
---@param editorId string
---@param limit integer
---@return table|nil result  { lines, more, next }
---@return string|nil code   db_error
function journal.read(held, before, editorId, limit)
    if #held == 0 then return { lines = {}, more = false, next = 0 } end
    local params = {}
    if not rights.coversAll(cfg.rights.allowed, held) then
        for i, right in ipairs(held) do params[i] = right end
    end
    local filteredRights = #params
    local cursor, filtered = before > 0, editorId ~= ''
    if cursor then params[#params + 1] = before end
    if filtered then params[#params + 1] = editorId end
    params[#params + 1] = limit + 1
    local rows, err = core.db.query(selectSql(filteredRights, cursor, filtered), params)
    if type(rows) ~= 'table' then
        VavaAtelier.log.error('journal illisible : %s', tostring(err))
        return nil, 'db_error'
    end
    local now, lines = time(), {}
    for i = 1, min(#rows, limit) do
        local row = rows[i]
        row.at = tonumber(row.at) or now
        local editor = editors.get(row.editor)
        local kind = editor and editors.kind(editor, row.kind)
        lines[i] = jt.line(row, texts.verbs, kind and kind.def, now, nil, filtered, texts.workshop)
    end
    return { lines = lines, more = #rows > limit, next = #lines > 0 and lines[#lines].id or 0 }
end

--- Purge des lignes plus anciennes que `journal.retentionDays` (au démarrage, sans le retarder).
function journal.purge()
    CreateThread(function()
        local days = cfg.journal.retentionDays
        local purged, err = core.db.update(PURGE_SQL, { days })
        if err then
            VavaAtelier.log.warn('journal non purgé : %s', tostring(err))
        elseif (tonumber(purged) or 0) > 0 then
            VavaAtelier.log.info('journal : %d ligne(s) de plus de %d jours retirée(s)', tonumber(purged), days)
        else
            VavaAtelier.log.info('journal : aucune ligne de plus de %d jours', days)
        end
    end)
end
