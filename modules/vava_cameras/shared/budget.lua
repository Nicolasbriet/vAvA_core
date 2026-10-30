--[[
    vava_cameras/shared/budget.lua
    Rôle : règle pure du débit montant d'un joueur filmé. Chaque spectateur a sa connexion et son encodeur, et tous
           partent de la connexion montante du joueur, qui porte aussi le jeu et la voix : leur total est borné par un
           budget. Admission : au plus N spectateurs d'une même qualité (une seule vue en grand) et la somme des
           débits planchers sous le budget. Répartition : chacun reçoit son plancher, puis le reste va à la plus grande
           image d'abord (vue en grand), jusqu'à son plafond, et enfin aux cases, à parts égales. Deux spectateurs
           d'une même qualité ont toujours le même débit : la répartition ne dépend que du nombre par qualité.
    Dépendances : shared/constants.lua (chargée côté serveur seulement)
]]

local pairs, ipairs, floor, sort = pairs, ipairs, math.floor, table.sort

local budget = {}
VavaCameras.budget = budget

---@class vAvA.CameraQuality
---@field bitrateKbps integer  plafond (débit nominal)
---@field minKbps integer      plancher

---@class vAvA.CameraBudget
---@field uplinkKbps integer                 total montant d'un joueur filmé
---@field perQuality table<string, integer>  spectateurs au plus par qualité (absente : sans autre borne)

--- Somme des planchers de ces spectateurs.
---@param counts table<string, integer>
---@param qualities table<string, vAvA.CameraQuality>
---@return integer
local function floorsOf(counts, qualities)
    local total = 0
    for quality, n in pairs(counts) do total = total + n * qualities[quality].minKbps end
    return total
end

--- Un spectateur de plus, de cette qualité, tient-il dans le budget du joueur filmé ?
---@param counts table<string, integer>  spectateurs actuels par qualité
---@param quality string
---@param qualities table<string, vAvA.CameraQuality>
---@param rules vAvA.CameraBudget
---@return boolean
function budget.admits(counts, quality, qualities, rules)
    local settings = qualities[quality]
    if not settings then return false end
    local max = rules.perQuality[quality]
    if max and (counts[quality] or 0) + 1 > max then return false end
    return floorsOf(counts, qualities) + settings.minKbps <= rules.uplinkKbps
end

--- Débit de chaque qualité présente (kbit/s, entier ≥ 1), dont la somme pour tous les spectateurs ne dépasse
--- jamais `totalKbps` (sauf budget plus petit qu'un kbit/s par spectateur).
---@param counts table<string, integer>  spectateurs par qualité
---@param qualities table<string, vAvA.CameraQuality>
---@param totalKbps integer
---@return table<string, integer> rates
function budget.rates(counts, qualities, totalKbps)
    local rates, order = {}, {}
    for quality, n in pairs(counts) do
        if n > 0 then order[#order + 1] = quality end
    end
    if #order == 0 then return rates end
    local floors = floorsOf(counts, qualities)
    if floors > totalKbps then
        -- planchers au-delà du budget (admis sous une autre règle) : réduits à proportion, rien au-dessus
        for _, quality in ipairs(order) do
            local share = floor(qualities[quality].minKbps * totalKbps / floors)
            rates[quality] = share < 1 and 1 or share
        end
        return rates
    end
    -- la plus grande image d'abord (vue en grand), puis les cases ; à plafond égal, par nom (ordre stable)
    sort(order, function(a, b)
        local ca, cb = qualities[a].bitrateKbps, qualities[b].bitrateKbps
        if ca ~= cb then return ca > cb end
        return a < b
    end)
    local left = totalKbps - floors
    for _, quality in ipairs(order) do
        local settings, n = qualities[quality], counts[quality]
        local extra = floor(left / n)
        local room = settings.bitrateKbps - settings.minKbps
        if extra > room then extra = room end
        if extra < 0 then extra = 0 end
        rates[quality] = settings.minKbps + extra
        left = left - extra * n
    end
    return rates
end
