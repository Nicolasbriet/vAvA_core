--[[
    vava_atelier/shared/codepack.lua
    Rôle : logique pure du paquet du Conseil (T-157) : lecture (decode), noms des fichiers, découpe en morceaux sans
           couper un caractère UTF-8 ; l'écriture (encode) est servie au seul serveur (shared/codepack_encode.lua,
           relecture réseau R-3). Le serveur assemble le paquet au démarrage (server/delivery.lua), le chargeur du
           membre le relit (client/loader.lua). Aucune fonction ne lève d'erreur. Testée :
           tests/spec/atelier_codepack_spec.lua.
           Format : « VAVAPAQ1\n », puis pour chaque fichier « <genre> <chemin> <octets>\n<octets du fichier>\n » ;
           genres L (Lua, exécuté), C (feuille de style), J (script de page), tous les L d'abord ; rien après le
           dernier fichier.
    Dépendances : shared/constants.lua
]]

local type, tonumber = type, tonumber
local mathType = math.type
local find, sub, byte, match, gmatch = string.find, string.sub, string.byte, string.match, string.gmatch

local LIMITS = VavaAtelier.CODEPACK
local HEAD = LIMITS.MAGIC .. '\n'
-- extension attendue de chaque genre
local EXTENSION = { L = 'lua', C = 'css', J = 'js' }
-- longueur d'une ligne d'en-tête au plus : genre, espace, chemin, espace, 7 chiffres, fin de ligne
local MAX_HEADER = 1 + 1 + LIMITS.MAX_NAME + 1 + 7 + 1
local NEWLINE = 10

local codepack = {}
VavaAtelier.codepack = codepack
-- pour shared/codepack_encode.lua (serveur) : en-tête du format et extension de chaque genre
codepack.HEAD = HEAD
codepack.EXTENSION = EXTENSION

--- Genre d'un fichier de page tel que la page le nomme (`bootPiece.kind`).
codepack.WEB_KIND = { C = 'css', J = 'js' }

--- Chemin d'un fichier du paquet : 1 à MAX_NAME octets ; segments séparés par `/` (MAX_DEPTH + 1 au plus), chacun en
--- minuscules ASCII, le dernier avec l'extension de son genre ; jamais `..`, `\`, `/` en tête ni segment vide.
---@param name any
---@param kind any  L | C | J
---@return boolean
function codepack.validName(name, kind)
    local extension = EXTENSION[kind]
    if not extension or type(name) ~= 'string' or #name < 1 or #name > LIMITS.MAX_NAME then return false end
    if sub(name, 1, 1) == '/' or sub(name, -1) == '/' or find(name, '//', 1, true) then return false end
    local segments = {}
    for segment in gmatch(name, '[^/]+') do segments[#segments + 1] = segment end
    local count = #segments
    if count > LIMITS.MAX_DEPTH + 1 then return false end
    for i = 1, count - 1 do
        if not find(segments[i], '^[a-z][a-z0-9_%-]*$') then return false end
    end
    return match(segments[count], '^[a-z][a-z0-9_%-]*%.([a-z]+)$') == extension
end
local validName = codepack.validName

--- Lecture stricte d'un paquet : chaque longueur délimite son fichier, rien n'est accepté en dehors du format.
---@param text any
---@return { kind: string, name: string, code: string }[]|nil pieces
---@return string|nil err  not_string | too_large | bad_magic | bad_header | bad_kind | bad_name | bad_order |
---                        nul_byte | duplicate | too_many | truncated | bad_end
function codepack.decode(text)
    if type(text) ~= 'string' then return nil, 'not_string' end
    local length = #text
    if length > LIMITS.MAX_BYTES then return nil, 'too_large' end
    if sub(text, 1, #HEAD) ~= HEAD then return nil, 'bad_magic' end
    local pieces, seen, web = {}, {}, false
    local pos = #HEAD + 1
    while pos <= length do
        if #pieces >= LIMITS.MAX_PIECES then return nil, 'too_many' end
        local stop = find(text, '\n', pos, true)
        if not stop or stop - pos > MAX_HEADER then return nil, 'bad_header' end
        -- classes écrites en ASCII (%u et %d suivent la locale du système) ; longueur sans zéro de tête (une seule
        -- écriture par paquet : encode(decode(t)) == t)
        local kind, name, digits = match(sub(text, pos, stop - 1), '^([A-Z]) ([^ ]+) ([0-9]+)$')
        if not kind or #digits > 7 or (#digits > 1 and sub(digits, 1, 1) == '0') then return nil, 'bad_header' end
        if not EXTENSION[kind] then return nil, 'bad_kind' end
        if not validName(name, kind) then return nil, 'bad_name' end
        if kind == 'L' then
            if web then return nil, 'bad_order' end
        else
            web = true
        end
        if seen[name] then return nil, 'duplicate' end
        seen[name] = true
        local first = stop + 1
        local last = first + tonumber(digits) - 1
        if last + 1 > length then return nil, 'truncated' end
        if byte(text, last + 1) ~= NEWLINE then return nil, 'bad_end' end
        local code = sub(text, first, last)
        if find(code, '\0', 1, true) then return nil, 'nul_byte' end
        pieces[#pieces + 1] = { kind = kind, name = name, code = code }
        pos = last + 2
    end
    return pieces
end

--- Morceaux d'au plus `size` octets dont la suite redonne `text` ; une coupure ne tombe jamais devant un octet de
--- continuation UTF-8 (0x80 à 0xBF) : on recule d'au plus 3 octets. Texte vide : liste vide.
---@param text any
---@param size any  entier ≥ 4
---@return string[]|nil parts
---@return string|nil err  not_string | bad_size
function codepack.cut(text, size)
    if type(text) ~= 'string' then return nil, 'not_string' end
    if mathType(size) ~= 'integer' or size < 4 then return nil, 'bad_size' end
    local parts, length, pos = {}, #text, 1
    while pos <= length do
        local next = pos + size
        if next > length then
            next = length + 1
        else
            local back = 0
            while back < 3 do
                local b = byte(text, next)
                if b < 0x80 or b > 0xBF then break end
                next, back = next - 1, back + 1
            end
        end
        parts[#parts + 1] = sub(text, pos, next - 1)
        pos = next
    end
    return parts
end
