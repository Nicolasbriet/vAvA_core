--[[
    vava_inventory/shared/grid.lua
    Rôle : géométrie pure des grilles : emprise d'un objet (pivoté ou non), collisions, marquage, recherche de place.
    Un conteneur tient une carte d'occupation (index de case → identifiant d'objet) : vérifier une place coûte
    la surface de l'objet, pas celle de la grille. Coordonnées en cases, origine en haut à gauche, à partir de 0.
    Dépendances : shared/constants.lua
]]

local ipairs = ipairs

local grid = {}
VavaInventory.grid = grid

local ORIENTATIONS = { false, true }

---@class vAvA.Grid
---@field width integer
---@field height integer
---@field occupancy table<integer, integer>

--- Largeur et hauteur occupées par un objet selon son orientation.
---@param def { width: integer, height: integer }
---@param rotated boolean
---@return integer w, integer h
function grid.footprint(def, rotated)
    if rotated then return def.height, def.width end
    return def.width, def.height
end

--- Vrai si le rectangle tient dans la grille sans chevaucher d'autre objet que `ignoreId`, ni une case de `reserved`.
---@param container vAvA.Grid
---@param w integer
---@param h integer
---@param x integer
---@param y integer
---@param ignoreId? integer
---@param reserved? table<integer, true>
---@return boolean
function grid.fits(container, w, h, x, y, ignoreId, reserved)
    if x < 0 or y < 0 or x + w > container.width or y + h > container.height then return false end
    local occupancy, width = container.occupancy, container.width
    for dy = 0, h - 1 do
        local row = (y + dy) * width + x
        for dx = 0, w - 1 do
            local index = row + dx
            local owner = occupancy[index]
            if (owner ~= nil and owner ~= ignoreId) or (reserved and reserved[index]) then return false end
        end
    end
    return true
end

---@param container vAvA.Grid
---@param w integer
---@param h integer
---@param x integer
---@param y integer
---@param id integer
function grid.mark(container, w, h, x, y, id)
    local occupancy, width = container.occupancy, container.width
    for dy = 0, h - 1 do
        local row = (y + dy) * width + x
        for dx = 0, w - 1 do occupancy[row + dx] = id end
    end
end

---@param container vAvA.Grid
---@param w integer
---@param h integer
---@param x integer
---@param y integer
---@param id integer
function grid.unmark(container, w, h, x, y, id)
    local occupancy, width = container.occupancy, container.width
    for dy = 0, h - 1 do
        local row = (y + dy) * width + x
        for dx = 0, w - 1 do
            if occupancy[row + dx] == id then occupancy[row + dx] = nil end
        end
    end
end

--- Réserve des cases dans une table temporaire (placement de plusieurs objets avant de valider).
---@param reserved table<integer, true>
---@param container vAvA.Grid
---@param w integer
---@param h integer
---@param x integer
---@param y integer
function grid.reserve(reserved, container, w, h, x, y)
    local width = container.width
    for dy = 0, h - 1 do
        local row = (y + dy) * width + x
        for dx = 0, w - 1 do reserved[row + dx] = true end
    end
end

--- Premier emplacement libre, ligne par ligne, d'abord dans le sens normal puis pivoté.
---@param container vAvA.Grid
---@param def { width: integer, height: integer }
---@param reserved? table<integer, true>
---@return integer|nil x
---@return integer|nil y
---@return boolean|nil rotated
function grid.findSpace(container, def, reserved)
    for _, rotated in ipairs(ORIENTATIONS) do
        local w, h = grid.footprint(def, rotated)
        for y = 0, container.height - h do
            for x = 0, container.width - w do
                if grid.fits(container, w, h, x, y, nil, reserved) then return x, y, rotated end
            end
        end
        if def.width == def.height then break end
    end
    return nil
end
