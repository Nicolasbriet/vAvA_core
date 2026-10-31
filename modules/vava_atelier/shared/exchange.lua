--[[
    vava_atelier/shared/exchange.lua
    Rôle : logique pure des archives JSON de l'Atelier (§ 5.9 de la spec T-101) : nom d'un fichier (lettres, chiffres,
           « _ », « - », terminé par .json, 64 octets, ni barre ni « .. » : aucun fichier lu ou écrit hors du dossier
           des archives), nom d'un export, forme d'un fichier (seules les versions publiées), lecture contrôlée d'un
           fichier reçu (version du format, ateliers connus et gardés, types déclarés, identifiants au motif, aucun
           doublon, profondeur d'une fiche bornée, format des données au plus celui de l'atelier) — un refus rend le
           chemin et la raison, et ne vaut que pour son atelier (tout ou rien par atelier, les autres passent) — et
           plan d'un import (inchangée, changée, retirée → reprise, inconnue → nouvelle ; un import ne retire jamais
           rien).
           Testée : tests/spec/atelier_exchange_spec.lua.
    Dépendances : shared/constants.lua
]]

local type, pairs, ipairs, tostring = type, pairs, ipairs, tostring
local mathType, tointeger = math.type, math.tointeger
local find, format, gsub, sub = string.find, string.format, string.gsub, string.sub
local sort = table.sort

local X = VavaAtelier.EXCHANGE
local DEF = VavaAtelier.DEF
local MAX_ENTRY = VavaAtelier.MAX_ENTRY
local MAX_EDITOR, MAX_KEY = VavaAtelier.MAX_EDITOR, VavaAtelier.MAX_KEY
-- motifs écrits octet par octet (`%w` dépend de la locale)
local ID_PATTERN = '^[A-Za-z0-9_%-]+$'
local EDITOR_PATTERN = '^[A-Za-z0-9_]+:[A-Za-z0-9_]+$'
local KIND_PATTERN = '^[A-Za-z][A-Za-z0-9_]*$'
local ENTRY_KEYS = { id = true, version = true, parent = true, place = true, data = true }

local exchange = {}
VavaAtelier.exchange = exchange

--- Nom de fichier permis : `^[A-Za-z0-9_-]+%.json$`, 64 octets au plus.
---@param name any
---@return boolean
function exchange.validName(name)
    return type(name) == 'string' and #name >= 6 and #name <= X.fileMax and find(name, X.filePattern) ~= nil
end

--- Nom d'un export : `atelier_<aaaammjj>_<hhmmss>.json`, ou `<atelier sans « : »>_<date>.json` pour un seul atelier.
---@param editorId string|nil
---@param stamp string  « 20261030_140500 »
---@return string
function exchange.exportName(editorId, stamp)
    local prefix = 'atelier'
    if type(editorId) == 'string' and editorId ~= '' then
        prefix = gsub(editorId, '[^A-Za-z0-9_]', '_')
        local room = X.fileMax - #stamp - #'_.json'
        if #prefix > room then prefix = sub(prefix, 1, room) end
    end
    return prefix .. '_' .. stamp .. '.json'
end

--- Fichier d'archives : { atelier = 1, exported_at, editors = { [atelier] = { format, kinds = { [type] =
--- { fiche } } } } } ; fiche { id, version, parent?, place?, data }.
---@param list { editor: string, format: integer, kinds: table<string, table[]> }[]
---@param exportedAt string  date ISO (« 2026-10-30T14:05:00Z »)
---@return table
function exchange.build(list, exportedAt)
    local editors = {}
    for _, entry in ipairs(list) do
        editors[entry.editor] = { format = entry.format, kinds = entry.kinds }
    end
    return { atelier = X.version, exported_at = exportedAt, editors = editors }
end

--- Profondeur d'une valeur (scalaire : 0, table : 1 + la plus profonde de ses valeurs), sans descendre au-delà de
--- `limit + 1` (un fichier piégé ne coûte pas plus que la borne).
---@param value any
---@param limit integer
---@return integer
function exchange.depth(value, limit)
    if type(value) ~= 'table' then return 0 end
    if limit <= 0 then return 1 end
    local deepest = 0
    for _, child in pairs(value) do
        local d = exchange.depth(child, limit - 1)
        if d > deepest then deepest = d end
        if deepest >= limit then break end
    end
    return 1 + deepest
end

--- Liste pure (clés 1 à n).
local function isList(value)
    if type(value) ~= 'table' then return false end
    local count = 0
    for key in pairs(value) do
        if mathType(key) ~= 'integer' then return false end
        count = count + 1
    end
    return count == #value
end

local function positiveInteger(value)
    local n = type(value) == 'number' and tointeger(value) or nil
    return n ~= nil and n >= 1, n
end

---@param value any
---@param pattern string
---@param max integer
---@return boolean
local function isId(value, pattern, max)
    return type(value) == 'string' and #value <= max and find(value, pattern) ~= nil
end

---@class vAvA.AtelierExchangeEditor
---@field stored boolean
---@field format integer
---@field kinds table<string, boolean>

---@class vAvA.AtelierExchangeEntry
---@field kind string
---@field id string
---@field version integer|nil
---@field parent string|nil
---@field place table|nil
---@field data table
---@field path string

--- Un atelier du fichier : liste de fiches, ou nil et « chemin : raison ».
---@return vAvA.AtelierExchangeEntry[]|nil
---@return string|nil err
local function parseEditor(editorId, block, info)
    local root = editorId
    if type(block) ~= 'table' then return nil, root .. ' : table attendue' end
    local blockFormat = 1
    if block.format ~= nil then
        local ok, n = positiveInteger(block.format)
        if not ok or n > DEF.formatMax then return nil, root .. '.format : entier de 1 à 65535 attendu' end
        blockFormat = n
    end
    if blockFormat > info.format then
        return nil, format('%s.format : %d plus récent que celui de l\'atelier (%d)', root, blockFormat, info.format)
    end
    if type(block.kinds) ~= 'table' then return nil, root .. '.kinds : table attendue' end
    local entries = {}
    local kindIds = {}
    for kindId in pairs(block.kinds) do
        if not isId(kindId, KIND_PATTERN, MAX_KEY) or not info.kinds[kindId] then
            return nil, format('%s.kinds.%s : type inconnu de cet atelier', root, tostring(kindId))
        end
        kindIds[#kindIds + 1] = kindId
    end
    sort(kindIds)
    for _, kindId in ipairs(kindIds) do
        local list = block.kinds[kindId]
        local here = format('%s.kinds.%s', root, kindId)
        if not isList(list) then return nil, here .. ' : liste de fiches attendue' end
        local seen = {}
        for i, entry in ipairs(list) do
            local path = format('%s[%d]', here, i)
            if type(entry) ~= 'table' then return nil, path .. ' : table attendue' end
            if exchange.depth(entry, X.depth) > X.depth then
                return nil, format('%s : plus de %d niveaux imbriqués', path, X.depth)
            end
            for key in pairs(entry) do
                if not ENTRY_KEYS[key] then return nil, format('%s.%s : clé inconnue', path, tostring(key)) end
            end
            if not isId(entry.id, ID_PATTERN, MAX_ENTRY) then
                return nil, path .. '.id : identifiant invalide (lettres, chiffres, _ et -, 48 octets au plus)'
            end
            if seen[entry.id] then return nil, format('%s.id : « %s » en double', path, entry.id) end
            seen[entry.id] = true
            local version = nil
            if entry.version ~= nil then
                local ok, n = positiveInteger(entry.version)
                if not ok or n > DEF.versionMax then return nil, path .. '.version : entier positif attendu' end
                version = n
            end
            if entry.parent ~= nil and not isId(entry.parent, ID_PATTERN, MAX_ENTRY) then
                return nil, path .. '.parent : identifiant invalide'
            end
            if entry.place ~= nil and type(entry.place) ~= 'table' then
                return nil, path .. '.place : table attendue'
            end
            if type(entry.data) ~= 'table' then return nil, path .. '.data : table attendue' end
            entries[#entries + 1] = {
                kind = kindId, id = entry.id, version = version, parent = entry.parent, place = entry.place,
                data = entry.data, path = path,
            }
        end
    end
    return entries
end

---@class vAvA.AtelierExchangeParsed
---@field error string|nil   fichier entier refusé (forme, version)
---@field editors { id: string, error: string|nil, entries: vAvA.AtelierExchangeEntry[]|nil }[]

--- Lit un fichier décodé. Un refus de forme générale rend `error` ; sinon chaque atelier a ses fiches, ou son refus
--- (« chemin : raison ») sans effet sur les autres.
---@param doc any
---@param known table<string, vAvA.AtelierExchangeEditor>  ateliers déclarés (gardés ou non)
---@return vAvA.AtelierExchangeParsed
function exchange.parse(doc, known)
    if type(doc) ~= 'table' then return { error = 'fichier : objet attendu', editors = {} } end
    if doc.atelier ~= X.version then
        return { error = format('atelier : %d attendu (format des archives)', X.version), editors = {} }
    end
    if type(doc.editors) ~= 'table' then return { error = 'editors : table attendue', editors = {} } end
    local ids = {}
    for editorId in pairs(doc.editors) do
        if type(editorId) ~= 'string' then return { error = 'editors : clés d\'ateliers attendues', editors = {} } end
        ids[#ids + 1] = editorId
    end
    sort(ids)
    local out = {}
    for _, editorId in ipairs(ids) do
        local info = known[editorId]
        local result = { id = editorId }
        if not isId(editorId, EDITOR_PATTERN, MAX_EDITOR) or not info or not info.stored then
            result.error = editorId .. ' : atelier inconnu, ou qui ne garde rien'
        else
            local entries, err = parseEditor(editorId, doc.editors[editorId], info)
            result.entries, result.error = entries, err
        end
        out[#out + 1] = result
    end
    return { editors = out }
end

---@class vAvA.AtelierExchangeCurrent
---@field fingerprint string|nil  empreinte de la version publiée (nil : pas de publiée)
---@field retired boolean|nil

--- Plan d'un import (ou d'un retour à l'original) pour un atelier : chaque fiche reçue (avec son empreinte) est
--- `unchanged` (identique à la publiée), `changed`, `revived` (retirée) ou `new` (inconnue). Rien n'est jamais retiré.
---@param entries { kind: string, id: string, fingerprint: string }[]
---@param current table<string, vAvA.AtelierExchangeCurrent>  'type|id' → état en base
---@return { items: table[], unchanged: integer, changed: integer, revived: integer, new: integer }
function exchange.plan(entries, current)
    local plan = { items = {}, unchanged = 0, changed = 0, revived = 0, new = 0 }
    for _, entry in ipairs(entries) do
        local now = current[entry.kind .. '|' .. entry.id]
        local action
        if now and now.fingerprint then
            action = now.fingerprint == entry.fingerprint and 'unchanged' or 'changed'
        elseif now and now.retired then
            action = 'revived'
        else
            -- inconnue, ou connue de la base sans version publiée ni retrait (brouillon seulement) : nouvelle version
            action = 'new'
        end
        plan[action] = plan[action] + 1
        plan.items[#plan.items + 1] = { kind = entry.kind, id = entry.id, action = action }
    end
    return plan
end
