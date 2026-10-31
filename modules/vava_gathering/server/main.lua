--[[
    vava_gathering/server/main.lua
    Rôle : déclaration du module auprès du core : catalogue (registre des outils, objets), journal, état des zones et
           des nœuds (chargé, puis déclaré entier aux abonnements de zone du core : une zone du core par zone de
           récolte), intentions du client (RPC à schéma strict et débit limité : commencer, interrompre, finir, ferrer,
           zones), joueurs partis, boucle lente d'écriture, de republication et de nouvel essai des zones refusées,
           commande du Conseil.
    Dépendances : tous les fichiers server/ du module
]]

local ipairs, tostring = ipairs, tostring
local sort = table.sort
local AddEventHandler, CreateThread, Wait = AddEventHandler, CreateThread, Wait

local core = VavaGathering.core
if not core then return end

local bridge = VavaGathering.bridge
local journal = VavaGathering.journal
local catalog = VavaGathering.catalog
local share = VavaGathering.share
local zonestate = VavaGathering.zonestate
local zones = VavaGathering.zones
local nodes = VavaGathering.nodes
local harvest = VavaGathering.harvest
local fishing = VavaGathering.fishing
local admin = VavaGathering.admin
local geometry = VavaGathering.geometry
local cfg = VavaGathering.config
local limits = cfg.rateLimits
local RPC = VavaGathering.RPC

local NODE = { type = 'string', min = 1, max = 48, pattern = VavaGathering.ID_PATTERN }
local TOKEN = { type = 'integer', min = 1, max = VavaGathering.MAX_TOKEN }
local BOOL = { type = 'boolean' }

--- Zones vues par un joueur, de la plus proche à la plus lointaine (distance lue côté serveur).
---@param src integer
---@return table[]
local function zonesFor(src)
    local x, y, z = bridge.Position(src)
    local list = {}
    for _, def in ipairs(catalog.zones()) do
        local view = zones.view(def)
        view.distance = x and math.floor(geometry.distance(x, y, z, def.x, def.y, def.z) + 0.5) or 0
        view.x, view.y, view.z, view.radius = nil, nil, nil, nil
        list[#list + 1] = view
    end
    sort(list, function(a, b) return a.distance < b.distance end)
    return list
end

---@param node vAvA.NodeDefinition
---@return integer|nil
local function publishedCharges(node)
    return nodes.published(node.id)
end

--- Déclare au core les zones de récolte (toutes, ou seulement celles qui ne le sont pas encore), avec leur état entier
--- tel que publié en dernier : bande, cicatrice, charges de chaque nœud. Une zone refusée est écrite en console par
--- share.lua et n'empêche pas les autres.
---@param missingOnly boolean
local function shareZones(missingOnly)
    for _, def in ipairs(catalog.zones()) do
        if not (missingOnly and share.isDeclared(def.id)) then
            local value = zones.published(def.id)
            if value then share.declare(def, zonestate.build(value, catalog.nodesOf(def.id), publishedCharges)) end
        end
    end
end

--- Écrit l'état modifié et republie ce qui a changé avec le temps. Bloque le thread courant.
local function flush()
    zones.tick()
    nodes.tick()
    shareZones(true)
    local queries = {}
    zones.collect(queries)
    nodes.collect(queries)
    if #queries == 0 then return end
    local ok, err = bridge.db.transaction(queries)
    if not ok then
        VavaGathering.log.error('écriture des zones et nœuds en échec (%d requête(s)), nouvel essai au prochain passage : %s', #queries, tostring(err))
        return
    end
    zones.markClean()
    nodes.markClean()
end

local function setup()
    -- T-132 : un config.lua d'avant 1.7.0 (gardé par une mise à jour) remplace la table de config_client.lua ; il
    -- contient tout ce que lit le serveur, le module démarre, mais un réglage client qu'on y change reste sans effet
    if cfg.clientFile ~= true then
        VavaGathering.log.warn('config.lua garde la forme d\'avant 1.7.0 (il remplace la table de config_client.lua) : '
            .. 'les réglages lus par les joueurs sont dans config_client.lua ; reportez vos changements d\'après '
            .. 'config.lua.nouveau')
    end
    local declared, declareErr = VavaGathering.commands.declare()
    if not declared then return false, 'commandes : ' .. tostring(declareErr) end
    local ok, err = catalog.define()
    if not ok then return false, 'catalogue : ' .. tostring(err) end
    journal.purge()
    ok, err = zones.load()
    if not ok then return false, 'zones : ' .. tostring(err) end
    ok, err = nodes.load()
    if not ok then return false, 'nœuds : ' .. tostring(err) end
    -- état relu (valeurs publiées posées), puis chaque zone déclarée entière : les joueurs proches la reçoivent
    zones.tick()
    nodes.tick()
    share.clearLegacy()
    shareZones(false)

    for _, def in ipairs({
        { RPC.BEGIN, { NODE }, limits.begin, harvest.begin },
        { RPC.CANCEL, { TOKEN }, limits.cancel, harvest.cancel },
        { RPC.FINISH, { TOKEN }, limits.finish, harvest.finish },
        { RPC.REEL, { TOKEN, BOOL }, limits.reel, fishing.reel },
        { RPC.ZONES, {}, limits.zones, function(src)
            if not bridge.GetCharacterId(src) then return false, 'no_character' end
            return true, zonesFor(src)
        end },
    }) do
        ok, err = core.rpc.register(def[1], { args = def[2], rateLimit = def[3] }, def[4])
        if not ok then return false, def[1] .. ' : ' .. tostring(err) end
    end

    for _, def in ipairs({
        { 'core:character:unloading', function(payload) harvest.forget(payload.source) end },
        { 'core:player:dropped', function(payload) harvest.forget(payload.source) end },
    }) do
        local id, hookErr = core.hooks.after(def[1], def[2])
        if not id then return false, hookErr end
    end

    CreateThread(function()
        -- boucle lente justifiée : au plus une transaction toutes les flushMs, et la republication des zones et
        -- nœuds qui se remettent avec le temps
        while true do
            Wait(cfg.persistence.flushMs)
            flush()
        end
    end)
    admin.start()
    VavaGathering.ready = true
    return true
end

-- arrêt du module : état écrit (une transaction) ; plus rien n'est envoyé (le core oublie nos zones de lui-même)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= VavaGathering.resource or not VavaGathering.ready then return end
    share.stop()
    flush()
end)

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(VavaGathering.resource, 'version', 0),
    coreVersion = cfg.coreVersion,
    dependencies = cfg.dependencies,
    setup = setup,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end
