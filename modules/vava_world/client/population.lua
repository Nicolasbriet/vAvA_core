--[[
    vava_world/client/population.lua
    Rôle : filet de sécurité chez chaque joueur, en plus de la décision du serveur : budgets de population à zéro,
           pas de véhicules garés, bateaux, trains, camions-poubelles ni policiers ; services d'intervention coupés,
           pas d'avis de recherche (les sons : client/audio.lua). Réglages persistants : posés une fois (et à chaque
           apparition), jamais à chaque image.
    Dépendances : shared/constants.lua, config.lua
]]

local PlayerId = PlayerId
local SetPedPopulationBudget, SetVehiclePopulationBudget, SetNumberOfParkedVehicles =
    SetPedPopulationBudget, SetVehiclePopulationBudget, SetNumberOfParkedVehicles
local SetAllLowPriorityVehicleGeneratorsActive, SetGarbageTrucks, SetRandomBoats, SetRandomTrains =
    SetAllLowPriorityVehicleGeneratorsActive, SetGarbageTrucks, SetRandomBoats, SetRandomTrains
local SetCreateRandomCops, SetCreateRandomCopsNotOnScenarios, SetCreateRandomCopsOnScenarios =
    SetCreateRandomCops, SetCreateRandomCopsNotOnScenarios, SetCreateRandomCopsOnScenarios
local EnableDispatchService, SetDispatchCopsForPlayer, SetMaxWantedLevel, SetPlayerWantedLevel, SetPlayerWantedLevelNow =
    EnableDispatchService, SetDispatchCopsForPlayer, SetMaxWantedLevel, SetPlayerWantedLevel, SetPlayerWantedLevelNow

local cfg = VavaWorld.config
local DISPATCH = VavaWorld.DISPATCH_SERVICES
local EMPTY_BUDGET = 0

local population = {}
VavaWorld.population = population

--- Applique les réglages du monde chez ce joueur.
function population.apply()
    if not cfg.population.enabled then
        SetPedPopulationBudget(EMPTY_BUDGET)
        SetVehiclePopulationBudget(EMPTY_BUDGET)
        SetNumberOfParkedVehicles(EMPTY_BUDGET)
        SetAllLowPriorityVehicleGeneratorsActive(false)
        SetGarbageTrucks(false)
        SetRandomBoats(false)
        SetRandomTrains(false)
        SetCreateRandomCops(false)
        SetCreateRandomCopsNotOnScenarios(false)
        SetCreateRandomCopsOnScenarios(false)
    end
    local player = PlayerId()
    for service = 1, DISPATCH do EnableDispatchService(service, false) end
    SetDispatchCopsForPlayer(player, false)
    SetMaxWantedLevel(cfg.client.wantedLevel)
    SetPlayerWantedLevel(player, cfg.client.wantedLevel, false)
    SetPlayerWantedLevelNow(player, false)
end
