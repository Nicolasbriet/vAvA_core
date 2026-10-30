--[[
    tests/audit/classe_c.lua
    Rôle : cas écrits pour `./scripts/audit-reseau.sh --essai` (jamais chargé, ni linté, ni audité en mode normal) :
           classe '%c' dans un motif (T-133), qui suit la locale du système. Chaque ligne qui compte finit par ce que
           l'audit doit en dire : « attendu: BLOQUANT », « attendu: AVERTISSEMENT » ou « attendu: rien ».
           Un bloc de commentaire qui cite gsub(s, '%c', ' ') ne compte pas.  -- attendu: rien
]]

local gsub, find = string.gsub, string.find
local CONTROLS = '[\0-\31\127]'  -- attendu: rien

local function nettoie(s)
    local a = gsub(s, '%c', ' ')  -- attendu: BLOQUANT
    local b = find(s, "[^%c]+")  -- attendu: BLOQUANT
    local c = find(s, '%%c')  -- attendu: rien
    local d = find(s, '%%%c')  -- attendu: BLOQUANT
    local e = find(s, [[%c]])  -- attendu: BLOQUANT
    local f = find(s, CONTROLS)  -- attendu: rien
    -- un commentaire qui cite find(s, '%c')  -- attendu: rien
    local g = find(s, 'x') -- puis '%c' cité en fin de ligne  -- attendu: rien
    local h = find(s, '%%c', 1, true) or find(s, '[%s%c]')  -- attendu: BLOQUANT
    return a, b, c, d, e, f, g, h
end

return nettoie
