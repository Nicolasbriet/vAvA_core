--[[
    vava_admin/server/main.lua
    Rôle : déclaration du module auprès du core : membres du Conseil chargés, journal purgé, bans vérifiés à la
           connexion, retour des membres partis en pleine observation, intentions du panneau, outils des autres
           modules, commandes de la console, oubli des joueurs partis ; à l'arrêt, les joueurs immobilisés sont libérés.
    Dépendances : tous les fichiers server/ du module
]]

local tostring = tostring
local CreateThread, AddEventHandler = CreateThread, AddEventHandler

local core = VavaAdmin.core
if not core then return end

local store = VavaAdmin.store
local staff = VavaAdmin.staff
local bans = VavaAdmin.bans
local reports = VavaAdmin.reports
local players = VavaAdmin.players
local spectate = VavaAdmin.spectate
local actions = VavaAdmin.actions
local rpc = VavaAdmin.rpc
local extensions = VavaAdmin.extensions
local console = VavaAdmin.console
local cfg = VavaAdmin.config

local function forget(payload)
    local src = payload.source
    if not src then return end
    players.forget(src)
    actions.forget(src)
    reports.forget(src)
    spectate.forget(src)
end

local function setup()
    -- T-132 : un config.lua d'avant 1.9.0 (gardé par une mise à jour) remplace la table de config_client.lua ; il
    -- contient tout ce que lit le serveur, le module démarre, mais un réglage client qu'on y change reste sans effet
    if VavaAdmin.config.clientFile ~= true then
        core.log.warn('config.lua garde la forme d\'avant 1.9.0 (il remplace la table de config_client.lua) : les '
            .. 'réglages lus par les joueurs sont dans config_client.lua ; reportez vos changements d\'après '
            .. 'config.lua.nouveau')
    end
    local declared, declareErr = VavaAdmin.commands.declare()
    if not declared then return false, 'commandes : ' .. tostring(declareErr) end
    local ok, err = staff.load()
    if not ok then return false, 'membres du Conseil : ' .. tostring(err) end
    ok, err = bans.start()
    if not ok then return false, err end
    ok, err = spectate.start()
    if not ok then return false, 'retour des observations : ' .. tostring(err) end
    local id
    id, err = core.hooks.after('core:player:dropped', forget)
    if not id then return false, err end
    ok, err = rpc.start()
    if not ok then return false, err end
    ok, err = extensions.start()
    if not ok then return false, 'outils des modules : ' .. tostring(err) end
    console.start()
    CreateThread(function()
        local purged, purgeErr = store.purgeLogs(cfg.logRetentionDays)
        if purgeErr then
            core.log.warn('journal non purgé : %s', tostring(purgeErr))
        elseif purged and purged > 0 then
            core.log.info('journal : %d entrée(s) de plus de %d jours retirée(s)', purged, cfg.logRetentionDays)
        end
    end)
    VavaAdmin.ready = true
    -- joueurs déjà en jeu (module ou core redémarré) : bans relus, sans retarder la fin du démarrage
    CreateThread(bans.sweep)
    return true
end

-- Arrêt (ou redémarrage) du module : personne ne reste immobilisé sans Registre pour le libérer.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= VavaAdmin.resource then return end
    local released = actions.releaseAll()
    if released > 0 then core.log.info('arrêt : %d joueur(s) immobilisé(s) libéré(s)', released) end
end)

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(VavaAdmin.resource, 'version', 0),
    coreVersion = cfg.coreVersion,
    setup = setup,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end
