--[[
    vava_world/server/main.lua
    Rôle : déclaration du module auprès du core : population des instances réglée et carte nettoyée au démarrage.
    Dépendances : tous les fichiers server/ du module
]]

local tostring = tostring

local core = VavaWorld.core
if not core then return end

local population = VavaWorld.population
local cfg = VavaWorld.config

local function setup()
    population.start()
    VavaWorld.ready = true
    return true
end

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(VavaWorld.resource, 'version', 0),
    coreVersion = cfg.coreVersion,
    setup = setup,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end
