--[[
    vava_pause/server/main.lua
    Rôle : déclaration du module auprès du core : touche au registre, fenêtre de combat (crochet vava_health:hit),
           révision des touches (crochets du registre), RPC ; fenêtre de combat oubliée au déchargement du personnage
           et au départ du joueur. Le module n'écrit rien en base et n'envoie aucun évènement aux clients.
    Dépendances : tous les fichiers server/ du module
]]

local tostring, ipairs = tostring, ipairs

local core = VavaPause.core
if not core then return end

local cfg = VavaPause.config
local fight = VavaPause.fight

local function forget(payload)
    if payload and payload.source then fight.forget(payload.source) end
end

local function setup()
    -- T-132 : un config.lua remplaçant la table de config_client.lua (gardé par une mise à jour) : le module démarre,
    -- mais un réglage client qu'on y change reste sans effet
    if cfg.clientFile ~= true then
        core.log.warn('config.lua remplace la table de config_client.lua : les réglages lus par les joueurs sont dans '
            .. 'config_client.lua ; reportez vos changements d\'après config.lua.nouveau')
    end
    local ok, err = VavaPause.commands.declare()
    if not ok then return false, 'commandes : ' .. tostring(err) end
    ok, err = fight.listen()
    if not ok then return false, err end
    ok, err = VavaPause.keys.listen()
    if not ok then return false, err end
    for _, name in ipairs({ 'core:character:unloading', 'core:player:dropped' }) do
        local id, hookErr = core.hooks.after(name, forget)
        if not id then return false, name .. ' : ' .. tostring(hookErr) end
    end
    ok, err = VavaPause.rpc.start()
    if not ok then return false, err end
    VavaPause.ready = true
    return true
end

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(VavaPause.resource, 'version', 0),
    coreVersion = cfg.coreVersion,
    setup = setup,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end
