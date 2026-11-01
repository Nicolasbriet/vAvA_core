--[[
    vava_atelier/shared/digest.lua
    Rôle : logique pure : empreintes du paquet du Conseil (T-157). `digest` : FNV-1a 64 bits sur les octets, en 16
           chiffres hexadécimaux (même algorithme que shared/fingerprint.lua, sans codage canonique) : version du
           paquet, contrôle des morceaux reçus et du stockage local contre l'usure, la coupure et la version périmée.
           Ce n'est pas une signature : FNV-1a s'inverse octet par octet. `sha256` (FIPS 180-4, en Lua pur) : empreinte
           que le serveur annonce et que le chargeur recalcule sur le texte complet juste avant tout `load`, quelle que
           soit sa provenance (relecture sécurité S-1 : un autre serveur qui écrirait le stockage local de la ressource
           ne peut pas fabriquer un paquet de même SHA-256). Testée : tests/spec/atelier_codepack_spec.lua.
    Dépendances : shared/constants.lua
]]

local type = type
local byte, format, rep, pack, unpack = string.byte, string.format, string.rep, string.pack, string.unpack

-- FNV-1a 64 bits (les littéraux hexadécimaux trop grands bouclent en Lua 5.4, comme le calcul : modulo 2^64)
local FNV_OFFSET = 0xcbf29ce484222325
local FNV_PRIME = 0x100000001b3

--- Empreinte FNV-1a d'une chaîne : 16 chiffres hexadécimaux. Toute autre valeur rend nil.
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

-- SHA-256 : mots de 32 bits rangés dans des entiers de 64 bits, ramenés par M après chaque somme ou rotation
local M = 0xffffffff
local K = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}
local WORDS = '>' .. rep('I4', 16)
local PAUSE_BLOCKS = 256      -- blocs de 64 octets entre deux pauses (16 Ko, ≈ 4 à 5 ms de Lua)

--- Empreinte SHA-256 d'une chaîne : 64 chiffres hexadécimaux minuscules. Toute autre valeur rend nil. `pause`
--- (facultatif) est appelée tous les 16 Ko : le chargeur y cède une image (≈ 70 ms de Lua pour 245 Ko sinon d'un coup).
---@param text string
---@param pause? fun()
---@return string|nil
function VavaAtelier.sha256(text, pause)
    if type(text) ~= 'string' then return nil end
    local length = #text
    local fill = (55 - length) % 64
    local message = text .. '\128' .. rep('\0', fill) .. pack('>I8', length * 8)
    local h0, h1, h2, h3, h4, h5, h6, h7 =
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    local w = {}
    local blocks = 0
    for start = 1, #message, 64 do
        blocks = blocks + 1
        if pause and blocks % PAUSE_BLOCKS == 0 then pause() end
        w[1], w[2], w[3], w[4], w[5], w[6], w[7], w[8], w[9], w[10], w[11], w[12], w[13], w[14], w[15], w[16] =
            unpack(WORDS, message, start)
        for i = 17, 64 do
            local x, y = w[i - 15], w[i - 2]
            local s0 = ((x >> 7) | (x << 25)) ~ ((x >> 18) | (x << 14)) ~ (x >> 3)
            local s1 = ((y >> 17) | (y << 15)) ~ ((y >> 19) | (y << 13)) ~ (y >> 10)
            w[i] = (w[i - 16] + (s0 & M) + w[i - 7] + (s1 & M)) & M
        end
        local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7
        for i = 1, 64 do
            local s1 = (((e >> 6) | (e << 26)) ~ ((e >> 11) | (e << 21)) ~ ((e >> 25) | (e << 7))) & M
            local t1 = h + s1 + ((e & f) ~ (~e & g)) + K[i] + w[i]
            local s0 = (((a >> 2) | (a << 30)) ~ ((a >> 13) | (a << 19)) ~ ((a >> 22) | (a << 10))) & M
            local t2 = s0 + ((a & b) ~ (a & c) ~ (b & c))
            h, g, f, e, d, c, b, a = g, f, e, (d + t1) & M, c, b, a, (t1 + t2) & M
        end
        h0, h1, h2, h3 = (h0 + a) & M, (h1 + b) & M, (h2 + c) & M, (h3 + d) & M
        h4, h5, h6, h7 = (h4 + e) & M, (h5 + f) & M, (h6 + g) & M, (h7 + h) & M
    end
    return format('%08x%08x%08x%08x%08x%08x%08x%08x', h0, h1, h2, h3, h4, h5, h6, h7)
end
