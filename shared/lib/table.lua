--[[
    shared/lib/table.lua
    Rôle : utilitaires purs sur les tables (copie de liste, retrait, égalité de valeur, clés triées).
    Dépendances : shared/init.lua
]]

local move, sort, remove = table.move, table.sort, table.remove
local pairs, tostring, type, next, rawget, rawequal = pairs, tostring, type, next, rawget, rawequal
local abs, mathType = math.abs, math.type

local tbl = {}
vAvA.lib.table = tbl

--- Copie superficielle d'une liste séquentielle.
---@generic T
---@param list T[]
---@return T[]
function tbl.copyArray(list)
    return move(list, 1, #list, 1, {})
end

--- Retire la première occurrence d'une valeur d'une liste séquentielle.
---@param list any[]
---@param value any
---@return boolean removed
function tbl.removeValue(list, value)
    for i = 1, #list do
        if list[i] == value then
            remove(list, i)
            return true
        end
    end
    return false
end

--- Vrai pour un nombre à partie décimale (NaN compris, jamais égal à rien).
---@param n number
---@return boolean
local function isFractional(n)
    return mathType(n) == 'float' and n ~= n // 1
end

--- Égalité de valeur : chaînes et booléens par ==, nombres par == (un entier égal à son flottant) ou, si tolerance est
--- donnée et que les deux ont une partie décimale, à tolerance près en écart relatif ; tables clé à clé, sans tenir
--- compte des métatables. Sert à comparer une valeur reçue du réseau (copie désérialisée, flottants éventuellement
--- arrondis) à celle que l'on a envoyée. Pour des arbres de données, pas des graphes à références partagées : une
--- même sous-table vue par deux chemins est comparée deux fois. Au-delà de maxDepth niveaux de tables imbriquées, les
--- valeurs sont jugées différentes : une donnée forgée trop profonde ne coûte jamais une récursion sans fin.
---@param a any
---@param b any
---@param maxDepth? integer  défaut 16
---@param tolerance? number  écart relatif admis entre deux nombres non entiers (défaut 0 : égalité stricte)
---@return boolean
function tbl.deepEqual(a, b, maxDepth, tolerance)
    if rawequal(a, b) then return true end
    local typeA, typeB = type(a), type(b)
    if typeA ~= 'table' or typeB ~= 'table' then
        if typeA == 'table' or typeB == 'table' then return false end
        if a == b then return true end
        -- seulement entre deux nombres à partie décimale : un entier (ou un flottant entier) reste comparé à
        -- l'identique, une valeur décalée d'une fraction de millionième ne l'est pas
        if not tolerance or typeA ~= 'number' or typeB ~= 'number' or not isFractional(a) or not isFractional(b) then
            return false
        end
        local scale = abs(a) > abs(b) and abs(a) or abs(b)
        return abs(a - b) <= tolerance * scale
    end
    local depth = maxDepth or 16
    if depth <= 0 then return false end
    for key, value in next, a do
        local other = rawget(b, key)
        if other == nil or not tbl.deepEqual(value, other, depth - 1, tolerance) then return false end
    end
    -- une clé de plus d'un côté : la première absente de l'autre suffit, sans compter toute la table
    for key in next, b do
        if rawget(a, key) == nil then return false end
    end
    return true
end

--- Clés d'une table, triées par représentation textuelle (ordre stable pour les logs et les listings).
---@param map table
---@return any[]
function tbl.sortedKeys(map)
    local keys = {}
    for key in pairs(map) do
        keys[#keys + 1] = key
    end
    sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end
