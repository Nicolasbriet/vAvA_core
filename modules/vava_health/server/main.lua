--[[
    vava_health/server/main.lua
    Rôle : déclaration du module auprès du core : champ de personnage, registre des modificateurs de la chaîne de
           dégâts, journal des coups, annulation des dégâts natifs, suivi de la vie, liens avec l'inventaire et les
           besoins, intentions du joueur (relever, rendre l'âme) en RPC sans argument et à débit limité. À l'arrêt :
           vie de chaque personnage et journal en attente écrits.
    Dépendances : tous les fichiers server/ du module
]]

local tostring = tostring
local AddEventHandler = AddEventHandler

local core = VavaHealth.core
if not core then return end

local state = VavaHealth.state
local life = VavaHealth.life
local assist = VavaHealth.assist
local links = VavaHealth.links
local modifiers = VavaHealth.modifiers
local journal = VavaHealth.journal
local natives = VavaHealth.natives
local hits = VavaHealth.hits
local cfg = VavaHealth.config
local RPC = VavaHealth.RPC

---@param src integer
---@return boolean ok
---@return string|nil code
local function giveUp(src)
    local entry = life.entry(src)
    if not entry or not entry.downed then return false, 'not_downed' end
    if entry.downedFor < cfg.downed.giveUpAfterMs then return false, 'too_early' end
    return life.respawn(src, 'choice')
end

---@param payload table  { source, … }
local function onDropped(payload)
    if not payload.source then return end
    hits.forget(payload.source)
    natives.forget(payload.source)
end

local function setup()
    -- T-132 : un config.lua d'avant 1.5.0 (gardé par une mise à jour) remplace la table de config_client.lua ; il
    -- contient tout ce que lit le serveur, le module démarre, mais un réglage client qu'on y change reste sans effet
    if VavaHealth.config.clientFile ~= true then
        core.log.warn('config.lua garde la forme d\'avant 1.5.0 (il remplace la table de config_client.lua) : les '
            .. 'réglages lus par les joueurs sont dans config_client.lua ; reportez vos changements d\'après '
            .. 'config.lua.nouveau')
    end
    local declared, declareErr = VavaHealth.commands.declare()
    if not declared then return false, 'commandes : ' .. tostring(declareErr) end
    local ok, err = state.define()
    if not ok then return false, err end
    ok, err = modifiers.start()
    if not ok then return false, 'registre des modificateurs : ' .. tostring(err) end
    ok, err = modifiers.define()
    if not ok then return false, 'registre des modificateurs : ' .. tostring(err) end
    local id
    id, err = core.hooks.after('core:player:dropped', onDropped)
    if not id then return false, err end
    journal.start()
    natives.start()
    ok, err = life.start()
    if not ok then return false, err end
    ok, err = links.start()
    if not ok then return false, err end
    ok, err = core.rpc.register(RPC.ASSIST, { args = {}, rateLimit = cfg.rateLimits.assist }, assist.start)
    if not ok then return false, err end
    ok, err = core.rpc.register(RPC.GIVE_UP, { args = {}, rateLimit = cfg.rateLimits.giveUp }, giveUp)
    if not ok then return false, err end
    VavaHealth.ready = true
    life.adoptActive()
    return true
end

-- arrêt du module : la vie de chaque personnage (écriture différée des coups) et le journal en attente sont écrits ;
-- l'API du core reste servie pendant `stopping`
AddEventHandler('onResourceStop', function(resource)
    if resource ~= VavaHealth.resource or not VavaHealth.ready then return end
    VavaHealth.ready = false
    life.persistAll()
    journal.flushAll()
end)

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(VavaHealth.resource, 'version', 0),
    coreVersion = cfg.coreVersion,
    setup = setup,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end
