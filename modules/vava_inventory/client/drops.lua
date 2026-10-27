--[[
    vava_inventory/client/drops.lua
    Rôle : sacs au sol connus du client. Le jeu ne transmet au client que les entités proches de lui ; leur statebag
           donne l'id du conteneur. Aucune boucle de proximité : le plus proche n'est cherché qu'à l'ouverture de
           l'inventaire (le serveur revérifie la distance).
    Dépendances : shared/constants.lua, config.lua
]]

local pairs = pairs
local CreateThread, Wait, GetGameTimer = CreateThread, Wait, GetGameTimer
local AddStateBagChangeHandler, GetEntityFromStateBagName = AddStateBagChangeHandler, GetEntityFromStateBagName
local DoesEntityExist, GetEntityCoords, PlayerPedId = DoesEntityExist, GetEntityCoords, PlayerPedId

local cfg = VavaInventory.config.drop
local DROP_STATE = VavaInventory.DROP_STATE

local drops = {}
VavaInventory.drops = drops

-- entité locale → id de conteneur
local known = {}

--- Id du conteneur du sac le plus proche dans un rayon, ou 0.
---@param radius number
---@return integer
function drops.nearest(radius)
    local position = GetEntityCoords(PlayerPedId())
    local bestId, bestDistance = 0, radius
    for entity, id in pairs(known) do
        if DoesEntityExist(entity) then
            local distance = #(GetEntityCoords(entity) - position)
            if distance <= bestDistance then bestId, bestDistance = id, distance end
        else
            known[entity] = nil
        end
    end
    return bestId
end

--- Suit les statebags des sacs. Appelé par client/main.lua.
function drops.start()
    AddStateBagChangeHandler(DROP_STATE, nil, function(bagName, _, value)
        CreateThread(function()
            -- le statebag peut précéder la création locale de l'entité : attente bornée
            local entity = GetEntityFromStateBagName(bagName)
            local deadline = GetGameTimer() + cfg.stateWaitMs
            while entity == 0 and GetGameTimer() < deadline do
                Wait(cfg.statePollMs)
                entity = GetEntityFromStateBagName(bagName)
            end
            if entity ~= 0 then known[entity] = value or nil end
        end)
    end)
end
