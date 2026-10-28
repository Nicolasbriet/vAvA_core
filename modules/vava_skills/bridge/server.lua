--[[
    vava_skills/bridge/server.lua
    Rôle : SEUL point de contact, côté serveur, entre les compétences et le core / les autres modules : personnage,
           compte, temps de jeu, positions (lues côté serveur), noms de personnages hors ligne, droits et journal du
           Conseil, notifications, chat, base de données. Chaque appel à une autre ressource est isolé : un module
           absent ou en erreur ne retire que la fonction concernée.
    Dépendances : shared/constants.lua, config.lua, server/core.lua
]]

local type, pairs, ipairs, pcall, tostring, tonumber = type, pairs, ipairs, pcall, tostring, tonumber
local mathType = math.type
local pack, unpack, concat = table.pack, table.unpack, table.concat
local rep = string.rep
local GetResourceState, TriggerClientEvent, IsPlayerAceAllowed, GetPlayers = GetResourceState, TriggerClientEvent, IsPlayerAceAllowed, GetPlayers
local GetPlayerPed, DoesEntityExist, GetEntityCoords = GetPlayerPed, DoesEntityExist, GetEntityCoords

local core = VavaSkills.core
if not core then return end

local cfg = VavaSkills.config
local EVENTS = VavaSkills.EVENTS
local CONSOLE = 0
local ADMIN, CHAT = 'vava_admin', 'vava_chat'

local SELECT_NAMES_SQL = 'SELECT `id`, `first_name`, `last_name` FROM `vava_characters` WHERE `id` IN (%s)'
local SELECT_NAME_SQL = 'SELECT `id`, `first_name`, `last_name` FROM `vava_characters` WHERE `id` = ?'

local Bridge = {}
VavaSkills.bridge = Bridge

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
        VavaSkills.log.warn('%s.%s en erreur : %s', resource, fn, tostring(results[2]))
        return false
    end
    return true, unpack(results, 2, results.n)
end

-- Personnage ----------------------------------------------------------------------------------------------------

--- Personnage actif d'un joueur : { id, accountId, firstName, lastName, playSeconds }, ou nil (en sélection).
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

---@param source integer
---@return integer|nil
function Bridge.GetAccountId(source)
    local session = core.players.get(source)
    return session and session.accountId or nil
end

--- Nom complet d'un personnage actif.
---@param source integer
---@return string|nil
function Bridge.GetCharacterName(source)
    local character = Bridge.GetCharacter(source)
    return character and (character.firstName .. ' ' .. character.lastName) or nil
end

--- Temps de jeu du personnage actif (secondes), 0 si inconnu.
---@param source integer
---@return integer
function Bridge.GetPlaySeconds(source)
    local character = Bridge.GetCharacter(source)
    local seconds = character and character.playSeconds
    return mathType(seconds) == 'integer' and seconds or 0
end

--- Joueurs dont le personnage est en jeu (sources).
---@return integer[]
function Bridge.ActivePlayers()
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src and Bridge.GetCharacterId(src) then list[#list + 1] = src end
    end
    return list
end

--- Noms de personnages par identifiant (hors ligne compris) : { [id] = 'Prénom Nom' }. Bloque le thread courant.
---@param ids integer[]
---@return table<integer, string>
function Bridge.NamesOf(ids)
    local names = {}
    if #ids == 0 then return names end
    local rows
    if #ids == 1 then
        local row = core.db.single(SELECT_NAME_SQL, { ids[1] })
        rows = row and { row } or {}
    else
        -- autant de « ? » que d'identifiants : aucune valeur n'entre dans le SQL
        rows = core.db.query(SELECT_NAMES_SQL:format(rep('?, ', #ids - 1) .. '?'), ids) or {}
    end
    for _, row in ipairs(rows) do
        local id = tonumber(row.id)
        if id then names[id] = row.first_name .. ' ' .. row.last_name end
    end
    return names
end

-- Positions (lues côté serveur, OneSync) --------------------------------------------------------------------------

---@param source integer
---@return number|nil x, number|nil y, number|nil z
function Bridge.Position(source)
    local ped = GetPlayerPed(source)
    if ped == 0 or not DoesEntityExist(ped) then return nil end
    local coords = GetEntityCoords(ped)
    return coords.x, coords.y, coords.z
end

--- Distance (m) entre deux joueurs, ou nil si l'un n'a pas de ped.
---@param a integer
---@param b integer
---@return number|nil
function Bridge.Distance(a, b)
    local ax, ay, az = Bridge.Position(a)
    local bx, by, bz = Bridge.Position(b)
    if not ax or not bx then return nil end
    local dx, dy, dz = ax - bx, ay - by, az - bz
    return (dx * dx + dy * dy + dz * dz) ^ 0.5
end

--- Vrai si les deux joueurs sont à moins de `radius` mètres l'un de l'autre.
---@param a integer
---@param b integer
---@param radius number
---@return boolean
function Bridge.Within(a, b, radius)
    local distance = Bridge.Distance(a, b)
    return distance ~= nil and distance <= radius
end

-- Conseil ---------------------------------------------------------------------------------------------------------

--- Droit du Conseil : la console l'a toujours ; sinon le droit vava_admin, ou la permission ACE sans vava_admin.
---@param source integer
---@param permission string
---@return boolean
function Bridge.IsAllowed(source, permission)
    if source == CONSOLE then return true end
    if GetResourceState(ADMIN) == 'started' then
        local called, allowed = call(ADMIN, 'can', source, permission)
        return called and allowed == true
    end
    return IsPlayerAceAllowed(source, cfg.admin.ace) == true
end

--- Inscrit une action du Conseil au journal du Registre (sans lui : la console du serveur la garde).
---@param source integer
---@param label string   32 signes au plus
---@param details table  { clé = texte ou nombre }, 8 au plus
function Bridge.AdminLog(source, label, details)
    local called, ok, err = false, nil, nil
    if source ~= CONSOLE then called, ok, err = call(ADMIN, 'log', source, label, details) end
    if not called or ok ~= true then
        local parts = {}
        for key, value in pairs(details) do parts[#parts + 1] = key .. '=' .. tostring(value) end
        VavaSkills.log.info('%s (par %d) : %s%s', label, source, concat(parts, ', '), called and (' — journal refusé : ' .. tostring(err)) or '')
    end
end

-- Messages --------------------------------------------------------------------------------------------------------

--- Notification à un joueur (vava_hud s'il est là, sinon celle du jeu) ; nature : info, warning, danger.
---@param source integer
---@param message string
---@param kind? string
function Bridge.Notify(source, message, kind)
    if source == CONSOLE then
        print(('[%s] %s'):format(VavaSkills.resource, message))
        return
    end
    TriggerClientEvent(EVENTS.NOTIFY, source, message, kind or 'info')
end

--- Ligne de texte dans le chat du joueur (réponse d'une commande) ; console : impression.
---@param source integer
---@param text string
function Bridge.Chat(source, text)
    if source == CONSOLE then
        print(('[%s] %s'):format(VavaSkills.resource, text))
        return
    end
    local called = call(CHAT, 'addMessage', source, { text = text })
    if not called then Bridge.Notify(source, text) end
end

-- Base de données (tables du module, sql/) -------------------------------------------------------------------------

Bridge.db = {
    query = function(sql, params) return core.db.query(sql, params) end,
    single = function(sql, params) return core.db.single(sql, params) end,
    scalar = function(sql, params) return core.db.scalar(sql, params) end,
    insert = function(sql, params) return core.db.insert(sql, params) end,
    update = function(sql, params) return core.db.update(sql, params) end,
    transaction = function(queries) return core.db.transaction(queries) end,
}

--- Entier lu en base (BIGINT et DECIMAL arrivent en texte depuis oxmysql), ou `default`.
---@param value any
---@param default integer
---@return integer
function Bridge.Integer(value, default)
    local number = tonumber(value)
    if number == nil then return default end
    local integer = math.tointeger(number)
    return integer or default
end

Bridge.CONSOLE = CONSOLE
