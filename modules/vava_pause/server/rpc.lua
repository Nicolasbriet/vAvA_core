--[[
    vava_pause/server/rpc.lua
    Rôle : intentions du client, en RPC à schéma strict et à débit limité :
      - `vava_pause:open(versionDesTouches)` : la seule demande à l'ouverture ; refus `not_ready`, `no_character`,
        `combat` (fenêtre de 10 s après un coup), `restrained` ou `busy` (crochet `vava_pause:opening`) ; à terre,
        bannière réduite (`{ downed = true }`) ;
      - `vava_pause:council(nature, texte, joindrePosition)` : demande au Conseil, texte normalisé ici, passée à
        vava_admin (position et témoins lus par lui, côté serveur) ;
      - `vava_pause:leave(mode)` : l'appelant seul est déconnecté, après le départ de la réponse.
    Dépendances : shared/constants.lua, config_client.lua, config.lua, shared/council.lua, server/core.lua,
                  bridge/server.lua, server/combat.lua, server/snapshot.lua
]]

local tostring, ipairs = tostring, ipairs
local SetTimeout, DropPlayer = SetTimeout, DropPlayer

local core = VavaPause.core
if not core then return end

local cfg = VavaPause.config
local RPC = VavaPause.RPC
local HOOKS = VavaPause.HOOKS
local KEPT = VavaPause.KEPT_REFUSALS
local bridge = VavaPause.bridge
local fight = VavaPause.fight
local compose = VavaPause.compose
local council = VavaPause.council
local limits = cfg.rateLimits

local KEYS_VERSION = { type = 'string', max = VavaPause.KEYS_VERSION.MAX, pattern = VavaPause.KEYS_VERSION.PATTERN }
local KIND = { type = 'string', enum = VavaPause.KINDS }
local TEXT = { type = 'string', min = 1, max = VavaPause.MAX_COUNCIL_TEXT }
local BOOL = { type = 'boolean' }
local MODE = { type = 'string', enum = VavaPause.LEAVE_MODES }

local rpc = {}
VavaPause.rpc = rpc

---@param src integer
---@param knownKeys string
local function open(src, knownKeys)
    if not VavaPause.ready then return false, 'not_ready' end
    local character = core.characters.getActive(src)
    if not character then return false, 'no_character' end
    if fight.remaining(src) > 0 then return false, 'combat' end
    local downed = bridge.isDowned(src)
    local allowed, reason = core.hooks.runBefore(HOOKS.OPENING, { source = src, characterId = character.id, downed = downed })
    if not allowed then return false, KEPT[reason] and reason or 'busy' end
    return true, compose.open(src, knownKeys, downed)
end

---@param src integer
---@param kind string
---@param text string
---@param withPosition boolean
local function writeCouncil(src, kind, text, withPosition)
    if not VavaPause.ready then return false, 'not_ready' end
    if not core.characters.getActive(src) then return false, 'no_character' end
    if not council.isKind(kind) then return false, 'invalid_kind' end
    local options = cfg.council
    local clean, code = council.normalize(text, {
        minChars = options.minChars, maxBytes = VavaPause.MAX_COUNCIL_TEXT, maxLines = options.maxLines,
    })
    if not clean then return false, code end
    local ok, value, seconds = bridge.submitRequest(src, kind, clean, withPosition)
    if not ok then return false, value, seconds end
    return true, value
end

---@param src integer
---@param mode string
local function leave(src, mode)
    local session = core.players.get(src)
    if not session then return false, 'no_session' end
    local accountId = session.accountId
    local message = cfg.leave.messages[mode]
    VavaPause.log.info('joueur %d : quitte Eldoria (%s)', src, mode)
    SetTimeout(cfg.leave.delayMs, function()
        -- le numéro peut avoir été repris entre-temps : seule la même session est déconnectée
        local current = core.players.get(src)
        if current and current.accountId == accountId then DropPlayer(tostring(src), message) end
    end)
    return true
end

--- Enregistre les RPC. Appelé pendant le setup.
---@return boolean ok
---@return string|nil err
function rpc.start()
    for _, def in ipairs({
        { RPC.OPEN, { KEYS_VERSION }, limits.open, open },
        { RPC.COUNCIL, { KIND, TEXT, BOOL }, limits.council, writeCouncil },
        { RPC.LEAVE, { MODE }, limits.leave, leave },
    }) do
        local ok, err = core.rpc.register(def[1], { args = def[2], rateLimit = def[3] }, def[4])
        if not ok then return false, def[1] .. ' : ' .. tostring(err) end
    end
    return true
end
