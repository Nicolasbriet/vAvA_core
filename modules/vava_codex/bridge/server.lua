--[[
    vava_codex/bridge/server.lua
    Rôle : SEUL point de contact, côté serveur, entre le Codex et le core / les autres modules : personnage et
           joueurs en jeu (tous, ou les seuls proches d'un joueur, positions lues par le serveur), rangs et droits du
           Conseil (vava_admin, sinon ACE), listes de valeurs des modules
           (export codexList), commandes enregistrées auprès du jeu, notifications. Chaque appel à une autre
           ressource est isolé : un module absent ou en erreur ne retire que la fonction concernée.
    Dépendances : shared/constants.lua, config.lua, server/core.lua
]]

local type, ipairs, pcall, tostring = type, ipairs, pcall, tostring
local mathType = math.type
local pack, unpack = table.pack, table.unpack
local GetResourceState, TriggerClientEvent, IsPlayerAceAllowed = GetResourceState, TriggerClientEvent, IsPlayerAceAllowed
local GetPlayers, GetRegisteredCommands = GetPlayers, GetRegisteredCommands
local GetPlayerPed, GetEntityCoords, GetPlayerRoutingBucket = GetPlayerPed, GetEntityCoords, GetPlayerRoutingBucket

local core = VavaCodex.core
if not core then return end

local cfg = VavaCodex.config
local EVENTS = VavaCodex.EVENTS
local MAX_OPTIONS = VavaCodex.MAX_OPTIONS
local CONSOLE = 0
local ADMIN = 'vava_admin'

local Bridge = {}
VavaCodex.bridge = Bridge

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
        VavaCodex.log.warn('%s.%s en erreur : %s', resource, fn, tostring(results[2]))
        return false
    end
    return true, unpack(results, 2, results.n)
end

-- Personnage et joueurs ---------------------------------------------------------------------------------------------

--- Personnage actif d'un joueur ({ id, accountId, firstName, lastName, … }) ou nil.
---@param source integer
---@return table|nil
function Bridge.GetCharacter(source)
    local session = core.players.get(source)
    if not session or session.state ~= 'active' then return nil end
    return core.characters.getActive(source)
end

---@param source integer
---@return integer|nil
function Bridge.GetCharacterId(source)
    local character = Bridge.GetCharacter(source)
    return character and character.id or nil
end

--- Joueurs en jeu avec un personnage, retenus par `keep(src)` s'il est donné : { { source, name } }, triés par nom.
---@param keep? fun(src: integer): boolean
---@return { source: integer, name: string }[]
local function activePlayers(keep)
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local character = src and (not keep or keep(src)) and Bridge.GetCharacter(src)
        if character then list[#list + 1] = { source = src, name = (character.firstName .. ' ' .. (character.lastName or '')):gsub('%s+$', '') } end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

--- Joueurs en jeu avec un personnage : { { source, name } }, triés par nom.
---@return { source: integer, name: string }[]
function Bridge.ActivePlayers()
    return activePlayers(nil)
end

--- Joueurs en jeu à moins de `radius` mètres de `source`, dans la même instance (positions lues par le serveur ; lui
--- compris) : même forme que ActivePlayers. La distance est vue d'abord : aucun personnage lu pour un joueur loin.
--- Sans position de `source` (chargement) : aucun.
---@param source integer
---@param radius number
---@return { source: integer, name: string }[]
function Bridge.NearbyPlayers(source, radius)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return {} end
    local origin = GetEntityCoords(ped)
    local bucket = GetPlayerRoutingBucket(source)
    local limit = radius * radius
    return activePlayers(function(src)
        local other = GetPlayerPed(src)
        if not other or other == 0 or GetPlayerRoutingBucket(src) ~= bucket then return false end
        local coords = GetEntityCoords(other)
        local dx, dy, dz = coords.x - origin.x, coords.y - origin.y, coords.z - origin.z
        return dx * dx + dy * dy + dz * dz <= limit
    end)
end

-- Conseil ---------------------------------------------------------------------------------------------------------

--- Membre du Conseil ? Avec vava_admin : tout rang ; sans lui : permission ACE de la config.
---@param source integer
---@return boolean
function Bridge.IsStaff(source)
    if source == CONSOLE then return true end
    if GetResourceState(ADMIN) == 'started' then
        local called, staff = call(ADMIN, 'isStaff', source)
        return called and staff == true
    end
    return IsPlayerAceAllowed(source, cfg.staff.ace) == true
end

--- Droit du Conseil ; sans vava_admin, la permission ACE de repli déclarée avec la commande, sinon le Conseil ACE.
---@param source integer
---@param permission string|nil
---@param ace string|nil
---@return boolean
function Bridge.Can(source, permission, ace)
    if source == CONSOLE then return true end
    if not permission then return Bridge.IsStaff(source) end
    if GetResourceState(ADMIN) == 'started' then
        local called, allowed = call(ADMIN, 'can', source, permission)
        return called and allowed == true
    end
    return IsPlayerAceAllowed(source, ace or cfg.staff.ace) == true
end

-- Modules ---------------------------------------------------------------------------------------------------------

--- Valeurs proposées par un module pour un argument de type `list` : son export `codexList(name)`, nettoyé.
---@param module string
---@param name string
---@return { value: string, label: string }[]
function Bridge.ListFrom(module, name)
    local called, raw = call(module, 'codexList', name)
    local out = {}
    if not called or type(raw) ~= 'table' then return out end
    for _, entry in ipairs(raw) do
        if type(entry) == 'table' and (type(entry.value) == 'string' or mathType(entry.value) == 'integer') then
            out[#out + 1] = { value = tostring(entry.value), label = type(entry.label) == 'string' and entry.label or tostring(entry.value) }
            if #out >= MAX_OPTIONS then break end
        end
    end
    return out
end

--- Commandes enregistrées auprès du jeu côté serveur : { { name, resource } }.
---@return { name: string, resource: string }[]
function Bridge.RegisteredCommands()
    local out = {}
    for _, entry in ipairs(GetRegisteredCommands() or {}) do
        if type(entry) == 'table' and type(entry.name) == 'string' then
            out[#out + 1] = { name = entry.name, resource = type(entry.resource) == 'string' and entry.resource or '' }
        end
    end
    return out
end

-- Joueur ----------------------------------------------------------------------------------------------------------

---@param source integer
---@param message string
---@param kind? string  info | warning | danger
function Bridge.Notify(source, message, kind)
    if source == CONSOLE then
        print(('[%s] %s'):format(VavaCodex.resource, message))
        return
    end
    TriggerClientEvent(EVENTS.NOTIFY, source, message, kind or 'info')
end
