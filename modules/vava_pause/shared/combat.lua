--[[
    vava_pause/shared/combat.lua
    Rôle : logique pure de la fenêtre de combat, servie au seul serveur : d'après un coup passé par la chaîne de
           dégâts (crochet after de vava_health:hit, annulé compris : une parade est un combat), qui est « en combat »
           — la cible, et l'auteur si c'est un autre joueur ; rien pour la faim et les pertes natives — et pour combien
           de temps encore.
    Dépendances : shared/constants.lua
]]

local type, ipairs = type, ipairs
local mathType = math.type

local combat = {}
VavaPause.combat = combat

---@param value any
---@return boolean
local function isPlayer(value)
    return mathType(value) == 'integer' and value > 0
end

--- Joueurs à marquer « en combat » pour ce coup : la cible, puis la source si c'est un autre joueur ; liste vide si la
--- nature du coup est ignorée.
---@param payload any  charge du crochet after de vava_health:hit
---@param ignoredKinds string[]
---@return integer[]
function combat.marks(payload, ignoredKinds)
    local out = {}
    if type(payload) ~= 'table' then return out end
    for _, kind in ipairs(ignoredKinds or {}) do
        if payload.kind == kind then return out end
    end
    if isPlayer(payload.target) then out[#out + 1] = payload.target end
    if isPlayer(payload.source) and payload.source ~= payload.target then out[#out + 1] = payload.source end
    return out
end

--- Pose la fenêtre de chaque joueur marqué (la plus lointaine échéance gardée).
---@param windows table<integer, integer>  joueur → fin de sa fenêtre (horloge du serveur)
---@param marked integer[]
---@param now integer
---@param windowMs integer
function combat.mark(windows, marked, now, windowMs)
    local untilMs = now + windowMs
    for _, src in ipairs(marked) do
        if not windows[src] or windows[src] < untilMs then windows[src] = untilMs end
    end
end

--- Temps restant de la fenêtre d'un joueur (0 : hors combat).
---@param windows table<integer, integer>
---@param src integer
---@param now integer
---@return integer
function combat.remaining(windows, src, now)
    local untilMs = windows[src]
    if not untilMs or untilMs <= now then return 0 end
    return untilMs - now
end
