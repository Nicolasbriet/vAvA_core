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
    -- T-132 : un config.lua d'avant 1.2.0 (gardé par une mise à jour) remplace la table de config_client.lua ; il
    -- contient tout ce que lit le serveur, le module démarre, mais un réglage client qu'on y change reste sans effet
    if cfg.clientFile ~= true then
        core.log.warn('config.lua garde la forme d\'avant 1.2.0 (il remplace la table de config_client.lua) : les '
            .. 'réglages lus par les joueurs sont dans config_client.lua ; reportez vos changements d\'après '
            .. 'config.lua.nouveau')
    end
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
