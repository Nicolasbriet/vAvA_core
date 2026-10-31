--[[
    vava_arrival/server/main.lua
    Rôle : déclaration du module auprès du core : commande au registre, config vérifiée (dotation, modules qui en
           déclarent des objets, chapitre du Codex), objets déclarés, journal purgé, accusé de lecture (RPC à schéma
           vide et débit limité), hooks du core (chargement : première venue reconnue ; apparition : dotation et
           accueil ; déchargement et départ : entrée oubliée ; retour de l'inventaire : objets redéclarés, dotations
           dues reprises ; annonce d'un module de `kit.providers` : dotations dues reprises), adoption des joueurs déjà
           en jeu (module redémarré), commande du Conseil. Aucune boucle.
    Dépendances : tous les fichiers server/ du module
]]

local type, ipairs, tostring = type, ipairs, tostring
local mathType = math.type

local core = VavaArrival.core
if not core then return end

local bridge = VavaArrival.bridge
local journal = VavaArrival.journal
local store = VavaArrival.store
local kit = VavaArrival.kit
local welcome = VavaArrival.welcome
local admin = VavaArrival.admin
local rules = VavaArrival.rules
local cfg = VavaArrival.config
local RPC = VavaArrival.RPC

--- Config lue au démarrage : une dotation ou un chapitre invalides refusent le module avec la raison.
---@return boolean ok
---@return string|nil err
local function checkConfig()
    local ok, code = rules.validateKit(cfg.kit.items)
    if not ok then return false, 'kit.items : ' .. tostring(code) end
    local cap = cfg.kit.perAccount
    if mathType(cap.max) ~= 'integer' or cap.max < 0 or type(cap.days) ~= 'number' or cap.days <= 0 then
        return false, 'kit.perAccount : max entier ≥ 0 et days > 0 attendus'
    end
    ok, code = rules.validateProviders(cfg.kit.providers)
    if not ok then return false, 'kit.providers : ' .. tostring(code) end
    if not rules.isId(cfg.codex.chapter) then return false, 'codex.chapter : identifiant attendu (64 octets, ^[%w_%-%.:]+$)' end
    return true
end

--- Reprend les personnages déjà joués (module redémarré en cours de partie) : leur ligne est relue, rien n'est envoyé.
--- Bloque le thread courant.
local function adoptActive()
    for _, src in ipairs(bridge.Players()) do
        local character = bridge.GetCharacter(src)
        if character then store.load(src, character.accountId, character.id, character.playSeconds, true) end
    end
end

local function setup()
    local declared, declareErr = VavaArrival.commands.declare()
    if not declared then return false, 'commandes : ' .. tostring(declareErr) end
    local ok, err = checkConfig()
    if not ok then return false, err end
    kit.declareItems()
    journal.purge()

    ok, err = core.rpc.register(RPC.WELCOMED, { args = {}, rateLimit = cfg.rateLimits.welcomed }, welcome.ack)
    if not ok then return false, RPC.WELCOMED .. ' : ' .. tostring(err) end

    for _, def in ipairs({
        { 'core:character:loaded', function(payload)
            store.load(payload.source, payload.accountId, payload.characterId, payload.playSeconds, false)
        end },
        { 'core:character:spawned', welcome.onSpawned },
        { 'core:character:unloading', function(payload) store.forget(payload.source) end },
        { 'core:player:dropped', function(payload)
            store.forget(payload.source)
            admin.forget(payload.source)
        end },
        -- l'inventaire redémarré a perdu nos objets : les redéclarer, puis reprendre les dotations dues ; un module qui
        -- déclare des objets de la dotation (kit.providers) devient prêt : reprendre les dotations dues
        { 'core:module:ready', function(payload)
            if payload.name ~= bridge.INVENTORY then
                welcome.onProviderReady(payload.name)
                return
            end
            kit.declareItems()
            welcome.onInventoryReady()
        end },
    }) do
        local id, hookErr = core.hooks.after(def[1], def[2])
        if not id then return false, def[1] .. ' : ' .. tostring(hookErr) end
    end

    adoptActive()
    admin.start()
    VavaArrival.ready = true
    return true
end

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(VavaArrival.resource, 'version', 0),
    coreVersion = cfg.coreVersion,
    dependencies = cfg.dependencies,
    setup = setup,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end
