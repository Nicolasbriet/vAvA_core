--[[
    vava_provisions/shared/pointzone.lua
    Rôle : règles pures du partage des points d'eau par les abonnements de zone du core (vAvA_core 0.11.0), adaptées
           de vava_crafting/shared/stationzone.lua (sans état changeant : la réserve n'est jamais publiée). Côté
           serveur : lieu de la zone d'un point (cercle au sol, marge) et dessin publié (`def`). Côté client : lecture
           prudente de ce qui arrive, et carnet des points connus (entrée dans une zone, changement, sortie) qui dit si
           quelque chose a bougé. Rien de secret dans l'état d'une zone : il est public pour quiconque peut s'en
           approcher. Testé dans tests/spec/provisions_pointzone_spec.lua.
    Dépendances : shared/constants.lua
]]

local type, pairs, ipairs, setmetatable = type, pairs, ipairs, setmetatable
local huge = math.huge
local find = string.find
local sort = table.sort

local pointzone = {}
VavaProvisions.pointzone = pointzone

-- Clé de l'état d'une zone de point d'eau.
pointzone.DEF = 'def'

-- Bornes de lecture côté client (une valeur hors bornes fait ignorer le point, jamais lever une erreur).
local ID_PATTERN, ID_MAX = VavaProvisions.ID_PATTERN, VavaProvisions.ID_MAX
local LABEL_MAX, MODEL_MAX = VavaProvisions.LABEL_MAX, VavaProvisions.MODEL_MAX
local MODEL_PATTERN = '^[A-Za-z0-9_]*$'

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

---@param value any
---@return boolean
local function identifier(value)
    return text(value, ID_MAX) and find(value, ID_PATTERN) ~= nil
end

-- Serveur ------------------------------------------------------------------------------------------------------------

--- Lieu de la zone du core d'un point : cercle au sol de `radius` mètres autour de lui, connu des joueurs à `margin`
--- mètres de son bord. Pas de `bucket` : la zone vaut pour toutes les instances (à revoir pour un point d'intérieur).
---@param point { x: number, y: number }
---@param radius number
---@param margin number
---@return { x: number, y: number, radius: number, margin: number }
function pointzone.area(point, radius, margin)
    return { x = point.x, y = point.y, radius = radius, margin = margin }
end

---@param kinds table|nil
---@param kindId string
---@return string
local function kindModel(kinds, kindId)
    local kind = type(kinds) == 'table' and kinds[kindId] or nil
    local model = type(kind) == 'table' and kind.model or nil
    return type(model) == 'string' and model or ''
end

--- Ce que les clients proches reçoivent pour dessiner un point (point validé par rules.validatePoint, modèle résolu).
--- Allégé : `model` seulement s'il diffère de celui de la sorte (le client le reprend de sa config), `heading`
--- seulement s'il n'est pas nul.
---@param point { kind: string, label: string, x: number, y: number, z: number, heading: number, model: string }
---@param kinds table|nil  sortes de la config
---@return { kind: string, label: string, x: number, y: number, z: number, heading: number|nil, model: string|nil }
function pointzone.drawing(point, kinds)
    local model = point.model or ''
    local heading = point.heading or 0.0
    return {
        kind = point.kind, label = point.label, x = point.x, y = point.y, z = point.z,
        heading = heading ~= 0 and heading or nil,
        model = model ~= kindModel(kinds, point.kind) and model or nil,
    }
end

-- Client -------------------------------------------------------------------------------------------------------------

--- Point lu dans l'état d'une zone, ou nil si la valeur est mal formée. Sans `model` : celui de la sorte (config du
--- client ; sorte inconnue : aucun prop) ; sans `heading` : 0.
---@param id any   identifiant local de la zone (= identifiant du point)
---@param raw any  valeur de `def`
---@param kinds table|nil  sortes de la config
---@return { id: string, kind: string, label: string, x: number, y: number, z: number, heading: number, model: string }|nil
function pointzone.readDrawing(id, raw, kinds)
    if not identifier(id) or type(raw) ~= 'table' then return nil end
    if not identifier(raw.kind) or not text(raw.label, LABEL_MAX) then return nil end
    if not finite(raw.x) or not finite(raw.y) or not finite(raw.z) then return nil end
    if raw.heading ~= nil and not finite(raw.heading) then return nil end
    local model = raw.model
    if model == nil then model = kindModel(kinds, raw.kind) end
    if type(model) ~= 'string' or #model > MODEL_MAX or not find(model, MODEL_PATTERN) then return nil end
    return {
        id = id, kind = raw.kind, label = raw.label, x = raw.x, y = raw.y, z = raw.z, heading = raw.heading or 0.0,
        model = model,
    }
end

---@param a table
---@param b table
---@return boolean
local function sameDrawing(a, b)
    return a.kind == b.kind and a.label == b.label and a.x == b.x and a.y == b.y and a.z == b.z
        and a.heading == b.heading and a.model == b.model
end
pointzone.sameDrawing = sameDrawing

---@class vAvA.WaterPointBook
---@field points table<string, table>   identifiant → point dessiné
---@field ordered table[]|nil           points triés par identifiant (refaits après un changement)
---@field count integer
---@field kinds table|nil               sortes de la config (modèle d'un point qui n'en publie pas)
local Book = {}
Book.__index = Book

--- Carnet des points connus du client : seulement ceux des zones qu'il suit.
---@param kinds table|nil  sortes de la config
---@return vAvA.WaterPointBook
function pointzone.book(kinds)
    return setmetatable({ points = {}, ordered = nil, count = 0, kinds = kinds }, Book)
end

--- Oublie un point.
---@param id string
---@return boolean changed  vrai s'il était connu
function Book:leave(id)
    if self.points[id] == nil then return false end
    self.points[id] = nil
    self.count = self.count - 1
    self.ordered = nil
    return true
end

---@param id string
---@param drawing table
---@return boolean changed
function Book:place(id, drawing)
    local previous = self.points[id]
    if previous and sameDrawing(previous, drawing) then return false end
    if not previous then self.count = self.count + 1 end
    self.points[id] = drawing
    self.ordered = nil
    return true
end

--- Zone suivie, état entier reçu (première fois, ou de nouveau entier) : le point est placé ou remplacé. Un dessin mal
--- formé fait oublier le point.
---@param id string
---@param state any
---@return boolean changed  un point est apparu, a bougé (lieu, nom, sorte, modèle) ou a disparu
function Book:enter(id, state)
    local drawing = type(state) == 'table' and pointzone.readDrawing(id, state[pointzone.DEF], self.kinds) or nil
    if not drawing then return self:leave(id) end
    return self:place(id, drawing)
end

--- Changements d'une zone suivie : `set` (clé → valeur), `removed` (liste de clés). Un point inconnu est ignoré (le
--- core envoie toujours l'état entier d'abord) ; un dessin retiré ou mal formé le fait oublier.
---@param id string
---@param set any
---@param removed any
---@return boolean changed
function Book:change(id, set, removed)
    if self.points[id] == nil then return false end
    if type(removed) == 'table' then
        for _, key in ipairs(removed) do
            if key == pointzone.DEF then return self:leave(id) end
        end
    end
    if type(set) == 'table' and set[pointzone.DEF] ~= nil then
        local drawing = pointzone.readDrawing(id, set[pointzone.DEF], self.kinds)
        if not drawing then return self:leave(id) end
        return self:place(id, drawing)
    end
    return false
end

--- Tout oublier (déchargement, sélection).
function Book:clear()
    self.points, self.ordered, self.count = {}, nil, 0
end

---@param id any
---@return table|nil
function Book:point(id)
    return type(id) == 'string' and self.points[id] or nil
end

---@return integer
function Book:size()
    return self.count
end

--- Points connus, triés par identifiant (liste gardée jusqu'au prochain changement : ne pas la modifier).
---@return table[]
function Book:list()
    if not self.ordered then
        local list = {}
        for _, point in pairs(self.points) do list[#list + 1] = point end
        sort(list, function(a, b) return a.id < b.id end)
        self.ordered = list
    end
    return self.ordered
end
