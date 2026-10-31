--[[
    vava_pause/shared/snapshot.lua
    Rôle : logique pure de l'instantané d'ouverture, servie au seul serveur : savoir-faire compactés (niveau
           décroissant puis libellé, plafond), confrérie revalidée (champs connus, textes sans contrôle, invisible ni chevron,
           couleurs « #rrggbb », meuble connu ou meuble par défaut), touches du registre `core:commands` (sorte `key`,
           portée permise, non cachées, bornées, triées par chapitre puis libellé, plafond), état de la demande au
           Conseil revalidé.
    Dépendances : shared/constants.lua
]]

local type, pairs, ipairs = type, pairs, ipairs
local mathType, floor, huge = math.type, math.floor, math.huge
local sort = table.sort
local find, match = string.find, string.match
local utf8len = utf8.len

local snapshot = {}
VavaPause.snapshot = snapshot

local ID_PATTERN = '^[%w_%-%.:]+$'
local COLOR_PATTERN = '^#%x%x%x%x%x%x$'
local CHARGE_PATTERN = '^[%w_]+$'
-- texte lisible : UTF-8 valide, sans chevron, sans aucun caractère de la liste de str.hasControl du core (relecture
-- sécurité S-1 de T-145) : contrôles ASCII et C1, espace sans largeur et marques de sens (U+200B à U+200F),
-- séparateurs et sens d'écriture (U+2028 à U+202E), isolats (U+2066 à U+2069), marque arabe (U+061C), U+FEFF
local REFUSED = {
    '[\0-\31\127<>]',
    '\194[\128-\159]',
    '\226\128[\139-\143\168-\174]',
    '\226\129[\166-\169]',
    '\216\156',
    '\239\187\191',
}

local SKILL = { id = 32, label = 48, rank = 32, rankLabel = 32 }
local GUILD = { label = 48, short = 16, grade = 32, charge = 24 }
local GUILD_FIELDS = { label = true, short = true, grade = true, cloth = true, clothDark = true, field = true, charge = true }
local KEY = { name = 64, label = 80, chapter = 40, module = 64, key = 32, keyDisplay = 40 }
local REQUEST_STATES = { sent = true, claimed = true, closed = true }

---@param value string
---@return boolean
local function refused(value)
    for _, pattern in ipairs(REFUSED) do
        if find(value, pattern) then return true end
    end
    return false
end

--- Texte lisible de 1 à `max` octets.
---@param value any
---@param max integer
---@return boolean
local function readable(value, max)
    return type(value) == 'string' and #value > 0 and #value <= max and utf8len(value) ~= nil and not refused(value)
end

---@param value any
---@return boolean
local function finite(value)
    return type(value) == 'number' and value == value and value > -huge and value < huge
end

-- Savoir-faire --------------------------------------------------------------------------------------------------------

--- Savoir-faire compactés : { id, label, level, rank, rankLabel }, niveau décroissant puis libellé puis id, `max` au
--- plus ; une vue malformée est écartée.
---@param views any  liste rendue par exports.vava_skills:getSkills
---@param max integer
---@return table[]
function snapshot.skills(views, max)
    local out = {}
    if type(views) ~= 'table' then return out end
    for _, view in ipairs(views) do
        local rank = type(view) == 'table' and view.rank or nil
        if type(rank) == 'table' and readable(view.id, SKILL.id) and match(view.id, ID_PATTERN)
            and readable(view.label, SKILL.label) and finite(view.level) and view.level >= 0 and view.level <= 100
            and readable(rank.name, SKILL.rank) and match(rank.name, CHARGE_PATTERN) and readable(rank.label, SKILL.rankLabel) then
            out[#out + 1] = { id = view.id, label = view.label, level = floor(view.level), rank = rank.name, rankLabel = rank.label }
        end
    end
    sort(out, function(a, b)
        if a.level ~= b.level then return a.level > b.level end
        if a.label ~= b.label then return a.label < b.label end
        return a.id < b.id
    end)
    for i = #out, max + 1, -1 do out[i] = nil end
    return out
end

-- Confrérie -----------------------------------------------------------------------------------------------------------

--- Confrérie revalidée (contrat `bannerOf` de vava_guilds) : copie, ou nil, raison. Un meuble inconnu devient
--- `defaultCharge`.
---@param raw any
---@param charges string[]  meubles connus
---@param defaultCharge string
---@return table|nil
---@return string|nil reason
function snapshot.guild(raw, charges, defaultCharge)
    if raw == nil then return nil end
    if type(raw) ~= 'table' then return nil, 'not_a_table' end
    for field in pairs(raw) do
        if not GUILD_FIELDS[field] then return nil, 'unknown_field' end
    end
    if not readable(raw.label, GUILD.label) or not readable(raw.short, GUILD.short) then return nil, 'invalid_label' end
    if raw.grade ~= nil and not readable(raw.grade, GUILD.grade) then return nil, 'invalid_grade' end
    for _, field in ipairs({ 'cloth', 'clothDark', 'field' }) do
        if type(raw[field]) ~= 'string' or not match(raw[field], COLOR_PATTERN) then return nil, 'invalid_color' end
    end
    local charge = defaultCharge
    if type(raw.charge) == 'string' and #raw.charge <= GUILD.charge and match(raw.charge, CHARGE_PATTERN) then
        for _, known in ipairs(charges or {}) do
            if known == raw.charge then charge = known end
        end
    end
    return {
        label = raw.label, short = raw.short, grade = raw.grade, cloth = raw.cloth, clothDark = raw.clothDark,
        field = raw.field, charge = charge,
    }
end

-- Touches -------------------------------------------------------------------------------------------------------------

--- Touches du registre `core:commands` : { name, label, chapter, module, key, keyDisplay?, hold? }, sorte `key`,
--- portée dans `scopes`, non cachées, bornées ; triées par chapitre puis libellé puis nom ; `max` au plus.
---@param entries any  { [nom] = déclaration } (core.registry.all)
---@param scopes string[]
---@param max integer
---@return table[]
function snapshot.keys(entries, scopes, max)
    local out = {}
    if type(entries) ~= 'table' then return out end
    local allowed = {}
    for _, scope in ipairs(scopes or {}) do allowed[scope] = true end
    for name, entry in pairs(entries) do
        if type(entry) == 'table' and entry.kind == 'key' and allowed[entry.scope] and entry.hidden ~= true
            and readable(name, KEY.name) and match(name, ID_PATTERN)
            and readable(entry.label, KEY.label) and readable(entry.chapter, KEY.chapter)
            and readable(entry.module, KEY.module) and readable(entry.key, KEY.key)
            and (entry.keyDisplay == nil or readable(entry.keyDisplay, KEY.keyDisplay)) then
            out[#out + 1] = {
                name = name, label = entry.label, chapter = entry.chapter, module = entry.module, key = entry.key,
                keyDisplay = entry.keyDisplay, hold = entry.hold == true or nil,
            }
        end
    end
    sort(out, function(a, b)
        if a.chapter ~= b.chapter then return a.chapter < b.chapter end
        if a.label ~= b.label then return a.label < b.label end
        return a.name < b.name
    end)
    for i = #out, max + 1, -1 do out[i] = nil end
    return out
end

-- Demande au Conseil --------------------------------------------------------------------------------------------------

--- État de la demande (export requestOf de vava_admin) revalidé : { id, kind, state, age }, ou nil.
---@param raw any
---@param kinds string[]
---@return table|nil
function snapshot.request(raw, kinds)
    if type(raw) ~= 'table' or mathType(raw.id) ~= 'integer' or raw.id <= 0 or not REQUEST_STATES[raw.state]
        or mathType(raw.age) ~= 'integer' or raw.age < 0 then
        return nil
    end
    for _, kind in ipairs(kinds) do
        if raw.kind == kind then return { id = raw.id, kind = kind, state = raw.state, age = raw.age } end
    end
    return nil
end
