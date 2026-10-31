--[[
    vava_codex/shared/dock.lua
    Rôle : logique pure du Codex « en panneau » (1.7.0) : rectangle où la page dessine le livre, donné par la ressource
           hôte (la bannière de vava_pause) en pourcentages de l'écran (vw, vh). Rend une copie à quatre champs, ou un
           refus : nombres finis, bord gauche et haut ≥ 0, largeur et hauteur ≥ 10, rien qui déborde de l'écran.
    Dépendances : shared/constants.lua
]]

local type, pairs = type, pairs
local huge = math.huge

local FIELDS = { left = true, top = true, width = true, height = true }
local MIN_SIZE = 10
local SCREEN = 100

local dock = {}
VavaCodex.dock = dock

---@param value any
---@return boolean
local function finite(value)
    return type(value) == 'number' and value == value and value > -huge and value < huge
end

--- Rectangle du panneau validé : copie `{ left, top, width, height }`, ou nil, 'invalid_rect'.
---@param rect any
---@return { left: number, top: number, width: number, height: number }|nil
---@return string|nil code
function dock.rect(rect)
    if type(rect) ~= 'table' then return nil, 'invalid_rect' end
    for key in pairs(rect) do
        if not FIELDS[key] then return nil, 'invalid_rect' end
    end
    local left, top, width, height = rect.left, rect.top, rect.width, rect.height
    if not (finite(left) and finite(top) and finite(width) and finite(height)) then return nil, 'invalid_rect' end
    if left < 0 or top < 0 or width < MIN_SIZE or height < MIN_SIZE then return nil, 'invalid_rect' end
    if left + width > SCREEN or top + height > SCREEN then return nil, 'invalid_rect' end
    return { left = left, top = top, width = width, height = height }
end
