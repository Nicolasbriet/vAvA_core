--[[
    vava_loading/shared/constants.lua
    Rôle : table du module (seule globale Lua de la ressource), noms des messages envoyés à la page de l'écran de
           chargement et des hooks écoutés, bornes, et deux fonctions pures (durée bornée, comparaison de versions).
    Dépendances : aucune
]]

local type, tonumber, floor, HUGE = type, tonumber, math.floor, math.huge
local match = string.match

VavaLoading = {}

VavaLoading.CORE_RESOURCE = 'vAvA_core'

-- Messages locaux envoyés à la page par SendLoadingScreenMessage (aucun réseau). La page ignore tout autre nom.
VavaLoading.MESSAGES = {
    RESOURCES = 'vava_loading:resources',   -- le script client tourne : les ressources du serveur se lancent (feu 4)
    WAITING = 'vava_loading:waiting',       -- session ouverte, sélection en préparation (feu 6)
    HANDOFF = 'vava_loading:handoff',       -- { ms } : sélection affichée, éclair puis fondu de la page
}

-- Hooks client du core écoutés (celui de l'écran de sélection est dans config.lua, selection.shownHook).
VavaLoading.HOOKS = {
    SELECTION = 'core:character:selection', -- le joueur est mis en attente : la sélection se prépare
    LOADED = 'core:character:loaded',       -- personnage chargé sans passer par la sélection : fermeture immédiate
}

-- Bornes de la durée de l'éclair (ms), la même que celles que la page accepte.
VavaLoading.HANDOFF_MIN_MS = 300
VavaLoading.HANDOFF_MAX_MS = 5000

--- Entier borné ; `fallback` si la valeur n'est pas un nombre fini.
---@param value any
---@param min integer
---@param max integer
---@param fallback integer
---@return integer
function VavaLoading.clamp(value, min, max, fallback)
    if type(value) ~= 'number' or value ~= value or value == HUGE or value == -HUGE then return fallback end
    value = floor(value)
    if value < min then return min end
    if value > max then return max end
    return value
end

--- Vrai si `version` (MAJEUR.MINEUR.CORRECTIF) est au moins `minimum` ; faux si l'une des deux est illisible.
---@param version any
---@param minimum any
---@return boolean
function VavaLoading.versionAtLeast(version, minimum)
    if type(version) ~= 'string' or type(minimum) ~= 'string' then return false end
    local a = { match(version, '^(%d+)%.(%d+)%.(%d+)$') }
    local b = { match(minimum, '^(%d+)%.(%d+)%.(%d+)$') }
    if #a ~= 3 or #b ~= 3 then return false end
    for i = 1, 3 do
        local x, y = tonumber(a[i]), tonumber(b[i])
        if x ~= y then return x > y end
    end
    return true
end
