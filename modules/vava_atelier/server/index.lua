--[[
    vava_atelier/server/index.lua
    Rôle : têtes des fiches gardées, en mémoire, par atelier (§ 5.8 de la spec T-101) : pour chaque fiche, sa version
           publiée, son brouillon (tenant, révision, statut, retrait), sa plus haute version figée, son retrait, sans
           les données (≈ 200 octets par fiche). Les listes, la recherche, les étiquettes, l'accueil et les contrôles
           des RPC lisent ici, jamais la base. État d'un atelier (`syncing`, `ready`, `failed`) ; verrou par fiche
           (une écriture à la fois, repris au-delà de `limits.busyMs`) ; identifiants rendus par la liste du module
           (identifiant d'une fiche nouvelle).
    Dépendances : shared/constants.lua, config.lua, shared/text.lua, server/core.lua
]]

local pairs, ipairs, tonumber, tostring = pairs, ipairs, tonumber, tostring
local tointeger = math.tointeger
local sort = table.sort
local GetGameTimer = GetGameTimer

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local text = VavaAtelier.text

local index = {}
VavaAtelier.index = index

---@class vAvA.AtelierHead
---@field kind string
---@field id string
---@field title string
---@field search string
---@field top integer|nil          plus haute version figée
---@field published table|nil      { row, version, title, parent, format, fingerprint, at }
---@field draft table|nil          { row, rev, status, removal, holder, holderLabel, base, title, parent, summary, at }
---@field retired table|nil        { row, version, title, batch, at }
---@field refused boolean|nil      publiée, mais refusée en jeu à la dernière synchronisation

-- atelier → { state, kinds = { [type] = { byId, sorted } }, moduleIds = { [type] = { [id] = true } } }
local editors = {}
-- verrous : 'atelier|type|id' → { token, since }
local locks = {}

---@param editorId string
---@return table
local function slot(editorId)
    local entry = editors[editorId]
    if not entry then
        entry = { state = 'syncing', kinds = {}, moduleIds = {} }
        editors[editorId] = entry
    end
    return entry
end

---@param entry table
---@param kindId string
---@return table
local function kindSlot(entry, kindId)
    local kind = entry.kinds[kindId]
    if not kind then
        kind = { byId = {}, sorted = nil }
        entry.kinds[kindId] = kind
    end
    return kind
end

--- État d'un atelier gardé : syncing | ready | failed ; nil s'il n'est pas suivi.
---@param editorId string
---@return string|nil
function index.state(editorId)
    local entry = editors[editorId]
    return entry and entry.state or nil
end

---@param editorId string
---@param state 'syncing'|'ready'|'failed'
function index.setState(editorId, state)
    slot(editorId).state = state
end

--- Oublie un atelier (retiré du registre).
---@param editorId string
function index.drop(editorId)
    editors[editorId] = nil
    for key in pairs(locks) do
        if key:sub(1, #editorId + 1) == editorId .. '|' then locks[key] = nil end
    end
end

--- Titre affiché d'une tête : celui de la publiée, sinon celui du brouillon, sinon celui du retrait.
---@param head vAvA.AtelierHead
function index.retitle(head)
    local title = (head.published and head.published.title) or (head.draft and head.draft.title)
        or (head.retired and head.retired.title) or head.id
    head.title = title
    head.search = text.normalize(title)
end

local function toInt(value)
    local n = tonumber(value)
    if not n then return nil end
    return tointeger(n) or n
end
index.toInt = toInt

--- Tête d'un brouillon tirée d'une ligne.
---@param row table
---@return table
function index.draftOf(row)
    return {
        row = toInt(row.id), rev = toInt(row.rev) or 1, status = row.status, removal = toInt(row.removal) == 1,
        holder = toInt(row.author_account_id), holderLabel = row.author_label, base = toInt(row.base_version),
        title = row.title, parent = row.parent, summary = row.summary, at = toInt(row.at),
    }
end

--- Tête d'une version publiée tirée d'une ligne.
---@param row table
---@return table
function index.publishedOf(row)
    return {
        row = toInt(row.id), version = toInt(row.version), title = row.title, parent = row.parent,
        format = toInt(row.format) or 1, fingerprint = row.fingerprint, at = toInt(row.at),
    }
end

--- Construit les têtes d'un atelier à partir des lignes vivantes, des retraits et des plus hautes versions.
---@param editorId string
---@param rows table[]
---@param retired table[]
---@param tops table[]
function index.build(editorId, rows, retired, tops)
    local entry = slot(editorId)
    entry.kinds = {}
    local function head(kindId, id)
        local kind = kindSlot(entry, kindId)
        local h = kind.byId[id]
        if not h then
            h = { kind = kindId, id = id }
            kind.byId[id] = h
        end
        return h
    end
    for _, row in ipairs(rows) do
        local h = head(row.kind, row.def_id)
        if row.status == 'published' then h.published = index.publishedOf(row) else h.draft = index.draftOf(row) end
    end
    for _, row in ipairs(tops) do head(row.kind, row.def_id).top = toInt(row.top) end
    for _, row in ipairs(retired) do
        local h = head(row.kind, row.def_id)
        local version = toInt(row.version)
        if not h.published and version and version == h.top then
            h.retired = { row = toInt(row.id), version = version, title = row.title, batch = toInt(row.batch),
                at = toInt(row.at) }
        end
    end
    for _, kind in pairs(entry.kinds) do
        for id, h in pairs(kind.byId) do
            if not h.published and not h.draft and not h.retired then
                kind.byId[id] = nil
            else
                index.retitle(h)
            end
        end
    end
end

--- Identifiants rendus par la liste du module à la dernière synchronisation (identifiant d'une fiche nouvelle).
---@param editorId string
---@param kindId string
---@param ids table<string, boolean>
function index.setModuleIds(editorId, kindId, ids)
    slot(editorId).moduleIds[kindId] = ids
end

--- Tête d'une fiche (vivante ou retirée), ou nil.
---@param editorId string
---@param kindId string
---@param id string
---@return vAvA.AtelierHead|nil
function index.get(editorId, kindId, id)
    local entry = editors[editorId]
    local kind = entry and entry.kinds[kindId]
    return kind and kind.byId[id] or nil
end

--- Crée ou rend la tête d'une fiche.
---@return vAvA.AtelierHead
function index.ensure(editorId, kindId, id)
    local kind = kindSlot(slot(editorId), kindId)
    local h = kind.byId[id]
    if not h then
        h = { kind = kindId, id = id, title = id, search = id }
        kind.byId[id] = h
    end
    return h
end

--- Une tête a changé : son titre est recalculé, la liste triée de son type oubliée ; une tête sans rien est retirée.
---@param editorId string
---@param head vAvA.AtelierHead
function index.touch(editorId, head)
    local entry = editors[editorId]
    if not entry then return end
    local kind = kindSlot(entry, head.kind)
    kind.sorted = nil
    if not head.published and not head.draft and not head.retired then
        kind.byId[head.id] = nil
        return
    end
    index.retitle(head)
end

--- Identifiant déjà pris pour un type (base, tout statut, ou liste du module).
---@return boolean
function index.taken(editorId, kindId, id)
    if index.get(editorId, kindId, id) then return true end
    local entry = editors[editorId]
    local ids = entry and entry.moduleIds[kindId]
    return ids ~= nil and ids[id] == true
end

--- Vrai si une fiche est vivante (publiée, ou brouillon jamais publié).
---@param head vAvA.AtelierHead|nil
---@return boolean
function index.alive(head)
    return head ~= nil and (head.published ~= nil or head.draft ~= nil)
end

--- Fiches vivantes d'un type, triées par nom (liste gardée jusqu'au prochain changement).
---@param editorId string
---@param kindId string
---@return vAvA.AtelierHead[]
function index.live(editorId, kindId)
    local entry = editors[editorId]
    if not entry then return {} end
    local kind = kindSlot(entry, kindId)
    if kind.sorted then return kind.sorted end
    local list = {}
    for _, h in pairs(kind.byId) do
        if index.alive(h) then list[#list + 1] = h end
    end
    sort(list, function(a, b)
        if a.search ~= b.search then return a.search < b.search end
        return a.id < b.id
    end)
    kind.sorted = list
    return list
end

--- Fiches retirées d'un type, les plus récemment retirées d'abord.
---@return vAvA.AtelierHead[]
function index.retired(editorId, kindId)
    local entry = editors[editorId]
    local kind = entry and entry.kinds[kindId]
    local list = {}
    if not kind then return list end
    for _, h in pairs(kind.byId) do
        if h.retired and not index.alive(h) then list[#list + 1] = h end
    end
    sort(list, function(a, b)
        local ta, tb = a.retired.at or 0, b.retired.at or 0
        if ta ~= tb then return ta > tb end
        return a.id < b.id
    end)
    return list
end

--- Toutes les têtes d'un atelier (lecture seule), type par type.
---@param editorId string
---@return table<string, { byId: table<string, vAvA.AtelierHead> }>
function index.kinds(editorId)
    local entry = editors[editorId]
    return entry and entry.kinds or {}
end

--- Nombre de fiches publiées d'un type.
---@return integer
function index.publishedCount(editorId, kindId)
    local count = 0
    for _, h in pairs((index.kinds(editorId)[kindId] or { byId = {} }).byId) do
        if h.published then count = count + 1 end
    end
    return count
end

--- Nombre de fiches vivantes d'un type.
---@return integer
function index.liveCount(editorId, kindId)
    return #index.live(editorId, kindId)
end

--- Brouillons tenus par un compte, tous ateliers confondus.
---@param accountId integer
---@return integer
function index.draftCount(accountId)
    local count = 0
    for _, entry in pairs(editors) do
        for _, kind in pairs(entry.kinds) do
            for _, h in pairs(kind.byId) do
                if h.draft and h.draft.holder == accountId then count = count + 1 end
            end
        end
    end
    return count
end

--- Brouillons tenus par un compte dans des ateliers donnés : { { editorId, head } }.
---@param accountId integer
---@param editorIds string[]
---@return table[]
function index.draftsOf(accountId, editorIds)
    local out = {}
    for _, editorId in ipairs(editorIds) do
        local entry = editors[editorId]
        if entry then
            for _, kind in pairs(entry.kinds) do
                for _, h in pairs(kind.byId) do
                    if h.draft and h.draft.holder == accountId then out[#out + 1] = { editor = editorId, head = h } end
                end
            end
        end
    end
    return out
end

--- Brouillons d'un atelier sous forme de références (lots : shared/lifecycle.lua › bundle).
---@param editorId string
---@return table[]
function index.draftRefs(editorId)
    local out = {}
    for kindId, kind in pairs(index.kinds(editorId)) do
        for id, h in pairs(kind.byId) do
            if h.draft then
                out[#out + 1] = { kind = kindId, id = id, parent = h.draft.parent, holder = h.draft.holder,
                    removal = h.draft.removal, status = h.draft.status }
            end
        end
    end
    sort(out, function(a, b)
        if a.kind ~= b.kind then return a.kind < b.kind end
        return a.id < b.id
    end)
    return out
end

--- Fiches publiées d'un atelier sous forme de références (retrait en cascade).
---@param editorId string
---@return table[]
function index.publishedRefs(editorId)
    local out = {}
    for kindId, kind in pairs(index.kinds(editorId)) do
        for id, h in pairs(kind.byId) do
            if h.published then out[#out + 1] = { kind = kindId, id = id, parent = h.published.parent } end
        end
    end
    return out
end

--- Empreinte de l'état d'un atelier (opération résumée puis confirmée) : versions publiées et brouillons.
---@param editorId string
---@return string
function index.digest(editorId)
    local parts = {}
    for kindId, kind in pairs(index.kinds(editorId)) do
        for id, h in pairs(kind.byId) do
            parts[kindId .. '|' .. id] = {
                h.published and h.published.version or 0, h.draft and h.draft.rev or 0, h.top or 0,
            }
        end
    end
    return VavaAtelier.fingerprint(parts) or ''
end

-- Verrous -----------------------------------------------------------------------------------------------------------

--- Prend les verrous de plusieurs fiches (toutes ou aucune). Rend un jeton, ou nil, 'busy'. Un verrou tenu au-delà
--- de `limits.busyMs` (appel resté en suspens) est repris, avec une ligne en console.
---@param keys string[]  'atelier|type|id'
---@return table|nil
---@return string|nil
function index.lock(keys)
    local now = GetGameTimer()
    for _, key in ipairs(keys) do
        local held = locks[key]
        if held then
            if now - held.since < cfg.limits.busyMs then return nil, 'busy' end
            VavaAtelier.log.warn('fiche %s : verrou tenu depuis %d ms, repris', key, now - held.since)
        end
    end
    local token = { keys = keys }
    for _, key in ipairs(keys) do locks[key] = { token = token, since = now } end
    return token
end

--- Rend les verrous d'un jeton (ceux qu'un autre a repris entre-temps restent à lui).
---@param token table|nil
function index.unlock(token)
    if not token then return end
    for _, key in ipairs(token.keys) do
        local held = locks[key]
        if held and held.token == token then locks[key] = nil end
    end
end

--- Clé du verrou d'une fiche.
---@return string
function index.key(editorId, kindId, id)
    return editorId .. '|' .. kindId .. '|' .. tostring(id)
end

--- Ateliers suivis (lecture seule) : atelier → { state, kinds, moduleIds } (console : /atelier_archives etat).
---@return table<string, table>
function index.all()
    return editors
end
