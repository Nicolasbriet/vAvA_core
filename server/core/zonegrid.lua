--[[
    server/core/zonegrid.lua
    Rôle : grille des zones (logique pure) : le sol est découpé en cases carrées ; chaque zone est inscrite dans toutes
           les cases que touche le carré qui englobe son cercle d'intérêt (centre ± portée). Un passage ne regarde que
           les zones de la case du joueur, au lieu de toutes. Aucune native, aucun envoi.
    Dépendances : shared/init.lua
]]

local setmetatable, next = setmetatable, next
local floor = math.floor

local zonegrid = {}
vAvA.zonegrid = zonegrid

-- Clé entière d'une case : (cx + OFFSET) * STRIDE + (cy + OFFSET), distincte pour |cx|, |cy| < OFFSET (2^20 cases :
-- bien au-delà de ±50 000 m, même avec des cases de 1 m).
local OFFSET = 1048576
local STRIDE = 2097152
-- ensemble vide rendu pour une case sans zone (jamais modifié)
local EMPTY = setmetatable({}, { __newindex = function() end })

---@class vAvA.ZoneGrid
---@field size number                                     côté d'une case (m)
---@field cells table<integer, table<integer, true>>      clé de case → numéros des zones inscrites
---@field spans table<integer, integer[]>                 numéro → { cx min, cx max, cy min, cy max }
local Grid = {}
Grid.__index = Grid

--- Nouvelle grille vide.
---@param cellSize number  côté d'une case, > 0
---@return vAvA.ZoneGrid
function zonegrid.new(cellSize)
    return setmetatable({ size = cellSize, cells = {}, spans = {} }, Grid)
end

--- Case d'un point.
---@param x number
---@param y number
---@return integer cx
---@return integer cy
function Grid:cellOf(x, y)
    local size = self.size
    return floor(x / size), floor(y / size)
end

--- Clé entière de la case d'un point.
---@param x number
---@param y number
---@return integer
function Grid:keyOf(x, y)
    local cx, cy = self:cellOf(x, y)
    return (cx + OFFSET) * STRIDE + (cy + OFFSET)
end

--- Inscrit une zone dans les cases que touche le carré centre ± portée (une zone déjà inscrite est d'abord retirée).
---@param handle integer
---@param x number
---@param y number
---@param reach number  rayon d'intérêt (rayon + marge)
function Grid:insert(handle, x, y, reach)
    if self.spans[handle] then self:remove(handle) end
    local minX, minY = self:cellOf(x - reach, y - reach)
    local maxX, maxY = self:cellOf(x + reach, y + reach)
    local cells = self.cells
    for cx = minX, maxX do
        local base = (cx + OFFSET) * STRIDE + OFFSET
        for cy = minY, maxY do
            local key = base + cy
            local set = cells[key]
            if not set then
                set = {}
                cells[key] = set
            end
            set[handle] = true
        end
    end
    self.spans[handle] = { minX, maxX, minY, maxY }
end

--- Retire une zone de toutes ses cases (une case vidée est oubliée).
---@param handle integer
function Grid:remove(handle)
    local span = self.spans[handle]
    if not span then return end
    self.spans[handle] = nil
    local cells = self.cells
    for cx = span[1], span[2] do
        local base = (cx + OFFSET) * STRIDE + OFFSET
        for cy = span[3], span[4] do
            local key = base + cy
            local set = cells[key]
            if set then
                set[handle] = nil
                if next(set) == nil then cells[key] = nil end
            end
        end
    end
end

--- Déplace une zone : retrait de ses anciennes cases, inscription dans les nouvelles.
---@param handle integer
---@param x number
---@param y number
---@param reach number
function Grid:move(handle, x, y, reach)
    self:remove(handle)
    self:insert(handle, x, y, reach)
end

--- Zones inscrites dans la case d'un point : ensemble numéro → true, propre à la grille (à lire, jamais à modifier).
---@param x number
---@param y number
---@return table<integer, true>
function Grid:candidates(x, y)
    return self.cells[self:keyOf(x, y)] or EMPTY
end

--- Nombre de cases occupées (lecture pour les tests et /vava_reseau).
---@return integer
function Grid:cellCount()
    local count = 0
    for _ in next, self.cells do count = count + 1 end
    return count
end
