--[[
    vava_world/server/population.lua
    Rôle : population de la carte, décidée par le serveur (OneSync) : coupée dans chaque instance préparée, sans aucun
           travail chez les joueurs. Au démarrage, ce que le jeu avait déjà créé (passants, véhicules garés ou en
           circulation) est retiré ; les joueurs, leurs véhicules occupés et les entités des scripts restent.
    Dépendances : shared/constants.lua, config_client.lua, config.lua, server/core.lua
]]

local ipairs = ipairs
local SetRoutingBucketPopulationEnabled, GetAllPeds, GetAllVehicles = SetRoutingBucketPopulationEnabled, GetAllPeds, GetAllVehicles
local DoesEntityExist, DeleteEntity, IsPedAPlayer, GetEntityPopulationType, GetPedInVehicleSeat =
    DoesEntityExist, DeleteEntity, IsPedAPlayer, GetEntityPopulationType, GetPedInVehicleSeat

local cfg = VavaWorld.config.population
local AMBIENT = VavaWorld.AMBIENT_TYPES
local DRIVER_SEAT = -1

local population = {}
VavaWorld.population = population

--- Règle la population d'une instance selon la configuration.
---@param bucket integer
function population.prepare(bucket)
    SetRoutingBucketPopulationEnabled(bucket, cfg.enabled)
end

---@param entity integer
---@return boolean
local function isAmbient(entity)
    return DoesEntityExist(entity) and AMBIENT[GetEntityPopulationType(entity)] == true
end

--- Retire la population déjà créée par le jeu. Renvoie le nombre de PNJ et de véhicules retirés.
---@return integer peds
---@return integer vehicles
function population.cleanup()
    local peds, vehicles = 0, 0
    for _, vehicle in ipairs(GetAllVehicles()) do
        local driver = GetPedInVehicleSeat(vehicle, DRIVER_SEAT)
        if isAmbient(vehicle) and not (driver ~= 0 and IsPedAPlayer(driver)) then
            DeleteEntity(vehicle)
            vehicles = vehicles + 1
        end
    end
    for _, ped in ipairs(GetAllPeds()) do
        if not IsPedAPlayer(ped) and isAmbient(ped) then
            DeleteEntity(ped)
            peds = peds + 1
        end
    end
    return peds, vehicles
end

--- Prépare les instances de la configuration, puis nettoie. Appelé pendant le setup du module.
function population.start()
    for _, bucket in ipairs(cfg.buckets) do population.prepare(bucket) end
    if cfg.enabled or not cfg.cleanupOnStart then return end
    local peds, vehicles = population.cleanup()
    if peds + vehicles > 0 then VavaWorld.log.info('population retirée : %d PNJ, %d véhicule(s)', peds, vehicles) end
end
