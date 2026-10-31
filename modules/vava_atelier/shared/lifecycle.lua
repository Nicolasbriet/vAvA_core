--[[
    vava_atelier/shared/lifecycle.lua
    Rôle : logique pure du cycle de vie d'une fiche gardée (§ 5.6, § 5.7, § 7.5 de la spec T-101) :
             - situation d'une fiche vue par l'appelant (nouvelle, publiée, son brouillon, son essai, son retrait, le
               brouillon d'un autre, retirée) et table des transitions permises : tout ce qui n'y est pas est refusé
               avec un code (`draft_taken`, `not_holder`, `no_draft`…) ;
             - numéros : une version prend son numéro à la publication (plus haute version figée + 1) ;
             - lot d'une publication : brouillons du même tenant dont le parent est la fiche (récursivement), borné ;
               parent publié ou dans le lot ; retrait et rétablissement en cascade ; ordre des appels au module
               (retraits des enfants d'abord, puis applications des parents d'abord, `last` au dernier) ; lot passé
               au module (références légères pour `validate`, data comprise pour l'unique `validateLot`) ;
             - purge de l'historique, réparation au démarrage, annulation d'un lot refusé par le module ;
             - pied de fiche (identifiants des boutons) selon la situation.
           Testée : tests/spec/atelier_lifecycle_spec.lua.
    Dépendances : shared/constants.lua, shared/fingerprint.lua
]]

local type, ipairs, pairs = type, ipairs, pairs
local sort = table.sort

local DEF = VavaAtelier.DEF
local FOOTER = VavaAtelier.FOOTER

local lc = {}
VavaAtelier.lifecycle = lc

-- Situations ---------------------------------------------------------------------------------------------------------

---@class vAvA.AtelierHeadView
---@field published? table   version publiée (au moins `version`)
---@field draft? { holder: integer|nil, status: string, removal: boolean }
---@field retired? table     dernière version de retrait d'une fiche retirée

--- Situation d'une fiche pour un compte : new, published, retired, own_draft, own_trial, own_removal, other_draft,
--- other_trial, other_removal.
---@param head vAvA.AtelierHeadView|nil
---@param accountId integer|nil
---@return string
function lc.situation(head, accountId)
    if not head then return 'new' end
    local draft = head.draft
    if draft then
        local own = accountId ~= nil and draft.holder == accountId
        local prefix = own and 'own_' or 'other_'
        if draft.removal then return prefix .. 'removal' end
        if draft.status == 'trial' then return prefix .. 'trial' end
        return prefix .. 'draft'
    end
    if head.published then return 'published' end
    if head.retired then return 'retired' end
    return 'new'
end

-- Transitions permises : action → situation → true ou code de refus. Une situation absente : `unknown_entry`.
local OTHER = { 'other_draft', 'other_trial', 'other_removal' }
local function rule(map, others)
    for _, situation in ipairs(OTHER) do
        if map[situation] == nil then map[situation] = others end
    end
    return map
end

lc.RULES = {
    save = rule({ new = true, published = true, own_draft = true, own_trial = true, own_removal = 'draft_open' },
        'draft_taken'),
    trial = rule({ own_draft = true, own_trial = 'trial_busy', own_removal = 'not_allowed', published = 'no_draft' },
        'not_holder'),
    endTrial = rule({ own_trial = true, own_draft = 'stale', own_removal = 'stale', published = 'no_draft' },
        'not_holder'),
    publish = rule({ own_draft = true, own_trial = true, own_removal = true, published = 'no_draft' }, 'not_holder'),
    discard = rule({ own_draft = true, own_trial = true, own_removal = true, published = 'no_draft' }, 'not_holder'),
    retire = rule({ published = true, own_draft = 'draft_open', own_trial = 'draft_open', own_removal = 'draft_open' },
        'draft_taken'),
    take = rule({ own_draft = 'not_allowed', own_trial = 'not_allowed', own_removal = 'not_allowed',
        published = 'no_draft' }, true),
    restore = rule({ published = true, retired = true, own_draft = true, own_trial = true, own_removal = true }, true),
}

--- Une action est-elle permise ? `member` : droit effectif de l'atelier ; `published` : la fiche a une version
--- publiée. Rend true, 'discard' (retirer un brouillon jamais publié = l'abandonner), ou false et un code.
---@param action string
---@param situation string
---@param member boolean
---@param published boolean
---@return boolean|string ok
---@return string|nil code
function lc.allowed(action, situation, member, published)
    if not member then return false, 'not_allowed' end
    local rules = lc.RULES[action]
    if not rules then return false, 'not_allowed' end
    if action == 'retire' and not published and (situation == 'own_draft' or situation == 'own_trial') then
        return 'discard'
    end
    local verdict = rules[situation]
    if verdict == true then return true end
    return false, verdict or 'unknown_entry'
end

-- Numéros ----------------------------------------------------------------------------------------------------------

--- Numéro de la prochaine version : plus haute version figée + 1 (1 pour une fiche nouvelle).
---@param maxFrozen integer|nil
---@return integer
function lc.nextVersion(maxFrozen)
    return (maxFrozen or 0) + 1
end

--- Retour à une version : seule une ancienne version archivée qui n'est pas un retrait se rétablit ; elle devient une
--- nouvelle version (plus haute + 1) qui retient d'où elle vient. nil, 'not_archived' sinon (la publiée, un retrait,
--- un brouillon).
---@param row { status: string, removal: boolean|integer|nil, version: integer|nil }
---@param maxFrozen integer
---@return { version: integer, restoredFrom: integer }|nil
---@return string|nil err
function lc.restorePlan(row, maxFrozen)
    local removal = row.removal == true or row.removal == 1
    if row.status ~= 'archived' or removal or not row.version then return nil, 'not_archived' end
    return { version = lc.nextVersion(maxFrozen), restoredFrom = row.version }
end

-- Lots -------------------------------------------------------------------------------------------------------------

---@class vAvA.AtelierDraftRef
---@field kind string
---@field id string
---@field parent string|nil
---@field holder integer|nil
---@field removal boolean|nil

local function byDepth(a, b)
    if a.depth ~= b.depth then return a.depth < b.depth end
    if a.kind ~= b.kind then return a.kind < b.kind end
    return a.id < b.id
end

--- Fiches enfants d'une publication : brouillons (retraits compris) du même tenant dont le parent est la fiche,
--- récursivement (profondeur 3 au plus, fiche comprise). Rend la liste triée (profondeur, type, identifiant), chaque
--- élément étant celui reçu avec `depth` ; nil, 'full' au-delà de `maxChildren`.
---@param main { kind: string, id: string }
---@param drafts vAvA.AtelierDraftRef[]
---@param kinds table<string, string|false>  type → type parent
---@param holder integer|nil
---@param maxChildren integer
---@return table[]|nil
---@return string|nil err
function lc.bundle(main, drafts, kinds, holder, maxChildren)
    local out, seen = {}, { [main.kind .. '|' .. main.id] = true }
    local frontier = { { kind = main.kind, id = main.id, depth = 1 } }
    while #frontier > 0 do
        local nextFrontier = {}
        for _, node in ipairs(frontier) do
            if node.depth < DEF.parentDepth then
                for _, draft in ipairs(drafts) do
                    local key = draft.kind .. '|' .. draft.id
                    if not seen[key] and draft.holder == holder and kinds[draft.kind] == node.kind
                        and draft.parent == node.id then
                        seen[key] = true
                        local item = { depth = node.depth + 1 }
                        for k, v in pairs(draft) do if item[k] == nil then item[k] = v end end
                        out[#out + 1] = item
                        if #out > maxChildren then return nil, 'full' end
                        nextFrontier[#nextFrontier + 1] = item
                    end
                end
            end
        end
        frontier = nextFrontier
    end
    sort(out, byDepth)
    return out
end

---@class vAvA.AtelierLotItem
---@field kind string
---@field id string
---@field data? table
---@field parent? string
---@field place? table
---@field removal? boolean

--- Lot d'une écriture tel que le module le reçoit. Sans `withData` : références légères `{ kind, id, parent?,
--- removal, place? }` (≈ 100 octets par fiche), le `ctx.bundle` de chaque `validate` (le lot n'est jamais resérialisé
--- entier pour chaque fiche) ; avec : la même liste et la `data` de chaque fiche, pour l'unique appel à `validateLot`.
--- Les tables du lieu et de la data ne sont pas copiées (lecture seule).
---@param items vAvA.AtelierLotItem[]
---@param withData? boolean
---@return table[]
function lc.lot(items, withData)
    local out = {}
    for i, item in ipairs(items) do
        local ref = { kind = item.kind, id = item.id, parent = item.parent, place = item.place,
            removal = item.removal == true }
        if withData then ref.data = item.data end
        out[i] = ref
    end
    return out
end

--- Parent d'une fiche prêt : type sans parent, parent dans le lot (`inBundle['type|id']`), ou parent publié.
---@param kindId string
---@param parentId string|nil
---@param kinds table<string, string|false>
---@param isPublished fun(kind: string, id: string): boolean
---@param inBundle? table<string, boolean>
---@return boolean ok
---@return string|nil err  parent_missing
function lc.parentReady(kindId, parentId, kinds, isPublished, inBundle)
    local parentKind = kinds[kindId]
    if not parentKind then return true end
    if type(parentId) ~= 'string' then return false, 'parent_missing' end
    if inBundle and inBundle[parentKind .. '|' .. parentId] then return true end
    if isPublished(parentKind, parentId) then return true end
    return false, 'parent_missing'
end

--- Retrait en cascade : fiches publiées descendantes d'une fiche (récursivement), triées des plus proches aux plus
--- profondes ; nil, 'full' au-delà de `maxChildren`.
---@param kindId string
---@param id string
---@param kinds table<string, string|false>
---@param published { kind: string, id: string, parent: string|nil }[]
---@param maxChildren integer
---@return table[]|nil
---@return string|nil err
function lc.cascade(kindId, id, kinds, published, maxChildren)
    local refs = {}
    for i, entry in ipairs(published) do
        refs[i] = { kind = entry.kind, id = entry.id, parent = entry.parent, holder = 0 }
    end
    return lc.bundle({ kind = kindId, id = id }, refs, kinds, 0, maxChildren)
end

--- Rétablissement en cascade : enfants retirés dans le même lot que la fiche (même `batch` de leur version de
--- retrait), chacun avec la version à rétablir (celle d'avant son retrait).
---@param batch integer|nil  lot de la version de retrait de la fiche rétablie (nil : fiche vivante, aucun enfant)
---@param main { kind: string, id: string }
---@param retired { kind: string, id: string, batch: integer|nil, version: integer }[]
---@return { kind: string, id: string, version: integer }[]
function lc.restoreCascade(batch, main, retired)
    local out = {}
    if not batch then return out end
    for _, entry in ipairs(retired) do
        if entry.batch == batch and not (entry.kind == main.kind and entry.id == main.id) and entry.version > 1 then
            out[#out + 1] = { kind = entry.kind, id = entry.id, version = entry.version - 1 }
        end
    end
    sort(out, function(a, b)
        if a.kind ~= b.kind then return a.kind < b.kind end
        return a.id < b.id
    end)
    return out
end

--- Ordre des appels au module pour un lot : retraits des plus profonds aux parents, puis applications des parents aux
--- plus profonds ; `last = true` sur le dernier. Rend une nouvelle liste (éléments copiés).
---@param items { kind: string, id: string, depth: integer, removal: boolean|nil }[]
---@return table[]
function lc.callOrder(items)
    local removals, applies = {}, {}
    for _, item in ipairs(items) do
        local copy = {}
        for k, v in pairs(item) do copy[k] = v end
        copy.last = nil
        if item.removal then removals[#removals + 1] = copy else applies[#applies + 1] = copy end
    end
    sort(removals, function(a, b)
        if a.depth ~= b.depth then return a.depth > b.depth end
        if a.kind ~= b.kind then return a.kind < b.kind end
        return a.id < b.id
    end)
    sort(applies, byDepth)
    local out = removals
    for _, item in ipairs(applies) do out[#out + 1] = item end
    if #out > 0 then out[#out].last = true end
    return out
end

-- Historique, réparation, annulation ----------------------------------------------------------------------------------

--- Versions d'une fiche à purger : on garde les `keep` plus hautes ; jamais la publiée ; la plus haute (dernière ligne
--- d'une fiche retirée) est toujours gardée.
---@param versions { id: integer, version: integer, status: string }[]
---@param keep integer
---@return integer[] ids
function lc.purge(versions, keep)
    local sorted = {}
    for i, row in ipairs(versions) do sorted[i] = row end
    sort(sorted, function(a, b) return a.version > b.version end)
    local out = {}
    for i, row in ipairs(sorted) do
        if i > keep and i > 1 and row.status ~= 'published' then out[#out + 1] = row.id end
    end
    sort(out)
    return out
end

--- Réparation d'une fiche au démarrage : plusieurs publiées → la plus haute reste, les autres sont archivées ;
--- plusieurs brouillons → le plus récent reste (puis le plus grand numéro de ligne), les autres sont supprimés.
---@param rows { id: integer, version: integer|nil, status: string, at: number|nil }[]
---@return { archive: integer[], delete: integer[] }
function lc.repair(rows)
    local published, drafts = {}, {}
    for _, row in ipairs(rows) do
        if row.status == 'published' then
            published[#published + 1] = row
        elseif row.status == 'draft' or row.status == 'trial' then
            drafts[#drafts + 1] = row
        end
    end
    local plan = { archive = {}, delete = {} }
    sort(published, function(a, b) return (a.version or 0) > (b.version or 0) end)
    for i = 2, #published do plan.archive[#plan.archive + 1] = published[i].id end
    sort(drafts, function(a, b)
        if (a.at or 0) ~= (b.at or 0) then return (a.at or 0) > (b.at or 0) end
        return a.id > b.id
    end)
    for i = 2, #drafts do plan.delete[#plan.delete + 1] = drafts[i].id end
    sort(plan.archive)
    sort(plan.delete)
    return plan
end

---@class vAvA.AtelierBatchPlan
---@field rows { id: integer, before: string }[]                 lignes changées par le lot et leur statut d'avant
---@field inserted { kind: string, id: string, version: integer }[]  lignes créées (retraits en cascade, copies)

--- Plan inverse d'un lot refusé par le module : lignes du lot rendues au brouillon (version retirée), ancienne publiée
--- rendue à `published`, lignes créées supprimées.
---@param plan vAvA.AtelierBatchPlan
---@return { toDraft: integer[], toPublished: integer[], delete: table[] }
function lc.undo(plan)
    local out = { toDraft = {}, toPublished = {}, delete = {} }
    for _, row in ipairs(plan.rows or {}) do
        if row.before == 'published' then
            out.toPublished[#out.toPublished + 1] = row.id
        elseif row.before == 'draft' or row.before == 'trial' then
            out.toDraft[#out.toDraft + 1] = row.id
        end
    end
    for _, ref in ipairs(plan.inserted or {}) do
        out.delete[#out.delete + 1] = { kind = ref.kind, id = ref.id, version = ref.version }
    end
    return out
end

--- Jeton d'un résumé : empreinte de ce qu'il décrit (ligne principale et sa révision, révisions des enfants, version
--- publiée, version visée). 16 chiffres hexadécimaux.
---@param parts table
---@return string|nil
function lc.token(parts)
    return VavaAtelier.fingerprint(parts)
end

-- Pied de fiche -----------------------------------------------------------------------------------------------------

---@class vAvA.AtelierFooterOptions
---@field stored boolean       atelier gardé (sinon : « Vérifier » seul)
---@field hasTrial boolean     l'atelier propose un essai
---@field versioned boolean    la fiche a au moins une version figée (« Historique »)
---@field archived? { removal: boolean, unreadable: boolean }  version archivée lue

--- Boutons du pied d'une fiche : { { id, primary?, link?, removal? } } (libellés posés par le serveur).
---@param situation string
---@param options vAvA.AtelierFooterOptions
---@return table[]
function lc.footer(situation, options)
    if not options.stored then return { { id = FOOTER.CHECK, primary = true } } end
    if options.archived then
        if options.archived.removal or options.archived.unreadable then return {} end
        return { { id = FOOTER.RESTORE, primary = true } }
    end
    local out = {}
    local function add(id, extra)
        local button = { id = id }
        for k, v in pairs(extra or {}) do button[k] = v end
        out[#out + 1] = button
    end
    local history = options.versioned
    if situation == 'new' then
        add(FOOTER.SAVE, { primary = true })
        add(FOOTER.CHECK, { link = true })
    elseif situation == 'published' then
        add(FOOTER.SAVE, { primary = true })
        add(FOOTER.HISTORY, { link = true })
        add(FOOTER.RETIRE, { link = true })
        add(FOOTER.CHECK, { link = true })
    elseif situation == 'own_draft' then
        add(FOOTER.SAVE)
        if options.hasTrial then add(FOOTER.TRIAL) end
        add(FOOTER.PUBLISH, { primary = true })
        if history then add(FOOTER.HISTORY, { link = true }) end
        add(FOOTER.DISCARD, { link = true })
        add(FOOTER.CHECK, { link = true })
    elseif situation == 'own_trial' then
        add(FOOTER.SAVE)
        add(FOOTER.END_TRIAL)
        add(FOOTER.PUBLISH, { primary = true })
        if history then add(FOOTER.HISTORY, { link = true }) end
        add(FOOTER.DISCARD, { link = true })
    elseif situation == 'own_removal' then
        add(FOOTER.PUBLISH, { primary = true, removal = true })
        if history then add(FOOTER.HISTORY, { link = true }) end
        add(FOOTER.DISCARD, { link = true, removal = true })
    elseif situation == 'other_draft' or situation == 'other_trial' or situation == 'other_removal' then
        add(FOOTER.TAKE)
        if history then add(FOOTER.HISTORY, { link = true }) end
    end
    return out
end
