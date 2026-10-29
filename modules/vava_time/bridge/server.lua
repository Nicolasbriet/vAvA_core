--[[
    vava_time/bridge/server.lua
    Rôle : SEUL point de contact, côté serveur, entre le temps du royaume et les autres modules : droits et journal du
           Conseil (vava_admin), outil « Ciel et heure » ajouté au Registre (et rajouté s'il redémarre), base de
           données. Chaque appel à une autre ressource est isolé : un module absent ou en erreur ne retire que la
           fonction concernée (sans vava_admin, personne n'a de droit et la console garde le journal).
    Dépendances : shared/constants.lua, config.lua, server/core.lua
]]

local pairs, pcall, tostring, tonumber = pairs, pcall, tostring, tonumber
local tointeger = math.tointeger
local pack, unpack, concat, sort = table.pack, table.unpack, table.concat, table.sort
local GetResourceState = GetResourceState

local core = VavaTime.core
if not core then return end

local cfg = VavaTime.config
local ADMIN = VavaTime.ADMIN

local Bridge = {}
VavaTime.bridge = Bridge

local function invoke(resource, fn, ...)
    local target = exports[resource]
    return target[fn](target, ...)
end

--- Export d'une autre ressource, isolé. Renvoie `called` (appel réussi) puis ses valeurs.
---@return boolean called
local function call(resource, fn, ...)
    if GetResourceState(resource) ~= 'started' then return false end
    local results = pack(pcall(invoke, resource, fn, ...))
    if not results[1] then
        VavaTime.log.warn('%s.%s en erreur : %s', resource, fn, tostring(results[2]))
        return false
    end
    return true, unpack(results, 2, results.n)
end

-- Conseil ---------------------------------------------------------------------------------------------------------

--- Droit du Conseil (vava_admin) : sans lui, personne n'a de droit.
---@param source integer
---@param permission string
---@return boolean
function Bridge.IsAllowed(source, permission)
    local called, allowed = call(ADMIN.RESOURCE, 'can', source, permission)
    return called and allowed == true
end

--- Détails du journal en une ligne de console (clés triées).
---@param details table
---@return string
local function flatten(details)
    local parts = {}
    for key, value in pairs(details) do parts[#parts + 1] = key .. '=' .. tostring(value) end
    sort(parts)
    return concat(parts, ', ')
end

--- Inscrit une action du Conseil au journal du Registre ; sans lui, la console du serveur la garde.
---@param source integer
---@param label string   32 octets au plus
---@param details table  { clé = texte ou nombre }, 8 au plus
function Bridge.AdminLog(source, label, details)
    local called, ok, err = call(ADMIN.RESOURCE, 'log', source, label, details)
    if not called or ok ~= true then
        VavaTime.log.info('%s (joueur %d) : %s%s', label, source, flatten(details), called and (' — journal refusé : ' .. tostring(err)) or '')
    end
end

--- Ajoute l'outil « Ciel et heure » à la page Outils du Registre, s'il est là.
local function addTool()
    local registry = core.registry
    if not registry.exists(ADMIN.REGISTRY) or registry.has(ADMIN.REGISTRY, ADMIN.TOOL) then return end
    local ok, err = registry.add(ADMIN.REGISTRY, ADMIN.TOOL, {
        label = cfg.tool.label, hint = cfg.tool.hint, permission = cfg.council.permission,
    })
    if not ok then VavaTime.log.warn('outil du Registre non ajouté : %s', tostring(err)) end
end

--- Branche l'outil du Registre (au démarrage, et à chaque redémarrage du Registre). Appelé pendant le setup.
---@return boolean ok
---@return string|nil err
function Bridge.StartAdmin()
    local id, err = core.hooks.after(ADMIN.READY, addTool)
    if not id then return false, err end
    addTool()
    return true
end

-- Base de données (table du module, sql/) -------------------------------------------------------------------------

Bridge.db = {
    single = function(sql, params) return core.db.single(sql, params) end,
    update = function(sql, params) return core.db.update(sql, params) end,
}

--- Entier lu en base (INT arrive en nombre, BIGINT et DECIMAL en texte depuis oxmysql), ou `default`.
---@param value any
---@param default integer|nil
---@return integer|nil
function Bridge.Integer(value, default)
    local number = tonumber(value)
    if number == nil then return default end
    local integer = tointeger(number)
    if integer == nil then return default end
    return integer
end
