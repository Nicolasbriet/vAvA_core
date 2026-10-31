--[[
    vava_atelier/server/history.lua
    Rôle : lecture seule de ce qui est gardé (§ 6.2, § 7.5 de la spec T-101) : historique d'une fiche (versions figées,
           des plus hautes aux plus basses, par pages), une version en lecture (champs, état, « Revenir à cette
           version » s'il y a lieu), fiches retirées du royaume d'un type (les plus récemment retirées d'abord) ; purge
           de l'historique au démarrage, dans un fil (on garde `history.keep` versions par fiche, jamais la publiée ni
           la dernière ligne d'une fiche retirée).
    Dépendances : shared/constants.lua, config.lua, shared/text.lua, shared/formvalues.lua, shared/journaltext.lua,
                  shared/changes.lua, shared/lifecycle.lua, server/core.lua, server/entries.lua, server/store.lua,
                  server/index.lua, server/calls.lua, server/lifecycle.lua
]]

local ipairs, format, tostring = ipairs, string.format, tostring
local ceil, max, min = math.ceil, math.max, math.min
local CreateThread = CreateThread
local time = os.time

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local texts = cfg.texts
local entries, store, index, calls, cycle = VavaAtelier.entries, VavaAtelier.store, VavaAtelier.index,
    VavaAtelier.calls, VavaAtelier.cycle
local text, fv, jt, changes, lc = VavaAtelier.text, VavaAtelier.formvalues, VavaAtelier.journaltext,
    VavaAtelier.changes, VavaAtelier.lifecycle
local OUT = VavaAtelier.OUT

local history = {}
VavaAtelier.history = history

--- Fiche connue (vivante ou retirée), atelier disponible : head ; nil, code.
local function known(ctx, id)
    local ok, code = cycle.available(ctx.editor)
    if not ok then return nil, code end
    local head = index.get(ctx.editor.id, ctx.kind.def.id, id)
    if not head then return nil, 'unknown_entry' end
    return head
end

--- RPC history : { versions = { { version, status, removal, restoredFrom?, summary?, author, when } }, more } ;
--- 20 lignes au plus (`history.pageLines`), ≈ 150 octets chacune : ≤ 4 Ko.
---@param ctx vAvA.AtelierContext
---@param id string
---@param before integer  0 : les plus récentes
function history.list(ctx, id, before)
    local head, code = known(ctx, id)
    if not head then return false, code end
    local limit = cfg.history.pageLines
    local rows, err = store.history(ctx.editor.id, ctx.kind.def.id, id, before, limit + 1)
    if not rows then return false, err end
    local now, versions = time(), {}
    for i = 1, min(#rows, limit) do
        local row = rows[i]
        versions[i] = {
            version = index.toInt(row.version), status = row.status, removal = index.toInt(row.removal) == 1,
            restoredFrom = index.toInt(row.restored_from),
            summary = jt.summary(row.summary),
            author = text.truncate(tostring(row.published_by or row.author_label or texts.console), OUT.actor),
            when = jt.age(now, index.toInt(row.at) or now),
        }
    end
    return true, { versions = versions, more = #rows > limit }
end

--- RPC version : une version figée en lecture : { id, title, version, values, labels, warnings?, state, footer }.
function history.version(ctx, id, version)
    local head, code = known(ctx, id)
    if not head then return false, code end
    local editor, kind = ctx.editor, ctx.kind
    local row, err = store.version(editor.id, kind.def.id, id, version)
    if err then return false, err end
    if not row then return false, 'unknown_version' end
    if ctx.session then ctx.session.entry = kind.def.id .. '|' .. id end
    local entry = calls.entryOf(editor, kind, row)
    if not entry then return false, 'unreadable' end
    local removal = index.toInt(row.removal) == 1
    local values = fv.toPacket(kind.def.form, entry.data)
    local state
    if row.status == 'published' then
        state = cycle.stateOf(head, 'published')
    elseif removal then
        state = { label = format(texts.states.archived, version), tone = 'removal' }
    else
        state = { label = format(texts.states.archived, version), tone = 'archived' }
    end
    local footer = {}
    if row.status == 'archived' then
        footer = cycle.footerOf(editor, lc.situation(head, ctx.accountId), head,
            { removal = removal, unreadable = false })
    end
    return true, {
        id = id, title = calls.titleOf(kind, entry.data, head.title), version = version, values = values,
        labels = entries.labels(editor, kind.def.form, values.s), warnings = #entry.reset > 0 and entry.reset or nil,
        state = state, footer = footer,
    }
end

--- RPC removed : { total, page, pages, entries = { { id, title, hint } } } (50 au plus).
function history.removed(ctx, page)
    local ok, code = cycle.available(ctx.editor)
    if not ok then return false, code end
    local kindDef = ctx.kind.def
    local list = index.retired(ctx.editor.id, kindDef.id)
    local size = cfg.limits.pageSize
    local pages = max(1, ceil(#list / size))
    page = min(page, pages)
    local now, out = time(), {}
    local word = texts.hints.retired[changes.feminine(kindDef) and 'feminine' or 'masculine']
    for i = (page - 1) * size + 1, min(#list, page * size) do
        local head = list[i]
        out[#out + 1] = { id = head.id, title = head.title,
            hint = text.truncate(format(word, jt.age(now, head.retired.at or now)), OUT.hint) }
    end
    return true, { total = #list, page = page, pages = pages, entries = out }
end

--- Purge de l'historique (au démarrage, dans un fil).
function history.purge()
    if not cfg.history.purgeOnStart then return end
    CreateThread(function()
        local keep = cfg.history.keep
        local fiches = store.purgeCandidates(keep)
        if not fiches then return end
        local removed = 0
        for _, fiche in ipairs(fiches) do
            local versions = store.versions(fiche.editor, fiche.kind, fiche.def_id)
            if versions then
                local list = {}
                for i, row in ipairs(versions) do
                    list[i] = { id = index.toInt(row.id), version = index.toInt(row.version), status = row.status }
                end
                local ids = lc.purge(list, keep)
                local count = store.deleteVersions(ids)
                removed = removed + (count or 0)
            end
        end
        VavaAtelier.log.info('définitions : %d version(s) ancienne(s) retirée(s) (%d gardées par fiche)', removed, keep)
    end)
end
