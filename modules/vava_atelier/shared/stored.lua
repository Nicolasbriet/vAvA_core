--[[
    vava_atelier/shared/stored.lua
    Rôle : logique pure de la fiche gardée (§ 5.5 de la spec T-101) : ce qui est écrit en base et ce qui est passé au
           module.
             - normalize(form, brut)     → data plate aux champs du formulaire en vigueur (champ manquant ou hors bornes
                                           → valeur de départ, signalé ; clé inconnue retirée ; 3.0 → 3 d'un entier)
             - encode(encode, data, lieu, max) → JSON de data, JSON du lieu ('' sans lieu), poids ; refus too_large
             - fingerprint(data, lieu, parent) → empreinte (comparaisons, colonne `fingerprint`)
             - read(ligne, ctx)          → { data, place, parent, reset, fingerprint } ou nil, raison : JSON décodé,
                                           format plus ancien monté par `upgrade`, normalisation, lieu contrôlé ; une
                                           ligne d'un format plus récent que l'éditeur, ou dont `upgrade` échoue, est
                                           illisible (jamais appliquée, jamais publiée)
             - def(entrée, id, version)  → fiche passée au module : data + id, version, parent?, place? (jamais status)
           Le JSON est fait par le pont (fonctions passées en argument) : rien ici ne touche au runtime.
           Testée : tests/spec/atelier_stored_spec.lua.
    Dépendances : shared/constants.lua, shared/formvalues.lua, shared/fingerprint.lua, shared/place.lua
]]

local type, pairs, tostring, tonumber = type, pairs, tostring, tonumber
local mathType = math.type
local find = string.find

local fv, place = VavaAtelier.formvalues, VavaAtelier.place
local ENTRY_PATTERN, MAX_ENTRY = VavaAtelier.ENTRY_PATTERN, VavaAtelier.MAX_ENTRY

local stored = {}
VavaAtelier.stored = stored

--- Data plate aux champs du formulaire en vigueur, et les champs repris à leur valeur de départ.
---@param form table
---@param raw any
---@return table data
---@return string[] reset
function stored.normalize(form, raw)
    local packet, reset = fv.toPacket(form, raw)
    local data = {}
    for _, card in pairs(packet) do
        for key, value in pairs(card) do data[key] = value end
    end
    return data, reset
end

--- Poids d'une fiche : JSON de data + JSON du lieu, au plus `maxBytes`.
---@param dataJson string
---@param placeJson string
---@param maxBytes integer
---@return boolean
function stored.fits(dataJson, placeJson, maxBytes)
    return #dataJson + #placeJson <= maxBytes
end

--- JSON d'une fiche : data, lieu ('' sans lieu), poids ; nil et `too_large` au-delà de `maxBytes`, ou `invalid` si le
--- codage échoue.
---@param encode fun(value: table): string|nil
---@param data table
---@param where table|nil
---@param maxBytes integer
---@return string|nil dataJson
---@return string placeJsonOrErr
---@return integer|nil bytes
function stored.encode(encode, data, where, maxBytes)
    local dataJson = encode(data)
    if type(dataJson) ~= 'string' then return nil, 'invalid' end
    local placeJson = ''
    if where ~= nil then
        placeJson = encode(where)
        if type(placeJson) ~= 'string' then return nil, 'invalid' end
    end
    if not stored.fits(dataJson, placeJson, maxBytes) then return nil, 'too_large' end
    return dataJson, placeJson, #dataJson + #placeJson
end

--- Empreinte d'une fiche (data normalisée, lieu arrondi, parent) : stable quel que soit l'ordre des clés.
---@param data table
---@param where table|nil
---@param parent string|nil
---@return string|nil
function stored.fingerprint(data, where, parent)
    return VavaAtelier.fingerprint({ d = data, p = where or false, r = parent or false })
end

---@param value any
---@return string|nil
local function parentOf(value)
    if type(value) == 'string' and value ~= '' and #value <= MAX_ENTRY and find(value, ENTRY_PATTERN) then
        return value
    end
    return nil
end
stored.parentOf = parentOf

---@class vAvA.AtelierStoredContext
---@field decode fun(json: string): any      décodage JSON (nil en cas d'erreur)
---@field form table                          formulaire en vigueur du type
---@field placement string|nil                forme du lieu du type
---@field limits table                        bornes des lieux (config.place)
---@field format integer                      format en vigueur de l'éditeur
---@field upgrade? fun(data: table, from: integer): table|nil, string|nil   montée de format (appel isolé)

---@class vAvA.AtelierStoredEntry
---@field data table
---@field place table|nil
---@field parent string|nil
---@field reset string[]
---@field fingerprint string

--- Fiche lue d'une ligne gardée. nil et une raison : format plus récent, `upgrade` en échec, JSON illisible, lieu
--- hors bornes (la fiche est alors « illisible par cet atelier »).
---@param row { data: string, place?: string, format?: integer, parent?: string }
---@param ctx vAvA.AtelierStoredContext
---@return vAvA.AtelierStoredEntry|nil
---@return string|nil err
function stored.read(row, ctx)
    local rowFormat = tonumber(row.format) or 1
    if rowFormat > ctx.format then
        return nil, ('format %s plus récent que celui de l\'atelier (%d)'):format(tostring(rowFormat), ctx.format)
    end
    local raw = type(row.data) == 'string' and ctx.decode(row.data) or nil
    if type(raw) ~= 'table' then return nil, 'données illisibles' end
    if rowFormat < ctx.format and ctx.upgrade then
        local upgraded, err = ctx.upgrade(raw, rowFormat)
        if type(upgraded) ~= 'table' then
            return nil, ('montée du format %d échouée : %s'):format(rowFormat, tostring(err or 'refusée'))
        end
        raw = upgraded
    end
    local data, reset = stored.normalize(ctx.form, raw)
    local where = nil
    if ctx.placement and type(row.place) == 'string' and row.place ~= '' then
        local decoded = ctx.decode(row.place)
        if type(decoded) ~= 'table' then return nil, 'lieu illisible' end
        local err
        where, err = place.check(ctx.placement, decoded, ctx.limits)
        if not where then return nil, 'lieu : ' .. tostring(err) end
    end
    local parent = parentOf(row.parent)
    return {
        data = data, place = where, parent = parent, reset = reset,
        fingerprint = stored.fingerprint(data, where, parent),
    }
end

--- Fiche passée au module : une copie de la data, plus `id`, `version`, et `parent`, `place` s'ils existent.
---@param entry { data: table, place?: table, parent?: string }
---@param id string
---@param version integer|nil
---@return table
function stored.def(entry, id, version)
    local def = {}
    for key, value in pairs(entry.data) do def[key] = value end
    def.id = id
    if mathType(version) == 'integer' then def.version = version end
    if entry.parent then def.parent = entry.parent end
    if entry.place then
        local copy = {}
        for key, value in pairs(entry.place) do copy[key] = value end
        def.place = copy
    end
    return def
end

--- Data et lieu rendus par `read` d'un module (graine, rapprochement) : clés réservées séparées, data normalisée.
---@param raw table  retour de `read(kind, id)`
---@param form table
---@param placement string|nil
---@param limits table
---@return vAvA.AtelierStoredEntry|nil
---@return string|nil err  lieu refusé
function stored.fromModule(raw, form, placement, limits)
    local fields = {}
    for key, value in pairs(raw) do
        if key ~= 'id' and key ~= 'place' and key ~= 'version' and key ~= 'status' and key ~= 'parent' then
            fields[key] = value
        end
    end
    local data, reset = stored.normalize(form, fields)
    local where, err = place.check(placement, raw.place, limits)
    if placement and raw.place ~= nil and not where then return nil, 'lieu : ' .. tostring(err) end
    local parent = parentOf(raw.parent)
    return {
        data = data, place = where, parent = parent, reset = reset,
        fingerprint = stored.fingerprint(data, where, parent),
    }
end
