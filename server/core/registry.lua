--[[
    server/core/registry.lua
    Rôle : registres génériques. Un module définit un registre (nom préfixé par son propre nom, schéma des entrées,
           validateur optionnel) ; d'autres modules y ajoutent des entrées validées. Base des futurs items,
           groupes, permissions. Données côté serveur uniquement : l'exposition au client passe par un RPC explicite.
    Dépendances : shared/lib/string.lua, shared/lib/schema.lua, shared/core/logger.lua, shared/core/hooks.lua
]]

local type, tostring, pairs, xpcall = type, tostring, pairs, xpcall
local traceback = debug.traceback
local mathType = math.type
local format = string.format

local str = vAvA.lib.string
local schema = vAvA.lib.schema
local hooks = vAvA.hooks
local log = vAvA.logger.create('registry')

local HOOK_ADDED = 'core:registry:added'
local HOOK_REMOVED = 'core:registry:removed'
local HOOK_DROPPED = 'core:registry:dropped'

local registry = {}
vAvA.registry = registry

---@class vAvA.RegistryEntry
---@field owner string
---@field data any

---@class vAvA.Registry
---@field owner string
---@field name string
---@field schema table
---@field validator? function
---@field maxEntries? integer
---@field entries table<string, vAvA.RegistryEntry>
---@field size integer

---@type table<string, vAvA.Registry>
local definitions = {}

---@class vAvA.RegistryOptions
---@field schema vAvA.SchemaDefinition                        schéma de chaque entrée
---@field validator? fun(key: string, data: any): boolean, string?  doit renvoyer true pour accepter
---@field maxEntries? integer

--- Définit un registre. Le nom doit être préfixé par "<owner>:".
---@param owner string
---@param name string
---@param options vAvA.RegistryOptions
---@return boolean ok
---@return string|nil err
function registry.define(owner, name, options)
    if not str.isIdentifier(name) or not str.hasPrefix(name, owner .. ':') then
        return false, format("nom de registre invalide '%s' (attendu : '%s:<nom>')", tostring(name), owner)
    end
    if definitions[name] then
        return false, format("registre '%s' déjà défini", name)
    end
    if type(options) ~= 'table' then
        return false, 'options requises : { schema = { ... } }'
    end
    local compiled, err = schema.compile(options.schema)
    if not compiled then return false, err end
    if options.validator ~= nil and not schema.isCallable(options.validator) then
        return false, 'validator non appelable'
    end
    if options.maxEntries ~= nil and (mathType(options.maxEntries) ~= 'integer' or options.maxEntries < 1) then
        return false, 'maxEntries doit être un entier positif'
    end
    definitions[name] = {
        owner = owner, name = name, schema = compiled, validator = options.validator,
        maxEntries = options.maxEntries, entries = {}, size = 0,
    }
    return true
end

--- Ajoute une entrée validée. Une clé déjà prise est refusée (retirer puis ajouter pour remplacer).
---@param owner string
---@param name string
---@param key string
---@param data any
---@return boolean ok
---@return string|nil err
function registry.add(owner, name, key, data)
    local def = definitions[name]
    if not def then return false, format("registre '%s' inexistant", tostring(name)) end
    if not str.isIdentifier(key) then return false, format("clé invalide '%s'", tostring(key)) end
    local existing = def.entries[key]
    if existing then
        return false, format("clé '%s' déjà enregistrée dans '%s' par '%s'", key, name, existing.owner)
    end
    if def.maxEntries and def.size >= def.maxEntries then
        return false, format("registre '%s' plein (%d entrées)", name, def.maxEntries)
    end

    local valid, err = schema.validate(def.schema, data)
    if not valid then return false, format("entrée '%s' invalide : %s", key, err) end

    if def.validator then
        local called, accepted, reason = xpcall(def.validator, traceback, key, data)
        if not called then
            -- fail-closed : un validateur en erreur refuse l'entrée
            log.error("validateur du registre '%s' (ressource %s) en erreur sur '%s' : %s", name, def.owner, key, tostring(accepted))
            return false, 'validator_error'
        end
        if accepted ~= true then
            return false, type(reason) == 'string' and reason or 'refusée par le validateur'
        end
        -- le validateur a pu céder la main : l'état doit être revérifié
        if definitions[name] ~= def or def.entries[key] then
            return false, 'registre modifié pendant la validation'
        end
    end

    def.entries[key] = { owner = owner, data = data }
    def.size = def.size + 1
    hooks.runAfter(HOOK_ADDED, { registry = name, key = key, owner = owner })
    return true
end

--- Retire une entrée. Autorisé à l'auteur de l'entrée et au propriétaire du registre.
---@param owner string
---@param name string
---@param key string
---@return boolean ok
---@return string|nil err
function registry.remove(owner, name, key)
    local def = definitions[name]
    if not def then return false, format("registre '%s' inexistant", tostring(name)) end
    local entry = def.entries[key]
    if not entry then return false, format("clé '%s' absente de '%s'", tostring(key), name) end
    if entry.owner ~= owner and def.owner ~= owner then
        return false, "seuls l'auteur de l'entrée et le propriétaire du registre peuvent la retirer"
    end
    def.entries[key] = nil
    def.size = def.size - 1
    hooks.runAfter(HOOK_REMOVED, { registry = name, key = key, owner = entry.owner, reason = 'removed' })
    return true
end

--- Donnée d'une entrée, ou nil. Lecture en mémoire, sans accès base.
--- Une autre ressource en reçoit une copie (sérialisation entre ressources).
---@param name string
---@param key string
---@return any|nil data
function registry.get(name, key)
    local def = definitions[name]
    if not def then return nil end
    local entry = def.entries[key]
    return entry and entry.data
end

---@param name string
---@param key string
---@return boolean
function registry.has(name, key)
    local def = definitions[name]
    return def ~= nil and def.entries[key] ~= nil
end

---@param name string
---@return boolean
function registry.exists(name)
    return definitions[name] ~= nil
end

--- Toutes les entrées d'un registre (clé → donnée). Construit une nouvelle table à chaque appel :
--- à appeler une fois puis à tenir à jour via les hooks core:registry:*.
---@param name string
---@return table<string, any>|nil
function registry.all(name)
    local def = definitions[name]
    if not def then return nil end
    local result = {}
    for key, entry in pairs(def.entries) do
        result[key] = entry.data
    end
    return result
end

--- Retire les registres définis par un propriétaire et les entrées qu'il a ajoutées ailleurs.
--- Les hooks sont déclenchés après les retraits : un handler qui modifie un registre ne perturbe aucun parcours.
---@param owner string
function registry.purgeOwner(owner)
    local dropped, removed = {}, {}

    for name, def in pairs(definitions) do
        if def.owner == owner then
            definitions[name] = nil
            local foreign = 0
            for _, entry in pairs(def.entries) do
                if entry.owner ~= owner then foreign = foreign + 1 end
            end
            if foreign > 0 then
                log.warn("registre '%s' supprimé avec son propriétaire '%s' : %d entrée(s) d'autres modules perdue(s)", name, owner, foreign)
            end
            dropped[#dropped + 1] = name
        end
    end

    for name, def in pairs(definitions) do
        for key, entry in pairs(def.entries) do
            if entry.owner == owner then
                def.entries[key] = nil
                def.size = def.size - 1
                removed[#removed + 1] = { registry = name, key = key, owner = owner, reason = 'owner_stopped' }
            end
        end
    end

    for i = 1, #dropped do
        hooks.runAfter(HOOK_DROPPED, { registry = dropped[i], owner = owner })
    end
    for i = 1, #removed do
        hooks.runAfter(HOOK_REMOVED, removed[i])
    end
end
