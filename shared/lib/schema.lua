--[[
    shared/lib/schema.lua
    Rôle : compilation et validation de schémas de données (types, bornes, structures imbriquées).
    Un schéma est compilé une fois à l'enregistrement (erreurs de définition détectées tôt), puis validé à chaque appel.
    Dépendances : shared/init.lua
]]

local type, pairs, next, tostring, pcall, getmetatable = type, pairs, next, tostring, pcall, getmetatable
local mathType, tointeger = math.type, math.tointeger
local format, find = string.format, string.find
local HUGE = math.huge

local schema = {}
vAvA.lib.schema = schema

local KNOWN_TYPES = {
    string = true, number = true, integer = true, boolean = true,
    table = true, array = true, map = true, any = true, ['function'] = true,
}
-- Types qu'aucun client ne peut légitimement envoyer.
local SERVER_ONLY_TYPES = { any = true, ['function'] = true }
local ENUM_TYPES = { string = true, number = true, integer = true }
local MAP_KEY_TYPES = { string = true, integer = true }
local NO_OPTIONS = {}

---@class vAvA.SchemaDefinition
---@field type 'string'|'number'|'integer'|'boolean'|'table'|'array'|'map'|'function'|'any'
---@field optional? boolean
---@field min? number      string : longueur min · number/integer : valeur min · array/map : nombre d'éléments min
---@field max? number
---@field pattern? string  string : motif Lua que la valeur doit contenir (ancrer avec ^ et $)
---@field enum? any[]      string/number/integer : valeurs autorisées
---@field fields? table<string, vAvA.SchemaDefinition>  table : champs attendus
---@field strict? boolean  table : refuse les clés non déclarées (défaut true, obligatoire en réseau)
---@field items? vAvA.SchemaDefinition  array : schéma de chaque élément
---@field key? vAvA.SchemaDefinition    map : schéma des clés (string ou integer)
---@field value? vAvA.SchemaDefinition  map : schéma des valeurs

---@class vAvA.SchemaCompileOptions
---@field net? boolean              entrée réseau : 'any', 'function' et tables non strictes interdits, bornes par défaut injectées
---@field maxStringLength? integer
---@field maxArrayLength? integer
---@field maxMapEntries? integer

--- Vrai si la valeur peut être appelée : fonction locale, ou référence de fonction venant d'une autre ressource
--- (FiveM la transmet comme une table dotée d'un __call).
---@param value any
---@return boolean
function schema.isCallable(value)
    if type(value) == 'function' then return true end
    if type(value) ~= 'table' then return false end
    local mt = getmetatable(value)
    return type(mt) == 'table' and mt.__call ~= nil
end

local compileNode

---@return table|nil node
---@return string|nil err
compileNode = function(def, options, path)
    if type(def) ~= 'table' then
        return nil, format('%s : définition attendue (table)', path)
    end
    local kind = def.type
    if not KNOWN_TYPES[kind] then
        return nil, format("%s : type inconnu '%s'", path, tostring(kind))
    end
    if SERVER_ONLY_TYPES[kind] and options.net then
        return nil, format("%s : le type '%s' est interdit pour une entrée réseau", path, kind)
    end
    if def.min ~= nil and type(def.min) ~= 'number' then
        return nil, format('%s : min doit être un nombre', path)
    end
    if def.max ~= nil and type(def.max) ~= 'number' then
        return nil, format('%s : max doit être un nombre', path)
    end
    if def.min and def.max and def.min > def.max then
        return nil, format('%s : min > max', path)
    end

    local node = { type = kind, optional = def.optional == true, min = def.min, max = def.max }

    if kind == 'string' then
        if def.pattern ~= nil then
            if type(def.pattern) ~= 'string' or not pcall(find, '', def.pattern) then
                return nil, format('%s : motif invalide', path)
            end
            node.pattern = def.pattern
        end
        if options.net and not node.max then node.max = options.maxStringLength end
    elseif kind == 'array' then
        local items, err = compileNode(def.items, options, path .. '[]')
        if not items then return nil, err end
        node.items = items
        if options.net and not node.max then node.max = options.maxArrayLength end
    elseif kind == 'map' then
        local key, keyErr = compileNode(def.key, options, path .. '<clé>')
        if not key then return nil, keyErr end
        if not MAP_KEY_TYPES[key.type] then
            return nil, format('%s : les clés de map doivent être de type string ou integer', path)
        end
        local value, valueErr = compileNode(def.value, options, path .. '<valeur>')
        if not value then return nil, valueErr end
        node.key, node.value = key, value
        if options.net and not node.max then node.max = options.maxMapEntries end
    elseif kind == 'table' then
        if type(def.fields) ~= 'table' then
            return nil, format('%s : fields attendu pour le type table', path)
        end
        local fields, count = {}, 0
        for name, fieldDef in pairs(def.fields) do
            if type(name) ~= 'string' then
                return nil, format('%s : les noms de champs doivent être des chaînes', path)
            end
            local field, err = compileNode(fieldDef, options, path .. '.' .. name)
            if not field then return nil, err end
            fields[name] = field
            count = count + 1
        end
        node.fields, node.fieldCount = fields, count
        node.strict = def.strict ~= false
        -- une table non stricte laisserait passer des clés arbitraires venant du client
        if options.net and not node.strict then
            return nil, format('%s : strict = false est interdit pour une entrée réseau', path)
        end
    end

    if def.enum ~= nil then
        if not ENUM_TYPES[kind] or type(def.enum) ~= 'table' then
            return nil, format('%s : enum réservé aux types string, number et integer (liste attendue)', path)
        end
        local set = {}
        for _, allowed in pairs(def.enum) do set[allowed] = true end
        if next(set) == nil then
            return nil, format('%s : enum vide', path)
        end
        node.enum = set
    end

    return node
end

local validateNode

-- Les messages d'erreur ne sont construits qu'en cas d'échec : le chemin nominal n'alloue aucune chaîne.
---@return boolean ok
---@return string|nil err
validateNode = function(node, value)
    if value == nil then
        if node.optional then return true end
        return false, 'valeur requise'
    end

    local kind = node.type
    if kind == 'any' then return true end
    -- avant le contrôle de métatable : une fonction d'une autre ressource arrive comme une table à __call
    if kind == 'function' then
        if schema.isCallable(value) then return true end
        return false, 'fonction attendue'
    end
    local valueType = type(value)
    -- une donnée brute n'a jamais de métatable ; une référence de fonction transmise par le réseau, si
    if valueType == 'table' and getmetatable(value) ~= nil then return false, 'donnée brute attendue' end

    if kind == 'string' then
        if valueType ~= 'string' then return false, 'chaîne attendue' end
        local length = #value
        if node.min and length < node.min then return false, format('longueur < %d', node.min) end
        if node.max and length > node.max then return false, format('longueur > %d', node.max) end
        if node.pattern and not find(value, node.pattern) then return false, 'format invalide' end
    elseif kind == 'number' or kind == 'integer' then
        if valueType ~= 'number' then return false, 'nombre attendu' end
        if value ~= value or value == HUGE or value == -HUGE then return false, 'nombre non fini' end
        -- un flottant n'est accepté que s'il a un équivalent entier : 3.0 oui ; 1e300 ou 2^63, entiers en apparence
        -- (x % 1 == 0) mais hors des entiers Lua, non (le RPC les convertirait en nil)
        if kind == 'integer' and mathType(value) ~= 'integer' and tointeger(value) == nil then
            return false, 'entier attendu'
        end
        if node.min and value < node.min then return false, format('valeur < %s', node.min) end
        if node.max and value > node.max then return false, format('valeur > %s', node.max) end
    elseif kind == 'boolean' then
        if valueType ~= 'boolean' then return false, 'booléen attendu' end
    elseif kind == 'table' then
        if valueType ~= 'table' then return false, 'table attendue' end
        local fields = node.fields
        if node.strict then
            local count = 0
            for key in pairs(value) do
                count = count + 1
                if count > node.fieldCount or fields[key] == nil then
                    return false, format("clé non autorisée '%s'", tostring(key))
                end
            end
        end
        for name, field in pairs(fields) do
            local ok, err = validateNode(field, value[name])
            if not ok then return false, name .. ' : ' .. err end
        end
    elseif kind == 'array' then
        if valueType ~= 'table' then return false, 'liste attendue' end
        local max, count = node.max, 0
        -- sortie dès la borne dépassée : une table géante n'est jamais parcourue entièrement
        for key in pairs(value) do
            count = count + 1
            if max and count > max then return false, format('plus de %d éléments', max) end
            if mathType(key) ~= 'integer' or key < 1 then return false, 'liste attendue (clés non séquentielles)' end
        end
        if node.min and count < node.min then return false, format('moins de %d éléments', node.min) end
        local items = node.items
        for i = 1, count do
            local item = value[i]
            if item == nil then return false, 'liste attendue (trous)' end
            local ok, err = validateNode(items, item)
            if not ok then return false, format('[%d] : %s', i, err) end
        end
    elseif kind == 'map' then
        if valueType ~= 'table' then return false, 'table attendue' end
        local max, count = node.max, 0
        local keyNode, valueNode = node.key, node.value
        for key, item in pairs(value) do
            count = count + 1
            if max and count > max then return false, format('plus de %d entrées', max) end
            local ok, err = validateNode(keyNode, key)
            if not ok then return false, 'clé : ' .. err end
            ok, err = validateNode(valueNode, item)
            if not ok then return false, format('[%s] : %s', tostring(key), err) end
        end
        if node.min and count < node.min then return false, format('moins de %d entrées', node.min) end
    end

    if node.enum and not node.enum[value] then return false, 'valeur non autorisée' end
    return true
end

--- Compile une définition de schéma.
---@param definition vAvA.SchemaDefinition
---@param options? vAvA.SchemaCompileOptions
---@return table|nil compiled
---@return string|nil err
function schema.compile(definition, options)
    return compileNode(definition, options or NO_OPTIONS, 'schéma')
end

--- Compile une liste ordonnée de schémas (arguments ou valeurs de retour d'un RPC).
---@param definitions vAvA.SchemaDefinition[]
---@param options? vAvA.SchemaCompileOptions
---@param label string  préfixe des messages d'erreur
---@return table[]|nil compiled
---@return string|nil err
function schema.compileList(definitions, options, label)
    if type(definitions) ~= 'table' then
        return nil, format('%s : liste de schémas attendue ({} si aucun)', label)
    end
    local count = #definitions
    for key in pairs(definitions) do
        if mathType(key) ~= 'integer' or key < 1 or key > count then
            return nil, format('%s : liste séquentielle attendue', label)
        end
    end
    local compiled = {}
    for i = 1, count do
        local node, err = compileNode(definitions[i], options or NO_OPTIONS, format('%s#%d', label, i))
        if not node then return nil, err end
        compiled[i] = node
    end
    return compiled
end

--- Valide une valeur contre un schéma compilé.
---@param compiled table
---@param value any
---@return boolean ok
---@return string|nil err
function schema.validate(compiled, value)
    return validateNode(compiled, value)
end

--- Valide une liste de valeurs reçue du réseau contre une liste de schémas compilés.
--- Le nombre de valeurs voyage à part : msgpack ne conserve pas le champ n d'une table.pack, et une liste
--- à trous n'a pas de longueur fiable. Toute valeur au-delà de `count` ou des schémas déclarés est refusée.
---@param compiledList table[]
---@param values any
---@param count any
---@return boolean ok
---@return string|nil err
function schema.validateList(compiledList, values, count)
    local max = #compiledList
    if mathType(count) ~= 'integer' or count < 0 or count > max then
        return false, format('nombre de valeurs invalide (0 à %d attendu)', max)
    end
    if type(values) ~= 'table' or getmetatable(values) ~= nil then
        return false, 'liste de valeurs attendue'
    end
    for i = 1, max do
        local value = values[i]
        if i > count and value ~= nil then
            return false, format('#%d : valeur au-delà du nombre annoncé', i)
        end
        local ok, err = validateNode(compiledList[i], value)
        if not ok then return false, format('#%d : %s', i, err) end
    end
    return true
end
