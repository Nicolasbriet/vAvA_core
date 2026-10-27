--[[
    vava_health/server/main.lua
    Rôle : déclaration du module auprès du core : champ de personnage, suivi de la vie, liens avec l'inventaire et les
           besoins, intentions du joueur (relever, rendre l'âme) en RPC sans argument et à débit limité.
    Dépendances : tous les fichiers server/ du module
]]

local tostring = tostring

local core = VavaHealth.core
if not core then return end

local state = VavaHealth.state
local life = VavaHealth.life
local assist = VavaHealth.assist
local links = VavaHealth.links
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

local function setup()
    local ok, err = state.define()
    if not ok then return false, err end
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

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(VavaHealth.resource, 'version', 0),
    coreVersion = cfg.coreVersion,
    setup = setup,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end
