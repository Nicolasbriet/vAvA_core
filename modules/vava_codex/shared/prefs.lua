--[[
    vava_codex/shared/prefs.lua
    Rôle : logique pure des préférences du Codex : copie défensive d'une valeur lue dans le champ du personnage,
           ramenée aux maximums actuels de la config. Un maximum abaissé après coup (`favorites.max`, `recent.max`)
           tronque la liste au lieu de rendre le champ invalide : sinon plus aucune écriture ne passerait son schéma, et
           chaque « Lancer » (qui note la commande aux dernières pages) serait refusé.
    Dépendances : shared/constants.lua
]]

local ipairs, type = ipairs, type

--- Copie bornée des préférences : signets (les premiers posés), dernières pages (les plus récentes, en tête), réglage.
---@param value any                                   valeur lue dans le champ (nil ou illisible : préférences vides)
---@param limits { favorites: integer, recent: integer }  maximums actuels
---@param keepOpenDefault boolean
---@return { favorites: string[], recent: table[], keepOpen: boolean }
function VavaCodex.fitPrefs(value, limits, keepOpenDefault)
    local out = { favorites = {}, recent = {}, keepOpen = keepOpenDefault }
    if type(value) ~= 'table' then return out end
    local favorites, recent = out.favorites, out.recent
    if type(value.favorites) == 'table' then
        for _, name in ipairs(value.favorites) do
            if #favorites >= limits.favorites then break end
            if type(name) == 'string' then favorites[#favorites + 1] = name end
        end
    end
    if type(value.recent) == 'table' then
        for _, entry in ipairs(value.recent) do
            if #recent >= limits.recent then break end
            if type(entry) == 'table' then recent[#recent + 1] = { name = entry.name, action = entry.action, at = entry.at } end
        end
    end
    if type(value.keepOpen) == 'boolean' then out.keepOpen = value.keepOpen end
    return out
end
