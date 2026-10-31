--[[
    vava_magic/shared/pages.lua
    Rôle : découpage du registre des murmures en lots (logique pure, sans base ni réseau) : une ligne lue en base
           remise au propre, poids estimé d'une page, lot borné en nombre de pages et en octets (au moins une page,
           pour que le lecteur avance toujours), curseur du lot suivant.
    Dépendances : shared/constants.lua
]]

local type, tonumber, tostring = type, tonumber, tostring
local tointeger, floor, mathType = math.tointeger, math.floor, math.type

local pages = {}
VavaMagic.pages = pages

-- Octets ajoutés par page au correspondant et au texte une fois sérialisée (msgpack : 5 clés nommées, numéro, date,
-- sens, en-têtes des deux textes) : 1 pour la table, 29 pour les clés, 9 + 5 + 1 pour les nombres, 3 + 3 pour les
-- en-têtes des textes, et 1 de marge.
pages.ENTRY_OVERHEAD = 52

-- Plafond d'un message de Murmure (octets), quelle que soit la config : `spells.murmure.textMaxBytes` borne le RPC
-- d'envoi et vient de config_client.lua (relecture sécurité S-1 de T-143).
pages.TEXT_CAP = 4096

--- Vrai si `textMax` (borne en octets d'un message de Murmure) est sûre : un entier de 1 à TEXT_CAP, et une page du
--- registre qui le porte (correspondant de `contactMax` octets, texte, ENTRY_OVERHEAD) tient dans un lot de `pageBytes`.
--- Sinon false et la raison.
---@param textMax any
---@param registers { contactMax: integer, pageBytes: integer }
---@return boolean ok
---@return string|nil reason
function pages.textBound(textMax, registers)
    if mathType(textMax) ~= 'integer' or textMax < 1 then return false, 'un nombre entier positif est attendu' end
    if textMax > pages.TEXT_CAP then return false, ('%d octets au plus'):format(pages.TEXT_CAP) end
    local room = registers.pageBytes - registers.contactMax - pages.ENTRY_OVERHEAD
    if textMax > room then
        return false, ('%d octets au plus, pour qu\'une page tienne dans un lot du registre (registers.pageBytes)'):format(room)
    end
    return true
end

---@param value any
---@return integer|nil
local function integer(value)
    value = tonumber(value)
    if type(value) ~= 'number' or value ~= value or value == math.huge or value == -math.huge then return nil end
    return tointeger(floor(value))
end

--- Page envoyée au client, d'après une ligne de `vava_magic_register_pages`. nil si la ligne est abîmée (sans numéro).
---@param row table  { id, written_at, direction, contact, body }
---@return { id: integer, at: integer, direction: integer|nil, contact: string, text: string }|nil
function pages.entry(row)
    if type(row) ~= 'table' then return nil end
    local id = integer(row.id)
    if not id or id < 1 then return nil end
    return {
        id = id, at = integer(row.written_at) or 0, direction = integer(row.direction),
        contact = row.contact ~= nil and tostring(row.contact) or '', text = row.body ~= nil and tostring(row.body) or '',
    }
end

--- Poids estimé d'une page envoyée (octets).
---@param entry { contact: string, text: string }
---@return integer
function pages.size(entry)
    return #entry.contact + #entry.text + pages.ENTRY_OVERHEAD
end

--- Lot à envoyer : les lignes lues (les plus récentes d'abord, `size + 1` au plus pour savoir s'il en reste), gardées
--- tant que le lot compte moins de `size` pages et ne dépasse pas `budget` octets. La première page part toujours,
--- quel que soit son poids. Les lignes abîmées sont écartées ; plus de `size` lignes lues : il peut en rester.
---@param rows table[]|nil
---@param size integer   pages par lot (≥ 1)
---@param budget integer octets par lot
---@return table[] list  pages du lot (liste)
---@return boolean more  il reste des pages plus anciennes
function pages.take(rows, size, budget)
    local list, weight = {}, 0
    if type(rows) ~= 'table' then return list, false end
    local total = #rows
    for index = 1, total do
        local entry = pages.entry(rows[index])
        if entry then
            if #list >= size then return list, true end
            local cost = pages.size(entry)
            if #list > 0 and weight + cost > budget then return list, true end
            list[#list + 1] = entry
            weight = weight + cost
        end
    end
    return list, total > size
end

--- Curseur du lot suivant : numéro de la plus ancienne page du lot (le lot suivant commence avant elle). nil pour
--- un lot vide.
---@param list table[]
---@return integer|nil
function pages.cursor(list)
    local last = list[#list]
    return last and last.id or nil
end
