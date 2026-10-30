--[[
    vava_atelier/shared/fingerprint.lua
    Rôle : logique pure de la version d'un contenu gardé par la page (accueil, descripteur d'un atelier) : empreinte
           FNV-1a 64 bits sur un codage canonique (clés triées, types distingués, longueurs écrites), qui ne dépend que
           de ce que la valeur contient. Copie de vava_codex/shared/fingerprint.lua (même algorithme, mêmes vecteurs de
           test : tests/spec/atelier_fingerprint_spec.lua), dans l'espace VavaAtelier ; une version commune dans le
           core serait une tâche à part.
    Dépendances : shared/constants.lua
]]

local type, pairs = type, pairs
local mathType = math.type
local byte, format = string.byte, string.format
local concat, sort = table.concat, table.sort

-- FNV-1a 64 bits : base et multiplicateur publiés (les littéraux hexadécimaux trop grands bouclent en Lua 5.4).
local FNV_OFFSET = 0xcbf29ce484222325
local FNV_PRIME = 0x100000001b3
local MAX_DEPTH = 16          -- tables imbriquées : 8 au plus dans un descripteur (types › type › formulaire › champs…)

-- rang d'un type de clé dans l'ordre canonique : booléens, puis nombres, puis chaînes
local KEY_RANK = { boolean = 1, number = 2, string = 3 }

--- Ordre total des clés d'une table : par type, puis par valeur (faux avant vrai ; nombres par valeur ; chaînes
--- octet par octet). En Lua 5.4, 1 et 1.0 sont la même clé : aucun ex aequo.
---@param a boolean|number|string
---@param b boolean|number|string
---@return boolean
local function keyBefore(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then return KEY_RANK[ta] < KEY_RANK[tb] end
    if ta == 'boolean' then return not a and b end
    return a < b
end

local encode

--- Code une table à la suite de `out` (`n` morceaux déjà écrits) : nombre de paires, puis chaque clé et sa valeur
--- dans l'ordre canonique. Une liste (clés 1 à n) se parcourt dans l'ordre sans tri : c'est déjà l'ordre canonique.
---@param value table
---@param out (string|integer)[]
---@param n integer
---@param depth integer
---@param path table<table, boolean>  tables en cours de codage (une table qui se contient elle-même est refusée)
---@return integer|nil n
---@return string|nil err
local function encodeTable(value, out, n, depth, path)
    if depth > MAX_DEPTH then return nil, 'too_deep' end
    if path[value] then return nil, 'cycle' end
    local keys, count, length, onlyStrings, inList = {}, 0, #value, true, true
    for key in pairs(value) do
        local kind = type(key)
        if not KEY_RANK[kind] then return nil, 'unsupported' end
        count = count + 1
        keys[count] = key
        if kind ~= 'string' then onlyStrings = false end
        if mathType(key) ~= 'integer' or key < 1 or key > length then inList = false end
    end
    -- n clés entières distinctes, toutes entre 1 et n : la table est une liste
    local isList = inList and count == length
    if not isList then
        -- l'ordre de parcours d'une table Lua n'est pas garanti : les clés sont triées (ordre total, sans ex aequo)
        if onlyStrings then sort(keys) else sort(keys, keyBefore) end
    end
    path[value] = true
    out[n + 1], out[n + 2], out[n + 3] = 'T', count, '{'
    n = n + 3
    local err
    for i = 1, count do
        local key = isList and i or keys[i]
        n, err = encode(key, out, n, depth + 1, path)
        if n then n, err = encode(value[key], out, n, depth + 1, path) end
        if not n then return nil, err end
    end
    path[value] = nil
    out[n + 1] = '}'
    return n + 1
end

--- Codage canonique, à la suite de `out` : même valeur, même suite ; deux valeurs différentes, deux suites
--- différentes (types et longueurs écrits : « 1 » ≠ 1 ≠ 1.5, { 'ab', 'c' } ≠ { 'a', 'bc' }). Les entiers sont
--- rangés tels quels (table.concat les écrit exactement), les réels avec 17 chiffres significatifs.
---@param value any
---@param out (string|integer)[]
---@param n integer  morceaux déjà écrits
---@param depth integer
---@param path table<table, boolean>
---@return integer|nil n
---@return string|nil err  unsupported | too_deep | cycle
encode = function(value, out, n, depth, path)
    local kind = type(value)
    if kind == 'string' then
        out[n + 1], out[n + 2], out[n + 3], out[n + 4] = 's', #value, ':', value
        return n + 4
    elseif kind == 'number' then
        if mathType(value) == 'integer' then
            out[n + 1], out[n + 2], out[n + 3] = 'i', value, ';'
        else
            out[n + 1], out[n + 2], out[n + 3] = 'd', format('%.17g', value), ';'
        end
        return n + 3
    elseif kind == 'boolean' then
        out[n + 1] = value and 't' or 'f'
        return n + 1
    elseif kind == 'table' then
        return encodeTable(value, out, n, depth, path)
    end
    return nil, 'unsupported'
end

---@param text string
---@return integer
local function fnv1a(text)
    local hash, prime = FNV_OFFSET, FNV_PRIME
    local length = #text
    local i = 1
    -- huit octets lus d'un coup dans des locales : aucune table créée pendant le calcul
    while i + 7 <= length do
        local b1, b2, b3, b4, b5, b6, b7, b8 = byte(text, i, i + 7)
        hash = (hash ~ b1) * prime
        hash = (hash ~ b2) * prime
        hash = (hash ~ b3) * prime
        hash = (hash ~ b4) * prime
        hash = (hash ~ b5) * prime
        hash = (hash ~ b6) * prime
        hash = (hash ~ b7) * prime
        hash = (hash ~ b8) * prime
        i = i + 8
    end
    while i <= length do
        hash = (hash ~ byte(text, i)) * prime
        i = i + 1
    end
    return hash
end

--- Empreinte d'une valeur : 16 chiffres hexadécimaux, ou nil et une raison (fonction, donnée du jeu, clé qui n'est ni
--- chaîne, ni nombre, ni booléen, table trop profonde ou qui se contient elle-même). Une même table rangée à deux
--- endroits est codée deux fois.
---@param value any
---@return string|nil fingerprint
---@return string|nil err
function VavaAtelier.fingerprint(value)
    local out = {}
    local n, err = encode(value, out, 0, 1, {})
    if not n then return nil, err end
    return format('%016x', fnv1a(concat(out, '', 1, n)))
end
