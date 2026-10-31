--[[
    vava_atelier/server/providers.lua
    Rôle : remplace les points d'extension de T-100 par la base pour les ateliers gardés (§ 3, § 6.2 de la spec
           T-101) : liste d'un type (têtes en mémoire : publiées et brouillons jamais publiés, titre du brouillon s'il
           n'y a pas de publiée), indice et ton d'une ligne vus par l'appelant (« Votre brouillon », « Brouillon de
           … », « En essai », « Retrait en attente », « Jamais publié », « Publiée, mais refusée en jeu »), fiche lue
           en base, brouillons de l'accueil (« Vos brouillons », les plus récents d'abord) et étiquette d'une carte
           (« 1 en essai », sinon le nombre de fiches publiées du premier type). Un atelier en lecture garde le
           comportement de T-100 (ce que dit le module).
    Dépendances : shared/constants.lua, config.lua, shared/text.lua, shared/changes.lua, bridge/server.lua,
                  server/core.lua, server/editors.lua, server/index.lua, server/trials.lua, server/lifecycle.lua
]]

local ipairs, format, tonumber = ipairs, string.format, tonumber
local match = string.match
local sort = table.sort

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local texts = cfg.texts
local Bridge = VavaAtelier.bridge
local providers = VavaAtelier.providers
local editors, index, trials, cycle = VavaAtelier.editors, VavaAtelier.index, VavaAtelier.trials, VavaAtelier.cycle
local text, changes = VavaAtelier.text, VavaAtelier.changes
local OUT = VavaAtelier.OUT

-- fournisseurs de T-100 (lecture chez le module), gardés pour les ateliers en lecture
local moduleIndex = providers.index
local moduleTag = providers.tag

--- Liste d'un type : têtes vivantes (atelier gardé), sinon la liste du module.
function providers.index(editor, kindId)
    if not editor.stored then return moduleIndex(editor, kindId) end
    if index.state(editor.id) ~= 'ready' then return false end
    local out = {}
    for i, head in ipairs(index.live(editor.id, kindId)) do out[i] = { id = head.id, title = head.title } end
    return true, out
end

--- Indice et ton d'une ligne de liste, vus par un compte ; nil pour une fiche publiée sans brouillon.
---@param editor vAvA.AtelierEditor
---@param kindId string
---@param id string
---@param accountId integer|nil
---@return string|nil hint
---@return string|nil tone
function providers.hint(editor, kindId, id, accountId)
    if not editor.stored then return nil end
    local head = index.get(editor.id, kindId, id)
    if not head then return nil end
    local hints = texts.hints
    local draft = head.draft
    if draft then
        if draft.removal then return hints.removal, 'removal' end
        if draft.status == 'trial' then return hints.trial, 'trial' end
        if accountId ~= nil and draft.holder == accountId then
            return head.published and hints.mine or hints.new, head.published and 'draft' or 'new'
        end
        return text.truncate(format(hints.other, draft.holderLabel or texts.console), OUT.hint), 'draft'
    end
    if head.refused then return hints.refused, 'refused' end
    return nil
end

--- Étiquette d'une carte : « 1 en essai » si un essai est en cours, sinon le nombre de fiches publiées du premier
--- type (atelier gardé) ; T-100 sinon.
function providers.tag(editorId)
    local editor = editors.get(editorId)
    if not editor or not editor.stored then return moduleTag(editorId) end
    local running = trials.inEditor(editorId)
    if running > 0 then return { text = format(texts.tagTrial, running), tone = 'trial' } end
    if index.state(editorId) ~= 'ready' then return nil end
    local kind = editor.kinds[editor.firstKind].def
    local count = index.publishedCount(editorId, editor.firstKind)
    return { text = format('%d %s', count, count > 1 and kind.nounPlural or kind.noun) }
end

--- Nombre en tête d'un résumé court (« 3 réglages changés » → 3).
local function leadingCount(summary)
    return tonumber(match(summary or '', '^(%d+)')) or 0
end

--- Brouillons d'un membre dans ses ateliers visibles, les plus récents d'abord : { { editor, kind, id, title, line,
--- status } } (`drafts.homeLines` au plus).
function providers.drafts(source, visibleIds)
    local accountId = Bridge.AccountId(source)
    if not accountId then return {} end
    local stored = {}
    for _, editorId in ipairs(visibleIds) do
        local editor = editors.get(editorId)
        if editor and editor.stored then stored[#stored + 1] = editorId end
    end
    local found = index.draftsOf(accountId, stored)
    sort(found, function(a, b)
        local ta, tb = a.head.draft.at or 0, b.head.draft.at or 0
        if ta ~= tb then return ta > tb end
        return a.head.id < b.head.id
    end)
    local out = {}
    for _, item in ipairs(found) do
        if #out >= cfg.drafts.homeLines then break end
        local editor = editors.get(item.editor)
        local head = item.head
        local kind = editor.kinds[head.kind].def
        local draft = head.draft
        -- enfants du même tenant sous cette fiche : ajoutés, retirés, changés
        local groups = {}
        for _, kindId in ipairs(editor.kindOrder) do
            if editor.parents[kindId] == head.kind then
                local childKind = editor.kinds[kindId].def
                local g = { noun = childKind.noun, nounPlural = childKind.nounPlural,
                    feminine = changes.feminine(childKind), added = 0, removed = 0, changed = 0 }
                for _, ref in ipairs(index.draftRefs(item.editor)) do
                    if ref.kind == kindId and ref.parent == head.id and ref.holder == accountId then
                        local child = index.get(item.editor, ref.kind, ref.id)
                        if ref.removal then g.removed = g.removed + 1
                        elseif child and child.published then g.changed = g.changed + 1
                        else g.added = g.added + 1 end
                    end
                end
                groups[#groups + 1] = g
            end
        end
        local childSummary, childCount = changes.children(groups, texts.changes)
        local parts = {}
        if draft.summary and draft.summary ~= '' then parts[#parts + 1] = draft.summary end
        if childSummary ~= '' then parts[#parts + 1] = childSummary end
        local line = changes.draftLine(kind, {
            new = head.published == nil, trial = draft.status == 'trial', removal = draft.removal,
            summary = table.concat(parts, ', '), count = leadingCount(draft.summary) + childCount,
        }, texts.drafts)
        out[#out + 1] = {
            editor = item.editor, kind = head.kind, id = head.id, title = head.title, line = line,
            status = draft.status == 'trial' and 'trial' or 'draft',
        }
    end
    return out
end

--- Fiche d'un atelier gardé, lue en base (server/lifecycle.lua).
providers.readStored = cycle.read
