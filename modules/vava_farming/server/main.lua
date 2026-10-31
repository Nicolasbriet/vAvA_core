--[[
    vava_farming/server/main.lua
    Rôle : déclaration du module auprès du core : catalogue (registre des cultures, objets, composteur), journal, état
           des emplacements et zones du core des parcelles (ancien state bag effacé), greniers, nuits de gel (vava_time), intentions du client (RPC à schéma strict et débit limité), joueurs partis,
           boucle lente d'écriture (emplacements, journal du grenier ; aussi à l'arrêt) et de republication (les plantes
           poussent), commande du Conseil.
    Dépendances : tous les fichiers server/ du module
]]

local ipairs, tostring = ipairs, tostring
local AddEventHandler, CreateThread, Wait = AddEventHandler, CreateThread, Wait

local core = VavaFarming.core
if not core then return end

local bridge = VavaFarming.bridge
local journal = VavaFarming.journal
local catalog = VavaFarming.catalog
local slots = VavaFarming.slots
local zones = VavaFarming.zones
local granary = VavaFarming.granary
local frost = VavaFarming.frost
local actions = VavaFarming.actions
local admin = VavaFarming.admin
local cfg = VavaFarming.config
local limits = cfg.rateLimits
local RPC = VavaFarming.RPC

local PARCEL = { type = 'string', min = 1, max = 32, pattern = VavaFarming.ID_PATTERN }
local WELL = { type = 'string', min = 1, max = 32, pattern = VavaFarming.ID_PATTERN }
local SLOT = { type = 'integer', min = 1, max = VavaFarming.MAX_SLOTS }
local ACTION = { type = 'string', enum = VavaFarming.ACTION_LIST }
local CROP = { type = 'string', max = 32, pattern = '^[%l%d_]*$' }   -- '' quand le geste n'en a pas besoin
local TIER = { type = 'integer', min = 0, max = VavaFarming.MAX_TIER }
local TOKEN = { type = 'integer', min = 1, max = VavaFarming.MAX_TOKEN }

--- Écrit l'état modifié et le journal du grenier en attente, en une seule transaction (à l'arrêt, FiveM ne reprend pas
--- un thread qui attend : seule la première requête lancée part), et republie ce qui a changé avec le temps. Bloque le
--- thread courant.
local function flush()
    slots.tick()
    local queries = {}
    local batch = slots.collect(queries)
    local logBatch = journal.collectGranary(queries)
    if #queries == 0 then return end
    local ok, err = bridge.db.transaction(queries)
    if ok then
        slots.markClean(batch)
    else
        slots.markFailed(batch)
        VavaFarming.log.error('écriture des emplacements et du journal du grenier en échec (%d requête(s)), nouvel essai au prochain passage : %s', #queries, tostring(err))
    end
    journal.granaryWritten(logBatch, ok == true)
end

local function setup()
    -- T-132 : un config.lua d'avant 1.8.0 (gardé par une mise à jour) remplace la table de config_client.lua ; il
    -- contient tout ce que lit le serveur, le module démarre, mais un réglage client qu'on y change reste sans effet
    if cfg.clientFile ~= true then
        VavaFarming.log.warn('config.lua garde la forme d\'avant 1.8.0 (il remplace la table de config_client.lua) : '
            .. 'les réglages lus par les joueurs sont dans config_client.lua ; reportez vos changements d\'après '
            .. 'config.lua.nouveau')
    end
    local declared, declareErr = VavaFarming.commands.declare()
    if not declared then return false, 'commandes : ' .. tostring(declareErr) end
    local ok, err = catalog.define()
    if not ok then return false, 'catalogue : ' .. tostring(err) end
    journal.purge()
    ok, err = slots.load()
    if not ok then return false, 'emplacements : ' .. tostring(err) end
    -- chaque parcelle devient une zone du core : seuls les joueurs proches la reçoivent (plus rien dans GlobalState)
    if not core.zones then return false, 'abonnements de zone absents (vAvA_core 0.11.0 au moins)' end
    zones.clearLegacy(catalog.parcels())
    slots.shareAll()
    ok, err = granary.start()
    if not ok then return false, 'greniers : ' .. tostring(err) end
    ok, err = frost.start()
    if not ok then return false, 'gel : ' .. tostring(err) end
    slots.tick()

    for _, def in ipairs({
        { RPC.OPEN, { PARCEL, SLOT }, limits.open, actions.menu },
        { RPC.BEGIN, { PARCEL, SLOT, ACTION, CROP, TIER }, limits.begin, function(src, parcelId, slot, action, crop, tier)
            return actions.begin(src, parcelId, slot, action, crop ~= '' and crop or nil, tier)
        end },
        { RPC.CANCEL, { TOKEN }, limits.cancel, actions.cancel },
        { RPC.FINISH, { TOKEN }, limits.finish, actions.finish },
        { RPC.FILL, { WELL }, limits.fill, actions.fill },
        { RPC.GRANARY, { PARCEL }, limits.granary, function(src, parcelId)
            if not bridge.GetCharacterId(src) then return false, 'no_character' end
            local parcel = catalog.parcel(parcelId)
            if not parcel then return false, 'unknown_parcel' end
            return granary.open(src, parcel)
        end },
    }) do
        ok, err = core.rpc.register(def[1], { args = def[2], rateLimit = def[3] }, def[4])
        if not ok then return false, def[1] .. ' : ' .. tostring(err) end
    end

    for _, def in ipairs({
        { 'core:character:unloading', function(payload) actions.forget(payload.source) end },
        { 'core:player:dropped', function(payload) actions.forget(payload.source) end },
    }) do
        local id, hookErr = core.hooks.after(def[1], def[2])
        if not id then return false, hookErr end
    end

    CreateThread(function()
        -- boucle lente justifiée : au plus une transaction toutes les flushMs, et la republication des stades qui
        -- changent avec le temps
        while true do
            Wait(cfg.persistence.flushMs)
            flush()
        end
    end)
    admin.start()
    VavaFarming.ready = true
    return true
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= VavaFarming.resource or not VavaFarming.ready then return end
    flush()
end)

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(VavaFarming.resource, 'version', 0),
    coreVersion = cfg.coreVersion,
    dependencies = cfg.dependencies,
    setup = setup,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end
