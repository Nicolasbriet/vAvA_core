--[[
    vava_pause/shared/settings.lua
    Rôle : logique pure des réglages du joueur, côté client : défauts, lecture tolérante de ce qui est gardé sur sa
           machine (texte illisible → défauts, clé inconnue retirée, valeur hors des choix ou d'un autre type → défaut
           de la clé), validation d'un changement, réglages montrés selon les ressources démarrées, forme envoyée à la
           page. Le décodage JSON est passé en paramètre (json.decode en jeu).
    Dépendances : shared/constants.lua
]]

local type, ipairs, pairs, pcall = type, ipairs, pairs, pcall

local settings = {}
VavaPause.settings = settings

-- Texte gardé au-delà de cette taille : ignoré (le format en fait moins d'un kilo-octet).
local MAX_STORED = 4096

---@param list table[]  définitions (config.settings.list)
---@param key string
---@return table|nil
local function definition(list, key)
    for _, def in ipairs(list) do
        if def.key == key then return def end
    end
    return nil
end

--- Valeur canonique si `value` est permise par la définition, sinon nil. Choix comparés par égalité (115.0 vaut 115 :
--- la valeur rendue est celle de la liste) ; levier : booléen seulement.
---@param def table
---@param value any
---@return any
local function accepted(def, value)
    if def.kind == 'lever' then
        if type(value) == 'boolean' then return value end
        return nil
    end
    if def.kind == 'choice' then
        if value == nil or value ~= value then return nil end
        for _, choice in ipairs(def.choices) do
            if type(choice) == type(value) and choice == value then return choice end
        end
    end
    return nil
end

--- Défauts : { [clé] = valeur }.
---@param list table[]
---@return table<string, any>
function settings.defaults(list)
    local out = {}
    for _, def in ipairs(list) do out[def.key] = def.default end
    return out
end

--- Valeurs complètes d'après une table lue (nil ou illisible : défauts) : chaque clé connue présente, les autres
--- retirées.
---@param raw any
---@param list table[]
---@return table<string, any>
function settings.normalize(raw, list)
    local out = {}
    for _, def in ipairs(list) do
        local value = nil
        if type(raw) == 'table' then value = accepted(def, raw[def.key]) end   -- un levier peut valoir false
        if value == nil then value = def.default end
        out[def.key] = value
    end
    return out
end

--- Valeurs d'après le texte gardé (KVP) : `decode` est json.decode ; texte absent, trop long ou illisible → défauts.
---@param text any
---@param list table[]
---@param decode fun(text: string): any
---@return table<string, any>
function settings.read(text, list, decode)
    if type(text) ~= 'string' or #text == 0 or #text > MAX_STORED then return settings.defaults(list) end
    local ok, raw = pcall(decode, text)
    return settings.normalize(ok and raw or nil, list)
end

--- Copie des seules clés connues, prête à être encodée et gardée.
---@param values table<string, any>
---@param list table[]
---@return table<string, any>
function settings.encodable(values, list)
    local out = {}
    for _, def in ipairs(list) do out[def.key] = values[def.key] end
    return out
end

--- Changement d'un réglage : `true, valeur` (canonique) ou `false, code` (unknown_setting, invalid_value).
---@param list table[]
---@param key any
---@param value any
---@return boolean ok
---@return any valueOrCode
function settings.validate(list, key, value)
    if type(key) ~= 'string' then return false, 'unknown_setting' end
    local def = definition(list, key)
    if not def then return false, 'unknown_setting' end
    local clean = accepted(def, value)
    if clean == nil then return false, 'invalid_value' end
    return true, clean
end

--- Vrai si au moins une ressource de `uses` est démarrée (`started(nom)`).
---@param def table
---@param started fun(resource: string): boolean
---@return boolean
function settings.usable(def, started)
    for _, resource in ipairs(def.uses or {}) do
        if started(resource) then return true end
    end
    return false
end

--- Définitions montrées à la page (réglages utilisables seulement) : copies { key, tab, kind, label, help, default,
--- choices?, labels? }.
---@param list table[]
---@param started fun(resource: string): boolean
---@return table[]
function settings.visible(list, started)
    local out = {}
    for _, def in ipairs(list) do
        if settings.usable(def, started) then
            local copy = {}
            for field, value in pairs(def) do
                if field ~= 'uses' then copy[field] = value end
            end
            out[#out + 1] = copy
        end
    end
    return out
end
