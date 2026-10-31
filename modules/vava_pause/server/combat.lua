--[[
    vava_pause/server/combat.lua
    Rôle : fenêtre de combat de chaque joueur, en mémoire : tout coup qui atteint le crochet after de vava_health:hit
           (annulé compris ; hors faim et pertes natives, config.combat.ignoredKinds) met la cible et l'auteur « en
           combat » `combat.windowMs` ; oubliée au déchargement du personnage et au départ du joueur. Sert au refus
           d'ouvrir la bannière et à l'export inCombat.
    Dépendances : shared/constants.lua, config.lua, shared/combat.lua, server/core.lua
]]

local tostring = tostring
local GetGameTimer = GetGameTimer

local core = VavaPause.core
if not core then return end

local cfg = VavaPause.config.combat
local rules = VavaPause.combat
local HIT = VavaPause.LISTENED.HIT

local fight = {}
VavaPause.fight = fight

---@type table<integer, integer>  joueur → fin de sa fenêtre
local windows = {}

--- Temps restant de la fenêtre de combat du joueur (0 : hors combat).
---@param src integer
---@return integer
function fight.remaining(src)
    return rules.remaining(windows, src, GetGameTimer())
end

---@param src integer
function fight.forget(src)
    windows[src] = nil
end

--- Abonnements. Appelé pendant le setup.
---@return boolean ok
---@return string|nil err
function fight.listen()
    local id, err = core.hooks.after(HIT, function(payload)
        rules.mark(windows, rules.marks(payload, cfg.ignoredKinds), GetGameTimer(), cfg.windowMs)
    end)
    if not id then return false, HIT .. ' : ' .. tostring(err) end
    return true
end
