--[[
    server/players/fields.lua
    Rôle : registre des champs de personnage déclarés par les modules (schéma, valeur par défaut, visibilité),
           lecture et écriture validées des valeurs. Les valeurs vivent dans character.data (colonne JSON).
    Visibilité : private (serveur seul, défaut) · owner (envoyé au seul joueur concerné) · public (statebag répliqué).
    Dépendances : shared/lib/string.lua, shared/lib/schema.lua
]]

local type, tostring, pairs = type, tostring, pairs
local format = string.format

local str = vAvA.lib.string
local schema = vAvA.lib.schema

local VISIBILITIES = { private = true, owner = true, public = true }

local fields = {}
vAvA.fields = fields

---@alias vAvA.FieldVisibility 'private'|'owner'|'public'

---@class vAvA.FieldDefinition
---@field owner string
---@field name string
---@field schema table
---@field default any
---@field visibility vAvA.FieldVisibility

---@type table<string, vAvA.FieldDefinition>
local definitions = {}

---@class vAvA.FieldOptions
---@field schema vAvA.SchemaDefinition
---@field default? any
---@field visibility? vAvA.FieldVisibility

--- Déclare un champ. Le nom doit être préfixé par "<owner>:".
---@param owner string
---@param name string
---@param options vAvA.FieldOptions
---@return boolean ok
---@return string|nil err
function fields.define(owner, name, options)
    if not str.isIdentifier(name) or not str.hasPrefix(name, owner .. ':') then
        return false, format("nom de champ invalide '%s' (attendu : '%s:<champ>')", tostring(name), owner)
    end
    if definitions[name] then
        return false, format("champ '%s' déjà défini par '%s'", name, definitions[name].owner)
    end
    if type(options) ~= 'table' then
        return false, 'options requises : { schema = { ... } }'
    end
    local compiled, err = schema.compile(options.schema)
    if not compiled then return false, err end
    local visibility = options.visibility or 'private'
    if not VISIBILITIES[visibility] then
        return false, format("visibilité invalide '%s' (private, owner ou public)", tostring(visibility))
    end
    if options.default ~= nil then
        local valid, defaultErr = schema.validate(compiled, options.default)
        if not valid then return false, 'valeur par défaut invalide : ' .. defaultErr end
    end
    definitions[name] = { owner = owner, name = name, schema = compiled, default = options.default, visibility = visibility }
    return true
end

--- Valide une valeur contre la définition d'un champ, sans l'écrire (champs fournis à la création).
---@param name string
---@param value any
---@return boolean ok
---@return string|nil err
function fields.validate(name, value)
    local def = definitions[name]
    if not def then return false, 'unknown_field' end
    local valid, err = schema.validate(def.schema, value)
    if not valid then return false, 'invalid_value : ' .. err end
    return true
end

--- Valeur d'un champ pour un personnage chargé (défaut si jamais écrit).
---@param character vAvA.Character
---@param name string
---@return any value
---@return string|nil err
function fields.get(character, name)
    local def = definitions[name]
    if not def then return nil, 'unknown_field' end
    local value = character.data[name]
    if value == nil then return def.default end
    return value
end

--- Écrit un champ après validation. Renvoie la définition si la valeur a changé (à sauvegarder et synchroniser),
--- nil si elle est identique : aucune écriture ni envoi inutile.
---@param character vAvA.Character
---@param name string
---@param value any
---@return boolean ok
---@return vAvA.FieldDefinition|string|nil changedOrErr
function fields.set(character, name, value)
    local def = definitions[name]
    if not def then return false, 'unknown_field' end
    local valid, err = schema.validate(def.schema, value)
    if not valid then return false, 'invalid_value : ' .. err end
    if type(value) ~= 'table' and character.data[name] == value then return true, nil end
    character.data[name] = value
    character.revision = character.revision + 1
    return true, def
end

--- Parcourt les champs visibles par le client propriétaire (owner et public).
---@param fn fun(name: string, def: vAvA.FieldDefinition)
function fields.forEachVisible(fn)
    for name, def in pairs(definitions) do
        if def.visibility ~= 'private' then fn(name, def) end
    end
end

--- Parcourt les champs publics (répliqués par statebag).
---@param fn fun(name: string, def: vAvA.FieldDefinition)
function fields.forEachPublic(fn)
    for name, def in pairs(definitions) do
        if def.visibility == 'public' then fn(name, def) end
    end
end

--- Retire les définitions d'un propriétaire arrêté. Les valeurs restent dans data et sont toujours sauvegardées :
--- au redémarrage du module, elles réapparaissent.
---@param owner string
function fields.purgeOwner(owner)
    for name, def in pairs(definitions) do
        if def.owner == owner then definitions[name] = nil end
    end
end
