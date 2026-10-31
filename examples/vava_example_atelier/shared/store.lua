--[[
    vava_example_atelier/shared/store.lua
    Rôle : logique pure des fiches de l'exemple, en mémoire (T-101) : un magasin par atelier, rempli par la config au
           démarrage puis tenu par l'Atelier (`apply` crée ou remplace, `remove` retire). Contrat d'aller-retour :
           après `apply(kind, def)`, `read(kind, def.id)` rend la même data, le même `place` et le même `parent`.
           `index` liste les fiches dans l'ordre d'arrivée. Et `diff` du panneau : « Texte repeint » quand seul le texte
           change (sinon nil : l'Atelier écrit le résumé générique). Et `shownChanged` : l'annonce d'un essai relancé
           ne repart que pour la fiche dont ce qui se lit a changé.
           Testée : tests/spec/examples_atelier_spec.lua.
    Dépendances : config.lua
]]

local type, pairs, ipairs = type, pairs, ipairs

local store = {}
VavaExampleAtelier.store = store

-- clés d'une fiche qui ne sont pas des champs du formulaire
local RESERVED = { id = true, version = true, parent = true, place = true, status = true }

local Store = {}
Store.__index = Store

local function copy(value)
    if type(value) ~= 'table' then return value end
    local out = {}
    for key, inner in pairs(value) do out[key] = copy(inner) end
    return out
end

--- Magasin vide, ou rempli d'une liste de fiches par type : { [type] = { { id, …champs, place?, parent? } } }.
---@param seeds? table<string, table[]>
---@return table
function store.new(seeds)
    local self = setmetatable({ kinds = {} }, Store)
    for kind, list in pairs(seeds or {}) do
        for _, entry in ipairs(list) do self:apply(kind, entry) end
    end
    return self
end

local function slot(self, kind)
    local entry = self.kinds[kind]
    if not entry then
        entry = { order = {}, byId = {} }
        self.kinds[kind] = entry
    end
    return entry
end

--- Crée ou remplace une fiche (la place d'une fiche connue dans l'ordre ne change pas).
---@param kind string
---@param def table  data + id, version?, parent?, place?
---@return boolean
function store.apply(self, kind, def)
    if type(def) ~= 'table' or type(def.id) ~= 'string' then return false end
    local s = slot(self, kind)
    local data = {}
    for key, value in pairs(def) do
        if not RESERVED[key] then data[key] = copy(value) end
    end
    if not s.byId[def.id] then s.order[#s.order + 1] = def.id end
    s.byId[def.id] = { data = data, place = copy(def.place), parent = def.parent, version = def.version }
    return true
end
Store.apply = store.apply

--- Retire une fiche ; vrai si elle existait.
function store.remove(self, kind, id)
    local s = self.kinds[kind]
    if not s or not s.byId[id] then return false end
    s.byId[id] = nil
    for i, known in ipairs(s.order) do
        if known == id then
            table.remove(s.order, i)
            break
        end
    end
    return true
end
Store.remove = store.remove

--- Fiche telle que l'Atelier la lit : data + place? + parent?, ou nil.
function store.read(self, kind, id)
    local s = self.kinds[kind]
    local entry = s and s.byId[id]
    if not entry then return nil end
    local out = copy(entry.data)
    out.place = copy(entry.place)
    out.parent = entry.parent
    return out
end
Store.read = store.read

--- Fiche brute (data, place, parent, version), ou nil.
function store.get(self, kind, id)
    local s = self.kinds[kind]
    return s and s.byId[id] or nil
end
Store.get = store.get

--- Liste d'un type : { { id, title } } dans l'ordre d'arrivée.
function store.index(self, kind)
    local s = self.kinds[kind]
    local out = {}
    if not s then return out end
    for i, id in ipairs(s.order) do out[i] = { id = id, title = s.byId[id].data.titre or id } end
    return out
end
Store.index = store.index

--- Fiches d'un type : liste de { id, data, place, parent } (lecture seule).
function store.all(self, kind)
    local s = self.kinds[kind]
    local out = {}
    if not s then return out end
    for i, id in ipairs(s.order) do
        local entry = s.byId[id]
        out[i] = { id = id, data = entry.data, place = entry.place, parent = entry.parent }
    end
    return out
end
Store.all = store.all

-- ce que l'annonce d'un essai montre, par type
local SHOWN = { panneau = { 'titre', 'texte' }, affiche = { 'titre' } }

--- L'annonce d'essai d'une fiche change-t-elle ? (relance après une sauvegarde : seule la fiche dont ce qui se lit a
--- changé est annoncée de nouveau ; une fiche jamais montrée l'est toujours)
---@param kind string
---@param before table|nil  fiche montrée avant (def), ou nil
---@param after table
---@return boolean
function store.shownChanged(kind, before, after)
    if type(before) ~= 'table' then return true end
    for _, key in ipairs(SHOWN[kind] or {}) do
        if before[key] ~= after[key] then return true end
    end
    return false
end

--- Résumé d'un changement de panneau : « Texte repeint » si seul le texte change, sinon nil.
---@param kind string
---@param before table|nil
---@param after table|nil
---@return string|nil
function store.diff(kind, before, after)
    if kind ~= 'panneau' or type(before) ~= 'table' or type(after) ~= 'table' then return nil end
    local changed = {}
    for key, value in pairs(after) do
        if not RESERVED[key] and before[key] ~= value then changed[#changed + 1] = key end
    end
    for key in pairs(before) do
        if not RESERVED[key] and after[key] == nil then changed[#changed + 1] = key end
    end
    if #changed == 1 and changed[1] == 'texte' then return VavaExampleAtelier.config.repainted end
    return nil
end
