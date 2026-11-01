--[[
    vava_atelier/shared/codepack_encode.lua
    Rôle : logique pure, servie au seul serveur : écriture du paquet du Conseil (T-157), le format que relit
           shared/codepack.lua (decode). Sortie de codepack.lua pour ne pas la livrer à chaque joueur (relecture
           réseau R-3). Testée : tests/spec/atelier_codepack_spec.lua.
    Dépendances : shared/constants.lua, shared/codepack.lua
]]

local type = type
local find = string.find
local concat = table.concat

local LIMITS = VavaAtelier.CODEPACK
local codepack = VavaAtelier.codepack
local HEAD, EXTENSION, validName = codepack.HEAD, codepack.EXTENSION, codepack.validName

--- Paquet à partir de ses fichiers, dans l'ordre donné.
---@param pieces { kind: string, name: string, code: string }[]  liste pure
---@return string|nil text
---@return string|nil err  too_many | bad_kind | bad_name | bad_order | not_string | nul_byte | duplicate | too_large
function codepack.encode(pieces)
    if type(pieces) ~= 'table' then return nil, 'not_string' end
    if #pieces > LIMITS.MAX_PIECES then return nil, 'too_many' end
    local out, n, size, web, seen = { HEAD }, 1, #HEAD, false, {}
    for i = 1, #pieces do
        local piece = pieces[i]
        if type(piece) ~= 'table' or not EXTENSION[piece.kind] then return nil, 'bad_kind' end
        local kind, name, code = piece.kind, piece.name, piece.code
        if not validName(name, kind) then return nil, 'bad_name' end
        if kind == 'L' then
            if web then return nil, 'bad_order' end
        else
            web = true
        end
        if type(code) ~= 'string' then return nil, 'not_string' end
        if find(code, '\0', 1, true) then return nil, 'nul_byte' end
        if seen[name] then return nil, 'duplicate' end
        seen[name] = true
        local header = kind .. ' ' .. name .. ' ' .. #code .. '\n'
        size = size + #header + #code + 1
        if size > LIMITS.MAX_BYTES then return nil, 'too_large' end
        out[n + 1], out[n + 2], out[n + 3] = header, code, '\n'
        n = n + 3
    end
    return concat(out, '', 1, n)
end
