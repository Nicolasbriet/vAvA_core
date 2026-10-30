--[[
    server/init.lua
    Rôle : démarrage du core côté serveur. Seul fichier serveur à effets de bord : niveau de log, export,
           net events, connexion des joueurs, nettoyage sur déconnexion et arrêt de ressource, puis boot asynchrone.
    Séquence : config validée → RPC ouverts → oxmysql prêt → table de suivi + historique → migrations du core
               → core prêt (les modules en attente démarrent) → joueurs déjà connectés repris → boucles lentes.
    Dépendances : tous les fichiers server/core/, server/players/ et shared/
]]

local tonumber, tostring, xpcall = tonumber, tostring, xpcall
local traceback = debug.traceback
local AddEventHandler, CreateThread = AddEventHandler, CreateThread

local logger = vAvA.logger
local hooks = vAvA.hooks
local database = vAvA.database
local migrations = vAvA.migrations
local ratelimit = vAvA.ratelimit
local rpc = vAvA.rpc
local registry = vAvA.registry
local modules = vAvA.modules
local api = vAvA.api
local accounts = vAvA.accounts
local fields = vAvA.fields
local sync = vAvA.sync
local persistence = vAvA.persistence
local positions = vAvA.positions
local characters = vAvA.characters
local cfg = vAvA.config.server
local log = logger.create('core')

if not logger.setLevel(cfg.log.level) then
    log.warn("niveau de log inconnu '%s' dans config/server.lua : debug conservé", tostring(cfg.log.level))
end

--- Retire tout ce qu'un propriétaire a enregistré. Les hooks partent en premier : les notifications émises
--- par les purges suivantes (registre) ne sont jamais envoyées à la ressource qui s'arrête.
---@param owner string
local function purgeOwner(owner)
    hooks.purgeOwner(owner)
    rpc.purgeOwner(owner)
    registry.purgeOwner(owner)
    fields.purgeOwner(owner)
end

---@param reason string
local function failBoot(reason)
    log.error('démarrage impossible : %s. Aucun module ne sera démarré.', reason)
    modules.setCoreFailed(reason)
end

local function boot()
    database.awaitReady()

    local ok, err = migrations.bootstrap()
    if not ok then return failBoot(err) end

    ok, err = migrations.apply(vAvA.CORE_OWNER, vAvA.resourceName)
    if not ok then return failBoot('migrations du core : ' .. err) end

    -- journalisé avant le déblocage : résoudre la promesse relance aussitôt les modules en attente
    log.info('vAvA_core v%s prêt (API v%d)', vAvA.version, vAvA.apiVersion)
    modules.setCoreReady()

    accounts.adoptConnected()
    persistence.start(characters.forEachActive)
    positions.start(characters.forEachActive)
end

modules.setPurgeHandler(purgeOwner)
accounts.setHandlers({ prepare = characters.prepareSession, close = characters.handleClose })
api.register()
-- branché quoi qu'il arrive : si le core échoue, les connexions sont refusées proprement (message « indisponible »)
accounts.start()

AddEventHandler('playerDropped', function(reason)
    local src = tonumber(source)
    if not src then return end
    rpc.purgePlayer(src)
    ratelimit.purgePlayer(src)
    -- avant le déchargement : plus rien n'est envoyé à ce numéro, qui peut être redonné pendant la sauvegarde
    sync.purgePlayer(src)
    -- déchargement et sauvegarde du personnage (peut attendre la base), puis libération de la session
    accounts.handleDropped(src, tostring(reason))
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == vAvA.resourceName then
        -- FiveM n'attend pas les écritures lancées à l'arrêt : on prévient plutôt que de promettre une sauvegarde
        local unsaved = persistence.pendingCount()
        if unsaved > 0 then
            log.warn('%d personnage(s) avec des modifications non sauvegardées : lancez vava_saveall avant d\'arrêter', unsaved)
        end
        return
    end
    purgeOwner(resource)
    modules.handleStop(resource)
    api.forget(resource)
end)

local configOk, configErr = rpc.init()
if configOk then
    configOk, configErr = characters.registerRpc()
end
if not configOk then
    -- configuration invalide : aucun net event n'est ouvert, aucun joueur n'est accepté
    failBoot(configErr)
else
    rpc.start()
    sync.start()
    CreateThread(function()
        local ok, crash = xpcall(boot, traceback)
        if not ok then failBoot('erreur interne : ' .. tostring(crash)) end
    end)
end
