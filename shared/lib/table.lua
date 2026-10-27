--[[
    shared/lib/table.lua
    Rôle : utilitaires purs sur les tables (copie de liste, retrait, clés triées).
    Dépendances : shared/init.lua
]]

local move, sort, remove = table.move, table.sort, table.remove
local pairs, tostring = pairs, tostring

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
