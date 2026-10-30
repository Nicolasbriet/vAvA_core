--[[
    vava_crafting/server/main.lua
    Rôle : déclaration du module auprès du core : catalogue (registres, objets, recettes auprès des compétences),
           journal, poinçon, état des stations (une zone du core par station), intentions du client (RPC à schéma
           strict et débit limité), joueurs partis, garde de la signature (hook des métadonnées), boucle lente
           d'écriture, commande du Conseil.
    Dépendances : tous les fichiers server/ du module
]]

local ipairs, tostring = ipairs, tostring
local AddEventHandler, CreateThread, Wait = AddEventHandler, CreateThread, Wait

local core = VavaCrafting.core
if not core then return end

local bridge = VavaCrafting.bridge
local journal = VavaCrafting.journal
local catalog = VavaCrafting.catalog
local stations = VavaCrafting.stations
local signature = VavaCrafting.signature
local guard = VavaCrafting.guard
local crafting = VavaCrafting.crafting
local repair = VavaCrafting.repair
local admin = VavaCrafting.admin
local cfg = VavaCrafting.config
local limits = cfg.rateLimits
local RPC = VavaCrafting.RPC

local STATION = { type = 'string', min = 1, max = VavaCrafting.STATION_ID_MAX, pattern = VavaCrafting.ID_PATTERN }
local RECIPE = { type = 'string', min = 1, max = 64, pattern = VavaCrafting.ID_PATTERN }
local CHOICES = { type = 'map', max = 12, key = { type = 'string', min = 1, max = 64, pattern = '^[%w_]+$' }, value = { type = 'integer', min = 1, max = VavaCrafting.MAX_TIER }, optional = true }
local TOKEN = { type = 'integer', min = 1, max = VavaCrafting.MAX_TOKEN }
local QUANTITY = { type = 'integer', min = 1, max = 10000 }
local INSTANCE = { type = 'integer', min = 1, max = VavaCrafting.MAX_INSTANCE }
local GLYPH = { type = 'string', min = 1, max = 8 }
local NAME = { type = 'string', min = 1, max = cfg.masterpiece.nameMax * 4 }

--- Écrit le combustible modifié. Bloque le thread courant.
local function flush()
    local queries = {}
    stations.collect(queries)
    if #queries == 0 then return end
    local ok, err = bridge.db.transaction(queries)
    if not ok then
        VavaCrafting.log.error('écriture des stations en échec (%d requête(s)), nouvel essai au prochain passage : %s', #queries, tostring(err))
        return
    end
    stations.markClean()
end

local function setup()
    local declared, declareErr = VavaCrafting.commands.declare()
    if not declared then return false, 'commandes : ' .. tostring(declareErr) end
    local ok, err = catalog.define()
    if not ok then return false, 'catalogue : ' .. tostring(err) end
    journal.purge()
    ok, err = signature.define()
    if not ok then return false, 'poinçon : ' .. tostring(err) end
    ok, err = stations.load()
    if not ok then return false, 'stations : ' .. tostring(err) end
    -- une zone du core par station : les joueurs proches la reçoivent, eux seuls (abonnements de zone)
    stations.declareAll()

    for _, def in ipairs({
        { RPC.OPEN, { STATION }, limits.open, crafting.menu },
        { RPC.CRAFT, { STATION, RECIPE, CHOICES }, limits.craft, crafting.begin },
        { RPC.CANCEL, { TOKEN }, limits.cancel, crafting.cancel },
        { RPC.FINISH, { TOKEN }, limits.finish, crafting.finish },
        { RPC.FUEL, { STATION, QUANTITY }, limits.fuel, crafting.fuel },
        { RPC.REPAIR, { STATION, INSTANCE }, limits.repair, repair.begin },
        { RPC.MARK, { GLYPH }, limits.mark, signature.setMark },
        { RPC.NAME, { INSTANCE, NAME }, limits.name, signature.name },
    }) do
        ok, err = core.rpc.register(def[1], { args = def[2], rateLimit = def[3] }, def[4])
        if not ok then return false, def[1] .. ' : ' .. tostring(err) end
    end

    for _, def in ipairs({
        { 'core:character:unloading', function(payload) crafting.forget(payload.source) signature.forget(payload.source) end },
        { 'core:player:dropped', function(payload) crafting.forget(payload.source) signature.forget(payload.source) end },
    }) do
        local id, hookErr = core.hooks.after(def[1], def[2])
        if not id then return false, hookErr end
    end
    -- signature et solidité des objets d'artisan : aucun autre module ne les réécrit
    local guardId, guardErr = bridge.GuardMetadata(guard.onMetadata)
    if not guardId then return false, 'garde des métadonnées : ' .. tostring(guardErr) end

    CreateThread(function()
        -- boucle lente justifiée : au plus une transaction toutes les flushMs, rien si rien n'a changé
        while true do
            Wait(cfg.persistence.flushMs)
            flush()
        end
    end)
    admin.start()
    VavaCrafting.ready = true
    return true
end

-- arrêt du module : combustible écrit, stations libérées
AddEventHandler('onResourceStop', function(resource)
    if resource ~= VavaCrafting.resource or not VavaCrafting.ready then return end
    flush()
end)

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(VavaCrafting.resource, 'version', 0),
    coreVersion = cfg.coreVersion,
    dependencies = cfg.dependencies,
    setup = setup,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end
