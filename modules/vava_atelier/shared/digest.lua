--[[
    vava_atelier/shared/digest.lua
    Rôle : logique pure : empreinte FNV-1a 64 bits d'une suite d'octets (le paquet du Conseil, T-157), en 16 chiffres
           hexadécimaux minuscules. Même algorithme que shared/fingerprint.lua (base et multiplicateur publiés, huit
           octets lus d'un coup), appliqué aux octets tels quels, sans codage canonique. Protège contre l'usure, la
           coupure et la version périmée, pas contre le propriétaire du disque (ce n'est pas une signature). Testée :
           tests/spec/atelier_codepack_spec.lua.
    Dépendances : shared/constants.lua
]]

local type = type
local byte, format = string.byte, string.format

-- FNV-1a 64 bits (les littéraux hexadécimaux trop grands bouclent en Lua 5.4, comme le calcul : modulo 2^64)
local FNV_OFFSET = 0xcbf29ce484222325
local FNV_PRIME = 0x100000001b3

--- Empreinte d'une chaîne : 16 chiffres hexadécimaux. Toute autre valeur rend nil.
---@param text string
---@return string|nil
function VavaAtelier.digest(text)
    if type(text) ~= 'string' then return nil end
    local hash, prime = FNV_OFFSET, FNV_PRIME
    local length = #text
    local i = 1
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
    return format('%016x', hash)
end
