--[[
    vava_crafting/shared/stationzone.lua
    Rôle : règles pures du partage des stations par les abonnements de zone du core (vAvA_core 0.11.0). Côté serveur :
           lieu de la zone d'une station (cercle au sol, marge), état publié — `def`, ce qu'il faut pour la dessiner et
           pour son invite, et `s`, combustible et occupation —, comparaison avant envoi. Côté client : lecture prudente de ce qui arrive,
           et carnet des stations connues (entrée dans une zone, changement, sortie) qui dit ce qui a bougé. Rien de
           secret dans l'état d'une zone : il est public pour quiconque peut s'en approcher.
           Testé dans tests/spec/crafting_stationzone_spec.lua.
    Dépendances : shared/constants.lua
]]

local type, pairs, ipairs, setmetatable = type, pairs, ipairs, setmetatable
local huge = math.huge
local sort = table.sort

local stationzone = {}
VavaCrafting.stationzone = stationzone

-- Clés de l'état d'une zone de station.
stationzone.DEF = 'def'
stationzone.STATUS = 's'

-- Bornes de lecture côté client (une valeur hors bornes fait ignorer la station, jamais lever une erreur).
local TYPE_MAX, LABEL_MAX, PROP_MAX = 32, 128, 64
local ID_PATTERN = VavaCrafting.ID_PATTERN
local CAPACITY_MAX = VavaCrafting.FUEL_CAPACITY_MAX
-- le serveur refuse d'emblée une station placée par un module au-delà de ces bornes (server/catalog.lua)
stationzone.LABEL_MAX, stationzone.PROP_MAX = LABEL_MAX, PROP_MAX

---@param value any
---@return boolean
local function finite(value)
    return type(value) == 'number' and value == value and value ~= huge and value ~= -huge
end

---@param value any
---@param maxLength integer
---@return boolean
local function text(value, maxLength)
    return type(value) == 'string' and #value >= 1 and #value <= maxLength
end

-- Serveur ------------------------------------------------------------------------------------------------------------

--- Lieu de la zone du core d'une station : cercle au sol de `radius` mètres autour d'elle, connu des joueurs à
--- `margin` mètres de son bord. Pas de `bucket` : la zone vaut pour toutes les instances ; le jour où une station sera
--- propre à une instance (logement, T-1xx), passer son routing bucket ici.
---@param station { x: number, y: number, z: number }
---@param radius number
---@param margin number
---@return { x: number, y: number, z: number, radius: number, margin: number }
function stationzone.area(station, radius, margin)
    return { x = station.x, y = station.y, z = station.z, radius = radius, margin = margin }
end

--- Ce que les clients proches reçoivent pour dessiner une station placée (définition du serveur, type résolu), avec le
--- nom du type et sa réserve de combustible pour l'invite : le client ne connaît pas les types (T-144).
---@param def vAvA.StationDefinition
---@return { type: string, typeLabel: string, capacity: integer|nil, label: string, x: number, y: number, z: number, heading: number, prop: string|nil }
function stationzone.drawing(def)
    local kind = def.type
    return {
        type = kind.id, typeLabel = kind.label, capacity = kind.fuel and kind.fuel.capacity or nil,
        label = def.label, x = def.x, y = def.y, z = def.z, heading = def.heading or 0.0, prop = def.prop or kind.prop,
    }
end

--- Combustible et occupation d'une station, tels que publiés.
---@param fuel integer
---@param busy boolean
---@return { fuel: integer, busy: boolean }
function stationzone.status(fuel, busy)
    return { fuel = fuel, busy = busy == true }
end

--- Deux états publiés identiques (nil n'est égal à rien).
---@param a table|nil
---@param b table|nil
---@return boolean
function stationzone.sameStatus(a, b)
    return a ~= nil and b ~= nil and a.fuel == b.fuel and a.busy == b.busy
end

-- Client -------------------------------------------------------------------------------------------------------------

--- Station lue dans l'état d'une zone, ou nil si la valeur est mal formée.
---@param id any       identifiant local de la zone (= identifiant de la station)
---@param raw any      valeur de `def`
---@return { id: string, type: string, typeLabel: string, capacity: integer|nil, label: string, x: number, y: number, z: number, heading: number, prop: string|nil }|nil
function stationzone.readDrawing(id, raw)
    if type(id) ~= 'string' or not id:find(ID_PATTERN) or type(raw) ~= 'table' then return nil end
    if not text(raw.type, TYPE_MAX) or not raw.type:find(ID_PATTERN) or not text(raw.label, LABEL_MAX) then return nil end
    if not text(raw.typeLabel, LABEL_MAX) then return nil end
    local capacity = raw.capacity
    if capacity ~= nil and (not finite(capacity) or capacity < 1 or capacity > CAPACITY_MAX or capacity % 1 ~= 0) then
        return nil
    end
    if not finite(raw.x) or not finite(raw.y) or not finite(raw.z) then return nil end
    if raw.heading ~= nil and not finite(raw.heading) then return nil end
    if raw.prop ~= nil and not text(raw.prop, PROP_MAX) then return nil end
    return {
        id = id, type = raw.type, typeLabel = raw.typeLabel, capacity = capacity, label = raw.label,
        x = raw.x, y = raw.y, z = raw.z, heading = raw.heading or 0.0, prop = raw.prop,
    }
end

-- État d'une station dont rien n'est encore connu : vide et libre (partagé, jamais modifié).
local IDLE = { fuel = 0, busy = false }
stationzone.IDLE = IDLE

--- Combustible et occupation lus dans l'état d'une zone (vide et libre si la valeur est absente ou mal formée).
---@param raw any  valeur de `s`
---@return { fuel: number, busy: boolean }
function stationzone.readStatus(raw)
    if type(raw) ~= 'table' then return IDLE end
    local fuel = raw.fuel
    return { fuel = (finite(fuel) and fuel >= 0) and fuel or 0, busy = raw.busy == true }
end

--- Même lieu, même modèle : le prop est gardé.
local function samePlace(a, b)
    return a.type == b.type and a.x == b.x and a.y == b.y and a.z == b.z and a.heading == b.heading and a.prop == b.prop
end
stationzone.samePlace = samePlace

--- Mêmes textes de l'invite (nom, nom du type, réserve).
local function sameText(a, b)
    return a.label == b.label and a.typeLabel == b.typeLabel and a.capacity == b.capacity
end
stationzone.sameText = sameText

---@param a table
---@param b table
---@return boolean
local function sameDrawing(a, b)
    return samePlace(a, b) and sameText(a, b)
end
stationzone.sameDrawing = sameDrawing

---@class vAvA.StationBook
---@field stations table<string, table>   identifiant → station dessinée
---@field statuses table<string, table>   identifiant → { fuel, busy }
---@field ordered table[]|nil             stations triées par identifiant (refaites après un changement de lieu)
---@field count integer
local Book = {}
Book.__index = Book

--- Carnet des stations connues du client : seulement celles des zones qu'il suit.
---@return vAvA.StationBook
function stationzone.book()
    return setmetatable({ stations = {}, statuses = {}, ordered = nil, count = 0 }, Book)
end

--- Oublie une station (son état avec elle).
---@param id string
---@return boolean placed  vrai si elle était connue : la liste des stations a changé
---@return boolean statusChanged  toujours faux (une station oubliée n'a plus d'état à montrer)
---@return boolean relabeled  toujours faux
function Book:leave(id)
    if self.stations[id] == nil then return false, false, false end
    self.stations[id], self.statuses[id] = nil, nil
    self.count = self.count - 1
    self.ordered = nil
    return true, false, false
end

--- Place une station : remplacée si le lieu ou le modèle changent ; textes seuls changés mis à jour sur place (R-1).
---@param id string
---@param drawing table
---@return boolean placed     apparue, ou lieu ou modèle changés
---@return boolean relabeled  textes de l'invite seuls changés
function Book:place(id, drawing)
    local previous = self.stations[id]
    if previous and samePlace(previous, drawing) then
        if sameText(previous, drawing) then return false, false end
        previous.label, previous.typeLabel, previous.capacity = drawing.label, drawing.typeLabel, drawing.capacity
        return false, true
    end
    if not previous then self.count = self.count + 1 end
    self.stations[id] = drawing
    self.ordered = nil
    return true, false
end

---@param id string
---@param status table
---@return boolean changed
function Book:setStatus(id, status)
    local previous = self.statuses[id] or IDLE
    self.statuses[id] = status
    return not stationzone.sameStatus(previous, status)
end

--- Zone suivie, état entier reçu (première fois, ou de nouveau entier) : la station est placée ou remplacée. Un
--- dessin mal formé fait oublier la station.
---@param id string
---@param state any
---@return boolean placed         une station est apparue, a bougé (lieu, modèle, type) ou a disparu
---@return boolean statusChanged  combustible ou occupation changés
---@return boolean relabeled      seuls les textes de l'invite ont changé (nom, nom du type, réserve)
function Book:enter(id, state)
    local drawing = type(state) == 'table' and stationzone.readDrawing(id, state[stationzone.DEF]) or nil
    if not drawing then return self:leave(id) end
    local placed, relabeled = self:place(id, drawing)
    local statusChanged = self:setStatus(id, stationzone.readStatus(state[stationzone.STATUS]))
    return placed, statusChanged, relabeled
end

--- Changements d'une zone suivie : `set` (clé → valeur), `removed` (liste de clés). Une station inconnue est ignorée
--- (le core envoie toujours l'état entier d'abord) ; un dessin retiré ou mal formé la fait oublier.
---@param id string
---@param set any
---@param removed any
---@return boolean placed
---@return boolean statusChanged
---@return boolean relabeled
function Book:change(id, set, removed)
    if self.stations[id] == nil then return false, false, false end
    local statusChanged = false
    if type(removed) == 'table' then
        for _, key in ipairs(removed) do
            if key == stationzone.DEF then return self:leave(id) end
            if key == stationzone.STATUS then statusChanged = self:setStatus(id, IDLE) or statusChanged end
        end
    end
    local placed, relabeled = false, false
    if type(set) == 'table' then
        local raw = set[stationzone.DEF]
        if raw ~= nil then
            local drawing = stationzone.readDrawing(id, raw)
            if not drawing then return self:leave(id) end
            placed, relabeled = self:place(id, drawing)
        end
        if set[stationzone.STATUS] ~= nil then
            statusChanged = self:setStatus(id, stationzone.readStatus(set[stationzone.STATUS])) or statusChanged
        end
    end
    return placed, statusChanged, relabeled
end

--- Tout oublier (déchargement, sélection).
function Book:clear()
    self.stations, self.statuses, self.ordered, self.count = {}, {}, nil, 0
end

---@param id any
---@return table|nil
function Book:station(id)
    return type(id) == 'string' and self.stations[id] or nil
end

--- Combustible et occupation connus (vide et libre tant que rien n'est arrivé).
---@param id any
---@return { fuel: number, busy: boolean }
function Book:status(id)
    return type(id) == 'string' and self.statuses[id] or IDLE
end

---@return integer
function Book:size()
    return self.count
end

--- Stations connues, triées par identifiant (liste gardée jusqu'au prochain changement de lieu : ne pas la modifier).
---@return table[]
function Book:list()
    if not self.ordered then
        local list = {}
        for _, station in pairs(self.stations) do list[#list + 1] = station end
        sort(list, function(a, b) return a.id < b.id end)
        self.ordered = list
    end
    return self.ordered
end
