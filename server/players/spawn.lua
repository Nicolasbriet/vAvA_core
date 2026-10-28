--[[
    server/players/spawn.lua
    Rôle : ordres d'apparition. Le serveur décide de la position et du modèle ; l'ordre est envoyé au seul
           joueur concerné, qui l'exécute puis confirme (core:characters:spawned).
    Dépendances : shared/init.lua, config/server.lua, server/players/playtime.lua
]]

local type = type
local HUGE = math.huge
local TriggerClientEvent = TriggerClientEvent

local EVENTS = vAvA.EVENTS
local playtime = vAvA.playtime
local cfg = vAvA.config.server.spawn

local spawn = {}
vAvA.spawn = spawn

---@param value any
---@return boolean
local function isFinite(value)
    return type(value) == 'number' and value == value and value ~= HUGE and value ~= -HUGE
end

---@class vAvA.SpawnPoint
---@field x number
---@field y number
---@field z number
---@field heading number

---@param coords any
---@return vAvA.SpawnPoint|nil
local function normalize(coords)
    if type(coords) ~= 'table' then return nil end
    local heading = coords.heading or 0.0
    if not (isFinite(coords.x) and isFinite(coords.y) and isFinite(coords.z) and isFinite(heading)) then return nil end
    return { x = coords.x, y = coords.y, z = coords.z, heading = heading }
end

---@param character vAvA.Character
---@param point vAvA.SpawnPoint
---@param withModel boolean
local function send(character, point, withModel)
    -- position non échantillonnée et temps de jeu suspendu tant que le client n'a pas confirmé
    playtime.pause(character)
    character.spawned = false
    TriggerClientEvent(EVENTS.SPAWN, character.source, {
        model = withModel and cfg.models[character.sex] or nil,
        x = point.x, y = point.y, z = point.z, heading = point.heading,
    })
end

--- Première apparition après sélection : dernière position connue, sinon point par défaut.
---@param character vAvA.Character
function spawn.forCharacter(character)
    send(character, character.position or cfg.defaultPoint, true)
end

--- Réapparition ou téléportation décidée par le serveur (soins, propriétés…). Sans coordonnées : dernière
--- position connue.
---@param character vAvA.Character
---@param coords? vAvA.SpawnPoint
---@return boolean ok
---@return string|nil err
function spawn.at(character, coords)
    local point
    if coords == nil then
        point = character.position or cfg.defaultPoint
    else
        point = normalize(coords)
        if not point then return false, 'invalid_coords' end
    end
    send(character, point, false)
    return true
end
