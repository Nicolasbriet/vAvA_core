--[[
    vava_pause/server/keys.lua
    Rôle : touches du joueur montrées par la bannière (Réglages → Touches) : entrées `key` du registre `core:commands`,
           compactées une fois par changement du registre (crochets core:registry:*), avec une version
           `<démarrage>-<révision>` : le client garde la liste et ne la reçoit de nouveau que si la version a changé.
    Dépendances : shared/constants.lua, config.lua, shared/snapshot.lua, server/core.lua
]]

local tostring, ipairs, os_time = tostring, ipairs, os.time

local core = VavaPause.core
if not core then return end

local cfg = VavaPause.config.snapshot
local snapshot = VavaPause.snapshot
local REGISTRY = 'core:commands'

local keys = {}
VavaPause.keys = keys

local bootId = tostring(os_time())
local revision = 0
local cached = nil   -- liste compacte, recalculée à la demande après un changement

--- Version de la liste du moment (24 octets au plus, VavaPause.KEYS_VERSION).
---@return string
function keys.version()
    return bootId .. '-' .. revision
end

--- Liste compacte des touches (copie gardée : ne pas la modifier).
---@return table[]
function keys.list()
    if not cached then
        cached = snapshot.keys(core.registry.all(REGISTRY), cfg.keyScopes, cfg.maxKeys)
    end
    return cached
end

local function changed(payload)
    if payload.registry ~= REGISTRY then return end
    revision = revision + 1
    cached = nil
end

--- Abonnements aux changements du registre. Appelé pendant le setup.
---@return boolean ok
---@return string|nil err
function keys.listen()
    for _, name in ipairs({ 'core:registry:added', 'core:registry:removed', 'core:registry:dropped' }) do
        local id, err = core.hooks.after(name, changed)
        if not id then return false, name .. ' : ' .. tostring(err) end
    end
    return true
end
