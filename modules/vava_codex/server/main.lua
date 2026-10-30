--[[
    vava_codex/server/main.lua
    Rôle : déclaration du module auprès du core (champ des préférences, commande du Codex au registre) et RPC du
           client (schéma strict, débit limité) : ouverture (contenu et préférences renvoyés seulement s'ils ont changé
           depuis la version que le client dit avoir), valeurs d'un argument, signets, dernières pages, réglage.
    Dépendances : tous les fichiers server/ du module, shared/fingerprint.lua, bridge/server.lua
]]

local ipairs, tostring = ipairs, tostring

local core = VavaCodex.core
if not core then return end

local cfg = VavaCodex.config
local catalog = VavaCodex.catalog
local answerOpen = VavaCodex.answerOpen
local prefs = VavaCodex.prefs
local commands = VavaCodex.commands
local RPC = VavaCodex.RPC

local NAME = { type = 'string', min = 1, max = VavaCodex.MAX_NAME, pattern = VavaCodex.NAME_PATTERN }
local ACTION = { type = 'string', min = 0, max = VavaCodex.MAX_ACTION }   -- '' : forme nue
local INDEX = { type = 'integer', min = 1, max = VavaCodex.MAX_ARGS }
local BOOL = { type = 'boolean' }
local VERSION = { type = 'string', min = 0, max = VavaCodex.VERSION_LENGTH, pattern = VavaCodex.VERSION_PATTERN }   -- '' : rien
local limits = cfg.rateLimits

--- Ouverture : tout ce que le joueur peut voir et ce qui reste à décrire (Conseil), recalculé ici avec ses droits du
--- moment, et ses préférences. Chacun ne part que si son empreinte diffère de celle que le client a envoyée : une
--- version inventée ou ancienne ne fait que renvoyer le contenu complet, jamais plus que ce que le joueur peut voir.
---@param src integer
---@param knownVersion string  empreinte du contenu gardé par la page ('' : aucun)
---@param knownPrefsVersion string  empreinte des préférences gardées ('' : aucune)
local function open(src, knownVersion, knownPrefsVersion)
    local current = prefs.get(src)
    if not current then return false, 'no_character' end
    local entries, chapters, staff = catalog.visible(src)
    local content = { entries = entries, chapters = chapters, staff = staff, undeclared = staff and catalog.undeclared() or {} }
    local answer = answerOpen(content, current, knownVersion, knownPrefsVersion)
    -- trace de test en jeu (niveau debug du core) : ce qui part réellement à chaque ouverture
    VavaCodex.log.debug('ouverture (joueur %d) : contenu %s, préférences %s', src,
        answer.content and 'envoyé (' .. #entries .. ' entrées)' or 'gardé par la page', answer.prefs and 'envoyées' or 'gardées')
    return true, answer
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

--- Une commande vient d'être lancée (depuis le Codex ou tapée dans le chat) : dernières pages. Seule une
--- sous-commande déclarée est gardée : tapé dans le chat, le second mot n'est souvent qu'un argument (« /mp 12 … »).
local function recent(src, name, action)
    local ok, code, known = catalog.canRun(src, name, action)
    if not ok then return false, code end
    local accepted, err, current = prefs.pushRecent(src, name, known)
    if not accepted then return false, err end
    return true, current.recent
end

local function keepOpen(src, value)
    local ok, code, current = prefs.setKeepOpen(src, value)
    if not ok then return false, code end
    return true, current.keepOpen
end

local RPCS = {
    { RPC.OPEN, { VERSION, VERSION }, limits.open, open },
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
