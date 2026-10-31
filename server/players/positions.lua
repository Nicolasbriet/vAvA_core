--[[
    server/players/positions.lua
    Rôle : position des personnages lue CÔTÉ SERVEUR (OneSync obligatoire) : le client n'envoie jamais la sienne.
    Un personnage n'est échantillonné qu'après la confirmation de son apparition par le serveur (0.14.0 : ped vu au
    point ordonné, server/players/spawn.lua ; la seule déclaration du client ne suffit plus) : avant, son ped peut
    encore être à l'ancien emplacement (changement de personnage) et cette position serait sauvegardée à tort.
    La même boucle relève le temps de jeu (server/players/playtime.lua) : un seul parcours des personnages actifs.
    Dépendances : config/server.lua, server/players/playtime.lua
]]

local CreateThread, Wait = CreateThread, Wait
local GetPlayerPed, DoesEntityExist, GetEntityCoords, GetEntityHeading = GetPlayerPed, DoesEntityExist, GetEntityCoords, GetEntityHeading

local playtime = vAvA.playtime
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

--- Relevé périodique d'un personnage actif : position, puis temps de jeu.
---@param character vAvA.Character
local function survey(character)
    positions.sample(character)
    playtime.settle(character)
end

--- Lance les relevés périodiques (position et temps de jeu). Appelé par init.lua.
---@param iterate fun(fn: fun(character: vAvA.Character))  parcours des personnages actifs
function positions.start(iterate)
    CreateThread(function()
        -- boucle lente justifiée : quelques natives par joueur actif toutes les positionSampleMs
        while true do
            Wait(cfg.positionSampleMs)
            iterate(survey)
        end
    end)
end
