--[[
    vava_atelier/server/store.lua
    Rôle : requêtes de la table vava_atelier_definitions (sql/0002_definitions.sql), toutes paramétrées (`?`), jamais
           une valeur dans le texte d'une requête ; listes `IN (?, …)` construites une fois par longueur. Une valeur
           absente part en '' ou 0 et devient NULL par NULLIF (une liste à trous ne traverse pas l'export du core).
           Lectures (têtes d'un atelier, fiches connues, retirées, une ligne, une version, historique, versions d'une
           fiche), écritures simples (brouillon, sauvegarde à révision, reprise, abandon, essai), et morceaux de
           transaction (publication, retrait, retour en arrière, graine, import, annulation d'un lot).
    Dépendances : shared/constants.lua, server/core.lua
]]

local type, ipairs, tostring, tonumber = type, ipairs, tostring, tonumber
local rep = string.rep
local concat = table.concat

local core = VavaAtelier.core
if not core then return end

local store = {}
VavaAtelier.store = store

local T = '`vava_atelier_definitions`'

-- têtes sans données ni lieu (≈ 200 octets par fiche) : le rapprochement compare les empreintes et ne relit, en lot
-- (`rows`), que les publiées qui diffèrent ; un brouillon est relu à la demande
local HEADS_SQL = 'SELECT `id`, `kind`, `def_id`, `version`, `status`, `removal`, `origin`, `format`, `title`, '
    .. '`parent`, `fingerprint`, `base_version`, `batch`, `rev`, `summary`, `author_account_id`, '
    .. '`author_label`, UNIX_TIMESTAMP(`updated_at`) AS `at` FROM ' .. T
    .. " WHERE `editor` = ? AND `status` IN ('draft', 'trial', 'published')"
local KNOWN_SQL = 'SELECT DISTINCT `kind`, `def_id` FROM ' .. T .. ' WHERE `editor` = ?'
local RETIRED_SQL = 'SELECT `id`, `kind`, `def_id`, `title`, `version`, `batch`, '
    .. 'UNIX_TIMESTAMP(`published_at`) AS `at` FROM ' .. T
    .. " WHERE `editor` = ? AND `removal` = 1 AND `status` = 'archived'"
local TOPS_SQL = 'SELECT `kind`, `def_id`, MAX(`version`) AS `top` FROM ' .. T
    .. ' WHERE `editor` = ? AND `version` IS NOT NULL GROUP BY `kind`, `def_id`'
local ROW_COLUMNS = '`id`, `editor`, `kind`, `def_id`, `version`, `status`, `removal`, `origin`, `format`, `title`, '
    .. '`parent`, `data`, `place`, `fingerprint`, `base_version`, `restored_from`, `batch`, `rev`, `summary`, '
    .. '`author_account_id`, `author_label`, `published_by`, UNIX_TIMESTAMP(`updated_at`) AS `at`'
local ROW_SQL = 'SELECT ' .. ROW_COLUMNS .. ' FROM ' .. T .. ' WHERE `id` = ?'
local VERSION_SQL = 'SELECT ' .. ROW_COLUMNS .. ' FROM ' .. T
    .. ' WHERE `editor` = ? AND `kind` = ? AND `def_id` = ? AND `version` = ?'
local HISTORY_HEAD = 'SELECT `version`, `status`, `removal`, `origin`, `restored_from`, `summary`, `author_label`, '
    .. '`published_by`, UNIX_TIMESTAMP(COALESCE(`published_at`, `created_at`)) AS `at` FROM ' .. T
    .. ' WHERE `editor` = ? AND `kind` = ? AND `def_id` = ? AND `version` IS NOT NULL'
local HISTORY_SQL = HISTORY_HEAD .. ' ORDER BY `version` DESC LIMIT ?'
local HISTORY_BEFORE_SQL = HISTORY_HEAD .. ' AND `version` < ? ORDER BY `version` DESC LIMIT ?'
local BATCH_REMOVALS_SQL = 'SELECT `kind`, `def_id`, `version`, `batch` FROM ' .. T
    .. " WHERE `editor` = ? AND `batch` = ? AND `removal` = 1 AND `status` = 'archived'"

local INSERT_DRAFT_SQL = 'INSERT INTO ' .. T .. ' (`editor`, `kind`, `def_id`, `version`, `status`, `removal`, '
    .. '`origin`, `format`, `title`, `parent`, `data`, `place`, `fingerprint`, `base_version`, `rev`, `summary`, '
    .. '`author_account_id`, `author_label`) '
    .. "VALUES (?, ?, ?, NULL, 'draft', ?, 'atelier', ?, ?, NULLIF(?, ''), ?, NULLIF(?, ''), ?, NULLIF(?, 0), 1, "
    .. "NULLIF(?, ''), NULLIF(?, 0), ?)"
local UPDATE_DRAFT_SQL = 'UPDATE ' .. T .. " SET `data` = ?, `place` = NULLIF(?, ''), `parent` = NULLIF(?, ''), "
    .. "`title` = ?, `fingerprint` = ?, `format` = ?, `summary` = NULLIF(?, ''), `rev` = `rev` + 1 "
    .. "WHERE `id` = ? AND `rev` = ? AND `status` IN ('draft', 'trial')"
local TAKE_SQL = 'UPDATE ' .. T .. ' SET `author_account_id` = NULLIF(?, 0), `author_label` = ?, '
    .. "`status` = 'draft', `rev` = `rev` + 1 WHERE `id` = ? AND `rev` = ? AND `status` IN ('draft', 'trial')"
local DISCARD_SQL = 'DELETE FROM ' .. T .. " WHERE `id` = ? AND `rev` = ? AND `status` IN ('draft', 'trial')"
local RESET_TRIALS_SQL = 'UPDATE ' .. T .. " SET `status` = 'draft' WHERE `status` = 'trial'"
local LIVE_ROWS_SQL = 'SELECT `id`, `editor`, `kind`, `def_id`, `version`, `status`, '
    .. 'UNIX_TIMESTAMP(`updated_at`) AS `at` FROM ' .. T .. " WHERE `status` IN ('draft', 'trial', 'published')"
local PURGE_CANDIDATES_SQL = 'SELECT `editor`, `kind`, `def_id` FROM ' .. T
    .. ' WHERE `version` IS NOT NULL GROUP BY `editor`, `kind`, `def_id` HAVING COUNT(*) > ?'
local VERSIONS_SQL = 'SELECT `id`, `version`, `status`, `removal` FROM ' .. T
    .. ' WHERE `editor` = ? AND `kind` = ? AND `def_id` = ? AND `version` IS NOT NULL'

-- morceaux de transaction
local ARCHIVE_SQL = 'UPDATE ' .. T .. " SET `status` = 'archived' WHERE `id` = ? AND `status` = 'published'"
local PUBLISH_SQL = 'UPDATE ' .. T .. " SET `status` = 'published', `version` = ?, `batch` = ?, "
    .. "`published_at` = NOW(), `published_by` = ?, `summary` = NULLIF(?, '') "
    .. "WHERE `id` = ? AND `rev` = ? AND `status` IN ('draft', 'trial')"
local RETIRE_SQL = 'UPDATE ' .. T .. " SET `status` = 'archived', `version` = ?, `batch` = ?, "
    .. "`published_at` = NOW(), `published_by` = ?, `summary` = NULLIF(?, '') "
    .. "WHERE `id` = ? AND `rev` = ? AND `status` IN ('draft', 'trial')"
local CASCADE_SQL = 'INSERT INTO ' .. T .. ' (`editor`, `kind`, `def_id`, `version`, `status`, `removal`, `origin`, '
    .. '`format`, `title`, `parent`, `data`, `place`, `fingerprint`, `base_version`, `batch`, `author_account_id`, '
    .. '`author_label`, `published_by`, `published_at`) '
    .. "SELECT `editor`, `kind`, `def_id`, ?, 'archived', 1, 'atelier', `format`, `title`, `parent`, `data`, "
    .. '`place`, `fingerprint`, `version`, ?, NULLIF(?, 0), ?, ?, NOW() FROM ' .. T .. ' WHERE `id` = ?'
local RESTORE_SQL = 'INSERT INTO ' .. T .. ' (`editor`, `kind`, `def_id`, `version`, `status`, `removal`, `origin`, '
    .. '`format`, `title`, `parent`, `data`, `place`, `fingerprint`, `restored_from`, `batch`, `author_account_id`, '
    .. '`author_label`, `published_by`, `published_at`, `summary`) '
    .. "SELECT `editor`, `kind`, `def_id`, ?, 'published', 0, 'restore', `format`, `title`, `parent`, `data`, "
    .. "`place`, `fingerprint`, `version`, ?, NULLIF(?, 0), ?, ?, NOW(), NULLIF(?, '') FROM " .. T .. ' WHERE `id` = ?'
local INSERT_PUBLISHED_SQL = 'INSERT INTO ' .. T .. ' (`editor`, `kind`, `def_id`, `version`, `status`, `removal`, '
    .. '`origin`, `format`, `title`, `parent`, `data`, `place`, `fingerprint`, `author_account_id`, `author_label`, '
    .. '`published_by`, `published_at`, `summary`) '
    .. "VALUES (?, ?, ?, ?, 'published', 0, ?, ?, ?, NULLIF(?, ''), ?, NULLIF(?, ''), ?, NULLIF(?, 0), ?, ?, NOW(), "
    .. "NULLIF(?, ''))"
local UNDO_DRAFT_SQL = 'UPDATE ' .. T .. " SET `status` = 'draft', `version` = NULL, `batch` = NULL, "
    .. '`published_at` = NULL, `published_by` = NULL WHERE `id` = ?'
local UNDO_PUBLISHED_SQL = 'UPDATE ' .. T .. " SET `status` = 'published' WHERE `id` = ? AND `status` = 'archived'"
local UNDO_INSERT_SQL = 'DELETE FROM ' .. T .. ' WHERE `editor` = ? AND `kind` = ? AND `def_id` = ? AND `version` = ?'

-- requêtes à liste `IN (?, …)`, construites une fois par forme et par longueur
local inQueries = {}

--- Requête `<head> IN (?, …)<tail>` à `n` paramètres (aucune valeur dans le texte).
---@param name string
---@param head string
---@param n integer
---@param tail? string
---@return string
local function inSql(name, head, n, tail)
    local key = name .. '#' .. n
    local sql = inQueries[key]
    if not sql then
        sql = head .. ' IN (' .. rep('?', n, ', ') .. ')' .. (tail or '')
        inQueries[key] = sql
    end
    return sql
end
local SET_STATUS_HEAD = 'UPDATE ' .. T .. ' SET `status` = ? WHERE `status` = ? AND `id`'
local ARCHIVE_IDS_HEAD = 'UPDATE ' .. T .. " SET `status` = 'archived' WHERE `status` = 'published' AND `id`"
local DELETE_DRAFTS_HEAD = 'DELETE FROM ' .. T .. " WHERE `status` IN ('draft', 'trial') AND `id`"
local PURGE_HEAD = 'DELETE FROM ' .. T .. " WHERE `status` = 'archived' AND `id`"
local ROWS_HEAD = 'SELECT ' .. ROW_COLUMNS .. ' FROM ' .. T .. ' WHERE `id`'
-- identifiants au plus par requête `IN (…)` d'une lecture en lot
local ROWS_CHUNK = 100

---@param rows any
---@param err any
---@return table|nil
---@return string|nil
local function rowsOr(rows, err, what)
    if type(rows) ~= 'table' then
        VavaAtelier.log.error('définitions : %s illisible (%s)', what, tostring(err))
        return nil, 'db_error'
    end
    return rows
end

-- Lectures ---------------------------------------------------------------------------------------------------------

--- Lignes vivantes d'un atelier (brouillons, essais, publiées), sans données ni lieu.
function store.heads(editorId)
    return rowsOr(core.db.query(HEADS_SQL, { editorId }), nil, 'têtes de ' .. editorId)
end

--- Fiches connues d'un atelier, tout statut : { { kind, def_id } }.
function store.known(editorId)
    return rowsOr(core.db.query(KNOWN_SQL, { editorId }), nil, 'fiches connues de ' .. editorId)
end

--- Versions de retrait archivées d'un atelier.
function store.retired(editorId)
    return rowsOr(core.db.query(RETIRED_SQL, { editorId }), nil, 'retraits de ' .. editorId)
end

--- Plus haute version figée de chaque fiche d'un atelier : { { kind, def_id, top } }.
function store.tops(editorId)
    return rowsOr(core.db.query(TOPS_SQL, { editorId }), nil, 'versions de ' .. editorId)
end

--- Une ligne entière, ou nil ; nil, 'db_error' si la base ne répond pas.
---@param id integer
---@return table|nil
---@return string|nil
function store.row(id)
    local row, err = core.db.single(ROW_SQL, { id })
    if err then
        VavaAtelier.log.error('définitions : ligne %s illisible (%s)', tostring(id), tostring(err))
        return nil, 'db_error'
    end
    return row
end

--- Lignes entières lues en lot (`WHERE id IN (…)`, paquets de `ROWS_CHUNK`) : table id → ligne (une ligne disparue
--- est absente), ou nil, 'db_error'. Remplace une lecture par fiche (lots, rapprochement, export).
---@param ids integer[]
---@return table<integer, table>|nil
---@return string|nil
function store.rows(ids)
    local out = {}
    for first = 1, #ids, ROWS_CHUNK do
        local params = {}
        for i = first, math.min(#ids, first + ROWS_CHUNK - 1) do params[#params + 1] = ids[i] end
        local rows, err = core.db.query(inSql('rows', ROWS_HEAD, #params), params)
        if type(rows) ~= 'table' then
            VavaAtelier.log.error('définitions : %d ligne(s) illisible(s) (%s)', #params, tostring(err))
            return nil, 'db_error'
        end
        for _, row in ipairs(rows) do
            local id = tonumber(row.id)
            if id then out[math.tointeger(id) or id] = row end
        end
    end
    return out
end

--- Une version figée d'une fiche, ou nil.
function store.version(editorId, kindId, defId, version)
    local row, err = core.db.single(VERSION_SQL, { editorId, kindId, defId, version })
    if err then
        VavaAtelier.log.error('définitions : version illisible (%s)', tostring(err))
        return nil, 'db_error'
    end
    return row
end

--- Page d'historique : versions figées, des plus hautes aux plus basses, sous `before` (0 : les plus récentes).
function store.history(editorId, kindId, defId, before, limit)
    if before > 0 then
        return rowsOr(core.db.query(HISTORY_BEFORE_SQL, { editorId, kindId, defId, before, limit }), nil, 'historique')
    end
    return rowsOr(core.db.query(HISTORY_SQL, { editorId, kindId, defId, limit }), nil, 'historique')
end

--- Versions de retrait d'un même lot (rétablissement en cascade).
function store.batchRemovals(editorId, batch)
    return rowsOr(core.db.query(BATCH_REMOVALS_SQL, { editorId, batch }), nil, 'lot ' .. tostring(batch))
end

-- Brouillons -------------------------------------------------------------------------------------------------------

---@class vAvA.AtelierDraftRow
---@field editor string
---@field kind string
---@field defId string
---@field removal boolean
---@field format integer
---@field title string
---@field parent string|nil
---@field data string
---@field place string    '' : sans lieu
---@field fingerprint string
---@field base integer|nil
---@field summary string|nil
---@field accountId integer|nil
---@field author string

--- Nouveau brouillon (révision 1) : son numéro de ligne, ou nil, 'db_error'.
---@param d vAvA.AtelierDraftRow
---@return integer|nil
---@return string|nil
function store.insertDraft(d)
    local id, err = core.db.insert(INSERT_DRAFT_SQL, {
        d.editor, d.kind, d.defId, d.removal and 1 or 0, d.format, d.title, d.parent or '', d.data, d.place or '',
        d.fingerprint, d.base or 0, d.summary or '', d.accountId or 0, d.author,
    })
    if not id then
        VavaAtelier.log.error('définitions : brouillon non écrit (%s)', tostring(err))
        return nil, 'db_error'
    end
    return tonumber(id)
end

--- Sauvegarde d'un brouillon à sa révision : lignes touchées (0 : révision dépassée), ou nil, 'db_error'.
function store.updateDraft(rowId, rev, d)
    local affected, err = core.db.update(UPDATE_DRAFT_SQL, {
        d.data, d.place or '', d.parent or '', d.title, d.fingerprint, d.format, d.summary or '', rowId, rev,
    })
    if affected == nil then
        VavaAtelier.log.error('définitions : brouillon non sauvegardé (%s)', tostring(err))
        return nil, 'db_error'
    end
    return tonumber(affected) or 0
end

--- Reprise d'un brouillon par un autre membre.
function store.takeDraft(rowId, rev, accountId, label)
    local affected, err = core.db.update(TAKE_SQL, { accountId or 0, label, rowId, rev })
    if affected == nil then
        VavaAtelier.log.error('définitions : reprise non écrite (%s)', tostring(err))
        return nil, 'db_error'
    end
    return tonumber(affected) or 0
end

--- Abandon d'un brouillon à sa révision.
function store.deleteDraft(rowId, rev)
    local affected, err = core.db.update(DISCARD_SQL, { rowId, rev })
    if affected == nil then
        VavaAtelier.log.error('définitions : abandon non écrit (%s)', tostring(err))
        return nil, 'db_error'
    end
    return tonumber(affected) or 0
end

--- Lignes passées d'un statut à l'autre (essai ↔ brouillon) : lignes touchées, ou nil, 'db_error'.
---@param ids integer[]
---@param from string
---@param to string
function store.setStatus(ids, from, to)
    if #ids == 0 then return 0 end
    local params = { to, from }
    for i, id in ipairs(ids) do params[i + 2] = id end
    local affected, err = core.db.update(inSql('status', SET_STATUS_HEAD, #ids), params)
    if affected == nil then
        VavaAtelier.log.error('définitions : statut non écrit (%s)', tostring(err))
        return nil, 'db_error'
    end
    return tonumber(affected) or 0
end

-- Transactions ---------------------------------------------------------------------------------------------------

--- Lance une transaction (liste de morceaux { query, values }) : true, ou nil, 'db_error'.
---@param statements table[]
---@return boolean|nil
---@return string|nil
function store.transaction(statements)
    if #statements == 0 then return true end
    local ok, err = core.db.transaction(statements)
    if not ok then
        VavaAtelier.log.error('définitions : transaction refusée (%d requêtes) : %s', #statements, tostring(err))
        return nil, 'db_error'
    end
    return true
end

-- Morceaux : ancienne publiée archivée ; brouillon publié ; brouillon de retrait archivé avec son numéro ; retrait
-- en cascade d'une publiée (copie de retrait) ; retour à une version (copie) ; version publiée d'une graine ou d'un
-- import.
function store.archiveStep(rowId) return { query = ARCHIVE_SQL, values = { rowId } } end

-- publication et retrait d'un brouillon à sa révision lue : une révision changée ne touche aucune ligne, ce que
-- l'appelant vérifie après la transaction (server/lifecycle.lua › lotWritten)
function store.publishStep(rowId, version, batch, by, summary, rev)
    return { query = PUBLISH_SQL, values = { version, batch, by, summary or '', rowId, rev } }
end

function store.retireStep(rowId, version, batch, by, summary, rev)
    return { query = RETIRE_SQL, values = { version, batch, by, summary or '', rowId, rev } }
end

function store.cascadeStep(publishedRowId, version, batch, accountId, author)
    return { query = CASCADE_SQL, values = { version, batch, accountId or 0, author, author, publishedRowId } }
end

function store.restoreStep(sourceRowId, version, batch, accountId, author, summary)
    return { query = RESTORE_SQL,
        values = { version, batch, accountId or 0, author, author, summary or '', sourceRowId } }
end

---@class vAvA.AtelierPublishedRow
---@field editor string
---@field kind string
---@field defId string
---@field version integer
---@field origin 'seed'|'import'
---@field format integer
---@field title string
---@field parent string|nil
---@field data string
---@field place string
---@field fingerprint string
---@field accountId integer|nil
---@field author string
---@field summary string|nil

---@param p vAvA.AtelierPublishedRow
function store.insertPublishedStep(p)
    return { query = INSERT_PUBLISHED_SQL, values = {
        p.editor, p.kind, p.defId, p.version, p.origin, p.format, p.title, p.parent or '', p.data, p.place or '',
        p.fingerprint, p.accountId or 0, p.author, p.author, p.summary or '',
    } }
end

--- Morceaux de l'annulation d'un lot (shared/lifecycle.lua › undo) pour un atelier.
---@param editorId string
---@param undo { toDraft: integer[], toPublished: integer[], delete: table[] }
---@return table[]
function store.undoSteps(editorId, undo)
    local steps = {}
    for _, ref in ipairs(undo.delete) do
        steps[#steps + 1] = { query = UNDO_INSERT_SQL, values = { editorId, ref.kind, ref.id, ref.version } }
    end
    for _, id in ipairs(undo.toDraft) do steps[#steps + 1] = { query = UNDO_DRAFT_SQL, values = { id } } end
    for _, id in ipairs(undo.toPublished) do steps[#steps + 1] = { query = UNDO_PUBLISHED_SQL, values = { id } } end
    return steps
end

-- Démarrage : réparation et purge --------------------------------------------------------------------------------

--- Essais rendus aux brouillons (un essai ne survit jamais à un redémarrage) : lignes touchées, ou nil.
function store.resetTrials()
    local affected, err = core.db.update(RESET_TRIALS_SQL, {})
    if affected == nil then
        VavaAtelier.log.error('définitions : essais non rendus aux brouillons (%s)', tostring(err))
        return nil, 'db_error'
    end
    return tonumber(affected) or 0
end

--- Lignes vivantes de tous les ateliers (réparation des doublons) : sans les données.
function store.liveRows()
    return rowsOr(core.db.query(LIVE_ROWS_SQL, {}), nil, 'lignes vivantes')
end

--- Doublons archivés (publiées en trop) et supprimés (brouillons en trop), en une transaction.
---@param archive integer[]
---@param delete integer[]
function store.repair(archive, delete)
    local steps = {}
    if #archive > 0 then
        steps[#steps + 1] = { query = inSql('archive', ARCHIVE_IDS_HEAD, #archive), values = archive }
    end
    if #delete > 0 then
        local values = {}
        for i, id in ipairs(delete) do values[i] = id end
        steps[#steps + 1] = { query = inSql('deleteDraft', DELETE_DRAFTS_HEAD, #delete), values = values }
    end
    return store.transaction(steps)
end

--- Fiches qui ont plus de `keep` versions figées.
function store.purgeCandidates(keep)
    return rowsOr(core.db.query(PURGE_CANDIDATES_SQL, { keep }), nil, 'historique à purger')
end

--- Versions figées d'une fiche (purge).
function store.versions(editorId, kindId, defId)
    return rowsOr(core.db.query(VERSIONS_SQL, { editorId, kindId, defId }), nil, 'versions')
end

--- Supprime des versions figées (purge) : jamais une ligne vivante.
---@param ids integer[]
function store.deleteVersions(ids)
    if #ids == 0 then return 0 end
    local affected, err = core.db.update(inSql('purge', PURGE_HEAD, #ids), ids)
    if affected == nil then
        VavaAtelier.log.warn('définitions : purge non écrite (%s)', tostring(err))
        return nil, 'db_error'
    end
    return tonumber(affected) or 0
end

--- Texte d'une liste d'identifiants pour la console.
---@param ids integer[]
---@return string
function store.describe(ids)
    local out = {}
    for i, id in ipairs(ids) do out[i] = tostring(id) end
    return concat(out, ', ')
end
