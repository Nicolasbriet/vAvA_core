--[[
    vava_inventory/shared/grid.lua
    Rôle : géométrie pure des grilles : emprise d'un objet (pivoté ou non), collisions, marquage, recherche de place,
           places rendues aux piles mises de côté (1.6.3).
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

---@class vAvA.GridReturn
---@field instance table   la pile mise de côté
---@field x integer
---@field y integer
---@field rotated boolean
---@field moved boolean     vrai si ce n'est pas sa place d'origine

--- Places à rendre à des piles d'un même objet mises de côté (définition absente au chargement), sans rien modifier.
--- D'abord, chaque pile dont la place d'origine est libre la reprend ; ensuite seulement, les autres prennent la
--- première place libre : une pile replacée ailleurs ne prend jamais la place d'origine libre d'une autre pile de la
--- liste. La carte d'occupation fait foi (aucune pile n'est recouverte) et chaque place rendue est réservée pour les
--- suivantes.
---@param container vAvA.Grid
---@param instances { x: integer, y: integer, rotated: boolean }[]  par ordre de priorité (la plus ancienne d'abord)
---@param def { width: integer, height: integer }
---@return vAvA.GridReturn[] placed
---@return table[] left  piles sans place, dans l'ordre reçu
function grid.planReturn(container, instances, def)
    local reserved, placed, others, left = {}, {}, {}, {}
    for _, instance in ipairs(instances) do
        local rotated = instance.rotated == true
        local w, h = grid.footprint(def, rotated)
        if grid.fits(container, w, h, instance.x, instance.y, nil, reserved) then
            grid.reserve(reserved, container, w, h, instance.x, instance.y)
            placed[#placed + 1] = { instance = instance, x = instance.x, y = instance.y, rotated = rotated, moved = false }
        else
            others[#others + 1] = instance
        end
    end
    for _, instance in ipairs(others) do
        local x, y, rotated = grid.findSpace(container, def, reserved)
        if x then
            local w, h = grid.footprint(def, rotated)
            grid.reserve(reserved, container, w, h, x, y)
            placed[#placed + 1] = { instance = instance, x = x, y = y, rotated = rotated, moved = true }
        else
            left[#left + 1] = instance
        end
    end
    return placed, left
end
