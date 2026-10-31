--[[
    vava_needs/server/main.lua
    Rôle : déclaration du module auprès du core : champ de personnage, abonnement à l'inventaire, boucle de baisse.
           Aucun RPC : le joueur n'exprime rien de plus que l'utilisation d'un objet, déjà validée par l'inventaire.
    Dépendances : tous les fichiers server/ du module
]]

local tostring = tostring
local AddEventHandler = AddEventHandler

local core = VavaNeeds.core
if not core then return end

local state = VavaNeeds.state
local decay = VavaNeeds.decay
local consume = VavaNeeds.consume
local cfg = VavaNeeds.config

local function setup()
    -- T-132 : un config.lua d'avant 1.3.0 (gardé par une mise à jour) remplace la table de config_client.lua ; il
    -- contient tout ce que lit le serveur, le module démarre, mais un réglage client qu'on y change reste sans effet
    if cfg.clientFile ~= true then
        core.log.warn('config.lua garde la forme d\'avant 1.3.0 (il remplace la table de config_client.lua) : les '
            .. 'réglages lus par les joueurs sont dans config_client.lua ; reportez vos changements d\'après '
            .. 'config.lua.nouveau')
    end
    local ok, err = state.define()
    if not ok then return false, err end
    ok, err = consume.start()
    if not ok then return false, err end
    ok, err = decay.start()
    if not ok then return false, err end
    VavaNeeds.ready = true
    decay.adoptActive()
    return true
end

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(VavaNeeds.resource, 'version', 0),
    coreVersion = cfg.coreVersion,
    setup = setup,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end

-- un modificateur ne survit pas au module qui l'a posé
AddEventHandler('onResourceStop', function(resource)
    if resource ~= VavaNeeds.resource then decay.purgeOwner(resource) end
end)
