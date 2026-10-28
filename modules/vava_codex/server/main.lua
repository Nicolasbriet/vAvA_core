--[[
    vava_codex/server/main.lua
    Rôle : déclaration du module auprès du core (champ des préférences, commande du Codex au registre) et RPC du
           client (schéma strict, débit limité) : ouverture, valeurs d'un argument, signets, dernières pages, réglage.
    Dépendances : tous les fichiers server/ du module, bridge/server.lua
]]

local ipairs, tostring = ipairs, tostring

local core = VavaCodex.core
if not core then return end

local cfg = VavaCodex.config
local catalog = VavaCodex.catalog
local prefs = VavaCodex.prefs
local commands = VavaCodex.commands
local RPC = VavaCodex.RPC

local NAME = { type = 'string', min = 1, max = VavaCodex.MAX_NAME, pattern = VavaCodex.NAME_PATTERN }
local ACTION = { type = 'string', min = 0, max = VavaCodex.MAX_ACTION }   -- '' : forme nue
local INDEX = { type = 'integer', min = 1, max = VavaCodex.MAX_ARGS }
local BOOL = { type = 'boolean' }
local limits = cfg.rateLimits

--- Ouverture : tout ce que le joueur peut voir, ce qui reste à décrire (Conseil), ses préférences.
local function open(src)
    local current = prefs.get(src)
    if not current then return false, 'no_character' end
    local entries, chapters, staff = catalog.visible(src)
    return true, {
        entries = entries, chapters = chapters, staff = staff,
        undeclared = staff and catalog.undeclared() or {},
        prefs = current,
    }
end

local function favorite(src, name, on)
    if on then
        local ok, code = catalog.canRun(src, name)
        if not ok and code ~= 'console' then return false, code end
    end
    local ok, code, current = prefs.setFavorite(src, name, on)
    if not ok then return false, code end
    return true, current.favorites
end

--- Une commande vient d'être lancée (depuis le Codex ou tapée dans le chat) : dernières pages.
local function recent(src, name, action)
    local ok, code = catalog.canRun(src, name)
    if not ok then return false, code end
    local accepted, err, current = prefs.pushRecent(src, name, action ~= '' and action or nil)
    if not accepted then return false, err end
    return true, current.recent
end

local function keepOpen(src, value)
    local ok, code, current = prefs.setKeepOpen(src, value)
    if not ok then return false, code end
    return true, current.keepOpen
end

local RPCS = {
    { RPC.OPEN, {}, limits.open, open },
    { RPC.OPTIONS, { NAME, ACTION, INDEX }, limits.options, catalog.options },
    { RPC.FAVORITE, { NAME, BOOL }, limits.prefs, favorite },
    { RPC.RECENT, { NAME, ACTION }, limits.prefs, recent },
    { RPC.KEEP_OPEN, { BOOL }, limits.prefs, keepOpen },
}

local function setup()
    local ok, err = prefs.define()
    if not ok then return false, 'préférences : ' .. tostring(err) end
    ok, err = commands.declare()
    if not ok then return false, 'commandes : ' .. tostring(err) end
    for _, def in ipairs(RPCS) do
        ok, err = core.rpc.register(def[1], { args = def[2], rateLimit = def[3] }, def[4])
        if not ok then return false, def[1] .. ' : ' .. tostring(err) end
    end
    return true
end

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(VavaCodex.resource, 'version', 0),
    coreVersion = cfg.coreVersion,
    setup = setup,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end
