--[[
    server/players/positions.lua
    Rôle : position des personnages lue CÔTÉ SERVEUR (OneSync obligatoire) : le client n'envoie jamais la sienne.
    Un personnage n'est échantillonné qu'après avoir confirmé son apparition : avant, son ped peut encore être
    à l'ancien emplacement (changement de personnage) et cette position serait sauvegardée à tort.
    Dépendances : config/server.lua
]]

local CreateThread, Wait = CreateThread, Wait
local GetPlayerPed, DoesEntityExist, GetEntityCoords, GetEntityHeading = GetPlayerPed, DoesEntityExist, GetEntityCoords, GetEntityHeading

local cfg = vAvA.config.server.persistence
local EPSILON_SQUARED = cfg.positionEpsilon * cfg.positionEpsilon

local positions = {}
vAvA.positions = positions

--- Relève la position du ped. Ne marque le personnage à sauvegarder que s'il a réellement bougé.
---@param character vAvA.Character
---@return boolean moved
function positions.sample(character)
    if not character.spawned then return false end
    local ped = GetPlayerPed(character.source)
    if ped == 0 or not DoesEntityExist(ped) then return false end
    local coords = GetEntityCoords(ped)
    local current = character.position
    if current then
        local dx, dy, dz = coords.x - current.x, coords.y - current.y, coords.z - current.z
        if dx * dx + dy * dy + dz * dz < EPSILON_SQUARED then return false end
    end
    character.position = { x = coords.x, y = coords.y, z = coords.z, heading = GetEntityHeading(ped) }
    character.revision = character.revision + 1
    return true
end

--- Lance l'échantillonnage périodique. Appelé par init.lua.
---@param iterate fun(fn: fun(character: vAvA.Character))  parcours des personnages actifs
function positions.start(iterate)
    CreateThread(function()
        -- boucle lente justifiée : quelques natives par joueur actif toutes les positionSampleMs
        while true do
            Wait(cfg.positionSampleMs)
            iterate(positions.sample)
        end
    end)
end
