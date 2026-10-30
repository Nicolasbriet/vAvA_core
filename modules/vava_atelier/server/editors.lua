--[[
    vava_atelier/server/editors.lua
    Rôle : registre vava_atelier:editors. Définition (validateur : shared/formschema.lua), contrôle du propriétaire
           (un module ne déclare que sous son nom : une clé dont le préfixe n'est pas la ressource qui l'a ajoutée est
           retirée aussitôt), cache des éditeurs tenu par les hooks du registre (droit effectif, types et champs
           indexés, fonctions du module, descripteur pour l'interface et son empreinte), cartes de l'accueil dans
           l'ordre (cartes « Bientôt » de la config, puis les autres par `order`).
    Dépendances : shared/constants.lua, config.lua, shared/formvalues.lua, shared/formschema.lua, shared/rights.lua,
                  shared/fingerprint.lua, server/core.lua
]]

local type, pairs, ipairs, tostring = type, pairs, ipairs, tostring
local find, match = string.find, string.match
local sort = table.sort

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local REGISTRY = VavaAtelier.REGISTRY
local fv, fs, rights = VavaAtelier.formvalues, VavaAtelier.formschema, VavaAtelier.rights

-- fonctions qu'un éditeur peut déclarer (jamais copiées dans le descripteur)
local FUNCTIONS = { 'index', 'read', 'validate', 'options', 'compare', 'apply', 'remove', 'trial', 'endTrial', 'diff' }
local IS_FUNCTION = {}
for _, name in ipairs(FUNCTIONS) do IS_FUNCTION[name] = true end
-- rang d'une carte déclarée sans `order`
local DEFAULT_ORDER = 500

local editors = {}
VavaAtelier.editors = editors

-- Contexte du validateur, tiré de la config une fois.
local schemaContext = { families = {}, rights = {}, icons = {} }
local floors, familyIndex = {}, {}
for i, family in ipairs(cfg.families) do
    schemaContext.families[family.id] = true
    floors[family.id] = family.floor
    familyIndex[family.id] = i
end
for _, right in ipairs(cfg.rights.allowed) do schemaContext.rights[right] = true end
for _, icon in ipairs(VavaAtelier.ICONS) do schemaContext.icons[icon] = true end
local rightsSettings = { allowed = cfg.rights.allowed, overrides = cfg.rights.overrides, floors = floors }

-- Cartes « Bientôt » : identifiant → rang dans la config.
local upcomingRank = {}
for i, card in ipairs(cfg.upcoming) do upcomingRank[card.id] = i end

---@class vAvA.AtelierKind
---@field def table           type déclaré (id, noun, nounPlural, article, newLabel, layout, form…)
---@field fields table<string, table>
---@field rank integer        place dans la déclaration (1 : type principal)

---@class vAvA.AtelierEditor
---@field id string
---@field owner string
---@field family string
---@field label string
---@field order integer
---@field right string        droit effectif
---@field fns table<string, any>
---@field kinds table<string, vAvA.AtelierKind>
---@field firstKind string
---@field descriptor table
---@field version string

---@type table<string, vAvA.AtelierEditor>
local loaded = {}

--- Validateur du registre : clé au motif `<ressource>:<nom>`, déclaration complète (shared/formschema.lua).
---@param key string
---@param data any
---@return boolean ok
---@return string|nil err
local function validator(key, data)
    if type(key) ~= 'string' or #key > VavaAtelier.MAX_EDITOR or not find(key, VavaAtelier.EDITOR_PATTERN) then
        return false, 'clé attendue au motif <ressource>:<nom> (64 octets au plus)'
    end
    return fs.checkEditor(data, schemaContext)
end

--- Définit le registre (au démarrage du module : les modules y ajoutent ensuite leurs éditeurs).
---@return boolean ok
---@return string|nil err
function editors.define()
    return core.registry.define(REGISTRY, {
        -- la forme complète est vérifiée par le validateur (types imbriqués, bornes croisées, fonctions)
        schema = { type = 'table', strict = false, fields = {} },
        validator = validator,
        maxEntries = cfg.limits.editors,
    })
end

--- Descripteur pour l'interface : la déclaration sans ses fonctions ni son droit, chaque champ avec son défaut
--- explicite, plus `id` et `hasCompare`.
---@param id string
---@param data table
---@return table
local function describe(id, data)
    local descriptor = { id = id, hasCompare = data.compare ~= nil }
    for key, value in pairs(data) do
        if not IS_FUNCTION[key] and key ~= 'right' then descriptor[key] = value end
    end
    for _, kind in ipairs(descriptor.kinds) do
        for _, field in ipairs(kind.form.fields) do
            if field.default == nil then field.default = fv.default(field) end
        end
    end
    return descriptor
end

--- Lit une entrée du registre et la range dans le cache.
---@param id string
---@param owner string
---@return boolean ok
local function load(id, owner)
    local data = core.registry.get(REGISTRY, id)
    if type(data) ~= 'table' then return false end
    local fns = {}
    for _, name in ipairs(FUNCTIONS) do fns[name] = data[name] end
    local kinds = {}
    for i, kind in ipairs(data.kinds) do
        local fields = {}
        for _, field in ipairs(kind.form.fields) do fields[field.id] = field end
        kinds[kind.id] = { def = kind, fields = fields, rank = i }
    end
    local descriptor = describe(id, data)
    local version, err = VavaAtelier.fingerprint(descriptor)
    if not version then
        VavaAtelier.log.error("éditeur '%s' : empreinte impossible (%s)", id, tostring(err))
        return false
    end
    loaded[id] = {
        id = id, owner = owner, family = data.family, label = data.label, icon = data.icon,
        description = data.description, order = data.order or DEFAULT_ORDER,
        right = rights.effective(id, data.right, data.family, rightsSettings),
        fns = fns, kinds = kinds, firstKind = data.kinds[1].id, descriptor = descriptor, version = version,
    }
    return true
end

--- Hook `core:registry:added` d'une entrée du registre : propriétaire vérifié, puis cache.
---@param key string
---@param owner string
function editors.added(key, owner)
    if match(key, '^([^:]+):') ~= owner then
        VavaAtelier.log.warn("éditeur '%s' ajouté par '%s' : un module ne déclare que sous son nom, entrée retirée",
            key, tostring(owner))
        core.registry.remove(REGISTRY, key)
        return
    end
    if load(key, owner) then
        VavaAtelier.log.info("atelier '%s' déclaré par %s (droit %s)", key, owner, loaded[key].right)
    end
end

--- Hook `core:registry:removed` d'une entrée du registre : oublié. Rend vrai s'il était connu.
---@param key string
---@return boolean
function editors.removed(key)
    local known = loaded[key] ~= nil
    loaded[key] = nil
    return known
end

--- Éditeur déclaré, ou nil.
---@param id string
---@return vAvA.AtelierEditor|nil
function editors.get(id)
    return loaded[id]
end

--- Type d'un éditeur, ou nil.
---@param editor vAvA.AtelierEditor
---@param kindId string
---@return vAvA.AtelierKind|nil
function editors.kind(editor, kindId)
    return editor.kinds[kindId]
end

--- Ordre de l'accueil : famille, puis carte de la config (dans son ordre), puis `order`, puis libellé.
local function before(a, b)
    local fa, fb = familyIndex[a.family] or 99, familyIndex[b.family] or 99
    if fa ~= fb then return fa < fb end
    local ua, ub = upcomingRank[a.id], upcomingRank[b.id]
    if ua and ub then return ua < ub end
    if ua or ub then return ua ~= nil end
    if a.order ~= b.order then return a.order < b.order end
    if a.label ~= b.label then return a.label < b.label end
    return a.id < b.id
end

--- Éditeurs déclarés, dans l'ordre de l'accueil.
---@return vAvA.AtelierEditor[]
function editors.list()
    local out = {}
    for _, editor in pairs(loaded) do out[#out + 1] = editor end
    sort(out, before)
    return out
end

--- Cartes « Bientôt » : celles de la config dont l'éditeur n'est pas déclaré, avec leur droit (plancher de la
--- famille, sauf surcharge), dans l'ordre de la config.
---@return { id: string, family: string, label: string, description: string, icon: string, right: string }[]
function editors.upcoming()
    local out = {}
    for _, card in ipairs(cfg.upcoming) do
        if not loaded[card.id] and familyIndex[card.family] then
            out[#out + 1] = {
                id = card.id, family = card.family, label = card.label, description = card.description,
                icon = card.icon,
                right = rights.effective(card.id, floors[card.family], card.family, rightsSettings),
            }
        end
    end
    return out
end

--- Ordre de l'accueil, exposé pour composer les cartes réelles et « Bientôt » ensemble.
editors.before = before
