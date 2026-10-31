--[[
    vava_admin/shared/requests.lua
    Rôle : logique pure des demandes au Conseil (1.10.0, T-145) : état de la demande d'un compte (la plus récente
           ouverte, sinon la dernière close depuis peu), texte normalisé, demandes ouvertes d'un compte, position
           arrondie au mètre, témoins retenus. Servi au seul serveur (testé hors jeu : tests/spec/admin_requests_spec.lua).
    Dépendances : shared/constants.lua
]]

local type, pairs, ipairs = type, pairs, ipairs
local floor, huge = math.floor, math.huge
local find, gsub = string.find, string.gsub
local utf8len = utf8.len

local rules = {}
VavaAdmin.requestRules = rules

---@param value any
---@return boolean
local function finite(value)
    return type(value) == 'number' and value == value and value > -huge and value < huge
end

-- Caractères refusés dans une demande (même liste que str.hasControl du core, saut de ligne permis) : contrôles ASCII
-- sauf le saut de ligne, contrôles C1 en UTF-8, espace sans largeur et marques de sens (U+200B à U+200F), séparateurs
-- de ligne et de paragraphe et sens d'écriture (U+2028 à U+202E), isolats de sens (U+2066 à U+2069), marque arabe
-- (U+061C), marque d'ordre des octets (U+FEFF). Écrits octet par octet (jamais %c : il suit la locale, T-133).
local REFUSED = {
    '[\0-\9\11-\31\127]',
    '\194[\128-\159]',
    '\226\128[\139-\143\168-\174]',
    '\226\129[\166-\169]',
    '\216\156',
    '\239\187\191',
}

--- Texte d'une demande normalisé (1.10.0, relecture sécurité S-1 et S-2 de T-145), pour /signaler comme pour la
--- bannière : UTF-8 valide, aucun caractère de REFUSED, espaces répétés, espaces de bord de ligne et bords du texte
--- retirés, au plus deux sauts de ligne de suite et `maxLines` lignes, au moins `minChars` caractères (comptés en
--- caractères). Rend le texte, ou nil, code : invalid_text, too_short.
---@param text any
---@param opts { minChars: integer, maxBytes: integer, maxLines: integer }
---@return string|nil
---@return string|nil code
function rules.normalize(text, opts)
    if type(text) ~= 'string' or #text > opts.maxBytes or not utf8len(text) then return nil, 'invalid_text' end
    for _, pattern in ipairs(REFUSED) do
        if find(text, pattern) then return nil, 'invalid_text' end
    end
    local clean = gsub(text, ' +', ' ')
    clean = gsub(clean, ' ?\n ?', '\n')
    clean = gsub(clean, '^[ \n]+', '')
    clean = gsub(clean, '[ \n]+$', '')
    clean = gsub(clean, '\n\n\n+', '\n\n')
    local _, breaks = gsub(clean, '\n', '\n')
    if breaks + 1 > opts.maxLines then return nil, 'invalid_text' end
    if utf8len(clean) < opts.minChars then return nil, 'too_short' end
    return clean
end

--- Demandes ouvertes d'un compte.
---@param open table<integer, table>  signalements ouverts { id, accountId, … }
---@param accountId integer
---@return integer
function rules.openCount(open, accountId)
    local count = 0
    for _, report in pairs(open) do
        if report.accountId == accountId then count = count + 1 end
    end
    return count
end

--- État de la demande d'un compte, pour la bannière : la plus récente de ses demandes ouvertes (`claimed` si un membre
--- l'a prise, sinon `sent`), sinon sa dernière demande close depuis moins de `memoryMs` (`closed`), sinon nil. `age` en
--- secondes : depuis l'envoi (ouverte) ou depuis la clôture (close).
---@param open table<integer, table>  signalements ouverts { id, accountId, kind, at, claimedBy? }
---@param closed { id: integer, kind: string, at: integer }|nil  dernière demande close du compte
---@param accountId integer
---@param now integer  GetGameTimer()
---@param memoryMs integer
---@return { id: integer, kind: string, state: string, age: integer }|nil
function rules.statusOf(open, closed, accountId, now, memoryMs)
    local latest = nil
    for _, report in pairs(open) do
        if report.accountId == accountId and (not latest or report.id > latest.id) then latest = report end
    end
    if latest then
        return {
            id = latest.id, kind = latest.kind, state = latest.claimedBy and 'claimed' or 'sent',
            age = floor(((now - latest.at) > 0 and (now - latest.at) or 0) / 1000),
        }
    end
    if closed and now - closed.at < memoryMs then
        return { id = closed.id, kind = closed.kind, state = 'closed', age = floor(((now - closed.at) > 0 and (now - closed.at) or 0) / 1000) }
    end
    return nil
end

--- Position lue par le serveur, arrondie au mètre : { x, y, z } entiers, ou nil si une coordonnée n'est pas un nombre
--- fini.
---@param coords any  vector3 ou { x, y, z }
---@return { x: integer, y: integer, z: integer }|nil
function rules.roundPosition(coords)
    if coords == nil then return nil end
    local x, y, z = coords.x, coords.y, coords.z
    if not (finite(x) and finite(y) and finite(z)) then return nil end
    return { x = floor(x + 0.5), y = floor(y + 0.5), z = floor(z + 0.5) }
end

--- Témoins d'un signalement de joueur : les joueurs proches donnés (auteur exclu), chacun gardé par son numéro de
--- compte et son nom de personnage, `max` au plus, dans l'ordre reçu ; un joueur sans compte ni nom est sauté.
---@param near integer[]  numéros des joueurs proches (core.net.playersNear)
---@param author integer  numéro de l'auteur
---@param max integer
---@param identify fun(src: integer): integer|nil, string|nil  numéro de compte et nom du personnage
---@return { accountId: integer, name: string }[]
function rules.witnesses(near, author, max, identify)
    local out = {}
    if type(near) ~= 'table' then return out end
    for _, src in ipairs(near) do
        if #out >= max then break end
        if src ~= author then
            local accountId, name = identify(src)
            if accountId and name then out[#out + 1] = { accountId = accountId, name = name } end
        end
    end
    return out
end
